// Audio through on AAudio: the FM-1's USB audio input, the phone's current output, through ThroughCore.
//
// Two streams, one callback (the full-duplex pattern Oboe's FullDuplexStream uses, written on AAudio directly so the
// app needs no extra library): the OUTPUT stream runs a data callback; the INPUT stream has none, and the output's
// callback reads it non-blocking (timeout 0) before it fills its buffer. Both ask for low-latency performance and
// exclusive sharing (MMAP, where the phone and the device allow it; AAudio falls back to shared on its own, and what
// was granted is read back for the stats).
//
// Rates: the input opens at the rate asked for, or, with 0, at whatever the phone gives (its USB path's own rate, so
// nothing resamples before us). The output opens at the phone's native rate. ThroughCore resamples between them and
// absorbs the jitter and the clock drift.
//
// A disconnect (the FM-1 unplugged, headphones in or out, Bluetooth connecting) arrives in the error callback; the
// streams can't be reopened from there, so it only raises a flag, and the Kotlin side restarts from its own thread.
#include <aaudio/AAudio.h>
#include <android/log.h>
#include <jni.h>
#include <time.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <string>

#include "through_core.h"

#define LOG_TAG "LupeThrough"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

namespace {

int64_t nowNanos() {
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return int64_t(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
}

// Indices of the stats array the Kotlin side reads (ThroughNative.kt mirrors them).
enum Stat {
    S_RUNNING, S_DISCONNECTED, S_IN_RATE, S_OUT_RATE, S_IN_EXCLUSIVE, S_OUT_EXCLUSIVE, S_OUT_LOW_LATENCY, S_OUT_BURST,
    S_OUT_BUFFER, S_IN_DEVICE, S_OUT_DEVICE, S_IN_LATENCY_MS, S_RING_MS, S_FILTER_MS, S_OUT_LATENCY_MS, S_TOTAL_MS,
    S_TARGET_MS, S_JITTER_MS, S_RATIO_PPM, S_UNDERRUNS, S_CATCHUPS, S_OVERFLOWS, S_ZERO_RUNS, S_REPEAT_RUNS,
    S_IN_XRUNS, S_OUT_XRUNS, S_FRAMES_IN, S_FRAMES_OUT, S_PLAYING, S_CALLBACKS, S_IN_CHANNELS, S_PEAK,
    S_TS_FLAGS,      // bit 0: the input gave a timestamp, bit 1: the output did (else the latency is from buffer fill)
    S_LAST_ERROR,    // the last error callback's AAudio code (0: none)
    S_LAST_ERROR_INPUT,  // 1: that error came from the input stream
    S_COUNT
};

class Engine {
public:
    ~Engine() { stop(); }

    /** Opens and starts both streams. Returns 0, or an AAudio error (negative). */
    int start(int inDevice, int inRate, bool exclusiveIn, bool exclusiveOut, int outDevice) {
        std::lock_guard<std::mutex> g(lock_);
        closeLocked();
        disconnected_ = false;
        lastErrorCode_ = 0;
        error_.clear();

        // the output first: its rate is the phone's native rate, and it drives everything
        AAudioStreamBuilder *b = nullptr;
        if (int r = AAudio_createStreamBuilder(&b); r != AAUDIO_OK) return fail("createStreamBuilder", r);
        AAudioStreamBuilder_setDirection(b, AAUDIO_DIRECTION_OUTPUT);
        AAudioStreamBuilder_setPerformanceMode(b, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
        AAudioStreamBuilder_setSharingMode(b, exclusiveOut ? AAUDIO_SHARING_MODE_EXCLUSIVE : AAUDIO_SHARING_MODE_SHARED);
        AAudioStreamBuilder_setFormat(b, AAUDIO_FORMAT_PCM_FLOAT);
        AAudioStreamBuilder_setChannelCount(b, 2);
        AAudioStreamBuilder_setUsage(b, AAUDIO_USAGE_MEDIA);
        AAudioStreamBuilder_setContentType(b, AAUDIO_CONTENT_TYPE_MUSIC);
        if (outDevice > 0) AAudioStreamBuilder_setDeviceId(b, outDevice);
        AAudioStreamBuilder_setDataCallback(b, &Engine::dataCb, this);
        AAudioStreamBuilder_setErrorCallback(b, &Engine::errorCb, this);
        int r = AAudioStreamBuilder_openStream(b, &out_);
        AAudioStreamBuilder_delete(b);
        if (r != AAUDIO_OK) return fail("open output", r);
        outRate_ = AAudioStream_getSampleRate(out_);
        burst_ = AAudioStream_getFramesPerBurst(out_);
        // two bursts to start; an output underrun adds one (as Oboe's LatencyTuner does)
        AAudioStream_setBufferSizeInFrames(out_, 2 * burst_);

        // the input: the FM-1, no callback (the output's callback reads it)
        if (int r2 = AAudio_createStreamBuilder(&b); r2 != AAUDIO_OK) return fail("createStreamBuilder", r2);
        AAudioStreamBuilder_setDirection(b, AAUDIO_DIRECTION_INPUT);
        AAudioStreamBuilder_setPerformanceMode(b, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
        AAudioStreamBuilder_setSharingMode(b, exclusiveIn ? AAUDIO_SHARING_MODE_EXCLUSIVE : AAUDIO_SHARING_MODE_SHARED);
        AAudioStreamBuilder_setFormat(b, AAUDIO_FORMAT_PCM_FLOAT);
        AAudioStreamBuilder_setChannelCount(b, 2);
        // VOICE_PERFORMANCE: the low-latency input path, no voice processing (UNPROCESSED is not always low-latency)
        AAudioStreamBuilder_setInputPreset(b, AAUDIO_INPUT_PRESET_VOICE_PERFORMANCE);
        if (inRate > 0) AAudioStreamBuilder_setSampleRate(b, inRate);
        if (inDevice > 0) AAudioStreamBuilder_setDeviceId(b, inDevice);
        AAudioStreamBuilder_setErrorCallback(b, &Engine::errorCb, this);
        r = AAudioStreamBuilder_openStream(b, &in_);
        AAudioStreamBuilder_delete(b);
        if (r != AAUDIO_OK) { int e = fail("open input", r); closeLocked(); return e; }
        inRate_ = AAudioStream_getSampleRate(in_);
        inChannels_ = AAudioStream_getChannelCount(in_);
        // hold as much as the input can: the callback drains it every time, and a bigger buffer only matters in a stall
        AAudioStream_setBufferSizeInFrames(in_, AAudioStream_getBufferCapacityInFrames(in_));

        through::ThroughCore::Config c;
        c.inRate = inRate_;
        c.outRate = outRate_;
        core_ = std::make_unique<through::ThroughCore>(c);
        inBuf_.assign(size_t(std::max(4096, AAudioStream_getBufferCapacityInFrames(in_))) * 2, 0.f);
        lastOutXruns_ = 0;
        callbacks_ = 0;
        framesRead_ = 0;
        framesWritten_ = 0;

        if ((r = AAudioStream_requestStart(in_)) != AAUDIO_OK) { int e = fail("start input", r); closeLocked(); return e; }
        if ((r = AAudioStream_requestStart(out_)) != AAUDIO_OK) { int e = fail("start output", r); closeLocked(); return e; }
        running_ = true;
        LOGI("started: in dev %d %d Hz %d ch %s, out dev %d %d Hz burst %d %s",
             AAudioStream_getDeviceId(in_), inRate_, inChannels_, sharing(in_), AAudioStream_getDeviceId(out_), outRate_, burst_, sharing(out_));
        return 0;
    }

    void stop() {
        std::lock_guard<std::mutex> g(lock_);
        closeLocked();
    }

    /** Fills `s` (S_COUNT doubles). Called from the Kotlin side a few times a second, never from the audio thread. */
    void stats(double *s) {
        std::lock_guard<std::mutex> g(lock_);
        for (int i = 0; i < S_COUNT; i++) s[i] = 0;
        s[S_DISCONNECTED] = disconnected_.load() ? 1 : 0;
        s[S_LAST_ERROR] = lastErrorCode_.load();
        s[S_LAST_ERROR_INPUT] = lastErrorInput_.load() ? 1 : 0;
        if (!running_ || !in_ || !out_ || !core_) return;
        s[S_RUNNING] = 1;
        s[S_IN_RATE] = inRate_;
        s[S_OUT_RATE] = outRate_;
        s[S_IN_EXCLUSIVE] = AAudioStream_getSharingMode(in_) == AAUDIO_SHARING_MODE_EXCLUSIVE;
        s[S_OUT_EXCLUSIVE] = AAudioStream_getSharingMode(out_) == AAUDIO_SHARING_MODE_EXCLUSIVE;
        s[S_OUT_LOW_LATENCY] = AAudioStream_getPerformanceMode(out_) == AAUDIO_PERFORMANCE_MODE_LOW_LATENCY;
        s[S_OUT_BURST] = burst_;
        s[S_OUT_BUFFER] = AAudioStream_getBufferSizeInFrames(out_);
        s[S_IN_DEVICE] = AAudioStream_getDeviceId(in_);
        s[S_OUT_DEVICE] = AAudioStream_getDeviceId(out_);
        s[S_IN_CHANNELS] = inChannels_;
        int64_t now = nowNanos();
        // input: how old the newest frame we've read is (a frame position at a time, from the stream's timestamp)
        int64_t pos = 0, t = 0;
        double inMs = -1, outMs = -1;
        int tsFlags = 0;
        if (AAudioStream_getTimestamp(in_, CLOCK_MONOTONIC, &pos, &t) == AAUDIO_OK) {
            tsFlags |= 1;
            // AAudio's own count, in the timestamp's frame base (ours would drift from it when the input drops frames)
            int64_t read = AAudioStream_getFramesRead(in_);
            inMs = (now - t) / 1e6 - double(read - pos) * 1000.0 / inRate_;
            if (inMs < 0) inMs = 0;
        }
        // output: frames written but not yet heard
        if (AAudioStream_getTimestamp(out_, CLOCK_MONOTONIC, &pos, &t) == AAUDIO_OK) {
            tsFlags |= 2;
            double played = pos + double(now - t) * outRate_ / 1e9;
            outMs = (double(AAudioStream_getFramesWritten(out_)) - played) * 1000.0 / outRate_;
            if (outMs < 0) outMs = 0;
        }
        // no timestamp (some MMAP paths give none at first, or ever): what waits in the stream's buffer, plus one burst
        if (inMs < 0) {
            int64_t waiting = AAudioStream_getFramesWritten(in_) - AAudioStream_getFramesRead(in_);
            inMs = double(std::max<int64_t>(0, waiting) + AAudioStream_getFramesPerBurst(in_)) * 1000.0 / inRate_;
        }
        if (outMs < 0) {
            int64_t queued = AAudioStream_getFramesWritten(out_) - AAudioStream_getFramesRead(out_);
            outMs = double(std::max<int64_t>(0, queued) + burst_) * 1000.0 / outRate_;
        }
        s[S_TS_FLAGS] = tsFlags;
        s[S_LAST_ERROR] = lastErrorCode_.load();
        snapLock_.lock();
        through::CoreStats c = snap_;
        snapLock_.unlock();
        double ringMs = c.fillMean * 1000.0 / inRate_;
        s[S_IN_LATENCY_MS] = inMs;
        s[S_RING_MS] = ringMs;
        s[S_FILTER_MS] = core_->filterDelayMs();
        s[S_OUT_LATENCY_MS] = outMs;
        s[S_TOTAL_MS] = inMs + ringMs + core_->filterDelayMs() + outMs;
        s[S_TARGET_MS] = c.target * 1000.0 / inRate_;
        s[S_JITTER_MS] = c.jitter * 1000.0 / inRate_;
        s[S_RATIO_PPM] = c.ratioPpm;
        s[S_UNDERRUNS] = double(c.underruns);
        s[S_CATCHUPS] = double(c.catchUps);
        s[S_OVERFLOWS] = double(c.overflows);
        s[S_ZERO_RUNS] = double(c.zeroRuns);
        s[S_REPEAT_RUNS] = double(c.repeatRuns);
        s[S_IN_XRUNS] = AAudioStream_getXRunCount(in_);
        s[S_OUT_XRUNS] = AAudioStream_getXRunCount(out_);
        s[S_FRAMES_IN] = double(c.framesIn);
        s[S_FRAMES_OUT] = double(c.framesOut);
        s[S_PLAYING] = c.playing ? 1 : 0;
        s[S_CALLBACKS] = double(callbacks_.load());
        s[S_PEAK] = peak_.exchange(0.f);
    }

    std::string error() {
        std::lock_guard<std::mutex> g(lock_);
        return error_;
    }

private:
    static aaudio_data_callback_result_t dataCb(AAudioStream *, void *user, void *audio, int32_t frames) {
        return static_cast<Engine *>(user)->onAudio(static_cast<float *>(audio), frames);
    }
    static void errorCb(AAudioStream *stream, void *user, aaudio_result_t err) {
        auto *e = static_cast<Engine *>(user);
        const char *which = stream == e->in_ ? "input" : stream == e->out_ ? "output" : "old";
        LOGW("%s stream error %s: the Kotlin side restarts", which, AAudio_convertResultToText(err));
        e->lastErrorCode_ = err;
        e->lastErrorInput_ = stream == e->in_;
        e->disconnected_ = true;
    }

    aaudio_data_callback_result_t onAudio(float *y, int32_t frames) {
        callbacks_++;
        // everything the input has (non-blocking)
        const int cap = int(inBuf_.size() / 2);
        float peak = peak_.load();
        for (;;) {
            int n = AAudioStream_read(in_, inBuf_.data(), cap, 0);
            if (n <= 0) break;
            if (inChannels_ == 1) {   // a mono input: spread it to both sides, from the end so it can run in place
                for (int i = n - 1; i >= 0; i--) { inBuf_[2 * i + 1] = inBuf_[i]; inBuf_[2 * i] = inBuf_[i]; }
            }
            for (int i = 0; i < 2 * n; i++) peak = std::max(peak, std::fabs(inBuf_[i]));
            core_->push(inBuf_.data(), n);
            framesRead_ += n;
            if (n < cap) break;
        }
        peak_.store(peak);
        core_->pull(y, frames);
        framesWritten_ += frames;
        // the output underran: one burst more of buffer, up to its capacity
        int32_t x = AAudioStream_getXRunCount(out_);
        if (x > lastOutXruns_) {
            lastOutXruns_ = x;
            int32_t want = AAudioStream_getBufferSizeInFrames(out_) + burst_;
            AAudioStream_setBufferSizeInFrames(out_, std::min(want, AAudioStream_getBufferCapacityInFrames(out_)));
        }
        // a copy for the stats, without blocking the audio thread (skipped if the reader holds it)
        if (snapLock_.try_lock()) { snap_ = core_->stats(); snapLock_.unlock(); }
        return AAUDIO_CALLBACK_RESULT_CONTINUE;
    }

    int fail(const char *what, int r) {
        error_ = std::string(what) + ": " + AAudio_convertResultToText(r);
        LOGW("%s", error_.c_str());
        return r < 0 ? r : -1;
    }

    static const char *sharing(AAudioStream *s) {
        return AAudioStream_getSharingMode(s) == AAUDIO_SHARING_MODE_EXCLUSIVE ? "exclusive" : "shared";
    }

    void closeLocked() {
        running_ = false;
        // stop, wait until it has (so no callback is still running), then close
        for (AAudioStream **s : {&out_, &in_}) {
            if (!*s) continue;
            AAudioStream_requestStop(*s);
            aaudio_stream_state_t next = AAUDIO_STREAM_STATE_UNINITIALIZED;
            AAudioStream_waitForStateChange(*s, AAUDIO_STREAM_STATE_STOPPING, &next, 200 * 1000000LL);
            AAudioStream_close(*s);
            *s = nullptr;
        }
        core_.reset();
    }

    std::mutex lock_;
    AAudioStream *in_ = nullptr, *out_ = nullptr;
    std::unique_ptr<through::ThroughCore> core_;
    std::vector<float> inBuf_;
    int inRate_ = 0, outRate_ = 0, burst_ = 0, inChannels_ = 2;
    int32_t lastOutXruns_ = 0;
    bool running_ = false;
    std::atomic<bool> disconnected_{false};
    std::atomic<int> lastErrorCode_{0};
    std::atomic<bool> lastErrorInput_{false};
    std::atomic<int64_t> callbacks_{0}, framesRead_{0}, framesWritten_{0};
    std::atomic<float> peak_{0.f};
    // a spin-free try-lock copy of the core's stats for the reader
    std::mutex snapLock_;
    through::CoreStats snap_;
    std::string error_;
};

Engine &engine() {
    static Engine e;
    return e;
}

}  // namespace

extern "C" {

JNIEXPORT jint JNICALL Java_com_scottgerstl_lupe_audio_ThroughNative_nativeStart(
    JNIEnv *, jclass, jint inDevice, jint inRate, jboolean exclusiveIn, jboolean exclusiveOut, jint outDevice) {
    return engine().start(inDevice, inRate, exclusiveIn, exclusiveOut, outDevice);
}

JNIEXPORT void JNICALL Java_com_scottgerstl_lupe_audio_ThroughNative_nativeStop(JNIEnv *, jclass) { engine().stop(); }

JNIEXPORT void JNICALL Java_com_scottgerstl_lupe_audio_ThroughNative_nativeStats(JNIEnv *env, jclass, jdoubleArray out) {
    double s[S_COUNT];
    engine().stats(s);
    jsize n = std::min<jsize>(env->GetArrayLength(out), S_COUNT);
    env->SetDoubleArrayRegion(out, 0, n, s);
}

JNIEXPORT jstring JNICALL Java_com_scottgerstl_lupe_audio_ThroughNative_nativeError(JNIEnv *env, jclass) {
    return env->NewStringUTF(engine().error().c_str());
}

JNIEXPORT jint JNICALL Java_com_scottgerstl_lupe_audio_ThroughNative_nativeStatCount(JNIEnv *, jclass) { return S_COUNT; }

}  // extern "C"

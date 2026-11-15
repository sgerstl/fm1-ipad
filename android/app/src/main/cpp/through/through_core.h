// Audio through: the FM-1's USB audio in, the phone's output out. The portable part (no Android in it), so the
// host test (tests/through_test.cpp) runs it against simulated FM-1 packet streams. through_engine.cpp wraps it in
// AAudio streams.
//
// One thread does everything: the output stream's callback reads whatever input has arrived (non-blocking) into
// the ring, then the resampler pulls exactly the frames the output asked for. Nothing here allocates or locks
// after construction.
//
// Three parts:
//  * Ring: the input frames, stereo float, indexed by absolute frame numbers.
//  * Resampler: windowed-sinc polyphase (32 taps, 256 phases interpolated), any ratio, the ratio nudged per
//    callback. It reads the FM-1 at whatever rate the stream gives (44.1 or 48 kHz) and writes the output's rate.
//  * Drift and jitter: a PI loop holds the ring's mean fill on a target by nudging the ratio (at most ±0.2 %, about 3.5
//    cents, inaudible); the target follows the jitter actually seen (how far the fill dips below its mean), grows
//    on an underrun, and shrinks slowly while things stay calm. That is the adaptive buffer: as small as the
//    stream allows, and no smaller.
//
// And one diagnostic: the FM-1 dithers its output, so exact digital zeros or exactly repeated frames in the middle
// of a signal were not sent by the FM-1. They come from the phone's USB audio path filling a gap (the Pixel's HAL
// logs "USB RX Dejitter underrun"). Counting them tells the phone's dropouts apart from ours.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <vector>

namespace through {

constexpr int kTapsHalf = 16;                 // zero crossings each side
constexpr int kTaps = 2 * kTapsHalf;          // 32
constexpr int kPhases = 256;

/** Windowed-sinc prototype, tabulated per phase. Pure function of the cutoff. */
class SincTable {
public:
    /** cutoff: in cycles per input sample (0.5 = the input's Nyquist). */
    explicit SincTable(double cutoff, double beta = 9.0) : table_((kPhases + 1) * kTaps) {
        const double i0b = bessel0(beta);
        for (int p = 0; p <= kPhases; p++) {
            double sum = 0;
            float *row = &table_[p * kTaps];
            for (int j = 0; j < kTaps; j++) {
                double x = (j - kTapsHalf + 1) - double(p) / kPhases;   // the tap's distance from the output instant
                double s = (x == 0) ? 2 * cutoff : std::sin(2 * M_PI * cutoff * x) / (M_PI * x);
                double r = x / kTapsHalf;                                // -1..1 across the window
                double w = (std::fabs(r) >= 1) ? 0 : bessel0(beta * std::sqrt(1 - r * r)) / i0b;
                row[j] = float(s * w);
                sum += s * w;
            }
            for (int j = 0; j < kTaps; j++) row[j] = float(row[j] / sum);   // unity gain at DC for every phase
        }
    }
    const float *row(int p) const { return &table_[p * kTaps]; }

private:
    static double bessel0(double x) {
        double s = 1, t = 1;
        for (int k = 1; k < 40; k++) { t *= (x / (2 * k)) * (x / (2 * k)); s += t; }
        return s;
    }
    std::vector<float> table_;
};

/** What the core reports (read by the engine for the stats; plain values, the engine copies them out). */
struct CoreStats {
    double fillMean = 0;        // frames, input rate
    double target = 0;          // frames, input rate
    double jitter = 0;          // frames: the deepest recent dip below the mean
    double ratioPpm = 0;        // the PI loop's correction
    int64_t underruns = 0;      // output asked for frames the ring didn't have (we played silence)
    int64_t catchUps = 0;       // the ring held far too much (a stall's backlog): skipped to the target
    int64_t overflows = 0;      // input arrived with no room (the output had stopped pulling)
    int64_t zeroRuns = 0;       // exact-zero runs inside a signal: the phone's USB path filled a gap
    int64_t repeatRuns = 0;     // exactly repeated frames inside a signal: likewise
    int64_t framesIn = 0, framesOut = 0;
    bool blind = false;         // no non-zero input for 0.5 s: undithered silence, gaps can't be seen
    bool playing = false;       // primed and pulling (false while it fills up at the start or after an underrun)
};

class ThroughCore {
public:
    struct Config {
        int inRate = 48000;
        int outRate = 48000;
        int ringFrames = 16384;       // power of two; ~340 ms at 48 kHz
        double minTargetMs = 1.0;     // the target never goes below this
        double maxTargetMs = 120.0;   // ... nor above this
        double safetyMs = 1.0;        // added to the measured jitter
        double jitterHalfLifeS = 30;  // how long a bad patch keeps the buffer up
        double maxPpm = 2000;         // the ratio nudge's limit (0.2 %, 3.5 cents)
    };

    explicit ThroughCore(const Config &c)
        : cfg_(c), mask_(c.ringFrames - 1), ring_(size_t(c.ringFrames) * 2),
          table_(0.5 * std::min(1.0, double(c.outRate) / c.inRate) * 0.91) {
        step0_ = double(c.inRate) / c.outRate;
        minTarget_ = c.minTargetMs * c.inRate / 1000.0;
        maxTarget_ = c.maxTargetMs * c.inRate / 1000.0;
        safety_ = c.safetyMs * c.inRate / 1000.0;
        target_ = std::max(minTarget_, 3.0 * c.inRate / 1000.0);   // start at 3 ms; it settles from there
        // the ring starts as silence (the vector is zeroed): the window's history, then the frames the first output
        // frame needs ahead
        rd_ = kTapsHalf - 1;
        w_ = rd_ + kTapsHalf;
    }

    /** Input frames as they arrive (interleaved stereo float). */
    void push(const float *x, int frames) {
        for (int i = 0; i < frames; i++) {
            float l = x[2 * i], r = x[2 * i + 1];
            detect(l, r);
            // room: frames older than the window's start (rd_ - kTapsHalf + 1) may be overwritten
            if (w_ - (rd_ - kTapsHalf + 1) >= cfg_.ringFrames) { st_.overflows++; continue; }
            ring_[size_t(w_ & mask_) * 2] = l;
            ring_[size_t(w_ & mask_) * 2 + 1] = r;
            w_++;
        }
        st_.framesIn += frames;
    }

    /** Frames ahead of the read point that the resampler can still use (input rate). */
    double fill() const { return double(w_ - rd_ - kTapsHalf) - frac_; }

    /** The output callback: exactly `frames` interleaved stereo frames into y. */
    void pull(float *y, int frames) {
        double f0 = fill();
        // the fill just before this callback's input arrived is not visible here; the low point the controller
        // cares about is after this pull, measured below
        if (!st_.playing) {
            // filling up: silence until the ring holds the target plus one callback's worth
            if (f0 >= target_ + frames * step0_) { st_.playing = true; mean_ = f0; integ_ = 0; }
            else { std::memset(y, 0, sizeof(float) * 2 * frames); st_.framesOut += frames; return; }
        }
        // backlog (a stall, or the start's stale input): jump to the target rather than play it all late
        double tooMuch = target_ + std::max(4 * jitter_, 20.0 * cfg_.inRate / 1000.0) + frames * step0_;
        if (f0 > tooMuch) {
            int64_t skip = int64_t(f0 - target_ - frames * step0_);
            rd_ += skip;
            mean_ = fill();
            integ_ = 0;
            st_.catchUps++;
        }
        double step = step0_ * (1.0 + ratio_);
        int i = 0;
        for (; i < frames; i++) {
            if (w_ - rd_ < kTapsHalf + 1) break;           // not enough ahead for this output frame
            int64_t base = rd_ - kTapsHalf + 1;
            double ph = frac_ * kPhases;
            int p = int(ph);
            float a = float(ph - p);
            const float *c0 = table_.row(p), *c1 = table_.row(p + 1);
            float l = 0, r = 0;
            for (int j = 0; j < kTaps; j++) {
                float c = c0[j] + (c1[j] - c0[j]) * a;
                size_t k = size_t((base + j) & mask_) * 2;
                l += c * ring_[k];
                r += c * ring_[k + 1];
            }
            y[2 * i] = l;
            y[2 * i + 1] = r;
            frac_ += step;
            int64_t adv = int64_t(frac_);
            rd_ += adv;
            frac_ -= double(adv);
        }
        if (i < frames) {
            // underrun: silence for the rest, refill to a larger target before playing again
            std::memset(y + 2 * i, 0, sizeof(float) * 2 * (frames - i));
            st_.underruns++;
            st_.playing = false;
            jitter_ += frames * step0_;                    // one callback more of margin
            setTarget();
        }
        st_.framesOut += frames;
        control(frames);
    }

    const CoreStats &stats() {
        st_.fillMean = mean_;
        st_.target = target_;
        st_.jitter = jitter_;
        st_.ratioPpm = ratio_ * 1e6;
        return st_;
    }
    int inRate() const { return cfg_.inRate; }
    /** The resampler's own delay (half its window), ms. */
    double filterDelayMs() const { return 1000.0 * kTapsHalf / cfg_.inRate; }

private:
    void control(int frames) {
        double f = fill();                     // the low point: right after a pull
        double dt = double(frames) / cfg_.outRate;
        // the mean fill (time constant ~0.5 s)
        double a = std::min(1.0, dt / 0.5);
        mean_ += (f - mean_) * a;
        // jitter: the deepest dip below the mean, decaying with the half-life
        double dip = mean_ - f;
        double decay = std::exp2(-dt / cfg_.jitterHalfLifeS);
        jitter_ = std::max(jitter_ * decay, dip);
        setTarget();
        // PI on the mean fill: a positive error (too full) speeds the read up
        double err = (mean_ - target_) / cfg_.inRate;           // seconds of error
        // anti-windup: the integral alone may hold at most the limit (a clock offset up to maxPpm)
        const double kp = 0.5, ki = 0.05, lim = cfg_.maxPpm * 1e-6;
        integ_ = std::clamp(integ_ + err * dt, -lim / ki, lim / ki);
        double ppm = kp * err + ki * integ_;                    // 1 ms high -> 500 ppm (pulled in over ~2 s)
        ratio_ = std::clamp(ppm, -cfg_.maxPpm * 1e-6, cfg_.maxPpm * 1e-6);
    }

    void setTarget() {
        target_ = std::clamp(safety_ + 1.5 * jitter_, minTarget_, maxTarget_);
    }

    void detect(float l, float r) {
        // The FM-1 dithers (Skiff 2.5, #110): even its silence is +-1 LSB noise, never a long run of exact zeros. So:
        //  * right after real signal, 4 exact-zero frames are a gap the phone's USB path filled;
        //  * in quiet (dither only), a run of 32 exact-zero frames is too (dither gives a zero frame on both sides
        //    about half the time: 32 in a row by chance is ~1e-8, a few a day). A gap is usually a packet, 44-49 frames.
        //  * input with no non-zero frame for half a second isn't dithered at all (not the FM-1, or muted upstream):
        //    gaps can't be seen in it, and the stats say so (blind).
        const float loud = 1e-3f;   // about -60 dBFS (33 LSB at 16 bits): well above the dither
        bool zero = (l == 0.f && r == 0.f);
        bool same = (l == lastL_ && r == lastR_);
        if (zero) {
            ++zeroRun_;
            if (zeroRun_ == 4 && lastLoud_) st_.zeroRuns++;
            else if (zeroRun_ == 32 && !lastLoud_) st_.zeroRuns++;
            if (++sinceNonZero_ >= cfg_.inRate / 2) st_.blind = true;
        } else {
            if (sinceNonZero_ >= cfg_.inRate / 2 && zeroRun_ >= 32 && !lastLoud_) st_.zeroRuns--;   // that long run was undithered silence, not a gap
            zeroRun_ = 0;
            sinceNonZero_ = 0;
            st_.blind = false;
        }
        if (same && !zero && (std::fabs(l) > loud || std::fabs(r) > loud)) {
            if (++repeatRun_ == 3) st_.repeatRuns++;
        } else {
            repeatRun_ = 0;
        }
        if (!zero) lastLoud_ = std::fabs(l) > loud || std::fabs(r) > loud;
        lastL_ = l;
        lastR_ = r;
    }

    Config cfg_;
    int64_t mask_;
    std::vector<float> ring_;
    SincTable table_;
    int64_t w_ = 0, rd_ = 0;
    double frac_ = 0;
    double step0_ = 1;
    double ratio_ = 0, integ_ = 0;
    double mean_ = 0, jitter_ = 0, target_ = 0;
    double minTarget_ = 0, maxTarget_ = 0, safety_ = 0;
    int zeroRun_ = 0, repeatRun_ = 0;
    int64_t sinceNonZero_ = 0;
    bool lastLoud_ = false;
    float lastL_ = 0, lastR_ = 0;
    CoreStats st_;
};

}  // namespace through

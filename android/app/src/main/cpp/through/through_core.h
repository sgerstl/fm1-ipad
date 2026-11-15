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
    int64_t repeatRuns = 0;     // 8+ exactly repeated loud frames: the FM-1's own ring underran (uac_packet repeats its last frame), or the phone repeated
    int64_t concealed = 0;      // gap zero runs concealed (Config::conceal): dropped, or filled, with crossfades
    int gapMode = 0;            // 0 not known yet, 1 the phone INSERTS its zeros (extra frames: dropped), 2 it REPLACES real frames (filled)
    double insertedness = 0;    // the last window's raw surplus over the gap frames: ~1 inserted, ~0 replaced
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
        bool conceal = true;          // take gap zero runs out of the stream (a stopgap for the phone's USB path)
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
        for (int i = 0; i < frames; i++) take(x[2 * i], x[2 * i + 1]);
        st_.framesIn += frames;
        winRawIn_ += frames;
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
        judgeGaps(frames);
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

    /**
     * One input frame: gap detection and (optionally) concealment, then the ring.
     *
     * A gap is a run of 4 to 255 exact-zero stereo frames *inside a signal*: right after a loud frame (|x| > 1e-3,
     * about -60 dBFS) and followed at once by one above 3e-4 (about -70 dBFS). Nothing else counts:
     *  * Skiff dithers only a word with bits below it (usb.c uac_dith: "a word with nothing below it (USB LEVEL FIXED,
     *    silence) stays as it is"), so silence, a decay's last bits and USB LEVEL FIXED come as exact zeros with a
     *    stray +-1. A rule for gaps in quiet (32 zeros in a row, 2026-11-15) fired on exactly that; it's gone. Gaps
     *    in quiet passages can't be told from the music, and aren't counted.
     *  * A run of kHoldCap (5 ms) or more is silence (a note cut off, the music stopping), never a gap.
     * A run is held back until it ends and judged then. A gap is concealed (Config::conceal): left out if the phone
     * inserted it (extra frames: an underrun filled), filled with the frames before it if it replaced real ones,
     * with crossfades (judgeGaps decides which). Shorter runs, longer runs and quiet ones go in as they came.
     * Repeats: 8 identical loud frames (dither makes a flat top repeat a few frames by chance). The FM-1 itself
     * repeats its last frame when its ring runs dry (uac_packet), so repeats point at the FM-1, zeros at the phone.
     */
    void take(float l, float r) {
        const float loud = 1e-3f;     // about -60 dBFS (33 LSB at 16 bits)
        const float resume = 3e-4f;   // about -70 dBFS (10 LSB): the signal goes on after the run
        if (l == 0.f && r == 0.f) {
            if (++sinceNonZero_ >= cfg_.inRate / 2) st_.blind = true;
            if (passZeros_) { write(0.f, 0.f); return; }
            if (++held_ >= kHoldCap) {                  // silence, not a gap: let it through as it is
                for (int k = 0; k < held_; k++) write(0.f, 0.f);
                held_ = 0;
                passZeros_ = true;
            }
            return;
        }
        if (held_ > 0) {
            bool gap = lastLoud_ && held_ >= 4 && (std::fabs(l) > resume || std::fabs(r) > resume);
            if (gap) { st_.zeroRuns++; winGapFrames_ += held_; }
            if (gap && cfg_.conceal) {
                st_.concealed++;
                if (st_.gapMode != 1) {
                    // replaced: the time is real, the sound lost. Fill it with the frames just before it (a repeat),
                    // faded in from the last frame so the start doesn't click
                    int n = std::min<int64_t>(held_, w_ - (rd_ - kTapsHalf + 1) - 1);
                    int64_t base = w_ - n;
                    for (int k = 0; k < held_; k++) {
                        size_t q = size_t((base + (k % std::max(1, n))) & mask_) * 2;
                        float fl = ring_[q], fr = ring_[q + 1];
                        if (k < 16) { float t = float(k + 1) / 17.f; fl = lastWL_ + (fl - lastWL_) * t; fr = lastWR_ + (fr - lastWR_) * t; }
                        write(fl, fr);
                    }
                }
                // inserted: the zeros were extra; leave them out. Until it's known, fill: a wrong fill only grows the
                // buffer for a moment (the next catch-up trims it), a wrong drop empties it (a hole)
                fade_ = kFade; fadeL_ = lastWL_; fadeR_ = lastWR_;
            } else {
                for (int k = 0; k < held_; k++) write(0.f, 0.f);
            }
            held_ = 0;
        }
        passZeros_ = false;
        sinceNonZero_ = 0;
        st_.blind = false;
        bool isLoud = std::fabs(l) > loud || std::fabs(r) > loud;
        if (isLoud && l == lastL_ && r == lastR_) { if (++repeatRun_ == 7) st_.repeatRuns++; }
        else repeatRun_ = 0;
        lastL_ = l; lastR_ = r;
        lastLoud_ = isLoud;
        float wl = l, wr = r;
        if (fade_ > 0) {   // from the frame before the gap to the stream, over kFade frames
            float t = float(kFade - fade_ + 1) / float(kFade + 1);
            wl = fadeL_ + (l - fadeL_) * t;
            wr = fadeR_ + (r - fadeR_) * t;
            fade_--;
        }
        write(wl, wr);
    }

    void write(float l, float r) {
        // room: frames older than the window's start (rd_ - kTapsHalf + 1) may be overwritten
        if (w_ - (rd_ - kTapsHalf + 1) >= cfg_.ringFrames) { st_.overflows++; return; }
        ring_[size_t(w_ & mask_) * 2] = l;
        ring_[size_t(w_ & mask_) * 2 + 1] = r;
        w_++;
        lastWL_ = l; lastWR_ = r;
    }

    /**
     * Every 2 s of output: did the gap zeros come on top of the stream, or in place of it? The raw input (zeros
     * included) against the output's consumption at the nominal ratio: inserted zeros make it run fast by about the
     * gap frames (15 gaps a second of 48 frames is 1.5 %, against clocks within 0.05 %); replaced ones don't.
     */
    void judgeGaps(int frames) {
        winOut_ += frames;
        if (winOut_ < int64_t(cfg_.outRate) * 2) return;
        if (winGapFrames_ >= 300) {
            // (the fills this window added are in the ring, not in the raw count: raw is what the phone handed us)
            double surplus = double(winRawIn_) - double(winOut_) * step0_;
            st_.insertedness = surplus / double(winGapFrames_);
            st_.gapMode = st_.insertedness > 0.5 ? 1 : 2;
        }
        winOut_ = winRawIn_ = winGapFrames_ = 0;
    }

    static constexpr int kHoldCap = 256;   // frames: the longest zero run held back (5 ms at 48 kHz)
    static constexpr int kFade = 32;       // frames: the crossfade over a concealed gap

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
    int held_ = 0, repeatRun_ = 0, fade_ = 0;
    int64_t winRawIn_ = 0, winOut_ = 0, winGapFrames_ = 0;
    int64_t sinceNonZero_ = 0;
    bool lastLoud_ = false, passZeros_ = false;
    float lastL_ = 0, lastR_ = 0, lastWL_ = 0, lastWR_ = 0, fadeL_ = 0, fadeR_ = 0;
    CoreStats st_;
};

}  // namespace through

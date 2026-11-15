// Host test for the audio-through core (through_core.h) and a model of Skiff-Lupe 2.5.1's USB audio packets.
//   android/app/src/main/cpp/through/tests/run.sh
// No Android here: what it checks is the resampler's quality, the adaptive buffer against FM-1-like packet streams
// (clock offsets, bursty delivery, stalls), the dropout detector, and how evenly the FM-1 paces its packets today
// against the pacing proposed in qa/device-checks/2026-11-15-audio-through.md.
#include "../through_core.h"

#include <cstdio>
#include <cstdlib>
#include <deque>
#include <random>
#include <string>

using through::ThroughCore;

// the proposed pacing's constants (see SkiffSource): the fill filter's shift, the proportional gain, the integral's divider
// B1's slip controller: slower than the pacing's (the packets stay 48 whatever it does; it only has to keep the
// FM-1's ring off its ends, and every needless slip is a slip)
#ifndef B1_SHIFT
#define B1_SHIFT 7
#endif
#ifndef B1_KP
#define B1_KP 1
#endif
#ifndef B1_KIDIV
#define B1_KIDIV 64
#endif
#ifndef PACE_SHIFT
#define PACE_SHIFT 5
#endif
#ifndef PACE_KP
#define PACE_KP 4
#endif
#ifndef PACE_KI_DIV
#define PACE_KI_DIV 4
#endif

static int failures = 0;
#define CHECK(cond, ...) do { if (!(cond)) { failures++; std::printf("  FAIL: "); std::printf(__VA_ARGS__); std::printf("\n"); } } while (0)

// ---------------------------------------------------------------------------------------------------------------
// 1. Resampler quality: a sine in, the output's error against the ideal sine (least-squares fit at the known
//    frequency), with the ratio nudge switched off so only the filter is measured.
static double snrDb(const std::vector<float> &y, int rate, double hz, size_t from) {
    // fit a*sin + b*cos + c, report signal / residual
    double ss = 0, sc = 0, cc = 0, ys = 0, yc = 0;
    for (size_t i = from; i < y.size(); i++) {
        double t = 2 * M_PI * hz * double(i) / rate, s = std::sin(t), c = std::cos(t);
        ss += s * s; sc += s * c; cc += c * c; ys += y[i] * s; yc += y[i] * c;
    }
    double det = ss * cc - sc * sc, a = (ys * cc - yc * sc) / det, b = (yc * ss - ys * sc) / det;
    double sig = 0, err = 0;
    for (size_t i = from; i < y.size(); i++) {
        double t = 2 * M_PI * hz * double(i) / rate, fit = a * std::sin(t) + b * std::cos(t);
        sig += fit * fit; err += (y[i] - fit) * (y[i] - fit);
    }
    return 10 * std::log10(sig / err);
}

static double resampleSnr(int inRate, int outRate, double hz) {
    ThroughCore::Config c;
    c.inRate = inRate; c.outRate = outRate; c.maxPpm = 0;
    ThroughCore core(c);
    const int burst = 240;
    std::vector<float> in, out, buf(burst * 2), left;
    double need = 0; int64_t n = 0;
    for (int cb = 0; cb < outRate * 2 / burst; cb++) {
        need += double(burst) * inRate / outRate;
        while (n < int64_t(need) + 64) {   // keep a little ahead: what a steady feed does
            float v = float(0.5 * std::sin(2 * M_PI * hz * double(n) / inRate));
            float fr[2] = {v, v};
            core.push(fr, 1);
            n++;
        }
        core.pull(buf.data(), burst);
        for (int i = 0; i < burst; i++) left.push_back(buf[2 * i]);
    }
    // the output starts after priming: find the first non-silent frame and measure from 0.2 s after it
    size_t start = 0;
    while (start < left.size() && left[start] == 0) start++;
    std::vector<float> y(left.begin() + long(start), left.end());
    return snrDb(y, outRate, hz, size_t(outRate / 5));
}

static void testResampler() {
    std::printf("resampler quality (32 taps, 256 phases, Kaiser 9):\n");
    struct { int in, out; double hz; double min; } cases[] = {
        {44100, 48000, 1000, 90}, {44100, 48000, 10000, 85}, {44100, 48000, 18000, 70},
        {48000, 48000, 1000, 90}, {48000, 44100, 1000, 90},
    };
    for (auto &k : cases) {
        double s = resampleSnr(k.in, k.out, k.hz);
        std::printf("  %5d -> %5d Hz, %5.0f Hz sine: SNR %.1f dB (want > %.0f)\n", k.in, k.out, k.hz, s, k.min);
        CHECK(s > k.min, "SNR %.1f dB at %d->%d %0.f Hz", s, k.in, k.out, k.hz);
    }
    // the spike's linear interpolator, for comparison (same measure)
    {
        int inRate = 44100, outRate = 48000; double hz = 10000;
        std::vector<float> y; double pos = 0, step = double(inRate) / outRate;
        for (int i = 0; i < outRate; i++, pos += step) {
            int k = int(pos); double f = pos - k;
            double a = 0.5 * std::sin(2 * M_PI * hz * k / inRate), b = 0.5 * std::sin(2 * M_PI * hz * (k + 1) / inRate);
            y.push_back(float(a + (b - a) * f));
        }
        std::printf("  (the spike's linear interpolation, 44100 -> 48000, 10 kHz: SNR %.1f dB)\n", snrDb(y, outRate, hz, 0));
    }
}

// ---------------------------------------------------------------------------------------------------------------
// 2. Skiff-Lupe 2.5.1's packet source (usb.c, uac_render_start / uac_tap48 / uac_packet), modelled in time.
//    The FM-1's I2S runs at ~44,117.6 Hz (usb.c's comment), renders HALF_FRAMES = 128 frames at a time; at 48 kHz
//    each render puts 128 x 160 / 147 frames in the ring. One packet per USB frame (1 ms of host time): 48 frames,
//    one more when the fill at the last render start (fill_min) is above UA_HI48 (139), one fewer below UA_LO48 (87).
//    `paced` swaps uac_packet's band rule for the proposal: a filtered fill drives a fractional rate, and an
//    accumulator spreads the extra (or missing) frames evenly.
struct SkiffSource {
    bool paced = false;
    bool b1 = false;           // option B1: every packet exactly 48; the ring's drift taken by a crossfaded one-frame slip
    double jitterMs = 0;       // renders start late by up to this (render load: FM6 pads); never early
    double i2sHz = 44100.0 * (1 + 422e-6);   // the FM-1's rate by the Mac's clock (check 18: 48020.3 Hz at 48 kHz, +422 ppm)
    std::mt19937 rng{7};
    double late = 0;           // this render's lateness, s
    int64_t slips = 0;
    int64_t minRing = 1 << 30, maxRing = 0;   // B1: the ring's range just after packets (UA_N 512: room either side)
    double tRender = 0;        // next render start, s
    double resAcc = 0;         // 160/147 bookkeeping
    int64_t ring = 113;        // UA_PRIME48
    int64_t fillMin = 113;
    // proposal state (integer, as firmware would hold it)
    int32_t fillQ8 = 113 * 256;   // filtered fill, Q8
    int32_t integQ8 = 0;
    int32_t accQ16 = 0;
    int64_t underruns = 0;

    /** Advances to host time t (s) and returns the next packet's frame count. */
    int packet(double t) {
        while (tRender + late <= t) {                // renders that started before this packet
            fillMin = ring;                          // uac_render_start: the low point of the saw tooth
            if (paced) fillQ8 += ((int32_t(fillMin) << 8) - fillQ8) >> PACE_SHIFT;
            if (b1) fillQ8 += ((int32_t(fillMin) << 8) - fillQ8) >> B1_SHIFT;
            resAcc += 128.0 * 160.0 / 147.0;
            int add = int(resAcc); resAcc -= add;
            ring += add;
            tRender += 128.0 / i2sHz;
            late = jitterMs > 0 ? std::uniform_real_distribution<double>(0, jitterMs / 1000.0)(rng) : 0;
        }
        int n = 48;
        if (b1) {
            // the packet is always 48; what the ring gives up is 48, 49 (drop a frame, the FM-1 fast) or 47 (repeat one),
            // decided by the same PI and accumulator as the even pacing, so slips come evenly and never in runs
            int32_t err = fillQ8 - 113 * 256;
            integQ8 = std::clamp(integQ8 + err / 64, -(1 << 20), 1 << 20);
            int32_t rateQ16 = std::clamp(err * B1_KP + integQ8 / B1_KIDIV, -(1 << 16), 1 << 16);
            accQ16 += rateQ16;
            int take = 48;
            if (accQ16 >= (1 << 16)) { take = 49; accQ16 -= 1 << 16; slips++; }
            else if (accQ16 <= -(1 << 16)) { take = 47; accQ16 += 1 << 16; slips++; }
            if (ring < take) { underruns++; ring = take; }
            ring -= take;
            minRing = std::min(minRing, ring);
            maxRing = std::max(maxRing, ring);
            return 48;
        }
        if (!paced) {
            if (fillMin > 139) n++; else if (fillMin < 87) n--;
        } else {
            // PI on the filtered fill around the band's middle (113), in 1/65536 frames per packet
            int32_t err = fillQ8 - 113 * 256;                  // Q8 frames
            integQ8 = std::clamp(integQ8 + err / 64, -(1 << 20), 1 << 20);
            int32_t rateQ16 = err * PACE_KP + integQ8 / PACE_KI_DIV;           // Q16 frames per packet
            rateQ16 = std::clamp(rateQ16, -(1 << 16), 1 << 16);
            accQ16 += rateQ16;
            if (accQ16 >= (1 << 16)) { n++; accQ16 -= 1 << 16; }
            else if (accQ16 <= -(1 << 16)) { n--; accQ16 += 1 << 16; }
        }
        if (ring < n) { underruns++; ring = n; }     // (uac_packet repeats the last frame; count it)
        ring -= n;
        return n;
    }
};

struct PacingReport { double shortPerS, longPerS, ppSpread, ppShort; int64_t underruns; double meanPerMs; };

/** Packet statistics over `seconds`: how often a packet is short or long, and the peak-to-peak spread of the
 *  running sum of (frames - mean): the cushion a host needs to read the stream at an even rate. */
static PacingReport pacing(bool paced, double seconds) {
    SkiffSource s; s.paced = paced;
    int nPk = int(seconds * 1000);
    std::vector<int> sizes(nPk);
    for (int k = 0; k < nPk; k++) sizes[k] = s.packet(k * 0.001);
    // skip the first second (settling)
    int from = 1000; double total = 0; int shortN = 0, longN = 0;
    for (int k = from; k < nPk; k++) { total += sizes[k]; shortN += sizes[k] < 48; longN += sizes[k] > 48; }
    double mean = total / (nPk - from), run = 0, lo = 0, hi = 0;
    for (int k = from; k < nPk; k++) { run += sizes[k] - mean; lo = std::min(lo, run); hi = std::max(hi, run); }
    // the same spread within any 16 ms (the Pixel's dejitter is "Size 16")
    double worst = 0;
    for (int k = from; k + 16 < nPk; k++) {
        double r2 = 0, l2 = 0, h2 = 0;
        for (int j = k; j < k + 16; j++) { r2 += sizes[j] - mean; l2 = std::min(l2, r2); h2 = std::max(h2, r2); }
        worst = std::max(worst, h2 - l2);
    }
    double secs = (nPk - from) / 1000.0;
    return {shortN / secs, longN / secs, hi - lo, worst, s.underruns, mean};
}

/**
 * A phone that takes exactly 48 frames per USB millisecond from a 16-frame cushion, as the Pixels appear to (check 16:
 * "Avail: 47 Had:1 Received 48 Size 16"; Lupe judged their gaps as replacing real frames): short of 48 it writes zeros
 * (an underrun, a gap), over 48 + 16 it drops the excess (a gap too). A reading of the Pixel's log, not its source.
 */
struct PhoneModel { double underrunsPerS, dropsPerS, fm1UnderrunsPerS, slipsPerS, shortPerS, longPerS; int64_t minRing, maxRing; };

static PhoneModel phoneModel(int mode, double jitterMs, double seconds) {   // mode 0 today, 1 even pacing (A), 2 B1
    SkiffSource s; s.paced = mode == 1; s.b1 = mode == 2; s.jitterMs = jitterMs;
    int64_t buf = 48 + 8, under = 0, drops = 0, shortN = 0, longN = 0, fm1u0 = 0, slips0 = 0;
    int nPk = int(seconds * 1000), from = 1000;
    for (int k = 0; k < nPk; k++) {
        if (k == from) { fm1u0 = s.underruns; slips0 = s.slips; under = drops = shortN = longN = 0; s.minRing = 1 << 30; s.maxRing = 0; }
        int n = s.packet(k * 0.001);
        shortN += n < 48; longN += n > 48;
        buf += n;
        if (buf > 48 + 16) { drops++; buf = 48 + 16; }
        if (buf < 48) { under++; buf = 0; } else buf -= 48;
    }
    double secs = (nPk - from) / 1000.0;
    return {under / secs, drops / secs, (s.underruns - fm1u0) / secs, (s.slips - slips0) / secs, shortN / secs, longN / secs, s.minRing, s.maxRing};
}

static void testPhoneModel() {
    std::printf("the FM-1 (+422 ppm) into a phone taking exactly 48 per ms with a 16-frame cushion, 30 s (a model):\n");
    const char *names[] = {"today (band rule)", "A, even pacing", "B1, always 48 + slip"};
    for (double j : {0.0, 1.0, 2.5}) {
        for (int m = 0; m < 3; m++) {
            auto r = phoneModel(m, j, 31);
            std::printf("  renders up to %.1f ms late, %-22s 47s %5.1f/s, 49s %5.1f/s · phone underruns %5.1f/s, drops %5.1f/s · FM-1 ring empty %4.1f/s, slips %4.1f/s\n",
                        j, names[m], r.shortPerS, r.longPerS, r.underrunsPerS, r.dropsPerS, r.fm1UnderrunsPerS, r.slipsPerS);
            if (m == 2) std::printf("      B1's ring after packets: %lld..%lld frames of 512\n", (long long)r.minRing, (long long)r.maxRing);
            if (m == 2) {
                CHECK(r.underrunsPerS == 0 && r.dropsPerS == 0, "B1 must leave the phone nothing to fill or drop (jitter %.1f)", j);
                CHECK(r.shortPerS == 0 && r.longPerS == 0, "B1 sends only 48s");
                CHECK(std::fabs(r.slipsPerS - 20.3) < 2, "B1 slips at the clock offset (~20/s at +422 ppm), got %.1f", r.slipsPerS);
                CHECK(r.fm1UnderrunsPerS == 0 && r.minRing > 16 && r.maxRing + 140 + 49 < 512, "B1's ring must stay off both ends (%lld..%lld)", (long long)r.minRing, (long long)r.maxRing);
            }
        }
    }
}

/**
 * B1's slip, as uac_packet would do it: 48 output frames from 49 ring frames (drop) or 47 (repeat), the extra or
 * missing frame spread over a 16-frame ramp in the middle of the packet: the read position moves from j to j +- 1
 * across the ramp, interpolated (linear, or 4-point cubic: Catmull-Rom), int16 in and out as the ring holds them.
 * Measured against the ideal: the same sine at the same warped time, so only the interpolation's error counts.
 */
static double slipSnr(double hz, bool cubic, int slipsPerS, double *worstDb) {
    const int rate = 48000, ramp = 16, every = rate / 1000 * (1000 / slipsPerS);   // a slip every N packets' worth of frames
    std::vector<int16_t> src;   // the ring's frames (one channel), with room for the warp
    for (int i = 0; i < rate * 3; i++) src.push_back(int16_t(std::lround(16000 * std::sin(2 * M_PI * hz * i / rate))));
    double sig = 0, err = 0, worst = 0;
    double pos = 64;            // read position in src
    for (int n = 0; n < rate * 2; n++) {
        int inPkt = n % every;
        double step = (inPkt >= 16 && inPkt < 16 + ramp) ? 1.0 + 1.0 / ramp : 1.0;   // a drop: read 17 frames' worth over 16
        int i = int(pos); double f = pos - i;
        double y;
        if (f == 0) y = src[size_t(i)];
        else if (!cubic) y = src[size_t(i)] + (src[size_t(i) + 1] - src[size_t(i)]) * f;
        else {
            double p0 = src[size_t(i) - 1], p1 = src[size_t(i)], p2 = src[size_t(i) + 1], p3 = src[size_t(i) + 2];
            y = p1 + 0.5 * f * (p2 - p0 + f * (2 * p0 - 5 * p1 + 4 * p2 - p3 + f * (3 * (p1 - p2) + p3 - p0)));
        }
        y = std::lround(std::clamp(y, -32768.0, 32767.0));
        double ideal = 16000 * std::sin(2 * M_PI * hz * pos / rate);
        sig += ideal * ideal; err += (y - ideal) * (y - ideal);
        if (inPkt >= 16 && inPkt < 16 + ramp) worst = std::max(worst, std::fabs(y - ideal));
        pos += step;
    }
    *worstDb = 20 * std::log10(std::max(worst, 1e-9) / 16000);
    return 10 * std::log10(sig / err);
}

/**
 * B1's slip done in the FM-1's own 44.1 -> 48 kHz polyphase resampler (usb.c uac_tap48: 160 phases, the phase
 * stepping UAC_FIR_M = 147 per output frame): stepping 148 instead for ~148 outputs makes one output frame fewer
 * (146: one more). Every output is still the filter at an exact phase, so the only change is the time map: 0.7 %
 * faster for 3 ms. Measured against the ideal sine at the same warped times.
 */
static double polySlipSnr(double hz, int slipsPerS, int *framesLost) {
    const double inRate = 44100.0;
    const int L = 160, M = 147, half = 16;
    std::vector<double> x;
    for (int i = 0; i < int(inRate * 3); i++) x.push_back(std::lround(16000 * std::sin(2 * M_PI * hz * i / inRate)));
    // the prototype: windowed sinc at the input's Nyquist (x0.91), 32 taps per phase, evaluated at the exact phase
    auto tap = [&](double d) {
        double fc = 0.5 * 0.91, s0 = d == 0 ? 2 * fc : std::sin(2 * M_PI * fc * d) / (M_PI * d), r = d / half;
        if (std::fabs(r) >= 1) return 0.0;
        auto i0 = [](double v) { double s = 1, t = 1; for (int k = 1; k < 30; k++) { t *= (v / (2 * k)) * (v / (2 * k)); s += t; } return s; };
        return s0 * i0(9.0 * std::sqrt(1 - r * r)) / i0(9.0);
    };
    int64_t base = 64; int ph = 0;       // output time = base + ph / L input frames
    int slipLeft = 0, nOut = 0, every = 48000 / slipsPerS;
    double sig = 0, err = 0, tIdeal;
    while (base + half + 2 < int64_t(x.size())) {
        double frac = double(ph) / L, y = 0, norm = 0;
        for (int j = -half + 1; j <= half; j++) { double w = tap(j - frac); y += w * x[size_t(base + j)]; norm += w; }
        y = std::lround(y / norm);
        tIdeal = double(base) + frac;
        double ideal = 16000 * std::sin(2 * M_PI * hz * tIdeal / inRate);
        if (nOut > 200) { sig += ideal * ideal; err += (y - ideal) * (y - ideal); }
        if (nOut % every == 0) slipLeft = 148;          // a drop: 148 outputs at 148
        int step = slipLeft > 0 ? M + 1 : M;
        if (slipLeft > 0) slipLeft--;
        ph += step;
        base += ph / L; ph %= L;
        nOut++;
    }
    // frames lost: the outputs a plain 147-step resampler would have made from the same input, minus these
    *framesLost = int(std::lround((double(base - 64) * L / M) - nOut));
    return 10 * std::log10(sig / err);
}

static void testSlip() {
    std::printf("B1's slip in the FM-1's polyphase resampler (148 steps for ~148 outputs), 20 a second:\n");
    for (double hz : {1000.0, 10000.0, 15000.0}) {
        int lost = 0;
        double snr = polySlipSnr(hz, 20, &lost);
        std::printf("  %5.0f Hz: SNR %5.1f dB against the ideal warped sine · frames made fewer: %d (expect %d: 20 a second for 3 s)\n", hz, snr, lost, 20 * 3);
        CHECK(std::abs(lost - 60) <= 1, "each slip must make exactly one frame fewer: %d", lost);
        CHECK(snr > 80 || hz > 12000, "polyphase slip at %.0f Hz: %.1f dB", hz, snr);
    }
    std::printf("the alternative, a slip on the ring's frames: a 16-frame ramp, 20 slips a second, int16 (SNR against the ideal warped sine; worst error in a ramp):\n");
    for (double hz : {1000.0, 5000.0, 10000.0, 15000.0}) {
        double wl, wc;
        double l = slipSnr(hz, false, 20, &wl), c = slipSnr(hz, true, 20, &wc);
        std::printf("  %5.0f Hz: linear %5.1f dB (worst %5.1f dBFS-rel), cubic %5.1f dB (worst %5.1f)\n", hz, l, wl, c, wc);
        // (recorded for the comparison: the ring-side slip needs interpolation, and 10 kHz shows it)
    }
}

static void testPacing() {
    std::printf("Skiff-Lupe 2.5.1 at 48 kHz, packet pacing over 60 s (model of usb.c):\n");
    auto now = pacing(false, 61), prop = pacing(true, 61);
    std::printf("  today (band 87..139 on fill_min): %.1f frames/ms, %.0f short (47) and %.0f long (49) packets a second, "
                "running-sum spread %.1f frames (%.1f within 16 ms), ring underruns %lld\n", now.meanPerMs, now.shortPerS, now.longPerS, now.ppSpread, now.ppShort, (long long)now.underruns);
    std::printf("  proposed (filtered fill, fractional rate, accumulator): %.1f frames/ms, %.0f short and %.0f long a second, "
                "spread %.1f frames (%.1f within 16 ms), ring underruns %lld\n", prop.meanPerMs, prop.shortPerS, prop.longPerS, prop.ppSpread, prop.ppShort, (long long)prop.underruns);
    CHECK(prop.ppSpread < 4, "the proposal's spread %.1f frames should be ~1-2", prop.ppSpread);
    CHECK(prop.underruns == 0, "the proposal must not empty the FM-1's ring");
    CHECK(std::fabs(prop.meanPerMs - now.meanPerMs) < 0.01, "both must carry the FM-1's real rate");
    CHECK(prop.shortPerS < 1, "the proposal sends no short packets when the FM-1's clock is fast");
}

// ---------------------------------------------------------------------------------------------------------------
// 3. The adaptive buffer against FM-1-like streams. Host time is the USB's; the phone's output clock and the FM-1's
//    effective rate are offsets from it. The app's input stream gets packets as the phone's USB path hands them on:
//    every `deliverMs` ms (a burst of the packets since the last), plus random lateness, plus rare stalls.
struct Scenario {
    std::string name;
    double phonePpm = 0;       // the phone's output clock against USB time
    double deliverMs = 1;      // how often the phone hands input on
    double lateMsMax = 0;      // random extra lateness of each hand-over
    double stallEveryS = 0;    // a stall of stallMs every this many seconds (0: none)
    double stallMs = 0;
    double gapsPerS = 0;       // the phone's USB path replacing a packet with zeros (the Pixel's dejitter underrun)
    bool paced = false;        // the FM-1's proposed pacing
    int burst = 240;           // the output callback's frames (5 ms at 48 kHz: the Pixel's)
    int inRate = 48000;
    bool quiet = false;        // the FM-1 quiet with dither (uac_dith on a word with bits below it: -1, 0 or +1 LSB)
    bool silence = false;      // the FM-1 silent: exact zeros (uac_dith leaves a word with nothing below it alone),
                               // a stray +-1 LSB now and then (a decay's last bits, USB LEVEL FIXED)
    double cutEveryS = 0;      // a loud note cut off to exact silence for 100 ms every this many seconds
    bool insertGaps = false;   // a gap is 48 zero frames *added* before the packet (an underrun filled), not the packet replaced
    bool conceal = true;       // ThroughCore::Config::conceal
};

struct SimResult { int64_t underruns, catchUps, zeroRuns; double meanLatencyMs, maxLatencyMs, ppm, targetMs; int64_t gapsInjected; int64_t concealed; double minPeak; int gapMode; double insertedness; };

static SimResult simulate(const Scenario &sc, double seconds, uint32_t seed = 1) {
    std::mt19937 rng(seed);
    std::uniform_real_distribution<double> uni(0, 1);
    ThroughCore::Config c; c.inRate = sc.inRate; c.outRate = 48000; c.conceal = sc.conceal;
    ThroughCore core(c);
    double minPeak = 1e9;      // the quietest 1 ms of output after settling (a 0.3 sine: ~0.3; a hole: ~0)
    SkiffSource src; src.paced = sc.paced;
    struct Pk { double at; int n; bool gap; int64_t first; };
    std::deque<Pk> inFlight;                 // packets received by the phone, waiting to be handed to the app
    std::deque<Pk> handed;                   // handed over, waiting for the next output callback to read them
    double tPk = 0, tDeliver = sc.deliverMs / 1000.0, tCb = 0, nextStall = sc.stallEveryS;
    double cbPeriod = sc.burst / (48000.0 * (1 + sc.phonePpm * 1e-6));
    int64_t frameNo = 0, gaps = 0;
    std::vector<float> buf, out(size_t(sc.burst) * 2);
    double latSum = 0, latMax = 0; int64_t latN = 0;
    SimResult r{};
    const double fmRate = 48000.0 * 44117.6 / 44100.0;   // the content's real rate, for a continuous sine
    while (tCb < seconds) {
        // the next event: a USB packet, a hand-over to the app, or an output callback
        double t = std::min({tPk, tDeliver, tCb});
        if (t == tPk) {
            int n = src.packet(tPk);
            bool gap = sc.gapsPerS > 0 && uni(rng) < sc.gapsPerS / 1000.0;
            inFlight.push_back({tPk, n, gap, frameNo});
            frameNo += n;
            tPk += 0.001;
        } else if (t == tDeliver) {
            double late = sc.lateMsMax * uni(rng) / 1000.0;
            if (sc.stallEveryS > 0 && tDeliver >= nextStall) { late += sc.stallMs / 1000.0; nextStall += sc.stallEveryS; }
            while (!inFlight.empty() && inFlight.front().at <= tDeliver) {
                Pk p = inFlight.front(); inFlight.pop_front();
                p.at = tDeliver + late;
                handed.push_back(p);
            }
            tDeliver += sc.deliverMs / 1000.0;
        } else {
            // the output callback: read what has been handed over (non-blocking), then pull a burst
            while (!handed.empty() && handed.front().at <= tCb) {
                Pk p = handed.front(); handed.pop_front();
                if (p.gap && sc.insertGaps) {   // the phone added 48 frames of zeros, then the real packet
                    std::vector<float> z(96, 0.f);
                    core.push(z.data(), 48);
                    gaps++;
                    p.gap = false;
                }
                buf.resize(size_t(p.n) * 2);
                for (int i = 0; i < p.n; i++) {
                    if (p.gap) { buf[2 * i] = buf[2 * i + 1] = 0.f; continue; }
                    if (sc.silence) {
                        buf[2 * i] = uni(rng) < 0.002 ? float((uni(rng) < 0.5 ? -1 : 1) / 32768.0) : 0.f;
                        buf[2 * i + 1] = uni(rng) < 0.002 ? float((uni(rng) < 0.5 ? -1 : 1) / 32768.0) : 0.f;
                        continue;
                    }
                    if (sc.cutEveryS > 0 && std::fmod(double(p.first + i) / 48000.0, sc.cutEveryS) < 0.1) {
                        buf[2 * i] = buf[2 * i + 1] = 0.f;      // the note cut off: exact silence
                        continue;
                    }
                    if (sc.quiet) {
                        // uac_dith(0): (64 + r1 + r2 - 127) >> 7 with r1, r2 uniform 0..127, per channel
                        auto d = [&] { int r1 = int(uni(rng) * 128), r2 = int(uni(rng) * 128); return float(((64 + r1 + r2 - 127) >> 7) / 32768.0); };
                        buf[2 * i] = d(); buf[2 * i + 1] = d();
                        continue;
                    }
                    float v = float(0.3 * std::sin(2 * M_PI * 440.0 * double(p.first + i) / fmRate));
                    buf[2 * i] = v; buf[2 * i + 1] = v;
                }
                if (p.gap) gaps++;
                core.push(buf.data(), p.n);
            }
            core.pull(out.data(), sc.burst);
            if (tCb > 3 && !sc.quiet) {
                for (int w0 = 0; w0 + 48 <= sc.burst; w0 += 48) {
                    float pk = 0;
                    for (int i = w0; i < w0 + 48; i++) pk = std::max(pk, std::fabs(out[2 * i]));
                    minPeak = std::min(minPeak, double(pk));
                }
            }
            if (tCb > 3) {   // after settling
                auto &s = core.stats();
                double lat = s.fillMean / sc.inRate * 1000 + core.filterDelayMs();
                latSum += lat; latN++; latMax = std::max(latMax, lat);
            }
            if (tCb > 3 && tCb - cbPeriod <= 3) {   // reset the counters at the settle point
                auto &s = core.stats();
                r.underruns = -s.underruns; r.catchUps = -s.catchUps; r.zeroRuns = -s.zeroRuns; r.concealed = -s.concealed; gaps = 0;
            }
            tCb += cbPeriod;
        }
    }
    auto &s = core.stats();
    r.underruns += s.underruns; r.catchUps += s.catchUps; r.zeroRuns += s.zeroRuns; r.concealed += s.concealed; r.minPeak = minPeak; r.gapMode = s.gapMode; r.insertedness = s.insertedness;
    r.meanLatencyMs = latSum / std::max<int64_t>(1, latN); r.maxLatencyMs = latMax;
    r.ppm = s.ratioPpm; r.targetMs = s.target / sc.inRate * 1000; r.gapsInjected = gaps;
    return r;
}

static void testAdaptive() {
    std::printf("adaptive buffer, 60 s each, counted after the first 3 s (latency = ring fill + filter, ms):\n");
    std::vector<Scenario> scs = {
        {"steady 1 ms packets, phone clock = USB", 0, 1, 0},
        {"phone clock -500 ppm", -500, 1, 0},
        {"phone clock +300 ppm", 300, 1, 0},
        {"handed on every 4 ms, up to 2 ms late", 0, 4, 2},
        {"handed on every 10 ms, up to 5 ms late", 100, 10, 5},
        {"as above, plus a 30 ms stall every 7 s", 100, 10, 5, 7, 30},
        {"proposed FM-1 pacing, 4 ms hand-overs", 0, 4, 2, 0, 0, 0, true},
    };
    for (auto &sc : scs) {
        auto r = simulate(sc, 63);
        std::printf("  %-44s underruns %lld, catch-ups %lld, latency mean %.1f max %.1f, target %.1f, ratio %+.0f ppm\n",
                    sc.name.c_str(), (long long)r.underruns, (long long)r.catchUps, r.meanLatencyMs, r.maxLatencyMs, r.targetMs, r.ppm);
        bool stalls = sc.stallEveryS > 0;
        if (!stalls) CHECK(r.underruns == 0, "%s: %lld underruns after settling", sc.name.c_str(), (long long)r.underruns);
        else CHECK(r.underruns <= 2, "%s: %lld underruns (a stall longer than the buffer may cost one, then the buffer grows)", sc.name.c_str(), (long long)r.underruns);
        // the ring's mean latency should sit near the jitter it has to cover, not grow without bound
        double budget = 1.5 * (sc.deliverMs + sc.lateMsMax) + 1000.0 * sc.burst / 48000 + 2 + (stalls ? sc.stallMs * 1.6 : 0);
        CHECK(r.meanLatencyMs < budget, "%s: mean latency %.1f ms over the budget %.1f", sc.name.c_str(), r.meanLatencyMs, budget);
    }
    // the dropout detector: zeros the phone put in are counted (the FM-1 dithers, so it never sends exact zeros)
    Scenario g{"phone path fills 5 gaps a second with zeros", 0, 1, 0, 0, 0, 5};
    auto r = simulate(g, 63);
    std::printf("  %-44s detected %lld of %lld injected gaps (underruns %lld)\n", g.name.c_str(), (long long)r.zeroRuns, (long long)r.gapsInjected, (long long)r.underruns);
    CHECK(r.zeroRuns >= r.gapsInjected * 9 / 10 && r.zeroRuns <= r.gapsInjected + 2, "detector: %lld of %lld", (long long)r.zeroRuns, (long long)r.gapsInjected);
    Scenario clean{"no gaps: no false dropouts", 0, 4, 2};
    r = simulate(clean, 63);
    CHECK(r.zeroRuns == 0, "false dropouts: %lld", (long long)r.zeroRuns);
    // concealment: the output's quietest millisecond, with the phone filling 15 gaps a second (both Pixels' rate)
    for (int insert = 0; insert < 2; insert++) {
        for (int conceal = 0; conceal < 2; conceal++) {
            Scenario cg{"", 0, 1, 0, 0, 0, 15}; cg.insertGaps = insert; cg.conceal = conceal;
            cg.name = std::string(insert ? "15 inserted" : "15 replaced") + " gaps/s, conceal " + (conceal ? "on" : "off");
            auto rc = simulate(cg, 33);
            std::printf("  %-44s quietest 1 ms of a 0.3 sine: peak %.3f · gaps %lld, concealed %lld, Lupe gaps %lld · judged %s (%.2f)\n", cg.name.c_str(),
                        rc.minPeak, (long long)rc.zeroRuns, (long long)rc.concealed, (long long)rc.underruns,
                        rc.gapMode == 1 ? "inserted" : rc.gapMode == 2 ? "replaced" : "unknown", rc.insertedness);
            if (conceal) {
                // a fill repeats the 48 frames before the gap, not period-aligned: a short dip (~-4 dB), not a hole
                CHECK(rc.minPeak > (insert ? 0.2 : 0.15), "%s: a hole still reaches the output (peak %.3f)", cg.name.c_str(), rc.minPeak);
                CHECK(rc.gapMode == (insert ? 1 : 2), "%s: judged the gaps wrongly (mode %d, %.2f)", cg.name.c_str(), rc.gapMode, rc.insertedness);
                CHECK(rc.underruns == 0, "%s: concealment cost %lld Lupe gaps", cg.name.c_str(), (long long)rc.underruns);
            } else {
                CHECK(rc.minPeak < 0.05, "%s: the test should see the hole without concealment (peak %.3f)", cg.name.c_str(), rc.minPeak);
            }
        }
    }
    // quiet and silence: nothing counts there (a gap can't be told from the music), and nothing false
    Scenario qg{"FM-1 quiet (dither), 5 gaps a second", 0, 1, 0, 0, 0, 5}; qg.quiet = true;
    r = simulate(qg, 63);
    std::printf("  %-44s counted %lld of %lld (gaps in quiet aren't counted)\n", qg.name.c_str(), (long long)r.zeroRuns, (long long)r.gapsInjected);
    CHECK(r.zeroRuns == 0, "quiet: %lld counted", (long long)r.zeroRuns);
    Scenario sl{"FM-1 silent: zeros, a stray +-1 (no dither)", 0, 4, 2}; sl.silence = true;
    r = simulate(sl, 63);
    std::printf("  %-44s false gaps %lld (the 2026-11-15 misfire)\n", sl.name.c_str(), (long long)r.zeroRuns);
    CHECK(r.zeroRuns == 0, "false gaps in undithered silence: %lld", (long long)r.zeroRuns);
    Scenario ct{"a note cut to silence every 0.5 s", 0, 4, 2}; ct.cutEveryS = 0.5;
    r = simulate(ct, 33);
    std::printf("  %-44s false gaps %lld\n", ct.name.c_str(), (long long)r.zeroRuns);
    CHECK(r.zeroRuns == 0, "false gaps at note cuts: %lld", (long long)r.zeroRuns);
}

int main() {
    testResampler();
    testPacing();
    testPhoneModel();
    testSlip();
    testAdaptive();
    std::printf(failures ? "\n%d FAILED\n" : "\nall passed\n", failures);
    return failures ? 1 : 0;
}

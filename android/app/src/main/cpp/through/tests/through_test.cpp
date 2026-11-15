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
    double i2sHz = 44117.6;
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
        while (tRender <= t) {                       // renders that started before this packet
            fillMin = ring;                          // uac_render_start: the low point of the saw tooth
            if (paced) fillQ8 += ((int32_t(fillMin) << 8) - fillQ8) >> PACE_SHIFT;
            resAcc += 128.0 * 160.0 / 147.0;
            int add = int(resAcc); resAcc -= add;
            ring += add;
            tRender += 128.0 / i2sHz;
        }
        int n = 48;
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
    bool quiet = false;        // the FM-1 silent: only its dither (Skiff 2.5's uac_dith on zero: -1, 0 or +1 LSB)
};

struct SimResult { int64_t underruns, catchUps, zeroRuns; double meanLatencyMs, maxLatencyMs, ppm, targetMs; int64_t gapsInjected; };

static SimResult simulate(const Scenario &sc, double seconds, uint32_t seed = 1) {
    std::mt19937 rng(seed);
    std::uniform_real_distribution<double> uni(0, 1);
    ThroughCore::Config c; c.inRate = sc.inRate; c.outRate = 48000;
    ThroughCore core(c);
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
                buf.resize(size_t(p.n) * 2);
                for (int i = 0; i < p.n; i++) {
                    if (p.gap) { buf[2 * i] = buf[2 * i + 1] = 0.f; continue; }
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
            if (tCb > 3) {   // after settling
                auto &s = core.stats();
                double lat = s.fillMean / sc.inRate * 1000 + core.filterDelayMs();
                latSum += lat; latN++; latMax = std::max(latMax, lat);
            }
            if (tCb > 3 && tCb - cbPeriod <= 3) {   // reset the counters at the settle point
                auto &s = core.stats();
                r.underruns = -s.underruns; r.catchUps = -s.catchUps; r.zeroRuns = -s.zeroRuns; gaps = 0;
            }
            tCb += cbPeriod;
        }
    }
    auto &s = core.stats();
    r.underruns += s.underruns; r.catchUps += s.catchUps; r.zeroRuns += s.zeroRuns;
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
    // the FM-1 silent (dither only): gaps still show, and the dither alone raises none
    Scenario qg{"FM-1 silent (dither), 5 gaps a second", 0, 1, 0, 0, 0, 5}; qg.quiet = true;
    r = simulate(qg, 63);
    std::printf("  %-44s detected %lld of %lld injected gaps\n", qg.name.c_str(), (long long)r.zeroRuns, (long long)r.gapsInjected);
    CHECK(r.zeroRuns >= r.gapsInjected * 9 / 10 && r.zeroRuns <= r.gapsInjected + 2, "quiet detector: %lld of %lld", (long long)r.zeroRuns, (long long)r.gapsInjected);
    Scenario qc{"FM-1 silent (dither), no gaps", 0, 4, 2}; qc.quiet = true;
    r = simulate(qc, 63);
    std::printf("  %-44s false gaps %lld\n", qc.name.c_str(), (long long)r.zeroRuns);
    CHECK(r.zeroRuns == 0, "false dropouts in dither: %lld", (long long)r.zeroRuns);
}

int main() {
    testResampler();
    testPacing();
    testAdaptive();
    std::printf(failures ? "\n%d FAILED\n" : "\nall passed\n", failures);
    return failures ? 1 : 0;
}

// Timing for the page lag (Scott's report, 2026-11-14: a family key changes the FM-1 at once, the phone a moment
// later). A trace opens on pickPage or goHome and logs, for 1.5 s, each step of the phone's own with its offset:
// the screen set (optimistic, then the FM-1's reply or push), every area built in that time (how long its builder
// took, how many bytes, whether it changed and was published). LagClock reads CLOCK_MONOTONIC, the clock Android's
// SystemClock.uptimeMillis reads, so these lines line up with the Kotlin side's (BridgedLupeCore's "lag" lines).
import Foundation
import SloopKit

public enum LagClock {
    /// Milliseconds on the monotonic clock (fractional).
    /// CLOCK_MONOTONIC read directly where it exists (Android, Linux): the very clock SystemClock.uptimeMillis reads,
    /// so the clock area's `atMs` can't be on another clock than the screen's, whatever Dispatch's own time is built on.
    public static func now() -> Double {
        #if os(Android) || os(Linux)
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return Double(ts.tv_sec) * 1000 + Double(ts.tv_nsec) / 1_000_000
        #else
        return Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
        #endif
    }
    public static func ms() -> Int { Int(now()) }
}

@MainActor final class LagTrace {
    static let window = 1500.0
    private(set) var what: String?
    private var t0 = 0.0
    private var lines: [String] = []
    private let log: (String) -> Void
    /// The whole trace, also kept for the tests (the last one).
    private(set) var last: [(at: Double, line: String)] = []
    private var current: [(at: Double, line: String)] = []

    init(log: @escaping (String) -> Void) { self.log = log }

    func start(_ what: String) {
        self.what = what; t0 = LagClock.now(); current = []
        mark("intent \(what) (clock \(LagClock.ms()))")
    }

    var active: Bool { what != nil && LagClock.now() - t0 < Self.window }

    func mark(_ s: String) {
        guard let what else { return }
        let dt = LagClock.now() - t0
        guard dt < Self.window else { finish(); return }
        current.append((dt, s)); last = current
        log(String(format: "lag %@ +%.1f ms: %@", what, dt, s))
    }

    func finish() { what = nil; last = current }
}


import Foundation
import SloopKit

/// -count-bodies: how many times each counted view's body runs, printed once a second (the redraw volume, for
/// before-and-after numbers where Instruments' SwiftUI tools need a device). Free when off; compiled out of release builds.
enum BodyCounter {
    static let on = LaunchArgs.all.contains("-count-bodies")
    nonisolated(unsafe) private static var counts: [String: Int] = [:]
    nonisolated(unsafe) private static var started = false
    private static let lock = NSLock()

    static func tick(_ name: String) {
        #if DEBUG
        guard on else { return }
        lock.lock(); counts[name, default: 0] += 1; let first = !started; started = true; lock.unlock()
        if first { report() }
        #endif
    }

    private static func report() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            lock.lock(); let c = counts; counts = [:]; lock.unlock()
            print("BODIES " + c.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
            fflush(stdout)
            report()
        }
    }
}

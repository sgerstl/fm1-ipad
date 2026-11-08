import SloopKit
import SwiftUI

// How song entries are named and referred to across the Song tab: a track's entry, its letter, its pattern number.

/// An entry on a track: what a block, the inspector and the menus act on.
struct EntryRef: Equatable, Hashable {
    var track: Int
    var entry: Int
}

enum Entries {
    static func letter(_ i: Int) -> String { String(UnicodeScalar(UInt8(65 + i))) }
    static func letters(_ r: ClosedRange<Int>) -> String { r.count == 1 ? letter(r.lowerBound) : "\(letter(r.lowerBound))–\(letter(r.upperBound))" }
    static func number(_ p: Int) -> String { String(format: "%02d", p) }
    /// Blocks take their track's colour (Scott, 2026-11-05); a pattern no single track names is one of
    /// four greys, by its number.
    static func tone(_ p: Int) -> Color { Theme.blockTones[(p - 1) % Theme.blockTones.count] }

    @MainActor static func soundName(_ s: EntrySound, session: DeviceSession) -> String {
        if let slot = s.userSlot { return session.userPresets.first { $0.slot == slot }?.name ?? "USER \(slot + 1)" }
        guard let e = s.engine else { return "" }
        return session.namesCache[e]?[safe: s.s1] ?? session.info?.engines[safe: e] ?? "ENGINE \(e + 1)"
    }

    @MainActor static func trackName(_ t: Int, session: DeviceSession) -> String {
        let tr = session.tracks[t]
        return tr.presetName.isEmpty ? "Track \(t + 1)" : tr.presetName.capitalized
    }

    static func divisionName(_ d: Int) -> String { ["1/4", "1/8", "1/16", "1/32", "8T", "16T", "1/2", "1/1", "2 BAR", "4 BAR"][safe: d] ?? "1/16" }
    static func directionName(_ d: Int) -> String { ["FWD", "RVRS", "PING", "RAND"][safe: d] ?? "FWD" }
}

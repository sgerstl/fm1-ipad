import Foundation

// Sections on Skiff's song (vault skiff-arrange-spec.md, the canvas's board 3): a bar range across the lanes,
// duplicated after itself or cleared. Tracks move on at their own pass ends, so each track snaps the range
// to its own pass edges, splitting an entry where a pass boundary falls inside it (08 ×2 becomes ×1 + ×1); a
// track whose passes can't meet the range is said so, with what snapping costs, and can be left out.

public enum SectionOp: Sendable { case duplicateAfter, clear }

/// One track's part in a section: where its passes meet the range, and the list after the op.
public struct SectionTrack: Equatable, Sendable {
    public var track: Int
    /// The range snapped to this track's pass edges, in ticks; nil when no pass falls inside it.
    public var from: Double?
    public var to: Double?
    /// The edges land on the range exactly.
    public var exact: Bool
    /// The entries the snapped range splits, as "Splits A at its 2nd pass".
    public var splits: [String]
    /// The list after the op (nil: nothing to do, or no room for it).
    public var result: [SongEntry]?
    /// Why it can't be done (16 entries), if so.
    public var refusal: String?

    /// What snapping costs, said in bars: "Bars 4¾–13¾: 9 bars, 1 more".
    public func cost(rangeBars: Double) -> String? {
        guard !exact, let f = from, let t = to else { return nil }
        let a = f / SongPlacement.ticksPerBar + 1, b = t / SongPlacement.ticksPerBar
        let len = (t - f) / SongPlacement.ticksPerBar, diff = len - rangeBars
        var s = "Bars \(SongSections.bars(a))–\(SongSections.bars(b)): \(SongSections.bars(len)) bar\(len == 1 ? "" : "s")"
        if abs(diff) > 0.01 { s += ", \(SongSections.bars(abs(diff))) \(diff > 0 ? "more" : "fewer")" }
        return s
    }
}

public enum SongSections {
    /// A bar count as the device's quarters read: 9, 4¾, 13½.
    public static func bars(_ b: Double) -> String {
        let whole = Int(b.rounded(.down)), q = Int(((b - Double(whole)) * 4).rounded())
        let frac = ["", "¼", "½", "¾", ""][q]
        let w = q == 4 ? whole + 1 : whole
        return w == 0 && !frac.isEmpty ? frac : "\(w)\(frac)"
    }

    /// One pass of a block (a chain: one time through all its parts), with the entries it plays as.
    struct Unit {
        var entries: [SongEntry]          // a single entry with reps 1; a chain's parts, the last with reps 1
        var origin: Int                   // the block's first entry: units from one entry merge back into one
        var start: Double, end: Double
    }

    static func units(_ list: SongList, _ blocks: [SongBlock]) -> [Unit] {
        var out: [Unit] = []
        for b in blocks {
            var parts = Array(list.entries[b.entries])
            parts[parts.count - 1].reps = 1
            for r in 0..<b.reps {
                let s = b.start + Double(r) * b.pass
                out.append(Unit(entries: parts, origin: b.entries.lowerBound, start: s, end: s + b.pass))
            }
        }
        return out
    }

    /// Units back into entries: neighbours from the same entry (or chain) become one again, their passes
    /// summed into REPS (16 at most a entry).
    static func entries(_ units: [Unit]) -> [SongEntry] {
        var out: [SongEntry] = []
        var i = 0
        while i < units.count {
            var n = 1
            while i + n < units.count, n < 16, units[i + n].origin == units[i].origin,
                  units[i + n].entries == units[i].entries { n += 1 }
            var parts = units[i].entries
            parts[parts.count - 1].reps = n
            out += parts
            i += n
        }
        return out
    }

    private static func passWord(_ k: Int) -> String {
        switch k { case 1: "1st"; case 2: "2nd"; case 3: "3rd"; default: "\(k)th" }
    }

    /// A track's part in the section [from, to) (ticks), snapped to its pass edges unless left out.
    public static func plan(track t: Int, list: SongList, blocks: [SongBlock], from: Double, to: Double, op: SectionOp) -> SectionTrack {
        let us = units(list, blocks)
        var none = SectionTrack(track: t, from: nil, to: nil, exact: false, splits: [], result: nil, refusal: nil)
        guard let span = list.span, !us.isEmpty else { return none }
        let edges = [us[0].start] + us.map(\.end)
        func nearest(_ x: Double) -> Int { edges.indices.min { abs(edges[$0] - x) < abs(edges[$1] - x) } ?? 0 }
        let a = nearest(from), b = nearest(to)
        guard b > a else { return none }
        none.from = edges[a]; none.to = edges[b]
        none.exact = abs(edges[a] - from) < 0.5 && abs(edges[b] - to) < 0.5
        // the entries the edges fall inside
        for k in [a, b] where k > 0 && k < us.count && us[k - 1].origin == us[k].origin {
            let pass = us[..<k].filter { $0.origin == us[k].origin }.count
            let letter = String(UnicodeScalar(UInt8(65 + us[k].origin)))
            none.splits.append("Splits \(letter) at its \(passWord(pass + 1)) pass")
        }
        // the section's units get their own origins, so they stay apart from what's around them
        var section = Array(us[a..<b])
        for k in section.indices { section[k].origin += 100 }
        var after: [Unit]
        switch op {
        case .duplicateAfter:
            var copy = section
            for k in copy.indices { copy[k].origin += 100 }
            after = Array(us[..<a]) + section + copy + Array(us[b...])
        case .clear:
            after = Array(us[..<a]) + Array(us[b...])
        }
        var es = entries(after)
        // entries before the list's first pattern (passed over) keep their places in front
        es = Array(repeating: .empty, count: span.lowerBound) + es
        if es.count > 16 {
            none.refusal = "T\(t + 1) would need \(es.count) entries; it has 16"
            return none
        }
        none.result = es + Array(repeating: .empty, count: 16 - es.count)
        return none
    }
}

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
    /// An entry on CHAIN with nothing after it chains nothing on Skiff, but anything moved in after it
    /// would join: such a flag comes off before a list is changed.
    public static func unchainDangling(_ es: [SongEntry]) -> [SongEntry] {
        var out = es
        for i in out.indices where out[i].chained && (i == out.count - 1 || out[i + 1].isEmpty) { out[i].chained = false }
        return out
    }

    /// Empty entries that were rests inside the list and now stand at its start or end would be passed over
    /// there (the list runs from its first pattern or REST to its last), shifting or shortening the track:
    /// they become REST entries of the same length. `range`: the entries that were the list.
    public static func restsAtEdges(_ es: [SongEntry], range: Range<Int>) -> [SongEntry] {
        var out = es
        let r = range.clamped(to: out.indices)
        guard let first = r.first(where: { !out[$0].isEmpty }), let last = r.last(where: { !out[$0].isEmpty }) else { return out }
        // inside the range everything sat between patterns before, so an empty outside first...last was a rest
        for i in r where (i < first || i > last) && out[i].isEmpty {
            out[i] = SongEntry(pattern: SongEntry.rest, reps: out[i].reps)
        }
        return out
    }

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
            if !b.isChain { parts[0].chained = false }
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
        // a rest that ends up first or last would be passed over: it becomes a REST
        es = restsAtEdges(es, range: 0..<es.count)
        // entries before the list's first pattern (passed over) keep their places in front
        es = Array(repeating: .empty, count: span.lowerBound) + es
        if es.count > 16 {
            none.refusal = "T\(t + 1) would need \(es.count) entries; it has 16"
            return none
        }
        none.result = es + Array(repeating: .empty, count: 16 - es.count)
        return none
    }

    /// A new entry dropped at `at` (ticks): it goes in at the nearest pass edge, splitting the entry it
    /// falls inside (board 1: "Inserts an entry at the nearest pass edge"). The entry's index, the edge,
    /// the split it makes, and the list after (nil: no room).
    public static func insert(_ e: SongEntry, list: SongList, blocks: [SongBlock], at: Double)
        -> (index: Int, at: Double, split: String?, result: [SongEntry]?) {
        let lead = list.span?.lowerBound ?? 0
        let us = units(list, blocks)
        guard !us.isEmpty else {
            var es = list.entries
            es[0] = e
            return (0, 0, nil, es)
        }
        let edges = [us[0].start] + us.map(\.end)
        let k = edges.indices.min { abs(edges[$0] - at) < abs(edges[$1] - at) } ?? edges.count - 1
        var split: String?
        if k > 0 && k < us.count && us[k - 1].origin == us[k].origin {
            let pass = us[..<k].filter { $0.origin == us[k].origin }.count
            split = "splits \(String(UnicodeScalar(UInt8(65 + us[k].origin)))) after its \(passWord(pass)) pass"
        }
        var after = Array(us[k...])
        for i in after.indices { after[i].origin += 100 }       // the part after a split stays its own entry
        let before = entries(Array(us[..<k]))
        let es = Array(repeating: SongEntry.empty, count: lead) + before + [e] + entries(after)
        let index = lead + before.count
        guard es.count <= 16 else { return (index, edges[k], split, nil) }
        return (index, edges[k], split, es + Array(repeating: .empty, count: 16 - es.count))
    }

    /// A block moved within its track (Scott, 2026-11-05: hold, then drag). Lists have no gaps, so a move is
    /// a reorder: the blocks behind it close up, the ones where it lands move over, a chain moves whole.
    /// `to` is its place among the other blocks (0: first; their count: after the last). Past the end,
    /// `restPasses` passes of REST hold the gap, so it plays where it was dropped (16 passes an entry).
    public static func move(list: SongList, blocks: [SongBlock], block b: Int, to k: Int, restPasses: Int = 0) -> SongMove {
        let lead = list.span?.lowerBound ?? 0
        let es = unchainDangling(list.entries)
        var groups = blocks.map { Array(es[$0.entries]) }
        guard groups.indices.contains(b) else { return SongMove(index: 0, rests: 0, result: nil, unchanged: true) }
        let moving = groups.remove(at: b)
        let at = max(0, min(k, groups.count))
        let rests = at == groups.count ? stride(from: restPasses, to: 0, by: -16).map { SongEntry(pattern: SongEntry.rest, reps: min(16, $0)) } : []
        let index = lead + groups[..<at].reduce(0) { $0 + $1.count } + rests.count
        if at == b && rests.isEmpty {
            return SongMove(index: blocks[b].entries.lowerBound, rests: 0, result: list.entries, unchanged: true)
        }
        groups.insert(rests + moving, at: at)
        // an empty entry that was a rest inside the list and now stands at an edge would be passed over
        let flat = unchainDangling(restsAtEdges(groups.flatMap { $0 }, range: 0..<groups.reduce(0) { $0 + $1.count }))
        let out = Array(repeating: SongEntry.empty, count: lead) + flat
        guard out.count <= 16 else { return SongMove(index: index, rests: rests.count, result: nil, unchanged: false) }
        return SongMove(index: index, rests: rests.count, result: out + Array(repeating: .empty, count: 16 - out.count), unchanged: false)
    }
}

/// What moving a block does: where its first entry lands, the RESTs put in past the end, the list after
/// (nil: more than 16 entries), and whether anything changes at all.
public struct SongMove: Equatable, Sendable {
    public var index: Int
    public var rests: Int
    public var result: [SongEntry]?
    public var unchanged: Bool
}


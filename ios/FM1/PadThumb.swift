import SloopKit
import SwiftUI

// A pattern's miniature on its pad: learned from the pattern's steps, drawn small.

/// A pattern's drawing for its pads (Scott, 2026-11-07: "every pad shows its music"), in 16 columns: a drum
/// track's hits, a synth track's notes as a contour (the highest note of each column, scaled to the pattern's range).
/// Lupe reads a pattern only while a track is on it (no read gives a pattern's steps otherwise), so these are kept as
/// they're seen, for the session, keyed by pattern number with its LEN (a pattern whose LEN changed is drawn again).
struct PadThumb: Equatable {
    var length: Int
    var drums: Bool
    /// 0...1 a column's height (drums) or pitch (synth); nil: nothing there.
    var columns: [Double?]
    /// The pattern's DIR and its motion records (the pad's marks, board 46 d): the track's while it's on it, else the pool's.
    var direction = 0
    var motion = 0

    @MainActor static func of(_ tr: TrackState, drums: Bool) -> PadThumb {
        let n = max(1, min(tr.length, tr.steps.count))
        func range(_ c: Int) -> Range<Int> { (c * n / 16)..<max(c * n / 16 + 1, (c + 1) * n / 16) }
        if drums {
            let cols: [Double?] = (0..<16).map { c in
                let hits = range(c).filter { $0 < tr.steps.count && tr.isOn($0) }.map { tr.gridSteps[$0].lanes.count }
                return hits.max().map { min(1, 0.35 + 0.2 * Double($0)) }
            }
            return PadThumb(length: tr.length, drums: true, columns: cols)
        }
        let tops: [Int?] = (0..<16).map { c in
            range(c).compactMap { i -> Int? in
                guard i < tr.steps.count, tr.steps[i].time == .note else { return nil }
                return tr.steps[i].notes.max()
            }.max()
        }
        let present = tops.compactMap { $0 }
        guard let lo = present.min(), let hi = present.max() else { return PadThumb(length: tr.length, drums: false, columns: Array(repeating: nil, count: 16)) }
        let span = Double(max(1, hi - lo))
        return PadThumb(length: tr.length, drums: false, columns: tops.map { $0.map { hi == lo ? 0.5 : 0.1 + 0.9 * Double($0 - lo) / span } })
    }

    /// Each track's pattern as it is now, into the session's drawings (the Song tab, both views, once a second).
    /// From a stored pattern (the pool read): the same picture its track would give it playing.
    static func of(_ s: SkiffPatternSketch) -> PadThumb {
        let n = s.length
        func range(_ c: Int) -> Range<Int> { (c * n / 16)..<max(c * n / 16 + 1, (c + 1) * n / 16) }
        if s.drums {
            let cols: [Double?] = (0..<16).map { c in
                range(c).filter { $0 < s.steps.count && s.steps[$0].note }.map { s.steps[$0].hits }.max().map { min(1, 0.35 + 0.2 * Double($0)) }
            }
            return PadThumb(length: n, drums: true, columns: cols)
        }
        let tops: [Int?] = (0..<16).map { c in range(c).compactMap { i in i < s.steps.count && s.steps[i].note ? s.steps[i].notes.max() : nil }.max() }
        let present = tops.compactMap { $0 }
        guard let lo = present.min(), let hi = present.max() else { return PadThumb(length: n, drums: false, columns: Array(repeating: nil, count: 16)) }
        let span = Double(max(1, hi - lo))
        return PadThumb(length: n, drums: false, columns: tops.map { $0.map { hi == lo ? 0.5 : 0.1 + 0.9 * Double($0 - lo) / span } })
    }

    /// While stopped on Pads, the stored patterns' pictures (PadPreviews): the pool's chunks whose patterns changed
    /// since they were last read (their LENs and uses: a pattern's steps change only while a track is on it, and
    /// that one is drawn live by `learn`). One read at a time.
    @MainActor static func fromPool(_ session: DeviceSession, _ store: SkiffSongStore, _ ui: EditorUI) async {
        guard PadPreviews.on, !session.playing, !store.offline, ui.songView == .pads, !poolReading,
              let pool = store.pool?.patterns, pool.count == 64 else { return }
        let sig = pool.map { "\($0.length).\($0.uses)" }
        let chunks = (0..<16).filter { c in (0..<4).contains { sig[4 * c + $0] != poolSeen[safe: 4 * c + $0] } }
        guard !chunks.isEmpty else { return }
        poolReading = true
        defer { poolReading = false }
        guard let recs = await session.readSkiffPool(chunks: chunks) else { return }   // (playing again, busy: next time)
        let live = Set(session.trackIndices.compactMap { store.song?.tracks[safe: $0]?.patternOn })
        // a picture drawn live wins over the stored one (an edit can still be waiting for flash): the pool fills in the
        // missing, and replaces one only where that pattern itself changed in the pool (a new one, a project opened)
        for (p, r) in recs where !live.contains(p) && (ui.padThumbs[p] == nil || sig[p] != poolSeen[safe: p]) {
            if let s = SkiffPatternSketch(record: r) { var th = of(s); th.direction = s.direction; th.motion = s.motion; ui.padThumbs[p] = th }
        }
        if poolSeen.count != 64 { poolSeen = Array(repeating: "", count: 64) }
        for c in chunks { for k in 0..<4 { poolSeen[4 * c + k] = sig[4 * c + k] } }
    }
    @MainActor private static var poolSeen: [String] = []
    @MainActor private static var poolReading = false

    @MainActor static func learn(_ session: DeviceSession, _ store: SkiffSongStore, _ ui: EditorUI) {
        for k in session.trackIndices {
            guard let p = store.song?.tracks[safe: k]?.patternOn, k < session.tracks.count else { continue }
            var th = of(session.tracks[k], drums: session.isKit(k))
            th.direction = session.tracks[k].direction; th.motion = session.motion[k]?.recorded ?? 0
            if ui.padThumbs[p] != th { ui.padThumbs[p] = th }
        }
    }
}

struct PadThumbView: View {
    let thumb: PadThumb
    let ink: Color

    var body: some View {
        Canvas { ctx, sz in
            let n = thumb.columns.count, w = sz.width / CGFloat(n)
            for (c, v) in thumb.columns.enumerated() {
                let x = CGFloat(c) * w
                if thumb.drums {
                    let h = max(3, sz.height * CGFloat(v ?? 0))
                    ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: sz.height - h, width: w - 2, height: h), cornerRadius: 1),
                             with: .color(v == nil ? ink.opacity(0.3) : ink))
                } else if let v {
                    // a note: a short bar at its pitch
                    let y = (sz.height - 4) * (1 - CGFloat(v))
                    ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: y, width: w - 2, height: 4), cornerRadius: 2), with: .color(ink))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: x + w / 2 - 1, y: sz.height - 2, width: 2, height: 2)), with: .color(ink.opacity(0.35)))
                }
            }
        }
        .frame(height: 24)
        .accessibilityHidden(true)
    }
}

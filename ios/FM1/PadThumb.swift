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
    @MainActor static func learn(_ session: DeviceSession, _ store: SkiffSongStore, _ ui: EditorUI) {
        for k in session.trackIndices {
            guard let p = store.song?.tracks[safe: k]?.patternOn, k < session.tracks.count else { continue }
            let th = of(session.tracks[k], drums: session.isKit(k))
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

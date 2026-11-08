import SloopKit
import SwiftUI

// Pads ↔ Timeline (Scott, 2026-11-08: "pads fold into lane"): the selected track's pads and its lane's blocks are the
// same entries seen two ways, so on the switch each pad flies to its block (and back), while the two views crossfade
// under them. The pieces in flight are plain copies drawn over the page, not the pads or blocks themselves: those carry
// gestures and timers, and moving them would re-lay out the lanes every frame (which dropped frames on 2026-11-06).

/// Where each pad and each block of the selected track is on screen (global). Written as they lay out, read only when
/// a fold starts, so it's a plain class: nothing redraws when a frame changes.
final class FoldFrames {
    var track = -1
    var pads: [Int: CGRect] = [:]
    /// Per entry: a chain's block split by its parts' lengths, so each pad has its own piece of it.
    var blocks: [Int: CGRect] = [:]

    func pad(_ i: Int, track t: Int, _ r: CGRect) {
        if t != track { track = t; pads = [:]; blocks = [:] }
        pads[i] = r
    }

    func block(_ b: SongBlock, track t: Int, _ r: CGRect) {
        if t != track { track = t; pads = [:]; blocks = [:] }
        let pass = max(b.pass, 1)
        var at: Double = 0
        for (k, e) in b.entries.enumerated() {
            let part = b.parts[safe: k] ?? pass / Double(b.entries.count)
            blocks[e] = CGRect(x: r.minX + r.width * at / pass, y: r.minY, width: r.width * part / pass, height: r.height)
            at += part
        }
    }
}

extension EnvironmentValues {
    @Entry var foldFrames: FoldFrames? = nil
}

/// One fold in progress: which way, and the pieces flying.
struct FoldRun: Equatable {
    struct Piece: Equatable, Identifiable {
        let id: Int
        let pad: CGRect, block: CGRect
        let label: String
        let rest: Bool
    }
    var toPads: Bool
    var pieces: [Piece] = []
    /// false: the pieces where they started (and the view going away shown); true: where they land.
    var landed = false

    /// The pieces between the two places, for every entry both views drew.
    @MainActor static func pieces(track t: Int, store: SkiffSongStore, frames: FoldFrames) -> [Piece] {
        guard frames.track == t, let list = store.song?.tracks[safe: t] else { return [] }
        return list.entries.indices.compactMap { i in
            let e = list.entries[i]
            guard !e.isEmpty, let p = frames.pads[i], let b = frames.blocks[i] else { return nil }
            return Piece(id: i, pad: p, block: b, label: e.isRest ? "REST" : Entries.number(e.pattern), rest: e.isRest)
        }
    }
}

/// The pieces in flight, drawn over the page in its own coordinates.
struct FoldLayer: View {
    let run: FoldRun
    let track: Int

    var body: some View {
        GeometryReader { g in
            let o = g.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                ForEach(run.pieces) { p in
                    // from the pad's place to the block's: pads → timeline lands on the block, timeline → pads on the pad
                    let r = run.toPads != run.landed ? p.block : p.pad
                    let onLane = run.toPads != run.landed
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: onLane ? 6 : 16)
                            .fill(p.rest ? Theme.control.opacity(0.6) : onLane ? Theme.track[track] : Theme.control)
                        Text(p.label)
                            .font(.system(size: onLane ? 11 : 22, weight: .semibold))
                            .foregroundStyle(onLane && !p.rest ? Theme.onColour : Theme.text)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .padding(.horizontal, onLane ? 6 : 12)
                    }
                    .frame(width: max(8, r.width), height: max(8, r.height))
                    .position(x: r.midX - o.x, y: r.midY - o.y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

import SloopKit
import SwiftUI

// Moving blocks on the timeline: the hold that lifts one, where a drop would land, and the drop itself.

/// How far through its pass a track is: a bar under the block it plays, in the track's colour, filling once
/// a pass (what the entry's REPS counts). From the clock-counted playhead, so it moves on a lane that loops
/// sooner than the song, where the song's playhead line shows nothing. Reduce Motion: four steps a second.
struct PassBar: View {
    let session: DeviceSession
    let track: Int
    let width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = BodyCounter.tick("PassBar")
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30, paused: !session.playing)) { _ in
            let p = session.passProgress(track) ?? 0
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track[track].opacity(0.3))
                Capsule().fill(Theme.track[track]).frame(width: max(3, width * CGFloat(p)))
            }
            .frame(width: width, height: 3)
        }
        .accessibilityHidden(true)
    }
}

/// UIKit's long press, for a block in the lanes' scroll view: it lets a scroll have the touch when the finger
/// moves first, and once held, follows the finger until it's let go, saying whether the touch was cancelled.
struct HoldRecognizer: UIGestureRecognizerRepresentable {
    /// The finger is reported in this space (the lane's), and globally (for a menu at the finger).
    var space: NamedCoordinateSpace
    var began: (CGPoint, CGPoint) -> Void
    var changed: (CGPoint, CGPoint) -> Void
    var ended: (CGPoint, CGPoint, _ cancelled: Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let g = UILongPressGestureRecognizer()
        g.minimumPressDuration = 0.4
        g.allowableMovement = Lane.holdSlop
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UILongPressGestureRecognizer, context: Context) {
        let p = context.converter.location(in: space)
        let global = context.converter.location(in: .global)
        switch g.state {
        case .began: began(p, global)
        case .changed: changed(p, global)
        case .ended: ended(p, global, false)
        case .cancelled, .failed: ended(p, global, true)
        default: break
        }
    }
}

/// A block's place in its lane, set by layout (alignment guides), not by an offset: the frame moves with it,
/// so the accordion's mask and the slide both follow the block.
struct Place: ViewModifier {
    var x: CGFloat
    var y: CGFloat
    func body(content: Content) -> some View {
        content.alignmentGuide(.leading) { _ in -x }.alignmentGuide(.top) { _ in -y }
    }
}

/// Where a pattern dragged from the bin would go: the entry index, the x it's drawn at (ticks), how long
/// it plays, and what the drop does, said in words.
struct DropSpot: Equatable {
    var track: Int
    var index: Int
    var at: Double
    var ticks: Double
    var pattern: Int
    var text: String
    /// The list after the drop (nil: no room).
    var result: [SongEntry]?
}

/// Where a held block would move to: its block (`from`, its first entry now), its place among the others,
/// the REST passes that hold a gap past the end, the list after, and what letting go does, said in words.
struct MoveSpot: Equatable {
    var track: Int
    var from: Int
    var to: Int
    var restPasses: Int
    var index: Int
    var result: [SongEntry]?
    var unchanged: Bool
    /// Why it can't go in now (playing, all 16 entries), before anything is sent.
    var refusal: String?
    var text: String

    /// The block from entry `e` moved to the finger (`at`, in the lane): before the first other block whose
    /// middle is past it; past the end, after REST passes that hold the gap.
    @MainActor static func make(store: SkiffSongStore, track t: Int, entry e: Int, barWidth: CGFloat, at: CGFloat) -> MoveSpot? {
        guard let list = store.song?.tracks[safe: t] else { return nil }
        let blocks = store.blocks(t)
        guard let b = blocks.firstIndex(where: { $0.entries.contains(e) }) else { return nil }
        let block = blocks[b]
        // the others, closed up: the place is among them
        var rest = list.entries
        rest.removeSubrange(block.entries)
        rest += Array(repeating: .empty, count: 16 - rest.count)
        let others = store.blocks(t, list: SongList(entries: rest))
        let x = Double(at / max(1, barWidth)) * SongPlacement.ticksPerBar
        let to = others.firstIndex { ($0.start + $0.end) / 2 > x } ?? others.count
        // past the end: REST passes (of the pattern before them) hold the gap, so it plays where it's let go
        let end = others.last?.end ?? 0
        let restPass = others.last?.parts.last ?? block.parts.first ?? SongPlacement.ticksPerBar
        let passes = to == others.count && x > end ? Int(((x - end) / restPass).rounded(.down)) : 0
        let m = SongSections.move(list: list, blocks: blocks, block: b, to: to, restPasses: passes)
        let name = "\(Entries.letters(block.entries)) (\(label(block, list)))"
        var refusal: String?
        var text: String
        if m.unchanged {
            text = "\(name) stays where it is"
        } else if let r = m.result {
            let start = store.blocks(t, list: SongList(entries: r)).first { $0.entries.lowerBound == m.index }?.start ?? 0
            text = "Move \(name) to bar \(SongSections.bars(start / SongPlacement.ticksPerBar + 1)) on T\(t + 1)"
            if m.rests > 0 {
                text += ", after a REST ×\(passes): that takes \(m.rests) more entr\(m.rests == 1 ? "y" : "ies")"
            }
            if let why = store.blocked(track: t, to: r) { refusal = why; text = why }
        } else {
            refusal = "T\(t + 1) has all 16 entries, so there's no room for the REST that would hold the gap. Play one entry more times, or chain two, to free a slot"
            text = refusal!
        }
        return MoveSpot(track: t, from: block.entries.lowerBound, to: to, restPasses: passes, index: m.index,
                        result: m.result, unchanged: m.unchanged, refusal: refusal, text: text)
    }

    static func label(_ b: SongBlock, _ list: SongList) -> String {
        if b.kind != .pattern { return "REST ×\(b.reps)" }
        let parts = b.entries.map { list.entries[$0].isRest ? "REST" : Entries.number(list.entries[$0].pattern) }
        return parts.joined(separator: "→") + " ×\(b.reps)"
    }
}

/// The drop: the nearest block edge (entries play back to back, so a new one goes between two).
struct LaneDrop: DropDelegate {
    let lane: Lane
    let blocks: [SongBlock]

    private func spot(_ info: DropInfo) -> DropSpot? {
        guard let p = lane.dragPattern else { return nil }
        return spot(at: info.location, pattern: p)
    }

    private func spot(at location: CGPoint, pattern p: Int) -> DropSpot? {
        guard let list = lane.store.song?.tracks[safe: lane.track] else { return nil }
        let ticks = Double(location.x / max(1, lane.barWidth)) * SongPlacement.ticksPerBar
        // the nearest pass edge, inside a repeating entry too (it splits)
        let ins = SongSections.insert(SongEntry(pattern: p, reps: 1), list: list, blocks: blocks, at: ticks)
        let pass = lane.store.passTicks(p - 1, track: lane.track)
        let bar = SongSections.bars(ins.at / SongPlacement.ticksPerBar + 1)
        let later = blocks.filter { $0.end > ins.at + 0.5 }
        var text = "Drop on T\(lane.track + 1): a new entry \(Entries.letter(ins.index)) at bar \(bar)"
        if let split = ins.split { text += ", " + split }
        if let f = later.first, let l = later.last {
            let shift = pass / SongPlacement.ticksPerBar
            let by = "\(SongSections.bars(shift)) bar\(shift == 1 ? "" : "s")"
            let moved = f.entries.lowerBound == l.entries.upperBound ? Entries.letter(f.entries.lowerBound)
                : "\(Entries.letter(f.entries.lowerBound))–\(Entries.letter(l.entries.upperBound))"
            text += ", \(moved) move\(f.entries.lowerBound == l.entries.upperBound ? "s" : "") \(by) later"
        }
        if ins.result == nil {
            text = "T\(lane.track + 1) has all 16 entries, so \(Entries.number(p)) can't go in. Play one entry more times, or chain two, to free a slot"
        }
        return DropSpot(track: lane.track, index: ins.index, at: ins.at, ticks: pass, pattern: p, text: text, result: ins.result)
    }

    func validateDrop(info: DropInfo) -> Bool { lane.dragPattern != nil }
    func dropEntered(info: DropInfo) { lane.dropAt = spot(info) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let s = spot(info)
        if s != lane.dropAt { lane.dropAt = s }
        return DropProposal(operation: .copy)
    }
    func dropExited(info: DropInfo) { if lane.dropAt?.track == lane.track { lane.dropAt = nil } }
    func performDrop(info: DropInfo) -> Bool {
        defer { lane.dropAt = nil; lane.dragPattern = nil }
        // the pattern from the dragged item itself ("pattern 12"), not the bin's note of it, which a drag
        // that ended elsewhere could leave behind
        guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
        let at = info.location, lane = lane
        _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let text = obj as? NSString, text.hasPrefix("pattern "), let p = Int(text.substring(from: 8)) else { return }
            Task { @MainActor in
                guard let s = LaneDrop(lane: lane, blocks: blocks).spot(at: at, pattern: p) else { return }
                guard let es = s.result else {
                    lane.store.refuse(track: lane.track, entry: nil, "T\(lane.track + 1) has all 16 entries. Play one entry more times, or chain two, to free a slot")
                    return
                }
                lane.selection = EntryRef(track: lane.track, entry: s.index)
                await lane.store.rewrite(track: lane.track, to: es, focus: s.index)
            }
        }
        return true
    }
}

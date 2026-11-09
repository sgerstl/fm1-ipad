import SloopKit
import SwiftUI

// One track's lane on the timeline: its header, the patterns it uses, the ruler over the lanes, and the lane itself.

struct LaneHeader: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    /// While a section is picked: what it does to this track (a split, the cost of snapping, left out).
    var note: String?
    /// The Song tab's: the track menu a long press on the name opens.
    var ui: EditorUI? = nil
    @Environment(\.arrangeLaneHeight) private var laneHeight
    @Environment(\.arrangeCompact) private var compact

    var body: some View {
        let _ = BodyCounter.tick("LaneHeader")
        let tr = session.tracks[track]
        let used = store.song?.tracks[safe: track]?.used ?? 0
        if compact { compactBody } else { fullBody(tr, used) }
    }

    /// The Song tab: the chip and the name on one line, as tall as the lane allows. The chip mutes, as SLOOP's Song
    /// tab did (Scott, 2026-11-06): on the selected track a tap mutes and unmutes; on another it selects, so a stray
    /// tap can't mute a track you weren't on. Muted: the chip goes grey with a line of the track's colour, and a
    /// crossed speaker leads the name.
    @ViewBuilder private var compactBody: some View {
        // the Song tab: the Pads' heads (Scott, 2026-11-09: one set for both views): full on tall lanes, one line on
        // short ones; a section's note, when one is picked, keeps the old line (it says what the section does here)
        if let ui, note == nil {
            Group {
                if laneHeight >= SkiffArrangePage.cardHeads {
                    TrackStripCard(session: session, store: store, ui: ui, track: track)
                } else {
                    TrackStripRow(session: session, store: store, ui: ui, track: track, preview: nil)
                }
            }
            .frame(width: SkiffArrangePage.headWidth(compact: true) - 12, height: laneHeight, alignment: .topLeading)
        } else {
            legacyCompactBody
        }
    }

    private var legacyCompactBody: some View {
        let selected = session.selectedTrack == track
        let muted = session.tracks[track].mute
        return HStack(spacing: 0) {
            MuteChip(session: session, track: track, selected: selected, size: 28)
                .frame(width: 44, height: max(laneHeight, 28))
            Button { session.select(track: track) } label: {
                HStack(spacing: 4) {
                    if muted { Image(systemName: "speaker.slash.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary) }
                    Text(note ?? Entries.trackName(track, session: session)).font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected || note != nil ? Theme.text : Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // long press: the track's menu by the finger, Sounds… first (Scott, 2026-11-06: picking a sound from the
            // Song page is useful; the Song tab's names never had the press the other pages' track list has)
            .trackMenuPress(session: session, ui: ui, track: track)
            .accessibilityLabel("Track \(track + 1), \(Entries.trackName(track, session: session))\(muted ? ", muted" : "")")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
        .frame(width: SkiffArrangePage.headWidth(compact: true) - 12, height: laneHeight, alignment: .leading)
    }

    private func fullBody(_ tr: TrackState, _ used: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MuteChip(session: session, track: track, selected: session.selectedTrack == track, size: 28)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(Entries.trackName(track, session: session) + (tr.mute ? " · muted" : "")).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(tr.engineName + (tr.length != 16 ? " · \(tr.length) steps" : ""))
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                if let note {
                    Text(note).font(.system(size: 11)).foregroundStyle(Theme.text).lineLimit(2).minimumScaleFactor(0.8)
                } else {
                    EntriesUsed(used: used, colour: Theme.track[track])
                }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
        .padding(.trailing, 8)
        .frame(width: SkiffArrangePage.headerWidth, height: laneHeight, alignment: .topLeading)
    }
}

/// How many of a track's 16 entries its list takes: a square each, the used ones in the track's colour.
/// Full and nearly full also say so in words, so the state doesn't rest on colour.
struct EntriesUsed: View {
    let used: Int
    let colour: Color

    var body: some View {
        let _ = BodyCounter.tick("EntriesUsed")
        HStack(spacing: 6) {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(0..<8, id: \.self) { k in
                            RoundedRectangle(cornerRadius: 1.5).fill(row * 8 + k < used ? colour : Theme.stepEmpty)
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
            if used >= 14 {
                Text(used >= 16 ? "Full" : "\(16 - used) left").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text).lineLimit(1).fixedSize()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(used) of 16 entries")
    }
}

struct Ruler: View {
    let bars: Int
    let barWidth: CGFloat
    @Binding var section: SectionRange?
    var selectBlock: () -> Void = {}
    var body: some View {
        let _ = BodyCounter.tick("Ruler")
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6).fill(Theme.panel)
            if let s = section {
                RoundedRectangle(cornerRadius: 6).fill(Theme.text.opacity(0.16))
                    .frame(width: CGFloat(s.to - s.from) * barWidth, height: 24)
                    .offset(x: CGFloat(s.from) * barWidth)
            }
            ForEach(Array(stride(from: 0, to: bars, by: 4)), id: \.self) { b in
                Text("\(b + 1)").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .offset(x: CGFloat(b) * barWidth + 6, y: 4)
            }
        }
        .frame(height: 24)
        .contentShape(Rectangle())
        // drag along it for a bar range across every lane (a tap clears it); two steppers in the bar set it too
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                let a = Int(max(0, min(v.startLocation.x, v.location.x)) / barWidth)
                let b = Int((max(v.startLocation.x, v.location.x) / barWidth).rounded(.up))
                if abs(v.translation.width) < 4 { return }
                selectBlock()
                section = SectionRange(from: max(0, min(a, bars - 1)), to: max(a + 1, min(b, bars)))
            }
            .onEnded { v in if abs(v.translation.width) < 4 { section = nil } })
        .accessibilityHidden(true)
    }
}

struct Lane: View {
    @Environment(\.arrangeLaneHeight) private var laneHeight
    @Environment(\.arrangeCompact) private var compact
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    let barWidth: CGFloat
    let width: CGFloat
    @Binding var selection: EntryRef?
    @Binding var dragPattern: Int?
    @Binding var dropAt: DropSpot?
    @Binding var lifted: EntryRef?
    @Binding var moveAt: MoveSpot?
    /// The block whose menu is open, and how to open one.
    let menuRef: EntryRef?
    let openMenu: (ArrangeMenu, CGPoint) -> Void
    var focus: AccessibilityFocusState<EntryRef?>.Binding
    let ui: EditorUI
    /// A section's range on this track, snapped to its passes (ticks).
    var bracket: ClosedRange<Double>? = nil

    /// The block (or its edge) under a finger: SwiftUI puts it back to nil however the touch ends (let go,
    /// taken by the scroll view, cancelled), and that's where every press's state is cleared.
    @GestureState private var press: EntryRef?
    /// How far the finger has gone since touch-down, where it is, and where it was when the block lifted.
    @State private var travel: CGFloat = 0
    @State private var last: CGPoint = .zero
    @State private var liftedAt: CGPoint?
    @State private var holdTimer: Task<Void, Never>?
    /// A right edge being dragged: the block's last entry and the REPS it would get.
    @State private var stretch: (entry: Int, reps: Int)?
    @State private var stretchStart: Int = 1
    /// A held block being dragged: the finger in the lane, and where on the block it took hold.
    @State private var finger: CGFloat?
    @State private var grab: CGFloat = 0
    @State private var laneFrame: CGRect = .zero
    /// The grid's view box being dragged: the bar it started on and the bar asked for last; when it was last tapped.
    @State private var boxFrom: Int?
    @State private var boxBar: Int?
    @State private var boxTapped: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let holdTime: Duration = .milliseconds(400)
    /// The lane's own coordinates: where a finger is along it, however far the lanes have scrolled.
    private var laneSpace: NamedCoordinateSpace { .named("lane\(track)") }
    /// A hold that wanders further than this before it lifts is a scroll, not a hold.
    static let holdSlop: CGFloat = 10

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store) }
    private func x(_ ticks: Double) -> CGFloat { CGFloat(ticks / SongPlacement.ticksPerBar) * barWidth }
    /// Loop entry (SONG OFF): the blocks say ↻ in place of ×N.
    private var loops: Bool { store.song?.mode == .off }
    /// The SLOOP Arrange page's motion, so the two pages move alike; none with Reduce Motion.
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86) }

    var body: some View {
        let _ = BodyCounter.tick("Lane")
        var list = store.song?.tracks[safe: track] ?? SongList()
        if let s = stretch { list.entries[s.entry].reps = s.reps }
        let blocks = store.blocks(track, list: list)
        let keyed = Self.keyed(blocks, list)
        // a block being moved here: every block laid out where the move would put it (the views stay the
        // list's own, so the one under the finger keeps its gesture), and the RESTs it would add
        let move = moveAt?.track == track ? moveAt : nil
        let preview = Self.preview(move, blocks: blocks, store: store, track: track)
        let selectedPattern: Int? = selection.flatMap { s in
            s.track == track ? list.entries[safe: s.entry]?.poolIndex : nil
        }
        let lastEnd = x(blocks.last?.end ?? 0)
        let spot = dropAt?.track == track ? dropAt : nil
        return ZStack(alignment: .topLeading) {
            // the selected track's lane: no well, the row's colour shows round its blocks (Scott, 2026-11-07)
            RoundedRectangle(cornerRadius: 8).fill(compact && session.selectedTrack == track ? .clear : Theme.well)
            // after the last block: a tap opens the add menu at the finger (repeat, new, rest, pick)
            Color.clear.contentShape(Rectangle())
                .frame(width: max(44, width - lastEnd - 4), height: laneHeight - 12)
                .onTapGesture(coordinateSpace: .global) { at in
                    if !store.offline { openMenu(.add(track), at) }
                }
                .accessibilityElement()
                .accessibilityLabel("Add to track \(track + 1)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openMenu(.add(track), CGPoint(x: laneFrame.minX + lastEnd + 24, y: laneFrame.midY)) }
                .offset(x: lastEnd + 2, y: 6)
            ForEach(Array(keyed.enumerated()), id: \.element.key) { i, item in
                blockView(item.block, list: list, place: preview?.places[i], landing: preview?.moved == i,
                          spot: spot, selectedPattern: selectedPattern)
                    .transition(item.block.kind == .rest && !reduceMotion ? .accordion : .identity)
            }
            if let preview {
                // the RESTs the move would add: they open from their left edge, and close back into it
                ForEach(preview.rests, id: \.key) { r in
                    BlockView(session: session, track: track, block: r.block, list: preview.list, width: max(8, x(r.block.length) - 4),
                              selected: false, linked: false, playing: false, loops: loops)
                        .frame(width: max(8, x(r.block.length) - 4), height: laneHeight - 12)
                        .modifier(Place(x: x(r.block.start) + 2, y: 6))
                        .allowsHitTesting(false)
                        .transition(reduceMotion ? .identity : .accordion)
                }
            }
            if preview == nil, spot == nil, let g = gridEntry(list), let b = blocks.first(where: { $0.kind == .pattern && $0.entries.contains(g) }),
               lifted != EntryRef(track: track, entry: b.entries.lowerBound) {
                // the Song tab: the bar the grid shows, on the block it edits (the box reads the grid's place itself)
                GridViewBox(session: session, store: store, ui: ui, track: track, entry: g, block: b, part: g - b.entries.lowerBound,
                            barWidth: barWidth, laneWidth: width, laneHeight: laneHeight,
                            gesture: boxGesture(b, entry: g))
            }
            if session.playing, let on = list.entryOn, let i = keyed.firstIndex(where: { $0.block.entries.contains(on) }) {
                // how far through its pass the track is, under the block it plays
                let b = keyed[i].block
                PassBar(session: session, track: track, width: max(8, x(preview?.places[i]?.length ?? b.length) - 4))
                    .modifier(Place(x: x(preview?.places[i]?.start ?? b.start) + 2, y: laneHeight - 5))
                    .allowsHitTesting(false)
            }
            if compact, session.playing, preview == nil {
                // where each track is in its entry's REPS, where it goes next, a launch waiting (SongPlayback)
                LaneMarks(session: session, store: store, track: track, blocks: blocks, barWidth: barWidth, laneHeight: laneHeight)
                    .allowsHitTesting(false)
            }
            if let r = bracket {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, lineWidth: 2)
                    .frame(width: max(4, x(r.upperBound) - x(r.lowerBound)), height: laneHeight)
                    .offset(x: x(r.lowerBound))
                    .allowsHitTesting(false)
            }
            if let preview, let m = preview.moved, let at = preview.places[m] {
                // where the moved block lands
                Rectangle().fill(Theme.text).frame(width: 2, height: laneHeight + 8)
                    .modifier(Place(x: x(at.start) - 1, y: -4))
                    .allowsHitTesting(false)
            }
            if let finger, let r = lifted, r.track == track, let b = store.blocks(track).first(where: { $0.entries.lowerBound == r.entry }) {
                // the held block under the finger (level 3); it follows the finger exactly, no animation
                let w = max(8, x(b.length) - 4)
                BlockView(session: session, track: track, block: b, list: store.song?.tracks[safe: track] ?? list, width: w,
                          selected: false, linked: false, playing: false, loops: loops)
                    .frame(width: w, height: laneHeight - 12)
                    .scaleEffect(reduceMotion ? 1 : 1.03)
                    .elevationShadow(.held)
                    .offset(x: finger - grab, y: 6)
                    .allowsHitTesting(false)
                    .transaction { $0.animation = nil }
            }
            if let spot {
                // where the dragged pattern goes: a line, and its ghost lifted under the finger
                Rectangle().fill(Theme.text).frame(width: 2, height: laneHeight + 8)
                    .offset(x: x(spot.at) - 1, y: -4)
                Text(Entries.number(spot.pattern)).font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(width: max(44, x(spot.ticks) - 4), height: laneHeight - 12, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.track[track]).elevationShadow(.held))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.text, lineWidth: 2))
                    .opacity(0.9)
                    .offset(x: x(spot.at) + 2, y: 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: laneHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // an edge being dragged follows the finger exactly; everything else slides (SLOOP Arrange's motion)
        .transaction { if stretch != nil { $0.animation = nil } }
        .animation(motion, value: list.entries)
        .animation(motion, value: spot)
        .coordinateSpace(laneSpace)
        .globalFrame($laneFrame)
        .onChange(of: press) { _, now in
            if let now { startHold(now) } else { endPress() }
        }
        .onDrop(of: [.plainText], delegate: LaneDrop(lane: self, blocks: blocks))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(track + 1), \(Entries.trackName(track, session: session))")
    }

    /// A move's layout: each of the list's blocks (by index) where it would be, the moved one's index, the
    /// RESTs it adds past the end, and the list it would leave (for those RESTs' labels).
    struct Preview {
        var places: [Int: (start: Double, length: Double)]
        var moved: Int?
        var rests: [(key: String, block: SongBlock)]
        var list: SongList
    }

    @MainActor static func preview(_ move: MoveSpot?, blocks: [SongBlock], store: SkiffSongStore, track: Int) -> Preview? {
        guard let move, !move.unchanged, let r = move.result,
              let bi = blocks.firstIndex(where: { $0.entries.lowerBound == move.from }) else { return nil }
        let list = SongList(entries: r)
        let after = store.blocks(track, list: list)
        var others = Array(blocks.indices)
        others.remove(at: bi)
        let at = min(move.to, others.count)
        let added = after.count - blocks.count
        guard added >= 0 else { return nil }
        // the order after: the others, with the RESTs and then the moved block at its place
        let order: [Int?] = others[..<at].map { $0 } + Array(repeating: nil, count: added) + [bi] + others[at...].map { $0 }
        guard order.count == after.count else { return nil }
        var p = Preview(places: [:], moved: bi, rests: [], list: list)
        for (k, o) in order.enumerated() {
            if let o { p.places[o] = (after[k].start, after[k].length) } else { p.rests.append(("rest+\(p.rests.count)", after[k])) }
        }
        return p
    }

    /// Blocks keyed by what they play (their patterns and sounds, the nth of its kind), not by entry number:
    /// a block that moves keeps its view, so it slides to its new place instead of changing in place.
    static func keyed(_ bs: [SongBlock], _ l: SongList) -> [(key: String, block: SongBlock)] {
        var seen: [String: Int] = [:]
        return bs.map { b in
            let sig = b.kind == .gap ? "gap" : b.entries.map { i -> String in
                let e = l.entries[i]
                return "\(e.pattern)" + (e.chained ? "c" : "") + (e.sound.map { "s\($0.s0).\($0.s1)" } ?? "")
            }.joined(separator: "-")
            let n = seen[sig, default: 0]
            seen[sig] = n + 1
            return ("\(sig)#\(n)", b)
        }
    }

    @ViewBuilder
    private func blockView(_ b: SongBlock, list: SongList, place: (start: Double, length: Double)?, landing: Bool,
                           spot: DropSpot?, selectedPattern: Int?) -> some View {
        let start = place?.start ?? b.start
        let bx = x(start) + (spot.map { start >= $0.at - 0.5 ? x($0.ticks) : 0 } ?? 0)
        let ref = EntryRef(track: track, entry: b.entries.lowerBound)
        let w = max(8, x(place?.length ?? b.length) - 4)
        do {
            let isHeld = (lifted == ref && finger == nil) || menuRef == ref
            let selected = selection?.track == track && b.entries.contains(selection?.entry ?? -1)
            let linked = !selected && selectedPattern != nil && b.entries.contains { list.entries[$0].poolIndex == selectedPattern }
            // a held block holds still: no playing mark while it's lifted or its menu is open
            BlockView(session: session, track: track, block: b, list: list, width: w,
                      selected: selected, linked: linked,
                      playing: !isHeld && lifted != ref && session.playing && b.entries.contains(list.entryOn ?? -1),
                      state: compact && session.playing ? LaneMarks.spoken(store.marks(track, launchIn: session.ticksToLaunch(track)), block: b, launch: session.launchMode) : nil,
                      loops: loops)
                .frame(width: w, height: laneHeight - 12)
                // carried: faint in its own place, or, once it would move, an empty dashed place where it lands
                // (the block itself is under the finger). The view stays, so the finger's gesture does too
                .opacity(landing ? 0 : finger != nil && lifted == ref ? 0.35 : 1)
                .overlay {
                    if landing {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
                .scaleEffect(isHeld && !reduceMotion ? 1.03 : 1)
                .shadow(color: .black.opacity(isHeld ? Elevation.held.shadow.opacity : 0),
                        radius: Elevation.held.shadow.radius, y: isHeld ? Elevation.held.shadow.y : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHeld)
                .onTapGesture(count: 2) { open(b) }
                .onTapGesture { selection = ref }
                // hold lifts it: let go for its menu, drag to move it. UIKit's long press, which shares a touch
                // with the lanes' scroll view: a press that moves first scrolls, one held still lifts
                .gesture(HoldRecognizer(space: laneSpace,
                    began: { p, _ in if lifted == nil, !store.offline { liftedAt = p; lifted = ref } },
                    changed: { p, _ in if lifted == ref { carry(b, ref: ref, at: p) } },
                    ended: { _, global, cancelled in
                        if lifted == ref, !cancelled { release(b, ref: ref, at: global) }
                        endPress()
                    }))
                .sensoryFeedback(.impact(weight: .medium), trigger: lifted == ref)
                .accessibilityFocused(focus, equals: ref)
                // the edge: drag at once for REPS, or hold it like the rest of the block
                .overlay(alignment: .trailing) { if b.kind != .gap { grip(b, ref: ref).opacity(landing ? 0 : 1) } }
                .overlay(alignment: .bottomTrailing) {
                    if stretch?.entry == b.entries.upperBound {
                        Text("×\(b.reps) · \(bars(b.length)) bars").font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8).frame(height: 24)
                            .elevated(.held, radius: 6)
                            .offset(x: 40, y: 30)
                    }
                }
                .modifier(Place(x: bx + 2, y: 6))
                .accessibilityAction { selection = ref }
                .accessibilityAction(named: "Edit pattern") { open(b) }
                .accessibilityAction(named: "Play once more") { edits.setReps(track, b, b.reps + 1) }
                .accessibilityAction(named: "Play once less") { edits.setReps(track, b, b.reps - 1) }
                .accessibilityAction(named: "Duplicate after") { edits.duplicateAfter(track, b) }
                .accessibilityAction(named: "Move earlier") { moveBy(b, -1) }
                .accessibilityAction(named: "Move later") { moveBy(b, 1) }
                .accessibilityAction(named: "Delete entry") { edits.delete(track, b) }
        }
    }

    private func bars(_ ticks: Double) -> String {
        let b = ticks / SongPlacement.ticksPerBar
        return b == b.rounded() ? "\(Int(b))" : String(format: "%.2g", b)
    }

    /// The edge you drag for REPS: drawn 8 pt, a 44 pt hit area; a pass at a time.
    private func grip(_ b: SongBlock, ref: EntryRef) -> some View {
        Capsule().fill(Theme.text.opacity(0.35)).frame(width: 4, height: 28)
            // 36 pt wide, 8 pt of it past the edge: no more than the gap and a sliver of the next block
            .frame(width: 36, height: laneHeight - 12)
            .contentShape(Rectangle())
            .offset(x: 8)
            // from touch-down: a drag that waits for movement loses to the lanes' scroll view
            .highPriorityGesture(edgeGesture(b, ref: ref))
            .accessibilityHidden(true)
    }

    // MARK: Pressing a block
    //
    // Held still for 0.4 s (within 10 pt), a block lifts and the lanes stop scrolling; then a drag moves it,
    // and letting go without moving opens its menu. Its edge takes the drag at once, for REPS, so the edge
    // runs its own hold timer: held still there, the block lifts just the same (a narrow block is nearly all
    // edge). However a touch ends (let go, taken by the scroll view, cancelled), endPress puts everything
    // back: the long press says so itself, and the edge's `press` goes back to nil.

    private func edgeGesture(_ b: SongBlock, ref: EntryRef) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: laneSpace)
            .updating($press) { _, state, _ in if state == nil { state = ref } }
            .onChanged { v in
                last = v.location
                if holdTimer == nil && lifted == nil && stretch == nil { startHold(ref) }
                if lifted == ref { carry(b, ref: ref, at: v.location); return }
                travel = max(travel, hypot(v.translation.width, v.translation.height))
                if travel > 4 { stretchTo(b, v) }
            }
            .onEnded { v in
                if lifted == ref {
                    release(b, ref: ref, at: CGPoint(x: v.location.x + laneFrame.minX, y: v.location.y + laneFrame.minY))
                } else {
                    endStretch(b, ref: ref, v)
                }
            }
    }

    /// The Song tab: the entry the grid below edits, when it's on this lane and loaded (the editor's own rule,
    /// PatternPane: the entry pinned on the selected track, else the one it plays; pinned elsewhere while
    /// playing, the grid is greyed and there's no box).
    private func gridEntry(_ list: SongList) -> Int? {
        guard compact, track == session.selectedTrack, let on = list.entryOn, !(list.entries[safe: on]?.isRest ?? true) else { return nil }
        if let p = ui.pinnedEntry, p.track == track, p.entry != on { return nil }
        return on
    }

    /// The grid's view box: dragged, the grid follows bar by bar (one request per bar, as SLOOP's overview); a
    /// tap is a tap on its block (select, twice to open), and held still it lifts the block like the rest of it.
    private func boxGesture(_ b: SongBlock, entry e: Int) -> some Gesture {
        let ref = EntryRef(track: track, entry: b.entries.lowerBound)
        return DragGesture(minimumDistance: 0, coordinateSpace: laneSpace)
            .updating($press) { _, state, _ in if state == nil { state = ref } }
            .onChanged { v in
                last = v.location
                if lifted == ref { carry(b, ref: ref, at: v.location); return }
                travel = max(travel, hypot(v.translation.width, v.translation.height))
                let k = e - b.entries.lowerBound
                guard travel > 4, b.parts.indices.contains(k) else { return }
                let len = max(1, session.tracks[safe: track]?.length ?? 16)
                let bars = GridViewBox<DragGesture>.bars(len)
                if boxFrom == nil { boxFrom = GridViewBox<DragGesture>.bar(ui.viewStep, bars: bars) }
                let barPx = max(8, x(b.parts[k] * 16 / Double(len)))
                let bar = max(0, min(bars - 1, (boxFrom ?? 0) + Int((v.translation.width / barPx).rounded())))
                if bar != boxBar { boxBar = bar; GridViewBox<DragGesture>.show(ui, bar: bar, bars: bars) }
            }
            .onEnded { v in
                let dragged = boxFrom != nil
                boxFrom = nil
                boxBar = nil
                if lifted == ref {
                    release(b, ref: ref, at: CGPoint(x: v.location.x + laneFrame.minX, y: v.location.y + laneFrame.minY))
                    return
                }
                guard !dragged, travel <= 4 else { return }
                if let t = boxTapped, Date().timeIntervalSince(t) < 0.3 {
                    boxTapped = nil
                    open(b)
                } else {
                    boxTapped = Date()
                    selection = EntryRef(track: track, entry: e)
                }
            }
    }

    /// The edge's hold: lifts the block if the finger is still down, near where it started, 0.4 s on.
    private func startHold(_ r: EntryRef) {
        travel = 0
        holdTimer = Task { @MainActor in
            try? await Task.sleep(for: Self.holdTime)
            guard !Task.isCancelled, press == r, travel < Self.holdSlop, stretch == nil, boxFrom == nil, !store.offline, lifted == nil else { return }
            liftedAt = last
            lifted = r
        }
    }

    /// Every way out of a press: the held block, the finger, the edge, the preview, all back to rest.
    private func endPress() {
        holdTimer?.cancel()
        holdTimer = nil
        // after the gesture's own onEnded, which may still need them
        Task { @MainActor in
            if let r = lifted, r.track == track { lifted = nil }
            finger = nil
            liftedAt = nil
            stretch = nil
            travel = 0
            if moveAt?.track == track { withAnimation(motion) { moveAt = nil } }
        }
    }

    private func carry(_ b: SongBlock, ref: EntryRef, at p: CGPoint) {
        let from = liftedAt ?? p
        guard finger != nil || hypot(p.x - from.x, p.y - from.y) > 6 else { return }
        let at = p.x
        if finger == nil { grab = from.x - x(b.start) - 2 }
        finger = at
        let m = MoveSpot.make(store: store, track: track, entry: ref.entry, barWidth: barWidth, at: at)
        if m != moveAt { withAnimation(motion) { moveAt = m } }
    }

    private func release(_ b: SongBlock, ref: EntryRef, at: CGPoint) {
        if finger != nil {
            let m = moveAt
            if let m, !m.unchanged, m.refusal == nil, let es = m.result {
                // the lane already shows the result. The rewrite draws it at once (before its first request),
                // and endPress, queued after it, clears the preview: no jump back in between
                // the selection moves in the same turn as the store's new list, so it never rings the wrong block
                Task {
                    selection = EntryRef(track: track, entry: m.index)
                    await store.rewrite(track: track, to: es, focus: m.index)
                }
            } else if let m, let why = m.refusal {
                // said in the inspector of the block that didn't move, with Stop where stopping lets it
                selection = EntryRef(track: track, entry: m.from)
                store.refuse(track: track, entry: m.from, why, needsStop: why.hasPrefix("Stop"))
            }
            return
        }
        // let go where it was lifted: the menu, at the finger
        selection = ref
        openMenu(.block(ref), at)
    }

    private func stretchTo(_ b: SongBlock, _ v: DragGesture.Value) {
        guard let list = store.song?.tracks[safe: track] else { return }
        if stretch == nil { stretchStart = list.entries[b.entries.upperBound].reps }
        let n = max(1, min(16, stretchStart + Int((v.translation.width / max(1, x(b.pass))).rounded())))
        stretch = (b.entries.upperBound, n)
    }

    private func endStretch(_ b: SongBlock, ref: EntryRef, _ v: DragGesture.Value) {
        // a tap on the edge (no drag) is a tap on its block
        guard let s = stretch else {
            if travel <= 4 { selection = ref }
            return
        }
        if s.reps != stretchStart, let blk = store.blocks(track).first(where: { $0.entries.contains(s.entry) }) {
            edits.setReps(track, blk, s.reps)
        }
    }

    private func moveBy(_ b: SongBlock, _ delta: Int) {
        if let i = edits.move(track, b, by: delta) { selection = EntryRef(track: track, entry: i) }
    }

    /// Double-tap: Sequence on the entry's pattern. Stopped, the track goes to the entry (LIST op 3) first.
    func open(_ b: SongBlock) {
        let e = b.entries.lowerBound
        selection = EntryRef(track: track, entry: e)
        let on = store.song?.tracks[safe: track]?.entryOn == e
        // playing, LIST op 3 would launch the entry: opening a pattern mustn't change what plays
        if !on && session.playing {
            store.refuse(track: track, entry: e, "Stop to open this entry's pattern: playing, the FM-1 would launch it", needsStop: true)
            return
        }
        Task {
            if !on { guard await store.send(.play(track: track, entry: e)) else { return } }
            session.select(track: track)
            if !compact { ui.page = .sequencer }          // the Song tab: the editor is right below
        }
    }
}

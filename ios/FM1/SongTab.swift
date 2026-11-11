import SloopKit
import SwiftUI

// Skiff's Song tab (canvas boards 19 and 20, design/boards/compose.py; Scott, 2026-11-05: "replacing the top portion
// of the sequence page with the arrange behavior and then adding that movable divider"). Arrange's lanes on top, all
// of their block behaviour, compressed; a divider, dragged and remembered; the selected track's pattern editor below.
// While playing, the editor shows what each track plays now and moves on with it; a block tapped pins it there.

struct SkiffSongPage: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    /// Where the editor sits (Scott, 2026-11-07, boards 32–34): No grid (shut: the pads or lanes full size), Half (the
    /// default: on Pads the pads as tall as the track strip) or Max (the editor largest). Three places, not a free drag:
    /// a drag snaps to the nearest on the spring. One for both views, which share the editor ("should just toggle the
    /// top and leave the bottom, since they are the same"). Kept across launches.
    @AppStorage(SongPosition.key) private var storedPosition = SongPosition.half.rawValue
    /// The pads' track controls open (PadsPage's choice): at Max they hang over the editor.
    @AppStorage("padControlsOpen") private var padControlsOpen = true
    /// The position the layout follows: plain state, set inside the spring, so a tap of the tab animates (a change to
    /// the stored setting carried no animation, and Open and Close jumped; Scott, 2026-11-08). Saved as it changes.
    @State private var placed: SongPosition?
    private var position: SongPosition { placed ?? SongPosition(rawValue: storedPosition) ?? .half }
    private var positionRaw: Int {
        get { position.rawValue }
        nonmutating set { placed = SongPosition(rawValue: newValue); storedPosition = newValue }
    }
    /// A drag in progress: the top half's height under the finger (with some give past the ends); nil, at rest.
    @State private var dragTop: CGFloat?
    @State private var dragFrom: CGFloat = 0
    /// The pads' layout, set inside the spring so pads and track rows morph with it (Scott, 2026-11-07: "animate in
    /// size, shape and position"); while dragging, the nearest position's.
    @State private var layout: PadsLayout?
    @State private var allPatterns = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.grid) private var grid

    /// (420: the step inspector's short layout fits whole at the editor's least, never scrolling; 2026-11-06)
    static let editorMin: CGFloat = 420
    /// The panel's lip under the tab when the editor is shut, and its padding round the editor.
    static let lip: CGFloat = 12, inset: CGFloat = 12
    /// The panel's tint stands this far in from the page's edges: none, so it's as wide as the pads and lanes over it
    /// and its tab sits under the track strip (Scott, 2026-11-09: 16 in, it read too narrow). The editor sits `inset`
    /// inside it, so nothing spills past the tint.
    static let panelEdge: CGFloat = 0
    /// The song's least: the tool row, the ruler and every lane at its least (28 pt and its gap), so it never spills.
    /// (no tool row in it since 2026-11-10: the top bar has the Timeline's tools)
    static func songMin(_ tracks: Int) -> CGFloat { 24 + 8 + CGFloat(tracks) * (28 + SkiffArrangePage.laneGap) }
    /// The give past either end: the drag follows the finger at this rate there.
    static let give: CGFloat = 0.3
    private var spring: Animation? { reduceMotion ? .easeOut(duration: 0.2) : .spring(response: DividerFeel.current.response * Self.slow, dampingFraction: DividerFeel.current.damping) }
    /// -slow-motion: the spring eight times slower, to watch a transition frame by frame (screen recordings, checks).
    static let slow: Double = LaunchArgs.all.contains("-slow-motion") ? 8 : 1

    /// The top half's height at each position. Half: the pads as tall as the strip (PadsPage.halfTop), the Timeline the
    /// same so the editor doesn't move between views; the editor's least wins on a short screen. Max: the pads' one row,
    /// or the lanes at their least.
    private func tops(_ total: CGFloat, pads: Bool) -> [SongPosition: CGFloat] {
        let lanes = Self.songMin(session.trackCount) + PadsPage.tabHeight + 8
        let maxTop = pads ? PadsPage.rowTop : lanes
        let half = max(maxTop, min(PadsPage.halfTop(session.trackCount), total - Self.editorMin))
        return [.none: total - Self.lip, .half: max(half, pads ? 0 : lanes), .max: min(maxTop, half)]
    }

    /// Pads ↔ Timeline (Scott, 2026-11-08, in place of the fold): the Timeline slides down behind the editor as the pads
    /// come in from above, and back up the same way. The top half is clipped at its foot, so what goes down goes under
    /// the panel. Both move as whole pictures (no re-layout per frame). Reduce Motion: a crossfade. Labs sets the time.
    private var songSlide: Animation? {
        let t = Labs.songSlide.value
        if t == 0 { return nil }
        return reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: t)
    }

    var body: some View {
        let _ = BodyCounter.tick("SkiffSongPage")
        let pads = ui.songView == .pads && store.performs && store.song != nil
        GeometryReader { g in
            let total = g.size.height
            let tops = tops(total, pads: pads)
            let rest = tops[position] ?? total
            let top = dragTop ?? rest
            let shown = layout ?? position.layout
            let editorShown = dragTop != nil || position != .none
            // (the track controls close over the largest editor, Scott 2026-11-09: nothing hangs over it now)
            // the Timeline's open track controls hang from the lane, past the lanes' foot over the editor where they don't
            // fit above (Scott, 2026-11-10: "fix the clipping"); the Pads' still close over the editor
            let overEditor = !pads && padControlsOpen && position != .none
            // the editor keeps its height while it slides under the fold, the page clipping it
            let bottom = max(Self.editorMin, total - top)
            VStack(spacing: 0) {
                // Pads and Timeline: the pads come in from above as the Timeline goes down behind the editor, and back
                ZStack(alignment: .topLeading) {
                    if pads {
                        PadsPage(session: session, store: store, ui: ui, layout: shown)
                            .transition(reduceMotion ? .opacity : .move(edge: .top))
                    } else {
                        SkiffArrangePage(session: session, store: store, ui: ui)
                            .environment(\.arrangeCompact, true)
                            .environment(\.arrangeLaneHeight, Self.laneHeight(top - PadsPage.tabHeight - 8, tracks: session.trackCount))
                            .padding(.bottom, PadsPage.tabHeight + 8)        // the panel's tab under the lane heads
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    }
                }
                .animation(songSlide, value: pads)
                // both halves pinned to the page's width: left loose, swapping the panel's contents (the sampler for
                // the editor) re-centred the top half 12 pt to the left (Scott, 2026-11-09)
                .frame(width: g.size.width, height: top)
                // (Timeline / Pads: the switch is in the top bar since 2026-11-10, board 47, still while they slide)
                // clipped at the foot only: a key on the top row (Cancel waiting) draws its raised edge a point
                // above the page and was cut (Scott, 2026-11-08). At Max on Pads the selected pad's track controls
                // hang down over the editor (no room above or below a single row), so there the foot gives way and
                // the pads draw over the panel (Scott, 2026-11-09: open stays open at every size)
                .mask(alignment: .bottom) { Rectangle().padding(.top, -24).padding(.bottom, overEditor ? -(TrackKnobBox.height(for: session) + 40) : 0) }
                .zIndex(overEditor ? 1 : 0)
                // shut, a swipe up from the foot of the page brings the editor back (beside the scene keys' taps)
                .simultaneousGesture(DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { v in
                        guard dragTop != nil || (v.startLocation.y > top - Self.pullZone && v.translation.height < 0) else { return }
                        ui.pulledAt = Date()
                        dragged(v.translation.height, tops: tops, pads: pads)
                    }
                    .onEnded { v in if dragTop != nil { ui.pulledAt = Date(); released(tops: tops, pads: pads, speed: v.velocity.height) } },
                    including: position == .none || dragTop != nil ? .all : .subviews)
                ZStack(alignment: .top) {
                    EditorPanelShape(tab: CGSize(width: PadsPage.panelTabWidth, height: PadsPage.tabHeight), inset: Self.panelEdge)
                        .fill(SelectionTint.fill(session.selectedTrack))
                    // a sample being made for the track: the sampler comes in from the right and pushes the editor off to the
                    // left, and back the other way on Cancel or a save (Scott, 2026-11-09); the pads above stay put
                    // the editor rising with the panel: no slide of its own, so it comes up with the tint (Scott,
                    // 2026-11-09: it moved in sideways, the sampler's swap transition firing on every rise); the
                    // sideways swap is only between the sampler and the editor, inside
                    if editorShown {
                        ZStack(alignment: .top) {
                            if let r = ui.sampler, !r.fromBrowse {
                                SamplerPanel(session: session, ui: ui, request: r)
                                    // held to the panel's inside: a wider sampler pushed the page and shifted it all 12 pt left
                                    .frame(width: max(0, g.size.width - 2 * (Self.panelEdge + Self.inset)))
                                    .padding(.vertical, Self.inset)
                                    .padding(.horizontal, Self.panelEdge + Self.inset)
                                    .geometryGroup()    // one piece: its keys' highlights don't trail it
                                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                                    .zIndex(1)          // above the tint while it leaves too, or it drops behind it and vanishes
                            } else {
                                PatternPane(session: session, store: store, ui: ui, height: bottom - 2 * Self.inset, trackMenu: pads && shown == .row)
                                    // the grid's steps give up the panel's edges, so a bar still fits across inside the tint
                                    .environment(\.grid, inPanel)
                                    .environment(\.flatPanels, true)
                                    .padding(.vertical, Self.inset)
                                    .padding(.horizontal, Self.panelEdge + Self.inset)
                                    .geometryGroup()
                                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
                                    .zIndex(1)
                            }
                        }
                        // opening from shut: the editor comes up from the panel's foot on the panel's own spring, so it
                        // rises with the tint instead of being uncovered by it (Scott, 2026-11-09)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                        .zIndex(1)
                    }
                }
                .frame(width: g.size.width, height: bottom, alignment: .top)
                // the panel's header strip (its top edge to the grid) drags and flicks the panel too, as the tab does
                // (Scott, 2026-11-09); its keys still take their taps (a drag starts past 12 pt, mostly up or down)
                .simultaneousGesture(DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { v in
                        guard dragTop != nil || (v.startLocation.y < Self.headerGrab && abs(v.translation.height) > abs(v.translation.width)) else { return }
                        ui.pulledAt = Date()
                        dragged(v.translation.height, tops: tops, pads: pads)
                    }
                    .onEnded { v in if dragTop != nil { ui.pulledAt = Date(); released(tops: tops, pads: pads, speed: v.velocity.height) } })
                // cut to the panel's own shape (its tab included): what slides in and out shows only on the tint
                .mask { EditorPanelShape(tab: CGSize(width: PadsPage.panelTabWidth, height: PadsPage.tabHeight), inset: Self.panelEdge) }
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.9), value: ui.sampler)
            }
            .frame(height: total, alignment: .top)
            .mask(alignment: .bottom) { Rectangle().padding(.top, -24) }
            .overlay(alignment: .topLeading) { tab(top: top, tops: tops, pads: pads) }
            .overlay { drawer }
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.3), value: ui.poolOpen)
        }
        // each pattern a track is on, drawn for its pads (PadThumb): in both views, so the pads have them on arrival
        .task {
            while !Task.isCancelled {
                PadThumb.learn(session, store, ui)
                await PadThumb.fromPool(session, store, ui)
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onAppear { SongPosition.migrate() }
        // Edit pattern from a pad with the editor shut: it opens (PadsPage asks through ui.openEditor)
        .onChange(of: ui.openEditor) { _, v in
            guard v > 0 else { return }
            if position == .none { withAnimation(spring) { positionRaw = SongPosition.half.rawValue; layout = nil } }
        }
        // the sampler asked for with the editor shut: it opens to Half to hold it
        .onChange(of: ui.sampler) { _, r in
            if let r, !r.fromBrowse, position == .none { withAnimation(spring) { positionRaw = SongPosition.half.rawValue; layout = nil } }
        }
    }


    private var inPanel: GridMetrics {
        var g = grid
        // all the room the panel takes round the editor, the edge and the inset (only the edge was given up, and the
        // grid ran out to the tint's sides with no inset)
        g.stepWidth = grid.stepWidth - 2 * (Self.panelEdge + Self.inset) / 16
        return g
    }

    /// The panel's tab, in the scene row's line (Scott's own alignment on board 31): Open at No grid, Close at Half,
    /// Less at Max. Tapped, the next place; dragged, the divider.
    private func tab(top: CGFloat, tops: [SongPosition: CGFloat], pads: Bool) -> some View {
        // which way it can go, as three chevrons in a row (Scott, 2026-11-09: words don't say the possibilities): shut, all
        // up; half, one up then two down; largest, all down
        let ups: [Bool] = switch position {
        case .none: [true, true, true]
        case .half: [true, false, false]
        case .max: [false, false, false]
        }
        return Button {
            guard !ui.justPulled else { return }          // (the lift that ends a drag of the tab isn't a tap)
            let next: SongPosition = switch position { case .none: .half; case .half: .none; case .max: .half }
            withAnimation(spring) { positionRaw = next.rawValue; layout = nil }
        } label: {
            TabCarets(ups: ups, colour: Theme.track[session.selectedTrack])   // (the track's colour on its tint: Scott, 2026-11-09)
            .frame(width: PadsPage.panelTabWidth, height: PadsPage.tabHeight)
            .contentShape(Rectangle())
            .geometryGroup()                   // rides the tab's spring with it (the words used to lag behind)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in ui.pulledAt = Date(); dragged(v.translation.height, tops: tops, pads: pads) }
            .onEnded { v in ui.pulledAt = Date(); released(tops: tops, pads: pads, speed: v.velocity.height) })
        .offset(x: Self.panelEdge, y: top - PadsPage.tabHeight)
        .accessibilityLabel("Pattern editor")
        .accessibilityValue(position == .none ? "closed" : position == .half ? "half" : "largest")
        .accessibilityHint(position == .none ? "Opens the pattern editor" : position == .half ? "Closes the pattern editor" : "Makes the pattern editor smaller")
        .accessibilityAdjustableAction { d in
            // increment (swipe up) makes the editor larger, as its value reads: closed, half, largest (2026-11-10:
            // it went the other way, swipe up closed it)
            let order: [SongPosition] = [.none, .half, .max]
            let i = order.firstIndex(of: position) ?? 1
            let j = d == .increment ? min(2, i + 1) : max(0, i - 1)
            withAnimation(spring) { positionRaw = order[j].rawValue; layout = nil }
        }
    }

    /// The nearest place to a top half this tall.
    private func nearest(_ top: CGFloat, _ tops: [SongPosition: CGFloat]) -> SongPosition {
        tops.min { abs($0.value - top) < abs($1.value - top) }?.key ?? .half
    }

    /// A drag of the tab (or, shut, of the foot of the page) `dy` points from where it began.
    private func dragged(_ dy: CGFloat, tops: [SongPosition: CGFloat], pads: Bool) {
        if dragTop == nil { dragFrom = tops[position] ?? 0 }
        let lo = tops[.max] ?? 0, hi = tops[.none] ?? 0
        let at = dragFrom + dy
        dragTop = at < lo ? lo - (lo - at) * Self.give : at > hi ? hi + (at - hi) * Self.give : at
        // the pads take the nearest place's layout as the finger passes, morphing on the spring
        let l = nearest(dragTop ?? at, tops).layout
        if l != (layout ?? position.layout) { withAnimation(spring) { layout = l } }
    }

    /// Let go: a flick (faster than Labs' speed) goes one place on in its direction from where the drag began, however
    /// short it was (Scott, 2026-11-09); slower, the nearest place.
    private func released(tops: [SongPosition: CGFloat], pads: Bool, speed: CGFloat = 0) {
        guard let at = dragTop else { return }
        let order = tops.sorted { $0.value < $1.value }.map(\.key)       // largest editor (top) to shut (bottom)
        var p = nearest(at, tops)
        if abs(speed) > Labs.flickSpeed, let i = order.firstIndex(of: position) {
            p = order[speed < 0 ? max(0, i - 1) : min(order.count - 1, i + 1)]
        }
        withAnimation(spring) { positionRaw = p.rawValue; dragTop = nil; layout = p.layout } completion: { layout = nil }
    }

    /// Shut, a swipe up from the foot of the page brings the editor back: the strip over the tab (the scene row and a
    /// little above) takes it too, beside its keys' taps, so the tab needn't be found (Scott, 2026-11-07).
    static let pullZone: CGFloat = 120
    /// The editor panel's header strip that drags it: its inset, the header row and the gap to the grid.
    static let headerGrab: CGFloat = 76

    /// The pattern pool (Scott: "Full height"): a level-3 drawer down the page's right edge, over both halves, the
    /// source a pattern is dragged from onto a lane. A tap outside, Escape or Patterns closes it. While a pattern is
    /// dragged the tap catcher steps aside, so the drop reaches the lanes (the editor takes none).
    /// (The container stays put and only its contents come and go, so the panel's own slide runs: inserted as a whole,
    /// it had only faded. Scott, 2026-11-09: "make it slide in and out".)
    private var drawer: some View {
        ZStack(alignment: .trailing) {
            if ui.poolOpen {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { ui.poolOpen = false }
                    .allowsHitTesting(ui.dragPattern == nil)
                    .accessibilityHidden(true)
                    .transition(.identity)
                PatternBin(session: session, store: store, all: $allPatterns, selection: ui.pinnedEntry,
                           dragPattern: Binding(get: { ui.dragPattern }, set: { ui.dragPattern = $0 }), drawer: true, ui: ui)
                    .frame(width: 288)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .flashRing(ui, .patternBin)          // SAVE > PATTERNS on the FM-1 lands here
                    // in from the right edge, out quicker (a panel: 300 ms in, ease-out; 220 ms out, ease-in)
                    .transition(reduceMotion ? .opacity
                                : .asymmetric(insertion: .move(edge: .trailing).animation(.easeOut(duration: 0.3)),
                                              removal: .move(edge: .trailing).animation(.easeIn(duration: 0.22))))
                    .background {
                        Button("Close the patterns") { ui.poolOpen = false; ui.dragPattern = nil }
                            .keyboardShortcut(.cancelAction).opacity(0).modifier(ShortcutOnly())
                    }
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { ui.poolOpen = false }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The lanes share what's left under the tool row and the ruler.
    static func laneHeight(_ top: CGFloat, tracks: Int) -> CGFloat {
        let lanes = top - 24 - 8
        // no cap: the lanes share all the room, as the pads' rows do, so at full size they're tall enough for the Pads'
        // full heads (Scott, 2026-11-09: "doesn't use all the vertical space")
        return max(28, lanes / CGFloat(max(1, tracks)) - SkiffArrangePage.laneGap)
    }

}

/// Where the Song tab's editor sits (SkiffSongPage).
enum SongPosition: Int {
    case none = 0, half = 1, max = 2
    static let key = "songPosition"
    /// The pads' layout here: full size, two rows of 8 over the editor, a row of 16 over the largest editor.
    var layout: PadsLayout { switch self { case .none: .full; case .half: .compact; case .max: .row } }
    /// The free drag's stored split before the three places: shut stays shut, anything else is Half.
    static func migrate() {
        let d = UserDefaults.standard
        guard d.object(forKey: key) == nil else { return }
        d.set((d.object(forKey: "songSplit") as? Double ?? 0.4) >= 0.999 ? SongPosition.none.rawValue : SongPosition.half.rawValue, forKey: key)
    }
}

/// The editor's panel in the selected track's tint with its tab: the tab (`tab`, at `inset` from the left) rising
/// from the panel's top-left, a concave fillet where it meets the panel's top edge, the panel's other corners round.
struct EditorPanelShape: Shape {
    var tab: CGSize
    var inset: CGFloat
    static let r: CGFloat = 12, f: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let r = Self.r, f = Self.f, x0 = rect.minX + inset, x1 = x0 + tab.width, y = rect.minY, ty = y - tab.height
        let right = rect.maxX - inset
        var p = Path()
        p.move(to: CGPoint(x: x0, y: ty + r))
        p.addArc(tangent1End: CGPoint(x: x0, y: ty), tangent2End: CGPoint(x: x0 + r, y: ty), radius: r)
        p.addLine(to: CGPoint(x: x1 - r, y: ty))
        p.addArc(tangent1End: CGPoint(x: x1, y: ty), tangent2End: CGPoint(x: x1, y: ty + r), radius: r)
        p.addLine(to: CGPoint(x: x1, y: y - f))
        p.addQuadCurve(to: CGPoint(x: x1 + f, y: y), control: CGPoint(x: x1, y: y))
        p.addLine(to: CGPoint(x: right - r, y: y))
        p.addArc(tangent1End: CGPoint(x: right, y: y), tangent2End: CGPoint(x: right, y: y + r), radius: r)
        p.addLine(to: CGPoint(x: right, y: rect.maxY))
        p.addLine(to: CGPoint(x: x0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The bottom half: whose pattern, which entry, follow or pinned; then the step panel and the editor.
struct PatternPane: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let height: CGFloat
    /// Max on Pads: the track strip folded away, the track's name is its menu (Scott, 2026-11-07, board 34).
    var trackMenu = false
    @State private var headerFrame: CGRect = .zero

    static let headerHeight: CGFloat = 44

    var body: some View {
        let _ = BodyCounter.tick("PatternPane")
        let t = session.selectedTrack
        let list = store.song?.tracks[safe: t]
        let pinned = ui.pinnedEntry.flatMap { $0.track == t ? $0 : nil }
        let entry = pinned?.entry ?? list?.entryOn
        let loaded = pinned == nil || pinned?.entry == list?.entryOn
        // pinned to an entry the track isn't on while the song plays: Skiff edits only the pattern a track has, so the
        // editor stays on what plays, editable, with a line saying the pinned one opens when it comes in (Scott,
        // 2026-11-09: the panel over the steps that said so interrupted too often). It switches by itself when the
        // entry starts (the pin then matches); stopped, the track goes there.
        let waiting = !loaded && session.playing ? pinned : nil
        let live = loaded || waiting != nil
        let editor = height - Self.headerHeight - 12
        VStack(alignment: .leading, spacing: 12) {
            header(t, list: list, entry: waiting != nil ? list?.entryOn : entry, pinned: pinned, waiting: waiting)
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    Group {
                        if session.isKit(t) { SelectedStepPanel(session: session, ui: ui) }
                        else { SkiffStepInspector(session: session, ui: ui) }
                    }
                    .flashRing(ui, .stepPanel)
                }
                .frame(width: Overview.boxWidth, height: editor)
                ZStack {
                    Group {
                        if session.isKit(t) { DrumGrid(session: session, ui: ui) } else { PianoRoll(session: session, ui: ui, track: t) }
                    }
                    .flashRing(ui, .grid)
                    .opacity(live ? 1 : 0.35)
                    .allowsHitTesting(live)
                }
            }
            .environment(\.editorHeight, editor)
            .environment(\.arrangeCompact, true)
        }
        // following: the track moved on to another entry, so the editor reads its pattern now, not at the next resync
        // (one trigger for a change of entry and pattern together: two had read the whole track twice, 2026-11-11)
        .onChange(of: "\(list?.entryOn ?? -1).\(list?.patternOn ?? -1)") { _, _ in Task { await session.rereadSteps(track: t) } }
        // stopped while pinned to another entry: the track goes there (LIST op 3), and its pattern opens
        .onChange(of: session.playing) { _, on in
            guard !on, let p = pinned, list?.entryOn != p.entry else { return }
            Task { await store.send(.play(track: p.track, entry: p.entry)) }
        }
    }

    // MARK: Header: "Bass · pattern 07 · entry C · also on entries D", Make unique, the picker; follow or pinned

    private func header(_ t: Int, list: SongList?, entry: Int?, pinned: EntryRef?, waiting: EntryRef? = nil) -> some View {
        let e = entry.flatMap { list?.entries[safe: $0] }
        let pattern = e.flatMap { $0.isRest || $0.isEmpty ? nil : $0.pattern } ?? list?.patternOn
        let shared = entry.map { list?.sharing($0) ?? [] } ?? []
        return HStack(spacing: 10) {
            if trackMenu {
                tracksMenu(t)
            } else {
                TrackChip(track: t, selected: true).frame(width: 28, height: 28)
                Text(Entries.trackName(t, session: session)).font(.lupe(15, .semibold)).lineLimit(1)
            }
            Button { openPicker(t, entry: entry) } label: {
                HStack(spacing: 4) {
                    Text("pattern").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                    Text(pattern.map(Entries.number) ?? "–").font(.lupe(15, .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10).frame(height: 36).raisedKey()
                .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(entry == nil || store.offline)
            .accessibilityLabel("Pattern \(pattern.map(Entries.number) ?? "none")")
            .accessibilityHint("Pick another pattern for this entry, or a new empty one")
            // (no "entry B" here: Scott, 2026-11-07)
            if let w = waiting { waitingLine(w) }
            if !session.isKit(t) { MotionChip(session: session, ui: ui, track: t) }
            if !shared.isEmpty, let entry {
                Text("also on entr\(shared.count == 1 ? "y" : "ies") \(shared.map(Entries.letter).joined(separator: ", "))")
                    .font(.lupe(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                Button { Task { await store.send(.copy(track: t, entry: entry)) } } label: {
                    Text("Make unique").font(.lupe(13, .semibold)).padding(.horizontal, 12).frame(height: 36).raisedKey()
                }
                .buttonStyle(PressSink())
                .disabled(store.offline || session.playing)
                .accessibilityHint("Gives this entry its own copy of the pattern")
            }
            Spacer(minLength: 0)
            // what's picked and what can be done to it: in the header's empty middle, under the divider's handle
            // (Scott, 2026-11-06: over the grid's foot it covered the velocity and the motion lanes)
            SelectionBar(edits: StepEdits(session: session, ui: ui, track: t,
                                          rows: session.isKit(t) ? [] : PianoRoll.rows(session.tracks[t], keeping: ui.keptRows[t] ?? [])),
                         notes: !session.isKit(t), inline: true)
                .fixedSize()
            Spacer(minLength: 0)
            followToggle(t, entry: entry, pinned: pinned)
        }
        .frame(height: Self.headerHeight)
        .globalFrame($headerFrame)
    }

    /// The six tracks in a menu (Max on Pads): pick one, see what it plays, mute it. A long press on a track elsewhere
    /// keeps its own menu (Sounds…, clear).
    private func tracksMenu(_ t: Int) -> some View {
        // the pad press menu's look, as every menu (Scott, 2026-11-08), opened under the key
        Button {
            ui.menu = AppMenu(title: "Tracks", groups: { tracksGroups(t) }, at: CGPoint(x: headerFrame.minX, y: headerFrame.maxY - 4), fromKey: true)
        } label: {
            HStack(spacing: 8) {
                TrackChip(track: t, selected: true).frame(width: 28, height: 28)
                Text(Entries.trackName(t, session: session)).font(.lupe(15, .semibold)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 4).padding(.trailing, 10).frame(height: 40).raisedKey()
        }
        .buttonStyle(PressSink())
        .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))")
        .accessibilityHint("Pick a track or mute one")
    }

    private func tracksGroups(_ t: Int) -> [[MenuItem]] {
        let perf = store.perform
        let pick = session.trackIndices.map { k -> MenuItem in
            let list = store.song?.tracks[safe: k]
            let plays = list?.entryOn.flatMap { e in list?.entries[safe: e].map { $0.isEmpty ? "" : $0.isRest ? "\(Entries.letter(e)) · rest" : "\(Entries.letter(e)) · \(Entries.number($0.pattern))" } } ?? ""
            return MenuItem(title: "\(k + 1) \(Entries.trackName(k, session: session))" + (plays.isEmpty ? "" : "  ·  \(plays)"),
                            chip: ("\(k + 1)", Theme.track[k]), checked: k == t) { session.select(track: k) }
        }
        let mute = session.trackIndices.map { k -> MenuItem in
            let muted = perf?.muted[safe: k] ?? session.tracks[k].mute
            return MenuItem(title: "\(muted ? "Unmute" : "Mute") \(Entries.trackName(k, session: session))",
                            icon: muted ? "speaker.slash.fill" : "speaker.wave.2") { Task { await store.performOp(.mute(track: k)) } }
        }
        return [pick, mute]
    }

    /// Follow, one toggle (Scott, 2026-11-06: "Following the song" was a pill that looked like a button, beside a real
    /// Follow button). On: sunk with its LED lit, the editor showing what the track plays now. Off: raised, and it
    /// says which entry it's pinned to; tapped, it follows again. Tapped while following, it pins the entry playing.
    private func followToggle(_ t: Int, entry: Int?, pinned: EntryRef?) -> some View {
        let on = pinned == nil
        return Button {
            if on { if let entry { ui.pinnedEntry = EntryRef(track: t, entry: entry) } } else { ui.pinnedEntry = nil }
        } label: {
            HStack(spacing: 8) {
                LED(on: on)
                Text("Follow").font(.lupe(13, on ? .semibold : .regular))
                if let p = pinned {
                    Label("pinned to \(Entries.letter(p.entry))", systemImage: "pin.fill")
                        .font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14).frame(height: 36).latchedKey(on)
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: on))
        .disabled(on && entry == nil)
        .help(on ? "Following the song: tap to stay on this entry" : "Pinned to entry \(Entries.letter(pinned!.entry)): tap to follow the song")
        .accessibilityLabel("Follow the song")
        .accessibilityValue(on ? "on" : "off, pinned to entry \(Entries.letter(pinned!.entry))")
        .accessibilityHint(on ? "Keeps the editor on this entry" : "Shows the pattern each track plays now again")
        .accessibilityAddTraits(on ? [.isToggle, .isSelected] : .isToggle)
    }

    /// The picker: the pool's patterns, those in use and the free ones, and a new empty one (LIST op 1, op 7).
    private func openPicker(_ t: Int, entry: Int?) {
        guard let entry else { return }
        let pool = store.pool?.patterns ?? []
        let used = pool.indices.filter { !pool[$0].isFree }, free = pool.indices.filter { pool[$0].isFree }
        ui.menu = AppMenu(title: "T\(t + 1) · entry \(Entries.letter(entry))", groups: {
            [[MenuItem(title: "New empty pattern", icon: "plus.square") { Task { await store.send(.new(track: t, entry: entry)) } }],
             used.map { i in
                MenuItem(title: "Pattern \(Entries.number(i + 1)) · \(pool[i].length) steps", chip: (Entries.number(i + 1), Theme.track[t])) { Task { await store.send(.set(track: t, entry: entry, pattern: i + 1)) } }
             },
             free.isEmpty ? [] : [MenuItem(title: "Free patterns: \(free.count)", enabled: false, note: true)],
             [MenuItem(title: "Show the pattern pool", icon: "square.grid.2x2") { ui.poolOpen = true }]].filter { !$0.isEmpty }
        }, at: CGPoint(x: headerFrame.minX + 200, y: headerFrame.maxY), fromKey: true)
    }

    /// The pinned entry waiting to come in (the song plays and the track is on another): said in the header, with a
    /// way to stop and edit it now. Nothing covers the steps. (Wording, Scott 2026-11-06: plain English, what each
    /// button does said on it.)
    private func waitingLine(_ p: EntryRef) -> some View {
        let c = Entries.letter(p.entry)
        return HStack(spacing: 8) {
            Image(systemName: "clock").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Text("\(c) opens when it comes in").font(.lupe(13)).foregroundStyle(Theme.text).lineLimit(1)
            Button { session.setPlaying(false) } label: {
                Text("Stop and edit \(c)").font(.lupe(13, .semibold)).padding(.horizontal, 12).frame(height: 36).raisedKey()
            }
            .buttonStyle(PressSink())
            .accessibilityHint("Stops the song and opens entry \(c) in the editor")
        }
        .accessibilityElement(children: .contain)
    }
}

/// Which way the Song tab shows the song. It follows the playback mode when that changes (Loop entry: Pads; Play song
/// and Play once: Timeline) and holding ARP on the FM-1 (Skiff's PERFORM layer); in between, the switch is the user's.
enum SongView: Equatable { case timeline, pads }

/// Timeline / Pads, at the head of either view.
struct SongViewSwitch: View {
    let ui: EditorUI

    /// Two icons in one key, the view you're in lit (Scott, 2026-11-09, board 43): bars of different lengths for the
    /// Timeline, a grid for the Pads. VoiceOver and a hold say the names.
    var body: some View {
        HStack(spacing: 2) {
            option(.timeline, "Timeline: every track's entries along the bars") { TimelineGlyph() }
            option(.pads, "Pads: every track's entries to launch, the scenes under them") { Image(systemName: "square.grid.2x2.fill").font(.system(size: 17, weight: .semibold)) }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.well))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Song view")
    }

    private func option<G: View>(_ v: SongView, _ hint: String, @ViewBuilder glyph: () -> G) -> some View {
        let on = ui.songView == v
        return Button { ui.songView = v } label: {
            glyph()
                .foregroundStyle(on ? Theme.text : Theme.textSecondary)
                .frame(width: 52, height: 38)
                .background { if on { RoundedRectangle(cornerRadius: 9).fill(Theme.control) } }   // (12 = 9 + its 3 inset)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.15), value: on)
        }
        .buttonStyle(PressSink())
        .help(v == .pads ? "Pads" : "Timeline")
        .accessibilityLabel(v == .pads ? "Pads" : "Timeline")
        .accessibilityHint(hint)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The Timeline's icon: three bars of different lengths, as blocks along bars.
private struct TimelineGlyph: View {
    var body: some View {
        Canvas { ctx, sz in
            let h: CGFloat = 4, r: CGFloat = 1.5
            let rows: [(CGFloat, CGFloat)] = [(0, 0.45), (0.5, 1), (0, 0.65)]
            for (k, (a, b)) in rows.enumerated() {
                let y = 3 + CGFloat(k) * (h + 3)
                ctx.fill(Path(roundedRect: CGRect(x: a * sz.width, y: y, width: (b - a) * sz.width, height: h), cornerRadius: r), with: .foreground)
            }
        }
        .frame(width: 20, height: 22)
    }
}

import SloopKit
import SwiftUI

// Arrange on Skiff (vault skiff-arrange-spec.md; the canvas's board A): one bar ruler, a lane per track, a
// block per list entry as wide as it plays, the selected entry's inspector below and the pattern pool at the
// side. Entries play back to back, so every change is a rewrite of a track's list (SkiffSongStore); while
// playing, what Skiff can't take shows "Stop to rearrange" where it was tried.

struct SkiffArrangePage: View {
    @Environment(\.arrangeLaneHeight) private var laneHeight
    @Environment(\.arrangeCompact) private var compact
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    @State private var selection: EntryRef?
    @State private var zoomBars: Int?
    @State private var allPatterns = false
    /// A pattern being dragged from the bin (set when the drag starts; EditorUI's, so the Song tab's drawer can
    /// start one), and where it would go.
    private var dragPattern: Int? { ui.dragPattern }
    private var dragPatternBinding: Binding<Int?> { Binding(get: { ui.dragPattern }, set: { ui.dragPattern = $0 }) }
    @State private var dropAt: DropSpot?
    /// A block held (lifted, the lanes don't scroll), where it would move to, and the menu open (a block's,
    /// an entry's sounds, a lane's add menu).
    @State private var lifted: EntryRef?
    @State private var moveAt: MoveSpot?
    @State private var menu: OpenMenu?
    @State private var pageFrame: CGRect = .zero
    @AccessibilityFocusState private var blockFocus: EntryRef?
    /// A bar range across the lanes (board 3): its first bar and the bar after its last, 0-based.
    @State private var section: SectionRange?
    @State private var leftOut: Set<Int> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The track controls open (the Pads' choice, shared: one switch for both views).
    @AppStorage("padControlsOpen") private var controlsOpen = true

    static let headerWidth: CGFloat = 152
    /// The Song tab's Timeline: the Pads' heads and their width (Scott, 2026-11-09: one set of track heads for both),
    /// so its lanes start where the pads do.
    static func headWidth(compact: Bool) -> CGFloat { compact ? PadsPage.compactStrip + 12 : headerWidth }
    private var headW: CGFloat { Self.headWidth(compact: compact) }
    static let fullLaneHeight: CGFloat = 80
    static let laneGap: CGFloat = 8
    static let binWidth: CGFloat = 272

    var body: some View {
        let _ = BodyCounter.tick("SkiffArrangePage")
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                toolRow
                if store.song == nil {
                    SkeletonLanes(count: session.trackCount)
                } else if (store.song?.tracks.allSatisfy { $0.used == 0 }) ?? true {
                    EmptySong(session: session, store: store)
                } else {
                    lanesArea
                }
                if let s = section {
                    SectionBar(range: s, songBars: max(songBars, 1), plans: sectionPlans(.duplicateAfter),
                               leftOut: $leftOut, busy: store.busy || store.offline,
                               set: { section = $0 }, apply: { applySection($0) }, cancel: { section = nil; leftOut = [] })
                    if let r = store.refusal, r.entry == nil { RefusalLine(refusal: r, session: session, store: store) }
                } else if let line = dropAt?.text ?? moveAt?.text {
                    Text(line).font(.lupe(13)).padding(.horizontal, 12).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                        .padding(.leading, headW)
                } else if let r = store.refusal, r.entry == nil || selection == nil {
                    RefusalLine(refusal: r, session: session, store: store)
                }
                if !compact { inspector }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // (the Song tab: the pool is a full-height drawer of the page's, SkiffSongPage)
            if !compact {
                PatternBin(session: session, store: store, all: $allPatterns, selection: selection, dragPattern: dragPatternBinding)
                    .frame(width: Self.binWidth)
                    .flashRing(ui, .patternBin)          // SAVE > PATTERNS on the FM-1 lands here
            }
        }
        // the Song tab: a block selected is the one the editor below shows (pinned); Follow lets it go
        .onChange(of: selection) { _, r in
            guard compact, r != ui.pinnedEntry else { return }
            ui.pinnedEntry = r
            if let r { pin(r) }
        }
        .onChange(of: ui.pinnedEntry) { _, r in if compact, r != selection { selection = r } }
        .overlay(alignment: .top) { if store.offline { OfflineBar(session: session) } }
        .overlay { menuOverlay }
        .globalFrame($pageFrame)
        // a menu on an entry that's gone (the song changed under it) closes; leaving the page drops every hold
        .onChange(of: store.song) { if let m = menu, !menuStillThere(m) { menu = nil } }
        // an entry's sounds belong to the selected entry: another one selected, they close
        .onDisappear { menu = nil; lifted = nil; moveAt = nil; dropAt = nil }
        .task(id: store.offline) { if !store.offline { await store.follow() } }
        // a change that would erase a pattern asks first (CLEAR erases one nothing else uses)
        .confirmationDialog(store.confirmation?.title ?? "", isPresented: Binding(
            get: { store.confirmation != nil }, set: { if !$0 { store.confirmation = nil } }), titleVisibility: .visible,
                            presenting: store.confirmation) { c in
            Button(c.confirmLabel, role: .destructive) {
                store.confirmation = nil
                Task { await c.action() }
            }
            Button("Cancel", role: .cancel) { store.confirmation = nil }
        } message: { c in Text(c.message) }
    }

    /// The block whose menu is open: it stays lifted, and holds still.
    private var menuRef: EntryRef? { if case .block(let r) = menu?.kind { r } else { nil } }

    // MARK: Menus (canvas board 2): Lupe's own, at the finger, one style across the page

    private var menus: ArrangeMenus { ArrangeMenus(session: session, store: store, ui: ui) { selection = $0 } }

    private func openMenu(_ kind: ArrangeMenu, _ at: CGPoint) { menu = OpenMenu(kind: kind, at: at) }

    private func block(_ r: EntryRef) -> SongBlock? { store.blocks(r.track).first { $0.entries.contains(r.entry) } }

    private func menuStillThere(_ m: OpenMenu) -> Bool {
        switch m.kind {
        case .block(let r): block(r) != nil
        case .add(let t): store.song?.tracks[safe: t] != nil
        }
    }

    /// An open menu's title, items, and what closing it does (a block's: focus back to the block).
    private func menuContent(_ m: OpenMenu) -> (title: String, groups: [[MenuItem]], close: () -> Void) {
        switch m.kind {
        case .block(let r):
            let b = block(r)!
            return ("T\(r.track + 1) · entr\(b.isChain ? "ies" : "y") \(Entries.letters(b.entries))", menus.block(r.track, b),
                    { menu = nil; selection = r; blockFocus = r })        // focus goes back to the block
        case .add(let t):
            return ("T\(t + 1) · after the last entry", menus.add(t), { menu = nil })
        }
    }

    private var menuOverlay: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                // a touch anywhere else closes it, and still reaches the page (OutsideTouch)
                Color.clear.allowsHitTesting(false)   // the layer's full size, for the placement; takes no touches
                if let m = menu, menuStillThere(m) {
                    let c = menuContent(m), at = CGPoint(x: m.at.x - pageFrame.minX, y: m.at.y - pageFrame.minY)
                    PlacedMenu(title: c.title, groups: c.groups, at: at, layer: g.size, margin: 0, close: c.close)
                        .id(m)
                        .transition(PlacedMenu.transition(at: at, layer: g.size, reduceMotion: reduceMotion))
                }
            }
        }
    }

    // MARK: Tool row: the song's length, the warning when lanes end apart, zoom

    private var songBars: Int { Int((store.laneEnds.max() ?? 0).rounded(.up)) }

    private var toolRow: some View {
        HStack(spacing: 12) {
            // (its place only: the live switch is the Song tab's, over both views, so it stays put as they slide)
            if compact, store.performs { SongViewSwitch(ui: ui).hidden().accessibilityHidden(true) }
            // the Song tab: the Timeline / Pads switch alone, no "Song · N bars · N tracks" beside it to blur into
            // (Scott, 2026-11-07); the Arrange page keeps it
            if !compact || !store.performs {
                Text("Song").font(.lupe(15, .semibold)).accessibilityAddTraits(.isHeader)
                Text("\(songBars) bar\(songBars == 1 ? "" : "s") · \(session.trackCount) tracks")
                    .foregroundStyle(Theme.textSecondary).lineLimit(1).fixedSize()
            }
            // (the playback mode moved to the top bar, beside play and stop: SongModeKeys, 2026-11-06)
            Spacer(minLength: 8)
            if !store.undoStack.isEmpty {
                // Lupe's own undo: the lists before the last change (a delete, a move, a section)
                Button { Task { await store.undo() } } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward").font(.lupe(15))
                        .padding(.horizontal, 14).frame(height: 44).raisedKey()
                }
                .buttonStyle(PressSink())
                .keyboardShortcut("z", modifiers: .command)
                .disabled(store.busy || store.offline)
            }
            if let w = loopApartWarning {
                // the first to give way when the row is narrow (the sound panel's rail beside it): it shortens
                Label(w, systemImage: "exclamationmark.triangle")
                    .font(.lupe(13)).lineLimit(1).truncationMode(.tail)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                    .layoutPriority(-1)
                    .accessibilityLabel(w)
            }
            if compact {
                Button { ui.poolOpen.toggle() } label: {
                    Label("Patterns", systemImage: "square.grid.2x2").font(.lupe(15))
                        .padding(.horizontal, 14).frame(height: 44).raisedKey()
                }
                .buttonStyle(PressSink(latched: ui.poolOpen))
                .accessibilityHint("The pattern pool: drag a pattern into a lane")
            }
            zoom
        }
        .frame(height: 44)
    }

    /// The Song tab: the editor follows this entry. Stopped, the track goes to it (LIST op 3) so its pattern is the
    /// one Skiff edits; playing, that would launch it, so the editor says so and waits for STOP.
    private func pin(_ r: EntryRef) {
        session.select(track: r.track)
        let l = store.song?.tracks[safe: r.track]
        guard l?.entryOn != r.entry, !session.playing, l?.entries[safe: r.entry]?.isEmpty == false else { return }
        Task { await store.send(.play(track: r.track, entry: r.entry)) }
    }

    /// Lanes that end on different bars loop apart in SONG ON (each track moves on at its own pass ends).
    private var loopApartWarning: String? {
        let ends = store.laneEnds.filter { $0 > 0 }
        guard let lo = ends.min(), let hi = ends.max(), hi - lo >= 0.25 else { return nil }
        func bar(_ b: Double) -> String { b == b.rounded() ? "\(Int(b))" : String(format: "%.1f", b) }
        return "Tracks end at bars \(bar(lo))–\(bar(hi)), so they loop apart"
    }

    private var bars: Int { zoomBars ?? max(8, (songBars + 3) / 4 * 4 + (songBars % 4 == 0 ? 4 : 0)) }

    private var zoom: some View {
        HStack(spacing: 4) {
            Button { zoomBars = min(128, bars * 2) } label: {
                Image(systemName: "minus").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44).raisedKey()
            }
            .buttonStyle(PressSink()).accessibilityLabel("Zoom out")
            Text("\(bars) bars").font(.lupe(13)).foregroundStyle(Theme.textSecondary).frame(width: 64)
                .accessibilityHidden(true)
            Button { zoomBars = max(4, bars / 2) } label: {
                Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44).raisedKey()
            }
            .buttonStyle(PressSink()).accessibilityLabel("Zoom in")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom, \(bars) bars across")
    }

    // MARK: Ruler and lanes

    private var lanesArea: some View {
        GeometryReader { geo in
            let laneWidth = geo.size.width - headW
            let barWidth = laneWidth / CGFloat(bars)
            let contentWidth = max(laneWidth, CGFloat(max(bars, songBars + 1)) * barWidth)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Self.laneGap) {
                    Color.clear.frame(height: 24)
                    let plans = section.map { _ in sectionPlans(.duplicateAfter) } ?? []
                    ForEach(0..<session.trackCount, id: \.self) { t in
                        LaneHeader(session: session, store: store, track: t, note: section.flatMap { s in note(t, plans, s) }, ui: ui)
                    }
                }
                .frame(width: headW)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: Self.laneGap) {
                        Ruler(bars: Int(contentWidth / barWidth), barWidth: barWidth, section: $section,
                              selectBlock: { selection = nil })
                        ForEach(0..<session.trackCount, id: \.self) { t in
                            Lane(session: session, store: store, track: t, barWidth: barWidth, width: contentWidth,
                                 selection: $selection, dragPattern: dragPatternBinding, dropAt: $dropAt, lifted: $lifted, moveAt: $moveAt,
                                 menuRef: menuRef, openMenu: openMenu, focus: $blockFocus, ui: ui,
                                 bracket: bracket(t))
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        SongPlayhead(session: session, store: store, barWidth: barWidth,
                                     height: 24 + CGFloat(session.trackCount) * (laneHeight + Self.laneGap))
                    }
                    .overlay(alignment: .topLeading) { laneControls(barWidth: barWidth, contentWidth: contentWidth) }
                    .frame(width: contentWidth, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(lifted != nil)
            }
            .background(alignment: .topLeading) { selectedRow }
            .opacity(store.offline ? 0.5 : 1)
        }
        .frame(height: 24 + CGFloat(session.trackCount) * (laneHeight + Self.laneGap))
        .disabled(store.offline)
        // a keyboard: arrows move between blocks and lanes, + and − set REPS, Delete deletes, Return opens.
        // Shortcuts on hidden buttons: iPadOS sends them without the lanes holding focus.
        .background { keyboardShortcuts }
    }

    /// The Song tab: the selected track's controls as on the Pads (Scott, 2026-11-09: "match them"): hanging straight
    /// off its lane at the block the editor shows (above where there's room), one strip with the lane, sliding out of
    /// it; they scroll with the blocks. Open or shut is the Pads' choice too.
    @ViewBuilder private func laneControls(barWidth: CGFloat, contentWidth: CGFloat) -> some View {
        let t = session.selectedTrack
        let list = store.song?.tracks[safe: t]
        let entry = ui.pinnedEntry.flatMap { $0.track == t ? $0.entry : nil } ?? list?.entryOn
        let block = entry.flatMap { e in store.blocks(t).first { $0.entries.contains(e) } }
        let total = 24 + CGFloat(session.trackCount) * (laneHeight + Self.laneGap)
        ZStack(alignment: .topLeading) {
            if compact, controlsOpen, dragPattern == nil, lifted == nil, let b = block {
                let h = laneHeight, gap = Self.laneGap
                let laneTop = 24 + gap + CGFloat(t) * (h + gap)
                let bx = CGFloat(b.start / SongPlacement.ticksPerBar) * barWidth + 2
                let bw = max(8, CGFloat(b.length / SongPlacement.ticksPerBar) * barWidth - 4)
                let tab = CGSize(width: TrackKnobBox.width, height: TrackKnobBox.height(for: session))
                let up = laneTop - tab.height >= 0
                let right = bx + tab.width > contentWidth
                let x = right ? max(0, bx + bw - tab.width) : bx
                let y = up ? laneTop - tab.height : laneTop + h
                let s = PadsPage.SelectedGeometry(frame: CGRect(x: bx, y: laneTop, width: bw, height: h), tab: tab, drop: 0, up: up, right: right,
                                                  tabAt: CGPoint(x: x, y: y), knobsAt: CGPoint(x: x, y: y), border: 0, inner: .zero,
                                                  padRadius: 8, earL: gap, earR: gap, col: 1)
                ZStack(alignment: .topLeading) {
                    LaneTabShape(box: CGRect(origin: s.knobsAt, size: tab), earL: gap, earR: gap, r: TrackKnobBox.outerRadius, up: up)
                        .fill(SelectionTint.fill(t))
                    TrackKnobBox(session: session, ui: ui, embedded: true, closesDown: up)
                        .frame(width: tab.width, height: tab.height, alignment: .topLeading)
                        .offset(x: x, y: y)
                }
                .frame(width: contentWidth, height: total, alignment: .topLeading)
                .id("lanebox\(t).\(b.id)")
                .transition(reduceMotion ? .opacity : Emerge.transition(s, row: false, slide: true))
            }
        }
        .frame(width: contentWidth, height: total, alignment: .topLeading)
        .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: block?.id)
        .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: t)
        .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: controlsOpen)
    }

    /// (The old box at the timeline's right end, before the Pads' was shared; kept for the Arrange page's look.)
    /// The Song tab: the selected track's LEVEL, STEPS and PAN at the timeline's right end, just under its lane, or
    /// just above it where it would run past the last lane (Scott, 2026-11-06). Over the lanes, outside their
    /// horizontal scroll; out of the way while a pattern or a block is carried, so the drop reaches the lane.
    @ViewBuilder private var knobBox: some View {
        if compact, dragPattern == nil, lifted == nil {
            let t = session.selectedTrack
            let top = 24 + Self.laneGap + CGFloat(t) * (laneHeight + Self.laneGap)
            let total = 24 + CGFloat(session.trackCount) * (laneHeight + Self.laneGap)
            let below = top + laneHeight + 4
            // under the row unless that runs well past the last lane (over the divider is fine): above it, it rose
            // over the ruler on short lanes (Scott, 2026-11-07, Clarinet on T3)
            let down = below + TrackKnobBox.height(for: session) <= total + 24
            // a sound panel over the page: the box steps left of it, so it stays in view (2026-11-06), and hangs free
            let panel = ui.soundPanel != nil
            // a tab of the selected row's own colour, hanging from its right end (above it on the last rows): the knobs
            // part of the track, not floating over the next one (Scott, 2026-11-07)
            TrackKnobBox(session: session, ui: ui, embedded: true, closesDown: !down)
                .background { RowTab(down: down, flushRight: !panel).fill(SelectionTint.fill(t)) }
                .offset(x: panel ? -(SoundPanel.width + 12) : 0,
                        y: down ? below : max(0, top - 4 - TrackKnobBox.height(for: session)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: t)
        }
    }

    /// The selected track's whole row lit, header and lane, in its colour (Scott, 2026-11-06: not only the chip and the
    /// name). Behind the blocks; the name's weight still marks it without colour.
    @ViewBuilder private var selectedRow: some View {
        if compact {
            // each track's lane, as on the Pads (board 41): a tag behind its head joined to a band under its blocks,
            // the selected one in its tint, the others the panel grey (Scott, 2026-11-09: one look for both views)
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<session.trackCount, id: \.self) { t in
                        let tall = laneHeight >= Self.cardHeads
                        LaneShape(tag: CGSize(width: headW, height: tall ? min(laneHeight, PadsPage.laneTag) : laneHeight),
                                  height: laneHeight, tagR: tall ? 19 : 10, padR: 8)
                            .fill(t == session.selectedTrack ? SelectionTint.fill(t) : Theme.panel)
                            .frame(width: g.size.width, height: laneHeight)
                            .offset(y: 24 + Self.laneGap + CGFloat(t) * (laneHeight + Self.laneGap))
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: session.selectedTrack)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
    /// From this lane height the Timeline's heads are the Pads' full ones (H1); under it, the one-line heads.
    static let cardHeads: CGFloat = 96

    private var keyboardShortcuts: some View {
        let keys: [(KeyEquivalent, String)] = [(.leftArrow, "Previous entry"), (.rightArrow, "Next entry"), (.upArrow, "Track above"),
                                               (.downArrow, "Track below"), ("=", "Play once more"), ("-", "Play once less"),
                                               (.delete, "Delete entry"), (.return, "Edit pattern"), (.escape, "Deselect")]
        return ZStack {
            ForEach(keys.indices, id: \.self) { i in
                Button(keys[i].1) { _ = key(keys[i].0) }
                    .keyboardShortcut(keys[i].0, modifiers: [])
            }
            // ⌥← ⌥→ move the selected block one place, as Move earlier and Move later do
            Button("Move earlier") { moveSelected(by: -1) }.keyboardShortcut(.leftArrow, modifiers: .option)
            Button("Move later") { moveSelected(by: 1) }.keyboardShortcut(.rightArrow, modifiers: .option)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func moveSelected(by delta: Int) {
        guard let sel = selection, let b = store.blocks(sel.track).first(where: { $0.entries.contains(sel.entry) }) else { return }
        if let i = ArrangeEdits(session: session, store: store).move(sel.track, b, by: delta) { selection = EntryRef(track: sel.track, entry: i) }
    }

    // MARK: Sections

    private func sectionPlans(_ op: SectionOp) -> [SectionTrack] {
        guard let s = section, let song = store.song else { return [] }
        return song.tracks.indices.map { t in
            SongSections.plan(track: t, list: song.tracks[t], blocks: store.blocks(t),
                              from: Double(s.from) * SongPlacement.ticksPerBar, to: Double(s.to) * SongPlacement.ticksPerBar, op: op)
        }
    }

    private func bracket(_ t: Int) -> ClosedRange<Double>? {
        guard section != nil, !leftOut.contains(t), let p = sectionPlans(.duplicateAfter)[safe: t],
              let f = p.from, let to = p.to else { return nil }
        return f...to
    }

    private func note(_ t: Int, _ plans: [SectionTrack], _ s: SectionRange) -> String? {
        guard let p = plans[safe: t] else { return nil }
        if leftOut.contains(t) { return "Left out" }
        if p.from == nil { return "Nothing in these bars" }
        if let r = p.refusal { return r }
        return ([p.cost(rangeBars: Double(s.to - s.from))].compactMap { $0 } + p.splits).first
    }

    private func applySection(_ op: SectionOp) {
        let plans = sectionPlans(op).filter { !leftOut.contains($0.track) && $0.from != nil }
        Task {
            let refused = await store.apply(section: plans)
            if refused.isEmpty { section = nil; leftOut = [] }
        }
    }

    // MARK: Keyboard

    private func key(_ k: KeyEquivalent) -> Bool {
        let edits = ArrangeEdits(session: session, store: store)
        if k == .escape, section != nil { section = nil; leftOut = []; return true }
        guard let sel = selection else {
            let t = session.selectedTrack
            if let b = store.blocks(t).first { selection = EntryRef(track: t, entry: b.entries.lowerBound) }
            return true
        }
        let blocks = store.blocks(sel.track)
        guard let i = blocks.firstIndex(where: { $0.entries.contains(sel.entry) }) else { selection = nil; return true }
        let b = blocks[i]
        switch k {
        case .leftArrow: if i > 0 { selection = EntryRef(track: sel.track, entry: blocks[i - 1].entries.lowerBound) }
        case .rightArrow: if i + 1 < blocks.count { selection = EntryRef(track: sel.track, entry: blocks[i + 1].entries.lowerBound) }
        case .upArrow, .downArrow:
            // the lane above or below, at the same place in time
            let t = sel.track + (k == .upArrow ? -1 : 1)
            guard t >= 0, t < session.trackCount else { return true }
            let other = store.blocks(t)
            if let near = other.min(by: { abs($0.start - b.start) < abs($1.start - b.start) }) {
                selection = EntryRef(track: t, entry: near.entries.lowerBound)
            }
        case "+", "=": edits.setReps(sel.track, b, b.reps + 1)
        case "-": edits.setReps(sel.track, b, b.reps - 1)
        case .delete, .deleteForward: edits.delete(sel.track, b)
        case .return:
            let on = store.song?.tracks[safe: sel.track]?.entryOn == b.entries.lowerBound
            if !on && session.playing {
                store.refuse(track: sel.track, entry: b.entries.lowerBound, "Stop to open this entry's pattern: playing, the FM-1 would launch it", needsStop: true)
            } else {
                Task {
                    if !on { guard await store.send(.play(track: sel.track, entry: b.entries.lowerBound)) else { return } }
                    session.select(track: sel.track)
                    ui.page = .sequencer
                }
            }
        case .escape: selection = nil; section = nil
        default: return false
        }
        return true
    }

    // MARK: Inspector

    @ViewBuilder private var inspector: some View {
        if let sel = selection, let song = store.song, sel.track < song.tracks.count,
           let block = store.blocks(sel.track).first(where: { $0.entries.contains(sel.entry) }) {
            EntryInspector(session: session, store: store, ui: ui, track: sel.track, block: block,
                           list: song.tracks[sel.track])
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("No entry selected").font(.lupe(15, .semibold))
                Text("Tap a block to see its pattern and how many times it plays. Double-tap opens it in Sequence.")
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .panel()
        }
    }
}

// MARK: - Header and lane

// MARK: - The Song tab's compact Arrange (canvas boards 19, 20)

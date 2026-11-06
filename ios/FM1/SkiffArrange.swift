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
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let headerWidth: CGFloat = 152
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
                    Text(line).font(.system(size: 13)).padding(.horizontal, 12).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                        .padding(.leading, Self.headerWidth)
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { pageFrame = $0 }
        // a menu on an entry that's gone (the song changed under it) closes; leaving the page drops every hold
        .onChange(of: store.song) { if let m = menu, !menuStillThere(m) { menu = nil } }
        // an entry's sounds belong to the selected entry: another one selected, they close
        .onChange(of: selection) { _, now in if case .sound(let r) = menu?.kind, r != now { menu = nil } }
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

    // MARK: Menus (canvas board 2): Jib's own, at the finger, one style across the page

    private var menus: ArrangeMenus { ArrangeMenus(session: session, store: store, ui: ui) { selection = $0 } }

    private func openMenu(_ kind: ArrangeMenu, _ at: CGPoint) { menu = OpenMenu(kind: kind, at: at) }

    private func block(_ r: EntryRef) -> SongBlock? { store.blocks(r.track).first { $0.entries.contains(r.entry) } }

    private func menuStillThere(_ m: OpenMenu) -> Bool {
        switch m.kind {
        case .block(let r), .sound(let r): block(r) != nil
        case .add(let t): store.song?.tracks[safe: t] != nil
        }
    }

    @ViewBuilder private var menuOverlay: some View {
        if let m = menu, menuStillThere(m) {
            let (title, groups, close): (String, [[MenuItem]], () -> Void) = {
                switch m.kind {
                case .block(let r):
                    let b = block(r)!
                    return ("T\(r.track + 1) · entr\(b.isChain ? "ies" : "y") \(Entries.letters(b.entries))", menus.block(r.track, b),
                            { menu = nil; selection = r; blockFocus = r })        // focus goes back to the block
                case .sound(let r):
                    let b = block(r)!
                    return ("T\(r.track + 1) · sound on entry \(Entries.letter(r.entry))", menus.sound(r.track, b), { menu = nil })
                case .add(let t):
                    return ("T\(t + 1) · after the last entry", menus.add(t), { menu = nil })
                }
            }()
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    // a tap anywhere else closes it
                    Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                        .accessibilityHidden(true)
                    MenuPanel(title: title, groups: groups, close: close)
                        .id(m)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in
                            let x = m.at.x - pageFrame.minX - 24
                            return -min(max(0, x), g.size.width - d.width)
                        }
                        .alignmentGuide(.top) { d in
                            // below the finger, or above it where it wouldn't fit
                            let y = m.at.y - pageFrame.minY
                            return -(y + 16 + d.height <= g.size.height ? y + 16 : max(0, y - 16 - d.height))
                        }
                }
            }
        }
    }

    // MARK: Tool row: the song's length, the warning when lanes end apart, zoom

    private var songBars: Int { Int((store.laneEnds.max() ?? 0).rounded(.up)) }

    private var toolRow: some View {
        HStack(spacing: 12) {
            Text("Song").font(.system(size: 15, weight: .semibold)).accessibilityAddTraits(.isHeader)
            Text("\(songBars) bar\(songBars == 1 ? "" : "s") · \(session.trackCount) tracks")
                .foregroundStyle(Theme.textSecondary).lineLimit(1).fixedSize()
            // (the playback mode moved to the top bar, beside play and stop: SongModeKeys, 2026-11-06)
            Spacer(minLength: 8)
            if !store.undoStack.isEmpty {
                // Jib's own undo: the lists before the last change (a delete, a move, a section)
                Button { Task { await store.undo() } } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward").font(.system(size: 15))
                        .padding(.horizontal, 14).frame(height: 44).raisedKey()
                }
                .buttonStyle(PressSink())
                .keyboardShortcut("z", modifiers: .command)
                .disabled(store.busy || store.offline)
            }
            if let w = loopApartWarning {
                // the first to give way when the row is narrow (the sound panel's rail beside it): it shortens
                Label(w, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                    .layoutPriority(-1)
                    .accessibilityLabel(w)
            }
            if compact {
                Button { ui.poolOpen.toggle() } label: {
                    Label("Patterns", systemImage: "square.grid.2x2").font(.system(size: 15))
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
            Text("\(bars) bars").font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(width: 64)
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
            let laneWidth = geo.size.width - Self.headerWidth
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
                .frame(width: Self.headerWidth)
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
                    .frame(width: contentWidth, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(lifted != nil)
            }
            .opacity(store.offline ? 0.5 : 1)
        }
        .frame(height: 24 + CGFloat(session.trackCount) * (laneHeight + Self.laneGap))
        .disabled(store.offline)
        // a keyboard: arrows move between blocks and lanes, + and − set REPS, Delete deletes, Return opens.
        // Shortcuts on hidden buttons: iPadOS sends them without the lanes holding focus.
        .background { keyboardShortcuts }
    }

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
                           list: song.tracks[sel.track], selection: $selection, openMenu: openMenu)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("No entry selected").font(.system(size: 15, weight: .semibold))
                Text("Tap a block to see its pattern and how many times it plays. Double-tap opens it in Sequence.")
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .panel()
        }
    }
}

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

// MARK: - Header and lane

struct LaneHeader: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    /// While a section is picked: what it does to this track (a split, the cost of snapping, left out).
    var note: String?
    /// The Song tab's: the selected lane's header carries the whole-track controls' key.
    var ui: EditorUI? = nil
    @Environment(\.arrangeLaneHeight) private var laneHeight
    @Environment(\.arrangeCompact) private var compact

    var body: some View {
        let _ = BodyCounter.tick("LaneHeader")
        let tr = session.tracks[track]
        let used = store.song?.tracks[safe: track]?.used ?? 0
        if compact { compactBody } else { fullBody(tr, used) }
    }

    /// The Song tab: the chip and the name on one line, as tall as the lane allows.
    private var compactBody: some View {
        let selected = session.selectedTrack == track
        let keyed = selected && ui != nil && note == nil
        return HStack(spacing: 0) {
            Button { session.select(track: track) } label: {
                HStack(spacing: 8) {
                    TrackChip(track: track, selected: selected).frame(width: 28, height: 28)
                    Text(note ?? Entries.trackName(track, session: session)).font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected || note != nil ? Theme.text : Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track \(track + 1), \(Entries.trackName(track, session: session))")
            .accessibilityAddTraits(selected ? .isSelected : [])
            if keyed, let ui { TrackControlsKey(ui: ui, height: laneHeight) }
        }
        .frame(width: SkiffArrangePage.headerWidth - 8, height: laneHeight, alignment: .leading)
    }

    private func fullBody(_ tr: TrackState, _ used: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { session.select(track: track) } label: {
                TrackChip(track: track, selected: session.selectedTrack == track)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel("Track \(track + 1)")
            .accessibilityAddTraits(session.selectedTrack == track ? .isSelected : [])
            VStack(alignment: .leading, spacing: 4) {
                Text(Entries.trackName(track, session: session)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let holdTime: Duration = .milliseconds(400)
    /// The lane's own coordinates: where a finger is along it, however far the lanes have scrolled.
    private var laneSpace: NamedCoordinateSpace { .named("lane\(track)") }
    /// A hold that wanders further than this before it lifts is a scroll, not a hold.
    static let holdSlop: CGFloat = 10

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store) }
    private func x(_ ticks: Double) -> CGFloat { CGFloat(ticks / SongPlacement.ticksPerBar) * barWidth }
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
            RoundedRectangle(cornerRadius: 8).fill(Theme.well)
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
                              selected: false, linked: false, playing: false)
                        .frame(width: max(8, x(r.block.length) - 4), height: laneHeight - 12)
                        .modifier(Place(x: x(r.block.start) + 2, y: 6))
                        .allowsHitTesting(false)
                        .transition(reduceMotion ? .identity : .accordion)
                }
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
                          selected: false, linked: false, playing: false)
                    .frame(width: w, height: laneHeight - 12)
                    .scaleEffect(reduceMotion ? 1 : 1.03)
                    .elevationShadow(.held, Look())
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
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.track[track]).elevationShadow(.held, Look()))
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { laneFrame = $0 }
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
                      state: compact && session.playing ? LaneMarks.spoken(store.marks(track, launchIn: session.ticksToLaunch(track)), block: b, launch: session.launchMode) : nil)
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
                .shadow(color: .black.opacity(isHeld ? Look().shadow(.held).opacity : 0),
                        radius: Look().shadow(.held).radius, y: isHeld ? Look().shadow(.held).y : 0)
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

    /// The edge's hold: lifts the block if the finger is still down, near where it started, 0.4 s on.
    private func startHold(_ r: EntryRef) {
        travel = 0
        holdTimer = Task { @MainActor in
            try? await Task.sleep(for: Self.holdTime)
            guard !Task.isCancelled, press == r, travel < Self.holdSlop, stretch == nil, !store.offline, lifted == nil else { return }
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

struct BlockView: View {
    let session: DeviceSession
    let track: Int
    let block: SongBlock
    let list: SongList
    let width: CGFloat
    let selected: Bool
    let linked: Bool
    let playing: Bool
    /// The Song tab while playing: what VoiceOver says of its playback ("pass 2 of 4", "next", "queued, …").
    var state: String? = nil
    @Environment(\.look) private var look
    @Environment(\.arrangeCompact) private var compact
    @Environment(\.arrangeLaneHeight) private var laneHeight

    private var first: SongEntry { list.entries[block.entries.lowerBound] }
    private var isRest: Bool { block.kind != .pattern }
    private var sound: EntrySound? { list.entries[block.entries.lowerBound].sound }

    private var label: String {
        if isRest { return "REST" }
        if block.isChain {
            return block.entries.map { list.entries[$0].isRest ? "REST" : Entries.number(list.entries[$0].pattern) }.joined(separator: "→")
        }
        return Entries.number(first.pattern)
    }

    private var sub: String {
        var s = (block.isChain ? "chain ×" : "×") + "\(block.reps)"
        if let snd = sound { s += " · " + Entries.soundName(snd, session: session) }
        return s
    }

    var body: some View {
        let _ = BodyCounter.tick("BlockView")
        let shape = BlockShape(cut: sound != nil ? 12 : 0)
        let wide = width >= 56
        let solid = !isRest
        // on a solid track colour every line is the dark text (6:1 or better on each); weight ranks them
        let strong = solid ? Theme.onColour : Theme.textSecondary
        let dim = strong
        VStack(alignment: .leading, spacing: 2) {
            if laneHeight < 52 {
                // a short lane (the Song tab): one line, "B · 05"
                Text(wide ? "\(Entries.letters(block.entries)) · \(isRest ? "REST" : label)" : (isRest ? "–" : label))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(strong)
            } else if wide {
                HStack(spacing: 4) {
                    Text(Entries.letters(block.entries)).font(.system(size: 11)).foregroundStyle(dim)
                    // an entry with its own sound: Skiff loads it as the entry starts (and the corner is cut)
                    if sound != nil { Image(systemName: "waveform").font(.system(size: 10, weight: .semibold)).foregroundStyle(dim) }
                }
                Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(strong)
                Text(sub).font(.system(size: 12)).foregroundStyle(dim)
            } else {
                Text(isRest ? "–" : label).font(.system(size: 13, weight: .semibold)).foregroundStyle(strong)
                if sound != nil { Image(systemName: "waveform").font(.system(size: 10, weight: .semibold)).foregroundStyle(strong) }
            }
        }
        .lineLimit(1)
        .padding(.horizontal, wide ? 8 : 4).padding(.vertical, laneHeight < 52 ? 0 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: laneHeight < 52 ? .leading : .topLeading)
        .background {
            if isRest {
                shape.stroke(Theme.disabledOutline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else {
                shape.fill(Theme.track[track])
                    .overlay { if block.isChain { ChainDividers(parts: block.parts, reps: block.reps) } }
            }
        }
        .overlay {
            // on a solid colour the ring goes outside, on the lane (light on amber would be under 3:1), and
            // the linked copies' dashes are dark
            if selected { shape.stroke(Theme.text, lineWidth: 2).padding(solid ? -3 : 1) }
            // the Song tab while playing: the block each track plays outlined inside
            else if compact, playing { shape.stroke(Theme.text, lineWidth: 2).padding(2) }
            else if linked { shape.stroke(solid ? Theme.onColour : Theme.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).padding(4) }
        }
        .compositingGroup()
        // the Song tab while playing: what isn't playing dimmed, so each track's playing block stands out
        .opacity(compact && session.playing && !playing && !selected ? 0.5 : 1)
        .shadow(color: .black.opacity(selected && look.flat ? look.shadow(.selected).opacity : 0),
                radius: look.shadow(.selected).radius, y: selected ? look.shadow(.selected).y : 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// "T1 Drums, entry B, pattern 02, 8 times, bars 5 to 12, also on entry D"
    private var spoken: String {
        let from = Int(block.start / SongPlacement.ticksPerBar) + 1
        let to = max(from, Int((block.end / SongPlacement.ticksPerBar).rounded(.up)))
        var s = "T\(track + 1) \(Entries.trackName(track, session: session)), entr\(block.isChain ? "ies" : "y") \(Entries.letters(block.entries)), "
        s += isRest ? "rest" : block.isChain ? "chain \(label)" : "pattern \(label)"
        s += ", \(block.reps) time\(block.reps == 1 ? "" : "s"), bars \(from) to \(to)"
        let others = list.sharing(block.entries.lowerBound)
        if !isRest, !others.isEmpty { s += ", also on entr\(others.count == 1 ? "y" : "ies") " + others.map(Entries.letter).joined(separator: ", ") }
        if let snd = sound { s += ", sound \(Entries.soundName(snd, session: session))" }
        if let state { s += ", " + state } else if playing { s += ", playing now" }
        return s
    }
}

/// A block's outline; an entry with a sound has its top right corner cut, as on Skiff's own screen.
struct BlockShape: Shape {
    var cut: CGFloat = 0
    func path(in r: CGRect) -> Path {
        guard cut > 0 else { return Path(roundedRect: r, cornerRadius: 6) }
        var p = Path()
        let c = min(cut, r.width / 2)
        p.move(to: CGPoint(x: r.minX + 6, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 6, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 6, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 6), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 6))
        p.addQuadCurve(to: CGPoint(x: r.minX + 6, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        return p
    }
}

/// A thin divider at each part of a chain, every pass.
struct ChainDividers: View {
    let parts: [Double]
    let reps: Int
    var body: some View {
        let _ = BodyCounter.tick("ChainDividers")
        GeometryReader { g in
            let total = parts.reduce(0, +) * Double(reps)
            Path { p in
                var at = 0.0
                for k in 0..<(parts.count * reps - 1) {
                    at += parts[k % parts.count]
                    let x = g.size.width * at / max(1, total)
                    p.addRect(CGRect(x: x - 1, y: 0, width: 2, height: g.size.height))
                }
            }
            .fill(Theme.page)
        }
        .allowsHitTesting(false)
    }
}

/// One line through every lane: MIDI clock counted since Start, wrapped at the song's end. Lanes that end
/// apart loop apart, so on those it's where the song's top would be.
struct SongPlayhead: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let barWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let _ = BodyCounter.tick("SongPlayhead")
        // the song's length once per body, not per frame (laneEnds places every lane's blocks); 30 frames a second
        // move a 2 pt line smoothly enough at any tempo
        let songTicks = (store.laneEnds.max() ?? 0) * SongPlacement.ticksPerBar
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.playing)) { _ in
            let ticks = session.clockTicks
            if ticks >= 0, songTicks > 0 {
                let at = Double(ticks).truncatingRemainder(dividingBy: songTicks)
                Rectangle().fill(Theme.text).frame(width: 2, height: height + 8)
                    .offset(x: CGFloat(at / SongPlacement.ticksPerBar) * barWidth + 1, y: -4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A bar range across the lanes: its first bar and the bar after its last, 0-based.
struct SectionRange: Equatable {
    var from: Int
    var to: Int
}

/// The section's bar (board 3): the range, two steppers to set it without a drag, Duplicate after (the
/// view's one primary) and Clear, and for each track whose passes can't meet the range, snap or leave out.
struct SectionBar: View {
    let range: SectionRange
    let songBars: Int
    let plans: [SectionTrack]
    @Binding var leftOut: Set<Int>
    let busy: Bool
    let set: (SectionRange) -> Void
    let apply: (SectionOp) -> Void
    let cancel: () -> Void

    var body: some View {
        let _ = BodyCounter.tick("SectionBar")
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Text("Bars \(range.from + 1)–\(range.to)").font(.system(size: 15, weight: .semibold)).fixedSize()
                Text("from").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                StepperKeys(label: "First bar", value: range.from + 1, range: 1...max(1, range.to), step: 1) {
                    set(SectionRange(from: $0 - 1, to: range.to))
                }
                Text("to").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                StepperKeys(label: "Last bar", value: range.to, range: (range.from + 1)...max(range.from + 1, songBars + 16), step: 1) {
                    set(SectionRange(from: range.from, to: $0))
                }
                key("Duplicate after", primary: true) { apply(.duplicateAfter) }
                key("Clear") { apply(.clear) }
                ForEach(plans.filter { !$0.exact && $0.from != nil }, id: \.track) { p in
                    HStack(spacing: 6) {
                        Text("T\(p.track + 1):").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        SegmentedKeys(label: "Track \(p.track + 1) in this section", options: ["Snap to its passes", "Leave it out"],
                                      selected: leftOut.contains(p.track) ? 1 : 0) { k in
                            if k == 1 { leftOut.insert(p.track) } else { leftOut.remove(p.track) }
                        }
                    }
                }
                Button(action: cancel) {
                    Text("Cancel").font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bars \(range.from + 1) to \(range.to) on every track")
    }

    private func key(_ title: String, primary: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: primary ? .semibold : .regular))
                .foregroundStyle(primary ? Theme.onColour : Theme.text)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .raisedKey(9, primary: primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(busy)
    }
}

// MARK: - The Song tab's compact Arrange (canvas boards 19, 20)

private struct ArrangeLaneHeightKey: EnvironmentKey { static let defaultValue: CGFloat = SkiffArrangePage.fullLaneHeight }
private struct ArrangeCompactKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// A lane's height: 80 on the Arrange page, less in the Song tab's top half (its divider sets it).
    var arrangeLaneHeight: CGFloat {
        get { self[ArrangeLaneHeightKey.self] }
        set { self[ArrangeLaneHeightKey.self] = newValue }
    }
    /// The Song tab's top half: no inspector, the pattern pool a drawer, a block tapped pins the editor below,
    /// and while playing each track's playing block bright and outlined, the others dimmed.
    var arrangeCompact: Bool {
        get { self[ArrangeCompactKey.self] }
        set { self[ArrangeCompactKey.self] = newValue }
    }
}


/// The Song tab's playback marks over a lane, while playing (SongPlayback; Skiff's README: SONG OFF / ON / ONCE,
/// LAUNCH): on the block playing, its pass of its REPS ("2/4"), or ↻ looping (Loop entry); a quiet outline on the
/// block it goes to next (Play song, Play once), with a wrap mark when that's the first again; END on the last
/// (Play once); a launch waiting: a pulsing outline and its countdown. Its own 4 Hz timeline, so the lane's blocks
/// don't redraw for it; marks per track (tracks drift apart). Reduce Motion: no pulse.
struct LaneMarks: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    let blocks: [SongBlock]
    let barWidth: CGFloat
    let laneHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func x(_ ticks: Double) -> CGFloat { CGFloat(ticks / SongPlacement.ticksPerBar) * barWidth }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { tl in
            let m = store.marks(track, launchIn: session.ticksToLaunch(track))
            let h = laneHeight - 12
            ZStack(alignment: .topLeading) {
                ForEach(blocks) { b in
                    let w = max(8, x(b.length) - 4)
                    ZStack(alignment: .topLeading) {
                        if m.playing == b.id { playingBadge(m).frame(width: w, height: h, alignment: .topTrailing) }
                        if m.next == b.id {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.text.opacity(0.55), lineWidth: 1.5).padding(2)
                            if m.wraps { badge(Image(systemName: "arrow.uturn.backward"), "").frame(width: w, height: h, alignment: .topLeading) }
                        }
                        if m.playing == b.id, m.ends { badge(nil, "END").frame(width: w, height: h, alignment: .bottomTrailing) }
                        if m.queued == b.id {
                            let pulse = reduceMotion ? 1 : 0.55 + 0.45 * abs(sin(tl.date.timeIntervalSinceReferenceDate * .pi))
                            RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.text, lineWidth: 2).opacity(pulse).padding(1)
                            badge(Image(systemName: "timer"), Self.countdown(m.launchIn, session.launchMode)).frame(width: w, height: h, alignment: .bottomLeading)
                        }
                    }
                    .frame(width: w, height: h)
                    .offset(x: x(b.start) + 2, y: 6)
                }
            }
        }
        .accessibilityHidden(true)          // (each block says its state itself)
    }

    @ViewBuilder private func playingBadge(_ m: SongPlayback.Marks) -> some View {
        if m.loops { badge(Image(systemName: "repeat"), "") }
        else if let p = m.pass, m.reps > 1 { badge(nil, "\(p)/\(m.reps)") }
    }

    private func badge(_ icon: Image?, _ text: String) -> some View {
        HStack(spacing: 2) {
            icon?.font(.system(size: 9, weight: .bold))
            if !text.isEmpty { Text(text).font(.system(size: 10, weight: .bold)).monospacedDigit() }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 4).frame(height: 14)
        .background(Capsule().fill(Theme.page.opacity(0.85)))
        .padding(3)
    }

    /// A launch's countdown in beats (24 ticks), as short as fits: "now", "1 beat", "3 beats".
    static func countdown(_ ticks: Double?, _ launch: SongPlayback.Launch) -> String {
        guard let t = ticks else { return launch == .loop ? "pass end" : launch == .bar ? "next bar" : "next beat" }
        let beats = Int((t / 24).rounded(.up))
        return beats <= 0 ? "now" : beats == 1 ? "1 beat" : "\(beats) beats"
    }

    /// What a block's state is, for VoiceOver.
    static func spoken(_ m: SongPlayback.Marks, block b: SongBlock, launch: SongPlayback.Launch) -> String? {
        var parts: [String] = []
        if m.playing == b.id {
            parts.append("playing")
            if m.loops { parts.append("looping") } else if let p = m.pass { parts.append("pass \(p) of \(m.reps)") }
            if m.ends { parts.append("the last: the song ends after it") }
        }
        if m.next == b.id { parts.append(m.wraps ? "next, back to the start" : "next") }
        if m.queued == b.id {
            let at = ["at the end of the pass", "at the next bar", "at the next beat", "now"][launch.rawValue]
            parts.append("queued, starts \(at)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}


/// SONG OFF / ON / ONCE (LIST op 6) as what each does: Loop entry, Play song, Play once. In the top bar beside play and
/// stop; the FM-1's own changes come back with the lists (polled), so the two stay in step.
struct SongModeKeys: View {
    let store: SkiffSongStore

    var body: some View {
        SegmentedKeys(label: "Playback", options: ["Loop entry", "Play song", "Play once"], selected: store.song?.mode.rawValue ?? -1,
                      enabled: [!store.offline, !store.offline, !store.offline]) { k in
            Task { await store.send(.song(SongMode(rawValue: k) ?? .on)) }
        }
        .accessibilityHint("Loop entry loops each track's entry; Play song plays the lists round; Play once plays them once and stops")
    }
}

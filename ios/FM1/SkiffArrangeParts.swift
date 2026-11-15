import SloopKit
import SwiftUI

// Arrange on Skiff, continued: the edits (each a rewrite of one track's list), the inspector, the pattern
// bin, and the song's states (refused, empty, loading, disconnected).

/// What a gesture or a menu does to a track's list. Each is a rewrite (SkiffSongStore.rewrite) or one of
/// Skiff's own ops where a rewrite can't say it (NEW, COPY).
@MainActor struct ArrangeEdits {
    let session: DeviceSession
    let store: SkiffSongStore
    /// For a delete's Undo strip (ListUndo); nil: the store's own confirm, as before.
    var ui: EditorUI? = nil

    /// The track's entries, dangling CHAIN flags off (anything moved in after one would join it).
    private func entries(_ t: Int) -> [SongEntry]? { store.song?.tracks[safe: t].map { SongSections.unchainDangling($0.entries) } }
    private func span(_ t: Int) -> ClosedRange<Int>? { store.song?.tracks[safe: t]?.span }

    private func full(_ t: Int, adding n: Int = 1) -> Bool {
        guard let l = store.song?.tracks[safe: t] else { return true }
        let span = l.span.map { $0.upperBound + 1 } ?? 0
        if span + n > 16 {
            store.refuse(track: t, entry: nil, "T\(t + 1) has all 16 entries. Play one entry more times, or chain two, to free a slot")
            return true
        }
        return false
    }

    /// Plays: the block's last entry's REPS (a chain repeats whole on its last entry's).
    func setReps(_ t: Int, _ b: SongBlock, _ n: Int) {
        guard var es = entries(t) else { return }
        es[b.entries.upperBound].reps = max(1, min(16, n))
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
    }

    /// A linked copy right after the block (the same patterns: an edit to one is heard in both).
    func duplicateAfter(_ t: Int, _ b: SongBlock) {
        guard var es = entries(t), !full(t, adding: b.entries.count) else { return }
        let copy = Array(es[b.entries])
        es.insert(contentsOf: copy, at: b.entries.upperBound + 1)
        es = Array(es.prefix(16))
        Task { await store.rewrite(track: t, to: es, focus: b.entries.upperBound + 1) }
    }

    /// The block goes on into the next one as one pattern (REPS 0, CHAIN).
    func chainIntoNext(_ t: Int, _ b: SongBlock) {
        guard var es = entries(t), b.kind != .gap, b.entries.upperBound < 15, !es[b.entries.upperBound + 1].isEmpty else {
            store.refuse(track: t, entry: b.entries.lowerBound, "Nothing after it to chain into")
            return
        }
        es[b.entries.upperBound].chained = true
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
    }

    /// A chain back into its parts, each played once.
    func split(_ t: Int, _ b: SongBlock) {
        guard var es = entries(t) else { return }
        for i in b.entries { es[i].chained = false; es[i].reps = 1 }
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
    }

    /// The block's entries out of the list; the ones after it move up.
    func delete(_ t: Int, _ b: SongBlock) {
        guard var es = entries(t), let sp = span(t) else { return }
        es.removeSubrange(b.entries)
        es += Array(repeating: .empty, count: 16 - es.count)
        // a rest left at the start or end would be passed over: it stays a rest
        es = SongSections.restsAtEdges(es, range: sp.lowerBound..<(sp.upperBound + 1 - b.entries.count))
        // no confirm (batch item 13 follow-up): the Undo strip instead, the patterns kept for it (ListUndo)
        guard let ui else { Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }; return }
        ListUndo.remove(track: t, entries: b.entries, after: es, what: "Deleted T\(t + 1) · \(Entries.letters(b.entries))",
                        store: store, session: session, ui: ui)
    }

    /// The block one place earlier or later among the track's blocks (the hold menu's route, without a drag).
    /// Returns where its first entry goes, for the selection to follow.
    @discardableResult
    func move(_ t: Int, _ b: SongBlock, by delta: Int) -> Int? {
        guard let l = store.song?.tracks[safe: t] else { return nil }
        let blocks = store.blocks(t)
        guard let i = blocks.firstIndex(where: { $0.id == b.id }), blocks.indices.contains(i + delta) else { return nil }
        let m = SongSections.move(list: l, blocks: blocks, block: i, to: i + delta)
        guard !m.unchanged, let es = m.result else { return nil }
        if let why = store.blocked(track: t, to: es) {
            store.refuse(track: t, entry: b.entries.lowerBound, why, needsStop: why.hasPrefix("Stop"))
            return nil
        }
        Task { await store.rewrite(track: t, to: es, focus: m.index) }
        return m.index
    }

    /// A new entry at `index`; the ones from there move on.
    func insert(_ t: Int, _ e: SongEntry, at index: Int) {
        guard var es = entries(t), !full(t) else { return }
        es.insert(e, at: min(index, es.count))
        es = Array(es.prefix(16))
        Task { await store.rewrite(track: t, to: es, focus: index) }
    }

    func setSound(_ t: Int, _ b: SongBlock, _ s: EntrySound?) {
        guard var es = entries(t) else { return }
        es[b.entries.lowerBound].sound = s
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
    }

    /// The entry gets a pattern of its own, a copy (LIST op 2).
    func makeUnique(_ t: Int, _ b: SongBlock) {
        Task { await store.send(.copy(track: t, entry: b.entries.lowerBound)) }
    }

    /// After the last entry: a new empty pattern (LIST op 7 on the next empty entry).
    func newPatternAtEnd(_ t: Int) {
        guard let l = store.song?.tracks[safe: t], !full(t) else { return }
        let at = l.span.map { $0.upperBound + 1 } ?? 0
        Task { await store.send(.new(track: t, entry: at)) }
    }

    func appendAtEnd(_ t: Int, _ e: SongEntry) {
        guard let l = store.song?.tracks[safe: t] else { return }
        insert(t, e, at: l.span.map { $0.upperBound + 1 } ?? 0)
    }

    /// The first free number after a pattern's, as COPY takes it (bank.c pool_alloc_after).
    func copyNumber(after p: Int) -> Int? {
        guard let pool = store.pool else { return nil }
        let order = Array(p..<64) + Array(0..<p)
        return order.first { pool.patterns[$0].isFree }.map { $0 + 1 }
    }
}

// MARK: - Inspector

struct EntryInspector: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let track: Int
    let block: SongBlock
    let list: SongList

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store, ui: ui) }
    private var first: SongEntry { list.entries[block.entries.lowerBound] }
    private var poolIndex: Int? { first.poolIndex }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("T\(track + 1) \(Entries.trackName(track, session: session)) · entr\(block.isChain ? "ies" : "y") \(Entries.letters(block.entries))")
                        .font(.lupe(17, .semibold)).lineLimit(1)
                    Text(patternLine).foregroundStyle(Theme.textSecondary).lineLimit(2)
                }
                preview
                Text(detailLine).font(.lupe(12)).foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 300, alignment: .leading)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plays").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                    StepperKeys(label: "Plays", value: block.reps, range: 1...16, step: 1, enabled: !store.busy,
                                format: { "\($0) time\($0 == 1 ? "" : "s")" }) { edits.setReps(track, block, $0) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sound on entry").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                    Text(first.sound.map { Entries.soundName($0, session: session) } ?? "None: keeps the track's sound")
                }
                if let r = store.refusal, r.track == track, let e = r.entry, block.entries.contains(e) {
                    RefusalLine(refusal: r, session: session, store: store)
                }
            }
            Spacer(minLength: 0)
            // the actions two by two, Delete last and apart under them: short enough that a move's line above
            // the inspector doesn't push the page past the screen
            VStack(spacing: 8) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        key("Edit pattern", primary: true, enabled: block.kind == .pattern) { open() }
                        key(uniqueTitle, enabled: poolIndex != nil && !block.isChain && store.pool?.free ?? 0 > 0) { edits.makeUnique(track, block) }
                    }
                    GridRow {
                        if block.isChain {
                            key("Split the chain") { edits.split(track, block) }
                        } else {
                            key("Chain to next", enabled: canChain) { edits.chainIntoNext(track, block) }
                        }
                        // the sound panel for this entry, as from its menu (Scott, 2026-11-08)
                        key("Select sound", enabled: block.kind == .pattern && store.sounds) {
                            ui.chooseSound(session, track: track, entry: SoundEntryTarget(ref: EntryRef(track: track, entry: block.entries.lowerBound), pad: false))
                        }
                    }
                }
                // last, apart: out of the list. Undo puts it back; one that would erase a pattern asks first
                Button(role: .destructive) { edits.delete(track, block) } label: {
                    Label(block.isChain ? "Delete entries" : "Delete entry", systemImage: "trash").font(.lupe(15))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 44).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(store.busy || store.offline)
                .padding(.top, 8)
            }
            .frame(width: 344)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected entry")
    }

    private var canChain: Bool { block.kind != .gap && block.entries.upperBound < 15 && !list.entries[block.entries.upperBound + 1].isEmpty }

    private var uniqueTitle: String {
        guard let p = poolIndex, let n = edits.copyNumber(after: p) else { return "Make unique" }
        return "Make unique (\(Entries.number(n)))"
    }

    private var patternLine: String {
        if block.kind != .pattern { return "A rest: silence for \(block.reps) pass\(block.reps == 1 ? "" : "es")" }
        if block.isChain { return "A chain: " + block.entries.map { list.entries[$0].label }.joined(separator: " → ") }
        let others = list.sharing(block.entries.lowerBound)
        let p = "Pattern \(Entries.number(first.pattern))"
        return others.isEmpty ? p + ", on this entry only" : p + ", also on entr\(others.count == 1 ? "y" : "ies") " + others.map(Entries.letter).joined(separator: ", ")
    }

    private var detailLine: String {
        guard let p = poolIndex else { return "" }
        let len = store.pool?.patterns[p].length ?? session.tracks[track].length
        let div = store.divisions[p] ?? session.tracks[track].division
        return "\(len) steps · \(Entries.divisionName(div))" + (list.patternOn == p ? " · \(Entries.directionName(session.tracks[track].direction))" : "")
    }

    /// The pattern's first 16 steps: known for the pattern the track is on (the others aren't read).
    @ViewBuilder private var preview: some View {
        if let p = poolIndex, list.patternOn == p {
            let tr = session.tracks[track]
            HStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4).fill(tr.isOn(i) ? Theme.textSecondary : Theme.well).frame(height: 24)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Steps 1 to 16: \((0..<16).filter(tr.isOn).count) on")
        } else if poolIndex != nil {
            Text("Its steps show here while the track plays it.").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                .frame(height: 24, alignment: .leading)
        }
    }

    private func key(_ title: String, primary: Bool = false, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.lupe(15, primary ? .semibold : .regular))
                .foregroundStyle(primary ? Theme.onColour : Theme.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .raisedKey(9, primary: primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!enabled || store.busy || store.offline)
    }

    private func open() {
        let e = block.entries.lowerBound
        let on = list.entryOn == e
        if !on && session.playing {
            store.refuse(track: track, entry: e, "Stop to open this entry's pattern: playing, the FM-1 would launch it", needsStop: true)
            return
        }
        Task {
            if !on { guard await store.send(.play(track: track, entry: e)) else { return } }
            session.select(track: track)
            ui.page = .sequencer
        }
    }
}

/// Why a change didn't take, said where it was tried; "Stop to rearrange" comes with Stop.
struct RefusalLine: View {
    let refusal: SkiffSongStore.Refusal
    let session: DeviceSession
    let store: SkiffSongStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 17, weight: .semibold)).accessibilityHidden(true)
            Text(refusal.text).font(.lupe(15)).fixedSize(horizontal: false, vertical: true)
            if refusal.needsStop, session.playing {
                Button { session.setPlaying(false); store.dismissRefusal() } label: {
                    Label("Stop", systemImage: "stop.fill").font(.lupe(13, .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 44).raisedKey()
                }
                .buttonStyle(PressSink())
            }
            Button { store.dismissRefusal() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .foregroundStyle(Theme.text)
        // on a lifted box, not bare on the page: white text on black was easy to miss (Scott, 2026-11-09); the
        // neutral lift, not a track tint, which already means "selected"
        .padding(.leading, 14)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tones[2]))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Pattern bin

struct PatternBin: View {
    let session: DeviceSession
    let store: SkiffSongStore
    @Binding var all: Bool
    let selection: EntryRef?
    @Binding var dragPattern: Int?
    /// The Song tab's drawer: the level-3 surface (held), not the bin's panel.
    var drawer = false
    /// Where a pattern's own menu opens (Empty, Clear: the drawer's SAVE > PATTERNS housekeeping); nil: no menu.
    var ui: EditorUI? = nil
    /// Where the confirms open (Lupe's own, in place, never a system dialog: Scott, 2026-11-10), when `ui` isn't given
    /// because the bin has no per-pattern menus.
    var host: EditorUI? = nil
    private var menus: EditorUI? { ui ?? host }
    @State private var clearKeyFrame: CGRect = .zero

    /// Pattern (0...63) → the tracks whose lists name it.
    private var tracksOf: [Int: [Int]] {
        var m: [Int: [Int]] = [:]
        for (t, l) in (store.song?.tracks ?? []).enumerated() {
            for e in l.entries { if let p = e.poolIndex, !(m[p]?.contains(t) ?? false) { m[p, default: []].append(t) } }
        }
        return m
    }

    private func inSong(_ p: Int) -> Int {
        (store.song?.tracks ?? []).reduce(0) { $0 + $1.entries.filter { $0.poolIndex == p }.count }
    }

    var body: some View {
        let pool = store.pool
        let m = tracksOf
        let used = m.count
        let other = (pool?.patterns.enumerated().filter { m[$0.offset] == nil && $0.element.uses > 0 }.count) ?? 0
        let shown = (0..<64).filter { p in all ? true : m[p] != nil }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // the drawer: an arrow to close it, left of the title (Scott, 2026-11-06), pointing the way it goes
                if drawer, let ui {
                    Button { ui.poolOpen = false; ui.dragPattern = nil } label: {
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))   // (flat, as the page's keys now)
                    }
                    .buttonStyle(PressSink())
                    .accessibilityLabel("Close patterns")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Patterns").font(.lupe(drawer ? 20 : 15, .semibold)).accessibilityAddTraits(.isHeader)
                    Text("\(used) in this song · \(other) in other projects · \(pool?.free ?? 0) free")
                        .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                }
            }
            SegmentedKeys(label: "Show", options: ["This song", "All 64"], selected: all ? 1 : 0) { all = $0 == 1 }
            ScrollView {
                if drawer {
                    // the Pads' language (Scott, 2026-11-09): cards grouped by the track that uses them, as the lanes
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(groups(shown, m), id: \.title) { g in
                            groupHead(g)
                            ForEach(g.patterns, id: \.self) { p in card(p, tracks: m[p] ?? []) }
                        }
                    }
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(shown, id: \.self) { p in row(p, tracks: m[p] ?? []) }
                    }
                }
            }
            .scrollIndicators(.hidden)
            Button {
                let t = selection?.track ?? session.selectedTrack
                ArrangeEdits(session: session, store: store, ui: ui).newPatternAtEnd(t)
            } label: {
                Group {
                    if drawer {
                        Text("New empty pattern").font(.lupe(15, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
                    } else {
                        Text("New empty pattern").font(.lupe(15)).frame(maxWidth: .infinity, minHeight: 44).raisedKey()
                    }
                }
            }
            .buttonStyle(PressSink())
            .disabled((pool?.free ?? 0) == 0 || store.busy || store.offline)
            if (pool?.free ?? 0) == 0 { Text("All 64 patterns are taken. Clear unused ones to make one.").font(.lupe(12)).foregroundStyle(Theme.textSecondary) }
            Button { askClearUnused(pool?.unused ?? 0) } label: {
                Text("Clear \(pool?.unused ?? 0) unused…").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled((pool?.unused ?? 0) == 0 || session.playing || store.busy || store.offline)
            .globalFrame($clearKeyFrame)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            // the drawer stands over the page (level 3), its one shadow on its shape; the bin sits in it (level 1)
            if drawer { RoundedRectangle(cornerRadius: 16).fill(Elevation.held.surface).elevationShadow(.held) }
        }
        .modifier(BinPanel(on: !drawer))
    }

    /// The drawer's groups: each track's own patterns under it, then those shared between tracks, those only saved
    /// projects use, and (All 64) the free ones.
    struct PatternGroup: Identifiable { var title: String; var track: Int?; var patterns: [Int]; var id: String { title } }
    private func groups(_ shown: [Int], _ m: [Int: [Int]]) -> [PatternGroup] {
        var out: [PatternGroup] = []
        for t in session.trackIndices {
            let ps = shown.filter { m[$0] == [t] }
            if !ps.isEmpty { out.append(PatternGroup(title: "T\(t + 1) \(Entries.trackName(t, session: session))", track: t, patterns: ps)) }
        }
        let shared = shown.filter { (m[$0]?.count ?? 0) > 1 }
        if !shared.isEmpty { out.append(PatternGroup(title: "Shared", track: nil, patterns: shared)) }
        let elsewhere = shown.filter { m[$0] == nil && !(store.pool?.patterns[$0].isFree ?? true) }
        if !elsewhere.isEmpty { out.append(PatternGroup(title: "Not in this song", track: nil, patterns: elsewhere)) }
        let free = shown.filter { store.pool?.patterns[$0].isFree ?? true }
        if !free.isEmpty { out.append(PatternGroup(title: "Free", track: nil, patterns: free)) }
        return out
    }

    private func groupHead(_ g: PatternGroup) -> some View {
        HStack(spacing: 8) {
            if let t = g.track { BigTrackChip(track: t, muted: false, side: 22) }
            Text(g.title).font(.lupe(13, .semibold)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 10).padding(.bottom, 2)
        .accessibilityAddTraits(.isHeader)
    }

    /// A pattern as the pads draw one: its number on its track's colour, what it is, its picture, how often the song
    /// plays it; the selected one tinted and outlined in its track's colour.
    private func card(_ p: Int, tracks: [Int]) -> some View {
        let pat = store.pool?.patterns[p]
        let free = pat?.isFree ?? true
        let n = inSong(p)
        let selected = selection.flatMap { s in store.song?.tracks[safe: s.track]?.entries[safe: s.entry]?.poolIndex } == p
        let owner = tracks.count == 1 ? tracks[0] : nil
        let colour = free ? Theme.well : owner.map { Theme.track[$0] } ?? Entries.tone(p + 1)
        return HStack(spacing: 12) {
            Text(Entries.number(p + 1)).font(.lupe(17, .bold)).monospacedDigit()
                .foregroundStyle(free ? Theme.textSecondary : owner != nil ? Theme.onColour : Theme.text)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(colour))
            VStack(alignment: .leading, spacing: 2) {
                Text(free ? "Free" : tracks.isEmpty ? "Not in this song"
                     : owner != nil ? Entries.trackName(owner!, session: session) : tracks.map { "T\($0 + 1)" }.joined(separator: ", "))
                    .font(.lupe(15, .semibold)).lineLimit(1)
                if let pat, pat.length > 0 {
                    Text("\(pat.length) steps · \(Entries.divisionName(store.divisions[p] ?? session.tracks[safe: tracks.first ?? 0]?.division ?? 2))")
                        .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if let th = ui?.padThumbs[p], !free {
                PadThumbView(thumb: th, ink: Theme.textSecondary).frame(width: 56, height: 18)
            }
            if n > 0 { Text("\(n)×").font(.lupe(13, .semibold)).monospacedDigit().foregroundStyle(Theme.textSecondary) }
            if ui != nil, !free { PatternMore(number: p + 1) { at in openMenu(p, at: at) } }
        }
        .padding(.leading, 8).padding(.trailing, ui != nil && !free ? 0 : 12)
        .frame(height: 60)
        .background(RoundedRectangle(cornerRadius: 12).fill(selected ? SelectionTint.fill(owner ?? session.selectedTrack) : Theme.control))
        .overlay { if selected { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.track[owner ?? session.selectedTrack], lineWidth: 2) } }
        .contentShape(Rectangle())
        .onDrag {
            guard !free else { return NSItemProvider() }
            dragPattern = p + 1
            return NSItemProvider(object: "pattern \(p + 1)" as NSString)
        } preview: {
            Text(Entries.number(p + 1)).font(.lupe(17, .bold)).foregroundStyle(owner != nil ? Theme.onColour : Theme.text)
                .frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 12).fill(colour))
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(free ? "" : "Drag onto a track to add it")
        .accessibilityAction(named: "Empty pattern") { if !free { ask(2, p) } }
        .accessibilityAction(named: "Clear pattern") { if !free { ask(1, p) } }
    }

    private func row(_ p: Int, tracks: [Int]) -> some View {
        let pat = store.pool?.patterns[p]
        let free = pat?.isFree ?? true
        let n = inSong(p)
        let selected = selection.flatMap { s in store.song?.tracks[safe: s.track]?.entries[safe: s.entry]?.poolIndex } == p
        return HStack(spacing: 10) {
            Text(Entries.number(p + 1)).font(.lupe(13, .semibold))
                .frame(width: 32, height: 28)
                // its track's colour; grey when no track's list (or more than one) names it
                .foregroundStyle(!free && tracks.count == 1 ? Theme.onColour : Theme.text)
                .background(RoundedRectangle(cornerRadius: 6).fill(free ? Theme.well
                    : tracks.count == 1 ? Theme.track[tracks[0]] : Entries.tone(p + 1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(free ? "Free" : tracks.isEmpty ? "Not in this song"
                     : tracks.count == 1 ? "T\(tracks[0] + 1) \(Entries.trackName(tracks[0], session: session))" : tracks.map { "T\($0 + 1)" }.joined(separator: ", "))
                    .lineLimit(1)
                    .font(.lupe(13))
                if let pat, pat.length > 0 {
                    Text("\(pat.length) st · \(Entries.divisionName(store.divisions[p] ?? session.tracks[safe: tracks.first ?? 0]?.division ?? 2))")
                        .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if n > 0 { Text("\(n)×").font(.lupe(12)).foregroundStyle(Theme.textSecondary) }
            if ui != nil, !free { PatternMore(number: p + 1) { at in openMenu(p, at: at) } }
        }
        .padding(.leading, 8).padding(.trailing, ui != nil && !free ? 0 : 8)
        .frame(height: 40)
        .background { if selected { RoundedRectangle(cornerRadius: 8).fill(Theme.control) } }
        .contentShape(Rectangle())
        // onDrag (not draggable): its closure runs as the drag starts, so the lanes know what's coming
        .onDrag {
            // only a kept pattern can go into an entry (SET refuses an empty one)
            guard !free else { return NSItemProvider() }
            dragPattern = p + 1
            return NSItemProvider(object: "pattern \(p + 1)" as NSString)
        } preview: {
            Text(Entries.number(p + 1)).font(.lupe(15, .semibold)).padding(.horizontal, 14).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(Entries.tone(p + 1)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(free ? "" : "Drag onto a track to add it")
        .accessibilityAction(named: "Empty pattern") { if !free { ask(2, p) } }
        .accessibilityAction(named: "Clear pattern") { if !free { ask(1, p) } }
    }

    /// Clear N unused: the themed confirm, opening at the key, already asking (it's the key's only job).
    private func askClearUnused(_ n: Int) {
        guard let ui = menus, n > 0 else { return }
        ui.menu = AppMenu(title: "Clear \(n) unused patterns", groups: {
            [[MenuItem.destructive(title: "Clear \(n) unused patterns", confirm: "Clear \(n) unused \(n == 1 ? "pattern" : "patterns")") {
                Task { _ = await store.clearUnused() }
            }, MenuItem(title: "Cancel", icon: "xmark") {}]]
        }, at: CGPoint(x: clearKeyFrame.midX, y: clearKeyFrame.midY), fan: true, asking: true)
    }

    /// The two one-pattern changes, as the menu's in-place confirms: Empty (POOL op 2) and Clear (op 1).
    private func emptyItem(_ p: Int, playing: Bool) -> MenuItem {
        MenuItem.destructive(title: playing ? "Empty its steps (stop first)" : "Empty its steps", icon: "square.dashed", enabled: !playing,
                             confirm: "Empty \(Entries.number(p + 1))'s steps") { run(2, p) }
    }
    private func clearItem(_ p: Int, playing: Bool, uses: Int) -> MenuItem {
        let title = playing ? "Clear pattern (stop first)" : uses > 0 ? "Clear pattern: \(uses == 1 ? "1 use" : "\(uses) use") it" : "Clear pattern"
        return MenuItem.destructive(title: title, icon: "trash", enabled: !playing && uses == 0,
                                    confirm: "Clear pattern \(Entries.number(p + 1))") { run(1, p) }
    }

    /// A pattern's menu: Empty (its steps), Clear (the number itself, when nothing uses it). Stopped only, as Skiff.
    /// A fan at the ⋯ (Scott, 2026-11-10: the themed confirm, in place, as Clear all pads), each asking once more.
    private func openMenu(_ p: Int, at: CGPoint) {
        guard let ui = menus else { return }
        ui.menu = AppMenu(title: "Pattern \(Entries.number(p + 1))", groups: {
            let uses = store.pool?.patterns[p].uses ?? 0
            let playing = session.playing
            return [[emptyItem(p, playing: playing), clearItem(p, playing: playing, uses: uses), MenuItem(title: "Cancel", icon: "xmark") {}]]
        }, at: at, fan: true)
    }

    /// VoiceOver's Empty and Clear actions: the same fan, opening on that item's confirm.
    private func ask(_ op: Int, _ p: Int) {
        if session.playing { store.refuse(track: nil, entry: nil, SongRC.playing.reason, needsStop: true); return }
        guard let ui = menus else { return }
        let uses = store.pool?.patterns[p].uses ?? 0
        if op == 1, uses > 0 { store.refuse(track: nil, entry: nil, "Clear needs it unused: \(uses == 1 ? "1 entry or track uses" : "\(uses) entries and tracks use") it"); return }
        let item = op == 1 ? clearItem(p, playing: false, uses: 0) : emptyItem(p, playing: false)
        let mid = CGPoint(x: clearKeyFrame.midX, y: clearKeyFrame.minY - 120)
        ui.menu = AppMenu(title: "Pattern \(Entries.number(p + 1))", groups: { [[item, MenuItem(title: "Cancel", icon: "xmark") {}]] },
                          at: mid, fan: true, asking: true)
    }

    private func run(_ op: Int, _ p: Int) {
        Task {
            let rc = await store.poolOp(op, pattern: p)
            if !rc.isDone { store.refuse(track: nil, entry: nil, rc == .empty ? "Nothing there to \(op == 1 ? "clear" : "empty")" : rc.reason, needsStop: rc == .playing) }
        }
    }
}

/// A pattern row's "more" key: 44 pt square, its menu opening under it.
private struct PatternMore: View {
    let number: Int
    let open: (CGPoint) -> Void
    @State private var frame: CGRect = .zero

    var body: some View {
        Button { open(CGPoint(x: frame.minX - 220, y: frame.maxY)) } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .globalFrame($frame)
        .accessibilityLabel("Pattern \(Entries.number(number)) options")
    }
}


// MARK: - States

struct EmptySong: View {
    let session: DeviceSession
    let store: SkiffSongStore
    var body: some View {
        VStack(spacing: 12) {
            Text("No song on this project yet").font(.lupe(17, .semibold))
            Text("Drag a pattern onto a track, or record a loop on the FM-1 and it shows up here.")
                .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Button { ArrangeEdits(session: session, store: store).newPatternAtEnd(0) } label: {
                Text("New pattern on T1").font(.lupe(15, .semibold)).foregroundStyle(Theme.onColour)
                    .padding(.horizontal, 16).frame(minHeight: 44).raisedKey(9, primary: true)
            }
            .buttonStyle(PressSink())
            .disabled(store.busy || store.offline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24 + CGFloat(session.trackCount) * (SkiffArrangePage.fullLaneHeight + SkiffArrangePage.laneGap))
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
    }
}

/// Loading: lanes in their final places, no blocks yet.
struct SkeletonLanes: View {
    let count: Int
    var body: some View {
        VStack(spacing: SkiffArrangePage.laneGap) {
            RoundedRectangle(cornerRadius: 6).fill(Theme.panel).frame(height: 24).padding(.leading, SkiffArrangePage.headerWidth)
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.control).frame(width: 28, height: 28)
                        .frame(width: SkiffArrangePage.headerWidth, alignment: .topLeading).padding(.top, 8)
                        .frame(maxHeight: .infinity, alignment: .top)
                    RoundedRectangle(cornerRadius: 8).fill(Theme.well)
                }
                .frame(height: SkiffArrangePage.fullLaneHeight)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Reading the song from the FM-1")
    }
}

struct OfflineBar: View {
    let session: DeviceSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cable.connector.slash").accessibilityHidden(true)
            // (Scott, 2026-11-07: say what to do, reconnect or switch it on)
            VStack(alignment: .leading, spacing: 2) {
                Text("FM-1 disconnected").fontWeight(.semibold)
                Text("Check the cable and that it's switched on. This is the song as it was; editing comes back with the FM-1.")
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            LookingForFM1()
        }
        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 44)
        .elevated(.panel, radius: 10)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}


private struct BinPanel: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View { if on { content.panel() } else { content } }
}

/// The Song tab: the bar of the pattern the grid shows, framed on the block the grid is editing (the selected
/// track's lane), as SLOOP's view box frames it on the overview (Overview.swift). It reads the grid's
/// `viewStep` itself, in a frame as big as its lane that never changes size, so a pan redraws this box and
/// nothing else (2026-11-07). On the repeat playing while the song plays (its pass, four times a second, as
/// LaneMarks reads it), else the first. Dragged, it moves the grid bar by bar (`Lane.boxGesture`); with
/// Reduce Motion it steps from bar to bar instead of sliding with the pan.
struct GridViewBox<G: Gesture>: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let track: Int
    /// The entry the grid edits, the block it's in, and that entry's part of the block (a chain's nth).
    let entry: Int
    let block: SongBlock
    let part: Int
    let barWidth: CGFloat
    let laneWidth: CGFloat
    let laneHeight: CGFloat
    let gesture: G
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func x(_ ticks: Double) -> CGFloat { CGFloat(ticks / SongPlacement.ticksPerBar) * barWidth }

    var body: some View {
        let _ = BodyCounter.tick("GridViewBox")
        Group {
            if session.playing, store.song?.tracks[safe: track]?.entryOn == entry {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    box(rep: (store.marks(track, launchIn: nil).pass ?? 1) - 1)
                }
            } else {
                box(rep: 0)
            }
        }
        .frame(width: laneWidth, height: laneHeight, alignment: .topLeading)
    }

    @ViewBuilder private func box(rep: Int) -> some View {
        let len = max(1, session.tracks[safe: track]?.length ?? 16)
        let bars = Self.bars(len)
        let bar = Self.bar(ui.viewStep, bars: bars)
        // Reduce Motion: the bar it settles on, not every point of the pan
        let from = max(0, min(CGFloat(len), reduceMotion ? CGFloat(bar * 16) : ui.viewStep))
        let to = min(CGFloat(len), from + 16)
        if to > from, block.parts.indices.contains(part) {
            let partTicks = block.parts[part]
            let at = block.start + Double(max(0, min(block.reps - 1, rep))) * block.pass + block.parts[..<part].reduce(0, +)
            // blocks sit 2 pt in and are 4 pt short of their span: the box overhangs its bar by 2 pt a side
            let x0 = x(at + partTicks * Double(from) / Double(len))
            let w = max(12, x(partTicks * Double(to - from) / Double(len)))
            RoundedRectangle(cornerRadius: 6)
                // light on the lane, with a dark keyline inside so its sides hold on a light track colour too
                .strokeBorder(Theme.text, lineWidth: 2)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.onColour, lineWidth: 1).padding(2))
                .frame(width: w, height: laneHeight - 4)
                // at least 28 pt to take hold of, however narrow the bar is drawn
                .frame(width: max(w, 28), height: laneHeight - 4)
                .contentShape(Rectangle())
                .highPriorityGesture(gesture)
                .accessibilityElement()
                .accessibilityLabel("Grid view")
                .accessibilityValue("bar \(bar + 1) of \(bars)")
                .accessibilityHint(bars > 1 ? "Swipe up or down to show another bar in the grid" : "")
                .accessibilityAdjustableAction { d in Self.show(ui, bar: bar + (d == .increment ? 1 : -1), bars: bars) }
                .offset(x: x0 - (max(w, 28) - w) / 2, y: 2)
        }
    }

    /// Bars of a pattern of `len` steps, as far as the grid pans (four).
    static func bars(_ len: Int) -> Int { max(1, min(4, (len + 15) / 16)) }
    static func bar(_ viewStep: CGFloat, bars: Int) -> Int { max(0, min(bars - 1, Int((viewStep / 16).rounded()))) }
    /// The grid to that bar (the request the grids obey, followsView).
    @MainActor static func show(_ ui: EditorUI, bar: Int, bars: Int) {
        let b = max(0, min(bars - 1, bar))
        if b == Self.bar(ui.viewStep, bars: bars) && ui.viewStep == CGFloat(b * 16) { return }
        ui.viewJump = ViewJump(bar: b, id: (ui.viewJump?.id ?? 0) + 1)
    }
}

// MARK: - FREE TAKE (Skiff 2.5, level 1; the Undo key on screen link v7)

/// A take the FM-1 put into a track while stopped (DeviceSession.freeTake): what it became, and the FM-1's FREE TAKE
/// picker mirrored (Skiff 2.5 ui_take.c, ui_draw.c fr_columns, draw_foot): its four knobs and its three keys, so the
/// picker on the FM-1's screen reads the same here. The screen link doesn't report the picker's state, so its knobs are
/// named, not valued; each turn rewrites the track and Lupe re-reads it. Then the undo: the editor protocol has none,
/// so the FM-1's own is named (SAVE held), with its depth. RefusalLine's box: the neutral lift, dismissed with its ✕ or
/// by the next take.
struct FreeTakeLine: View {
    let take: FreeTake
    let session: DeviceSession

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform.badge.plus").font(.system(size: 17, weight: .semibold))
                .padding(.top, 13).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.lupe(15, .semibold)).fixedSize(horizontal: false, vertical: true)
                if take.undoFromHere {
                    // (v7) kept from the picker here or on the FM-1; Undo is the FM-1's own, asked for from here
                    Text(take.undone ? "Undone: the track is as it was before the take. Redo puts the take back."
                                     : "Undo brings back what was there (the FM-1 keeps the last \(take.undoLevels) changes).")
                        .font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised).fixedSize(horizontal: false, vertical: true)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { knobs; keys }
                        VStack(alignment: .leading, spacing: 8) { knobs; keys }
                    }
                    Text("Once it's kept, hold SAVE on the FM-1 to undo it (it keeps the last \(take.undoLevels) changes).")
                        .font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 12)
            Spacer(minLength: 0)
            if take.undoFromHere {
                Button { session.undoFreeTake() } label: {
                    Label(take.undone ? "Redo" : "Undo", systemImage: take.undone ? "arrow.uturn.forward" : "arrow.uturn.backward")
                        .font(.lupe(15, .semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                        .raisedKey().contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .padding(.vertical, 12)
                .accessibilityHint(take.undone ? "Puts the take back on the FM-1" : "Puts the track back as it was before the take, on the FM-1")
            }
            Button { session.dismissFreeTake() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .foregroundStyle(Theme.text)
        .padding(.leading, 14)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tones[2]))
        .fixedSize(horizontal: false, vertical: true)    // its own height: the lanes above don't squeeze it
        .accessibilityElement(children: .contain)
    }

    /// The picker's four knobs, as its cards name them (fr_columns: GUESS, BARS, FROM, TEMPO).
    private var knobs: some View {
        HStack(spacing: 6) {
            FMKey(name: "KNOBS 1–4")
            Text("guess · bars · first note · tempo").font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("On the FM-1, knobs 1 to 4 pick the tempo guess, the bars, the first note and whether the tempo is set")
    }

    /// The picker's footer (draw_foot): OCT+ KEEP, OCT− BACK, PLAY LISTEN.
    private var keys: some View {
        HStack(spacing: 12) {
            ForEach([("OCT+", "keep"), ("OCT−", "put back"), ("PLAY", "listen")], id: \.0) { k in
                HStack(spacing: 6) {
                    FMKey(name: k.0)
                    Text(k.1).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("On the FM-1, OCT plus keeps it, OCT minus puts the track back, PLAY listens")
    }

    private var title: String {
        let t = session.tracks[safe: take.track]
        let bars = max(1, (t?.division == 1 ? take.length / 8 : take.length / 16))
        let entry = take.entry.map { " (entry \(Entries.letter($0)))" } ?? ""
        return "Free take on T\(take.track + 1)\(entry): \(bars) bar\(bars == 1 ? "" : "s") at \(take.bpm) BPM"
    }
}

/// An FM-1 control named on screen, as its own key hints draw them (gfx.c cv_key_hint): the name in a key's outline.
/// A label, not a button.
private struct FMKey: View {
    let name: String
    var body: some View {
        Text(name).font(.lupe(12, .semibold)).tracking(0.4)
            .padding(.horizontal, 6).frame(height: 22)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.textSecondaryRaised, lineWidth: 1))
    }
}

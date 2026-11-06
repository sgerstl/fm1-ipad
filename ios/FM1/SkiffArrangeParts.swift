import SloopKit
import SwiftUI

// Arrange on Skiff, continued: the edits (each a rewrite of one track's list), the inspector, the pattern
// bin, and the song's states (refused, empty, loading, disconnected).

/// What a gesture or a menu does to a track's list. Each is a rewrite (SkiffSongStore.rewrite) or one of
/// Skiff's own ops where a rewrite can't say it (NEW, COPY).
@MainActor struct ArrangeEdits {
    let session: DeviceSession
    let store: SkiffSongStore

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
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
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
    @Binding var selection: EntryRef?
    let openMenu: (ArrangeMenu, CGPoint) -> Void
    @State private var soundKey: CGRect = .zero

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store) }
    private var first: SongEntry { list.entries[block.entries.lowerBound] }
    private var poolIndex: Int? { first.poolIndex }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("T\(track + 1) \(Entries.trackName(track, session: session)) · entr\(block.isChain ? "ies" : "y") \(Entries.letters(block.entries))")
                        .font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    Text(patternLine).foregroundStyle(Theme.textSecondary).lineLimit(2)
                }
                preview
                Text(detailLine).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 300, alignment: .leading)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plays").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    StepperKeys(label: "Plays", value: block.reps, range: 1...16, step: 1, enabled: !store.busy,
                                format: { "\($0) time\($0 == 1 ? "" : "s")" }) { edits.setReps(track, block, $0) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sound on entry").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
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
                        // the sounds open in Jib's own menu, as everywhere on this page
                        key("Set sound…", enabled: block.kind == .pattern && store.sounds) {
                            openMenu(.sound(EntryRef(track: track, entry: block.entries.lowerBound)), CGPoint(x: soundKey.minX, y: soundKey.minY))
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { soundKey = $0 }
                    }
                }
                // last, apart: out of the list. Undo puts it back; one that would erase a pattern asks first
                Button(role: .destructive) { edits.delete(track, block) } label: {
                    Label(block.isChain ? "Delete entries" : "Delete entry", systemImage: "trash").font(.system(size: 15))
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
        if block.isChain { return "A chain: " + block.entries.map { list.entries[$0].isRest ? "REST" : Entries.number(list.entries[$0].pattern) }.joined(separator: " → ") }
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
            Text("Its steps show here while the track plays it.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .frame(height: 24, alignment: .leading)
        }
    }

    private func key(_ title: String, primary: Bool = false, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: primary ? .semibold : .regular))
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
            Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
            Text(refusal.text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            if refusal.needsStop, session.playing {
                Button { session.setPlaying(false); store.dismissRefusal() } label: {
                    Label("Stop", systemImage: "stop.fill").font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).frame(minHeight: 44).raisedKey()
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
    @State private var confirmClear = false
    /// A one-pattern change waiting on its confirm: POOL op 1 (Clear) or 2 (Empty), and the pattern 0…63.
    @State private var pending: (op: Int, p: Int)?
    private let look = Look()

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
                            .frame(width: 44, height: 44).raisedKey()
                    }
                    .buttonStyle(PressSink())
                    .accessibilityLabel("Close patterns")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Patterns").font(.system(size: 15, weight: .semibold)).accessibilityAddTraits(.isHeader)
                    Text("\(used) in this song · \(other) in other projects · \(pool?.free ?? 0) free")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
            }
            SegmentedKeys(label: "Show", options: ["This song", "All 64"], selected: all ? 1 : 0) { all = $0 == 1 }
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(shown, id: \.self) { p in row(p, tracks: m[p] ?? []) }
                }
            }
            .scrollIndicators(.hidden)
            Button {
                let t = selection?.track ?? session.selectedTrack
                ArrangeEdits(session: session, store: store).newPatternAtEnd(t)
            } label: {
                Text("New empty pattern").font(.system(size: 15)).frame(maxWidth: .infinity, minHeight: 44).raisedKey()
            }
            .buttonStyle(PressSink())
            .disabled((pool?.free ?? 0) == 0 || store.busy || store.offline)
            if (pool?.free ?? 0) == 0 { Text("All 64 patterns are taken. Clear unused ones to make one.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }
            Button { confirmClear = true } label: {
                Text("Clear \(pool?.unused ?? 0) unused…").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled((pool?.unused ?? 0) == 0 || session.playing || store.busy || store.offline)
            .confirmationDialog("Clear \(pool?.unused ?? 0) unused patterns?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear \(pool?.unused ?? 0) patterns", role: .destructive) { Task { _ = await store.clearUnused() } }
            } message: {
                Text("Patterns no list and no saved project uses. This can't be undone.")
            }
            .alert(pendingTitle, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { x in
                Button(x.op == 1 ? "Clear pattern" : "Empty pattern", role: .destructive) { run(x.op, x.p) }
                Button("Cancel", role: .cancel) {}
            } message: { x in
                Text(x.op == 1 ? "Its number comes free for a new pattern. This can't be undone."
                     : "Its steps go; the pattern and the entries that use it stay. This can't be undone.")
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            // the drawer stands over the page (level 3), its one shadow on its shape; the bin sits in it (level 1)
            if drawer { RoundedRectangle(cornerRadius: 16).fill(look.surface(.held)).elevationShadow(.held, look) }
        }
        .modifier(BinPanel(on: !drawer))
    }

    private func row(_ p: Int, tracks: [Int]) -> some View {
        let pat = store.pool?.patterns[p]
        let free = pat?.isFree ?? true
        let n = inSong(p)
        let selected = selection.flatMap { s in store.song?.tracks[safe: s.track]?.entries[safe: s.entry]?.poolIndex } == p
        return HStack(spacing: 10) {
            Text(Entries.number(p + 1)).font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 28)
                // its track's colour; grey when no track's list (or more than one) names it
                .foregroundStyle(!free && tracks.count == 1 ? Theme.onColour : Theme.text)
                .background(RoundedRectangle(cornerRadius: 6).fill(free ? Theme.well
                    : tracks.count == 1 ? Theme.track[tracks[0]] : Entries.tone(p + 1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(free ? "Free" : tracks.isEmpty ? "Not in this song"
                     : tracks.count == 1 ? "T\(tracks[0] + 1) \(Entries.trackName(tracks[0], session: session))" : tracks.map { "T\($0 + 1)" }.joined(separator: ", "))
                    .lineLimit(1)
                    .font(.system(size: 13))
                if let pat, pat.length > 0 {
                    Text("\(pat.length) st · \(Entries.divisionName(store.divisions[p] ?? session.tracks[safe: tracks.first ?? 0]?.division ?? 2))")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if n > 0 { Text("\(n)×").font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }
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
            Text(Entries.number(p + 1)).font(.system(size: 15, weight: .semibold)).padding(.horizontal, 14).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(Entries.tone(p + 1)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(free ? "" : "Drag onto a track to add it")
        .accessibilityAction(named: "Empty pattern") { if !free { ask(2, p) } }
        .accessibilityAction(named: "Clear pattern") { if !free { ask(1, p) } }
    }

    private var pendingTitle: String {
        guard let x = pending else { return "" }
        return "\(x.op == 1 ? "Clear" : "Empty") pattern \(Entries.number(x.p + 1))?"
    }

    /// A pattern's menu: Empty (its steps), Clear (the number itself, when nothing uses it). Stopped only, as Skiff.
    private func openMenu(_ p: Int, at: CGPoint) {
        guard let ui else { return }
        ui.menu = JibMenu(title: "Pattern \(Entries.number(p + 1))", groups: {
            let uses = store.pool?.patterns[p].uses ?? 0
            let playing = session.playing
            var notes: [MenuItem] = []
            if playing { notes.append(.note("Stop to change patterns: Skiff does this only while stopped.")) }
            else if uses > 0 { notes.append(.note("Clear needs it unused: \(uses == 1 ? "1 entry or track uses" : "\(uses) entries and tracks use") it.")) }
            return [[MenuItem(title: "Empty its steps…", icon: "square.dashed", enabled: !playing) { ask(2, p) },
                     MenuItem(title: "Clear pattern…", icon: "trash", enabled: !playing && uses == 0) { ask(1, p) }]]
                + (notes.isEmpty ? [] : [notes])
        }, at: at)
    }

    private func ask(_ op: Int, _ p: Int) {
        if session.playing { store.refuse(track: nil, entry: nil, SongRC.playing.reason, needsStop: true); return }
        pending = (op, p)
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel("Pattern \(Entries.number(number)) options")
    }
}


// MARK: - States

struct EmptySong: View {
    let session: DeviceSession
    let store: SkiffSongStore
    var body: some View {
        VStack(spacing: 12) {
            Text("No song on this project yet").font(.system(size: 17, weight: .semibold))
            Text("Drag a pattern onto a track, or record a loop on the FM-1 and it shows up here.")
                .foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Button { ArrangeEdits(session: session, store: store).newPatternAtEnd(0) } label: {
                Text("New pattern on T1").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.onColour)
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
            Text("FM-1 disconnected. This is the song as it was; editing is off until it's back.")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).frame(minHeight: 44)
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

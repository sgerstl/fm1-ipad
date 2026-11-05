import SloopKit
import SwiftUI

// Arrange on Skiff, continued: the edits (each a rewrite of one track's list), the inspector, the pattern
// bin, and the song's states (refused, empty, loading, disconnected).

/// What a gesture or a menu does to a track's list. Each is a rewrite (SkiffSongStore.rewrite) or one of
/// Skiff's own ops where a rewrite can't say it (NEW, COPY).
@MainActor struct ArrangeEdits {
    let session: DeviceSession
    let store: SkiffSongStore

    private func entries(_ t: Int) -> [SongEntry]? { store.song?.tracks[safe: t]?.entries }

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
        guard var es = entries(t), b.entries.upperBound < 15, !es[b.entries.upperBound + 1].isEmpty else {
            store.refuse(track: t, entry: b.entries.lowerBound, "Nothing after it to chain into")
            return
        }
        es[b.entries.upperBound].chained = true
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
    }

    /// A chain back into its parts, each played once.
    func split(_ t: Int, _ b: SongBlock) {
        guard var es = entries(t) else { return }
        for i in b.entries where es[i].chained { es[i].chained = false; es[i].reps = 1 }
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
    }

    /// The block's entries out of the list; the ones after it move up.
    func delete(_ t: Int, _ b: SongBlock) {
        guard var es = entries(t) else { return }
        es.removeSubrange(b.entries)
        es += Array(repeating: .empty, count: 16 - es.count)
        Task { await store.rewrite(track: t, to: es, focus: b.entries.lowerBound) }
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
            VStack(spacing: 8) {
                key("Edit pattern", primary: true, enabled: block.kind == .pattern) { open() }
                key(uniqueTitle, enabled: poolIndex != nil && !block.isChain && store.pool?.free ?? 0 > 0) { edits.makeUnique(track, block) }
                if block.isChain {
                    key("Split the chain") { edits.split(track, block) }
                } else {
                    key("Chain to next", enabled: canChain) { edits.chainIntoNext(track, block) }
                }
                SoundMenu(session: session, store: store, track: track, block: block)
            }
            .frame(width: 200)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected entry")
    }

    private var canChain: Bool { block.entries.upperBound < 15 && !list.entries[block.entries.upperBound + 1].isEmpty }

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

/// Set sound: none, or a preset of an engine the track may play, or a user preset.
struct SoundMenu: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    let block: SongBlock

    var body: some View {
        Menu {
            SoundItems(session: session, store: store, track: track, block: block)
        } label: {
            Text("Set sound…").font(.system(size: 15)).frame(maxWidth: .infinity, minHeight: 44).raisedKey()
        }
        .disabled(block.kind != .pattern || !store.sounds || store.busy || store.offline)
    }
}

/// The sounds an entry can take: none, the user presets, each engine's presets the track may play.
struct SoundItems: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    let block: SongBlock

    var body: some View {
        let edits = ArrangeEdits(session: session, store: store)
        Group {
            Button("No sound: keep the track's") { edits.setSound(track, block, nil) }
            if !session.userPresets.isEmpty {
                Menu("User presets") {
                    ForEach(session.userPresets) { u in
                        Button(u.name) { edits.setSound(track, block, EntrySound(s0: 64 + u.slot, s1: 0)) }
                    }
                }
            }
            ForEach(Array((session.info?.engines ?? []).enumerated()), id: \.offset) { e, name in
                if session.shape.canPlay(track: track, engine: e), let presets = session.namesCache[e], !presets.isEmpty {
                    Menu(name.capitalized) {
                        ForEach(Array(presets.enumerated()), id: \.offset) { k, p in
                            Button(p.capitalized) { edits.setSound(track, block, EntrySound(s0: e + 1, s1: k)) }
                        }
                    }
                }
            }
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
    @State private var confirmClear = false

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
            VStack(alignment: .leading, spacing: 4) {
                Text("Patterns").font(.system(size: 15, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text("\(used) in this song · \(other) in other projects · \(pool?.free ?? 0) free")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
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
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .panel()
    }

    private func row(_ p: Int, tracks: [Int]) -> some View {
        let pat = store.pool?.patterns[p]
        let free = pat?.isFree ?? true
        let n = inSong(p)
        let selected = selection.flatMap { s in store.song?.tracks[safe: s.track]?.entries[safe: s.entry]?.poolIndex } == p
        return HStack(spacing: 10) {
            Text(Entries.number(p + 1)).font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(free ? Theme.well : Entries.tone(p + 1)))
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
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background { if selected { RoundedRectangle(cornerRadius: 8).fill(Theme.control) } }
        .contentShape(Rectangle())
        // onDrag (not draggable): its closure runs as the drag starts, so the lanes know what's coming
        .onDrag {
            dragPattern = p + 1
            return NSItemProvider(object: "pattern \(p + 1)" as NSString)
        } preview: {
            Text(Entries.number(p + 1)).font(.system(size: 15, weight: .semibold)).padding(.horizontal, 14).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(Entries.tone(p + 1)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(free ? "" : "Drag onto a track to add it")
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
        .frame(height: 24 + CGFloat(session.trackCount) * (SkiffArrangePage.laneHeight + SkiffArrangePage.laneGap))
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
                .frame(height: SkiffArrangePage.laneHeight)
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

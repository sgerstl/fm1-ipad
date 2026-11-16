import SloopKit
import SwiftUI

// The Patterns sheet (board 79, decision 38; Scott approved 2026-11-15): the FM-1's pool of 64 pattern numbers,
// shared by every saved project. It lists the kept patterns as cards (number, length, a sketch of its notes in its first
// user's colour, where this project uses it, a dot when saved projects use it too); unused ones are dashed. White,
// because the pool is global. Filters All · Unused · This project. Select clears unused patterns with one confirm in
// place (red only on its key; can't be undone; stopped only). While playing everything live still shows; the sketches
// wait for a stop (reading them stops playback, so length bars stand in) and so does clearing. Opened in pick mode
// from a full pool's empty pad ("Put a kept pattern here…"), a tap puts that pattern on the pad. The iPhone shows it in
// its own sheet frame; the iPad as a page sheet over the app (2026-11-17, Scott: "I keep bumping up against the patterns
// being full"; the iPad had only the drawer's Clear unused and one-at-a-time Clear).

enum PatternsSheetMode: Equatable {
    case manage
    case pick(track: Int, entry: Int)
}

struct PatternsSheet: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let mode: PatternsSheetMode
    @State private var filter = Filter.all
    @State private var selecting = false
    @State private var picked: Set<Int> = []
    @State private var confirming = false
    @State private var confirmAt = Date.distantPast
    @State private var note: String?
    @State private var working = false

    enum Filter: String, CaseIterable { case all = "All", unused = "Unused", project = "This project" }

    private var pool: [PatternPool.Pattern] { store.pool?.patterns ?? [] }
    private var kept: [Int] { pool.indices.filter { pool[$0].length > 0 } }
    private func unused(_ p: Int) -> Bool { pool[safe: p].map { $0.length > 0 && $0.uses == 0 } ?? false }
    /// Where this project uses pattern p: (track, entry) pairs.
    private func uses(_ p: Int) -> [(Int, Int)] {
        guard let song = store.song else { return [] }
        return song.tracks.enumerated().flatMap { t, l in l.entries.enumerated().compactMap { i, e in e.poolIndex == p ? (t, i) : nil } }
    }
    private var playing: Bool { session.playing }
    /// The iPad's page sheet: room for the filter and counts at their full width.
    private var wide: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var picking: (track: Int, entry: Int)? { if case .pick(let t, let e) = mode { (t, e) } else { nil } }

    var body: some View {
        let shown = kept.filter { p in
            switch filter {
            case .all: true
            case .unused: unused(p)
            case .project: !uses(p).isEmpty
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(shown, id: \.self) { p in card(p) }
                }
                .padding(2)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .animation(.easeOut(duration: 0.15), value: selecting)
        .animation(.easeOut(duration: 0.15), value: confirming)
        .animation(.easeOut(duration: 0.15), value: filter)
        // the sketches, while stopped: read from the FM-1's pool once and cached (PadThumb); never while playing
        .task(id: playing) { if !playing { await PadThumb.forSheet(session, store, ui) } }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(picking.map { "Put a pattern on \($0.track + 1) · \(Entries.letter($0.entry))" } ?? "Patterns")
                .font(.lupe(17, .semibold)).accessibilityAddTraits(.isHeader)
            let free = store.pool?.free ?? 0, unusedN = store.pool?.unused ?? 0
            Text("\(kept.count) kept · \(free) free · \(unusedN) unused").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                .lineLimit(wide ? 1 : nil).fixedSize(horizontal: wide, vertical: false)
            if picking == nil {
                Picker("Show", selection: $filter) { ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                    // the iPad sizes it to its words (at 230 "This project" was cut, 2026-11-17); the phone's header has no room for that
                    .frame(width: wide ? nil : 230).fixedSize(horizontal: wide, vertical: false)
            }
            Spacer(minLength: 0)
            if picking == nil {
                if selecting {
                    key("Done") { selecting = false; picked = []; confirming = false }
                } else {
                    key("Select", enabled: !kept.isEmpty) { selecting = true; note = nil }
                    let n = store.pool?.unused ?? 0
                    key(n > 0 ? "Clear \(n) unused…" : "No unused", enabled: n > 0 && !playing) {
                        selecting = true; picked = Set(kept.filter(unused)); askConfirm()
                    }
                }
            }
            SheetClose(label: "Close Patterns") { ui.patternsSheet = nil }
        }
        .frame(minHeight: 44)
    }

    private func key(_ title: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.lupe(14, .semibold)).padding(.horizontal, 12).frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!enabled).opacity(enabled ? 1 : 0.45)
    }

    // MARK: A card

    private func card(_ p: Int) -> some View {
        let here = uses(p)
        let isUnused = unused(p)
        let firstColour = here.first.map { Theme.track[$0.0] } ?? Theme.textTertiary
        let saved = (pool[safe: p]?.uses ?? 0) > localRefs(p, here: here)       // saved projects name it too
        let sel = picked.contains(p)
        let dim = selecting && !isUnused
        return Button { tap(p, isUnused: isUnused, here: here) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Entries.number(p + 1)).font(.lupeNumber(17, .bold)).monospacedDigit()
                    Spacer(minLength: 0)
                    Text("\(pool[safe: p]?.length ?? 0)").font(.lupe(10, .semibold)).foregroundStyle(Theme.textTertiary)
                }
                Group {
                    if !playing, let th = ui.padThumbs[p], th.length == pool[safe: p]?.length {
                        PadThumbView(thumb: th, ink: firstColour)
                    } else {
                        // playing (or not read yet): bars for its length, the sketch waits for a stop
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<8, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1).fill(Theme.stepEmpty)
                                    .frame(height: 6 + CGFloat((p * 7 + i * 5) % 9) * 2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                HStack(spacing: 3) {
                    if saved { Circle().fill(Theme.textSecondary).frame(width: 6, height: 6).accessibilityHidden(true) }
                    if isUnused {
                        Text("unused").foregroundStyle(Theme.textTertiary)
                    } else if here.isEmpty {
                        Text("saved projects").foregroundStyle(Theme.textSecondary)
                    } else {
                        usesText(here)
                    }
                }
                .font(.lupe(10)).lineLimit(1)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .frame(height: 88)
            .background {
                if isUnused {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.disabledOutline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.control)
                }
            }
            .overlay { if sel { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, lineWidth: 2).padding(-1) } }
            .overlay(alignment: .bottomTrailing) {
                if selecting && isUnused {
                    ZStack {
                        Circle().strokeBorder(sel ? Theme.text : Theme.textSecondary, lineWidth: 1.5)
                        if sel { Circle().fill(Theme.text); Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.onColour) }
                    }
                    .frame(width: 16, height: 16).padding(5)
                }
            }
            .opacity(dim ? 0.38 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(spoken(p, here: here, isUnused: isUnused, saved: saved))
        .accessibilityAddTraits(sel ? .isSelected : [])
        .accessibilityHint(picking != nil ? "Puts it on the pad" : selecting ? (isUnused ? "Picks it to clear" : "Used: can't be cleared") : "")
    }

    /// What this project's own state accounts for in the FM-1's use count (P1's rule, bank.c pool_refs minus LIST): the
    /// entries naming it, plus each track on it whose own entry doesn't name it. More than that: saved projects too.
    private func localRefs(_ p: Int, here: [(Int, Int)]) -> Int {
        guard let song = store.song else { return here.count }
        let tracksOn = song.tracks.filter { l in
            l.patternOn == p && (l.entryOn.flatMap { l.entries[safe: $0]?.poolIndex } != p)
        }.count
        return here.count + tracksOn
    }

    /// "T2 A · T4 C": each use's track number in its colour, the entry's letter in grey.
    private func usesText(_ here: [(Int, Int)]) -> Text {
        var out = Text("")
        for (k, u) in here.prefix(3).enumerated() {
            let sep = k > 0 ? " · " : ""
            out = out + Text(sep + "T\(u.0 + 1) ").foregroundStyle(Theme.track[u.0])
            out = out + Text(Entries.letter(u.1)).foregroundStyle(Theme.textSecondary)
        }
        return out
    }

    private func spoken(_ p: Int, here: [(Int, Int)], isUnused: Bool, saved: Bool) -> String {
        let len = pool[safe: p]?.length ?? 0
        var s = "Pattern \(Entries.number(p + 1)), \(len) steps"
        if isUnused { s += ", unused" }
        else if here.isEmpty { s += ", used by saved projects" }
        else {
            let list = here.map { "track \($0.0 + 1) \(Entries.letter($0.1))" }.joined(separator: ", ")
            s += ", used by " + list
            if saved { s += ", and by saved projects" }
        }
        return s
    }

    private func tap(_ p: Int, isUnused: Bool, here: [(Int, Int)]) {
        if let pk = picking {
            // the pad plays the same pattern as its other uses (edits shared)
            Task {
                if await store.send(.set(track: pk.track, entry: pk.entry, pattern: p + 1)) { ui.patternsSheet = nil }
            }
            return
        }
        guard selecting else { return }
        guard isUnused else {
            note = "\(Entries.number(p + 1)) is used: " + (here.isEmpty ? "by saved projects" : here.map { "T\($0.0 + 1) \(Entries.letter($0.1))" }.joined(separator: " · "))
            return
        }
        confirming = false
        if picked.contains(p) { picked.remove(p) } else { picked.insert(p) }
    }

    private func askConfirm() {
        guard !picked.isEmpty else { return }
        confirmAt = Date(); confirming = true
        UIAccessibility.post(notification: .announcement, argument: "Clear \(picked.count) patterns? Can't be undone")
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        if confirming {
            let list = picked.sorted().map { Entries.number($0 + 1) }
            HStack(spacing: 10) {
                (Text("Clear \(picked.count) pattern\(picked.count == 1 ? "" : "s")? ").foregroundStyle(Theme.text)
                    + Text(list.prefix(8).joined(separator: ", ") + (list.count > 8 ? "…" : "") + " · nothing uses them · can't be undone").foregroundStyle(Theme.textSecondary))
                    .font(.lupe(14)).lineLimit(2)
                Spacer(minLength: 0)
                key("Keep") { confirming = false }
                Button { clear() } label: {
                    Text("Clear \(picked.count)").font(.lupe(14, .semibold)).foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.rec))
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(working || playing)
                .accessibilityHint("Can't be undone")
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
            .transition(.opacity)
        } else if playing {
            line("Playing: pictures and saved-project names load when you stop. Clearing needs the FM-1 stopped.")
        } else if picking != nil {
            line("The pad will play the same pattern as its other uses; editing it changes them all.")
        } else if selecting {
            HStack(spacing: 10) {
                Text(note ?? "\(picked.count) picked · only unused patterns can be cleared; tap a used one to see where it's used")
                    .font(.lupe(14)).foregroundStyle(Theme.textSecondary).lineLimit(2)
                Spacer(minLength: 0)
                key("Pick all unused", enabled: (store.pool?.unused ?? 0) > 0) { picked = Set(kept.filter(unused)) }
                key("Clear \(picked.count)…", enabled: !picked.isEmpty) { askConfirm() }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
        }
    }

    private func line(_ s: String) -> some View {
        Text(s).font(.lupe(14)).foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
    }

    /// Clears the picked patterns one by one (POOL op 1, stopped only); every unused one at once is CLEAR UNUSED.
    private func clear() {
        guard Date().timeIntervalSince(confirmAt) > 0.4, !playing else { return }       // (no double tap through the confirm)
        let list = picked.sorted()
        working = true
        Task {
            if Set(list) == Set(kept.filter(unused)) { _ = await store.clearUnused() }
            else { for p in list { _ = await store.poolOp(1, pattern: p) } }
            working = false; confirming = false; selecting = false; picked = []
        }
    }
}

extension PadThumb {
    /// The Patterns sheet's sketches (board 79): while stopped only, every kept pattern without a current drawing, read
    /// from the FM-1's pool (reading stops playback, so never while playing). Cached in the session's drawings.
    @MainActor static func forSheet(_ session: DeviceSession, _ store: SkiffSongStore, _ ui: EditorUI) async {
        // the patterns the tracks are on now draw from their live steps first (no read), and are never replaced by the
        // stored copy (an edit can still be on its way to flash)
        learn(session, store, ui)
        // P1's rules (as the iPad's PadThumb.fromPool): never while playing, nor while the store is busy; 3 s quiet after
        // a stop or a change first (the first read on a connection sends BACKUP_LIST, which writes to flash)
        while true {
            guard !session.playing, !store.offline, !Task.isCancelled else { return }
            let quiet = Date().timeIntervalSince(max(session.stoppedAt, store.lastChange))
            if quiet >= 3, !store.busy { break }
            try? await Task.sleep(for: .milliseconds(max(200, Int((3 - quiet) * 1000))))
        }
        guard let pool = store.pool?.patterns, pool.count == 64 else { return }
        let live = Set(session.trackIndices.compactMap { store.song?.tracks[safe: $0]?.patternOn })
        let missing = (0..<64).filter { pool[$0].length > 0 && !live.contains($0) && ui.padThumbs[$0]?.length != pool[$0].length }
        let chunks = Array(Set(missing.map { $0 / 4 })).sorted()
        guard !chunks.isEmpty, let recs = await session.readSkiffPool(chunks: chunks) else { return }
        for (p, r) in recs where !live.contains(p) && ui.padThumbs[p]?.length != pool[safe: p]?.length {
            if let s = SkiffPatternSketch(record: r) { var th = of(s); th.direction = s.direction; th.motion = s.motion; ui.padThumbs[p] = th }
        }
    }
}

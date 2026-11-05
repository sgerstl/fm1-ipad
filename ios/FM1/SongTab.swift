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
    /// The song's share of the height, kept across launches.
    @AppStorage("songSplit") private var split = 0.40
    @State private var dragFrom: Double?
    @State private var allPatterns = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let editorMin: CGFloat = 380, dividerHeight: CGFloat = 16
    /// The song's least: the tool row, the ruler and every lane at its least (28 pt and its gap), so it never spills.
    static func songMin(_ tracks: Int) -> CGFloat { 44 + 8 + 24 + 8 + CGFloat(tracks) * (28 + SkiffArrangePage.laneGap) }

    var body: some View {
        GeometryReader { g in
            let total = g.size.height
            let least = Self.songMin(session.trackCount)
            let top = min(max(total * split, least), max(least, total - Self.editorMin - Self.dividerHeight))
            let bottom = total - top - Self.dividerHeight
            VStack(spacing: 0) {
                SkiffArrangePage(session: session, store: store, ui: ui)
                    .environment(\.arrangeCompact, true)
                    .environment(\.arrangeLaneHeight, Self.laneHeight(top, tracks: session.trackCount))
                    .frame(height: top)
                    .clipped()
                divider(total, least: least)
                PatternPane(session: session, store: store, ui: ui, height: bottom)
                    .frame(height: bottom)
            }
            .overlay { drawer }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: ui.poolOpen)
        }
    }

    /// The pattern pool (Scott: "Full height"): a level-3 drawer down the page's right edge, over both halves, the
    /// source a pattern is dragged from onto a lane. A tap outside, Escape or Patterns closes it. While a pattern is
    /// dragged the tap catcher steps aside, so the drop reaches the lanes (the editor takes none).
    @ViewBuilder private var drawer: some View {
        if ui.poolOpen {
            ZStack(alignment: .trailing) {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { ui.poolOpen = false }
                    .allowsHitTesting(ui.dragPattern == nil)
                    .accessibilityHidden(true)
                PatternBin(session: session, store: store, all: $allPatterns, selection: ui.pinnedEntry,
                           dragPattern: Binding(get: { ui.dragPattern }, set: { ui.dragPattern = $0 }), drawer: true)
                    .frame(width: 288)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .flashRing(ui, .patternBin)          // SAVE > PATTERNS on the FM-1 lands here
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
            .background {
                Button("Close the patterns") { ui.poolOpen = false; ui.dragPattern = nil }
                    .keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { ui.poolOpen = false }
        }
    }

    /// The lanes share what's left under the tool row and the ruler.
    static func laneHeight(_ top: CGFloat, tracks: Int) -> CGFloat {
        let lanes = top - 44 - 8 - 24 - 8
        return max(28, min(SkiffArrangePage.fullLaneHeight, lanes / CGFloat(max(1, tracks)) - SkiffArrangePage.laneGap))
    }

    private func divider(_ total: CGFloat, least: CGFloat) -> some View {
        Capsule().fill(Theme.disabledOutline).frame(width: 56, height: 5)
            .frame(maxWidth: .infinity).frame(height: Self.dividerHeight)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { v in
                    if dragFrom == nil { dragFrom = split }
                    let lo = least / total, hi = (total - Self.editorMin - Self.dividerHeight) / total
                    split = min(max((dragFrom ?? split) + v.translation.height / total, lo), hi)
                }
                .onEnded { _ in dragFrom = nil })
            .accessibilityElement()
            .accessibilityLabel("Divider between the song and the pattern")
            .accessibilityValue("song \(Int((split * 100).rounded())) percent")
            .accessibilityAdjustableAction { d in split = min(max(split + (d == .increment ? 0.05 : -0.05), 0.2), 0.6) }
    }
}

/// The bottom half: whose pattern, which entry, follow or pinned; then the step panel and the editor.
struct PatternPane: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let height: CGFloat
    @State private var headerFrame: CGRect = .zero

    static let headerHeight: CGFloat = 44

    var body: some View {
        let t = session.selectedTrack
        let list = store.song?.tracks[safe: t]
        let pinned = ui.pinnedEntry.flatMap { $0.track == t ? $0 : nil }
        let entry = pinned?.entry ?? list?.entryOn
        let loaded = pinned == nil || pinned?.entry == list?.entryOn
        let editor = height - Self.headerHeight - 12
        VStack(alignment: .leading, spacing: 12) {
            header(t, list: list, entry: entry, pinned: pinned)
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
                    .opacity(loaded ? 1 : 0.35)
                    .allowsHitTesting(loaded)
                    if !loaded, let p = pinned { notLoaded(p, list: list) }
                }
            }
            .environment(\.editorHeight, editor)
            .environment(\.arrangeCompact, true)
        }
        // following: the track moved on to another entry, so the editor reads its pattern now, not at the next resync
        .onChange(of: list?.entryOn) { _, _ in Task { await session.rereadSteps(track: t) } }
        .onChange(of: list?.patternOn) { _, _ in Task { await session.rereadSteps(track: t) } }
    }

    // MARK: Header: "Bass · pattern 07 · entry C · also on entries D", Make unique, the picker; follow or pinned

    private func header(_ t: Int, list: SongList?, entry: Int?, pinned: EntryRef?) -> some View {
        let e = entry.flatMap { list?.entries[safe: $0] }
        let pattern = e.flatMap { $0.isRest || $0.isEmpty ? nil : $0.pattern } ?? list?.patternOn
        let shared = entry.map { list?.sharing($0) ?? [] } ?? []
        return HStack(spacing: 10) {
            TrackChip(track: t, selected: true).frame(width: 28, height: 28)
            Text(Entries.trackName(t, session: session)).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            Button { openPicker(t, entry: entry) } label: {
                HStack(spacing: 4) {
                    Text("pattern").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Text(pattern.map(Entries.number) ?? "–").font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10).frame(height: 36).raisedKey()
                .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(entry == nil || store.offline)
            .accessibilityLabel("Pattern \(pattern.map(Entries.number) ?? "none")")
            .accessibilityHint("Pick another pattern for this entry, or a new empty one")
            if let entry { Text("entry \(Entries.letter(entry))").font(.system(size: 13)).foregroundStyle(Theme.textSecondary) }
            if !shared.isEmpty, let entry {
                Text("also on entr\(shared.count == 1 ? "y" : "ies") \(shared.map(Entries.letter).joined(separator: ", "))")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                Button { Task { await store.send(.copy(track: t, entry: entry)) } } label: {
                    Text("Make unique").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).frame(height: 36).raisedKey()
                }
                .buttonStyle(PressSink())
                .disabled(store.offline || session.playing)
                .accessibilityHint("Gives this entry its own copy of the pattern")
            }
            Spacer(minLength: 0)
            if let p = pinned {
                Label("Pinned to entry \(Entries.letter(p.entry))", systemImage: "pin").font(.system(size: 13))
                    .padding(.horizontal, 10).frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                Button { ui.pinnedEntry = nil } label: {
                    Text("Follow").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).frame(height: 36).raisedKey()
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Shows the pattern each track plays now again")
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: 0x30D158)).frame(width: 8, height: 8).accessibilityHidden(true)
                    Text("Following the song").font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 10).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.tones[2]))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(height: Self.headerHeight)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { headerFrame = $0 }
    }

    /// The picker: the pool's patterns, those in use and the free ones, and a new empty one (LIST op 1, op 7).
    private func openPicker(_ t: Int, entry: Int?) {
        guard let entry else { return }
        let pool = store.pool?.patterns ?? []
        let used = pool.indices.filter { !pool[$0].isFree }, free = pool.indices.filter { pool[$0].isFree }
        ui.menu = JibMenu(title: "T\(t + 1) · entry \(Entries.letter(entry))", groups: {
            [[MenuItem(title: "New empty pattern", icon: "plus.square") { Task { await store.send(.new(track: t, entry: entry)) } }],
             used.map { i in
                MenuItem(title: "Pattern \(Entries.number(i + 1)) · \(pool[i].length) steps", chip: (Entries.number(i + 1), Theme.track[t]),
                         note: false) { Task { await store.send(.set(track: t, entry: entry, pattern: i + 1)) } }
             },
             free.isEmpty ? [] : [MenuItem(title: "Free patterns: \(free.count)", enabled: false, note: true)],
             [MenuItem(title: "Show the pattern pool", icon: "square.grid.2x2") { ui.poolOpen = true }]].filter { !$0.isEmpty }
        }, at: CGPoint(x: headerFrame.minX + 200, y: headerFrame.maxY))
    }

    /// Pinned to an entry that isn't what the track plays: Skiff edits the pattern a track has, and sending the
    /// track there while playing would launch it, so it opens on STOP.
    private func notLoaded(_ p: EntryRef, list: SongList?) -> some View {
        VStack(spacing: 12) {
            Text("Entry \(Entries.letter(p.entry))'s pattern opens when the song stops")
                .font(.system(size: 17, weight: .semibold))
            Text("Skiff edits the pattern a track is playing; going to entry \(Entries.letter(p.entry)) now would launch it.")
                .font(.system(size: 13)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button { session.setPlaying(false) } label: {
                    Text("Stop").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 18).frame(minHeight: 44).raisedKey(primary: true)
                }
                .buttonStyle(PressSink())
                Button { ui.pinnedEntry = nil } label: {
                    Text("Follow").font(.system(size: 15, weight: .semibold)).padding(.horizontal, 18).frame(minHeight: 44).raisedKey()
                }
                .buttonStyle(PressSink())
            }
        }
        .padding(20)
        .frame(maxWidth: 440)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel).elevationShadow(.panel, Look()))
        // stopped, the track goes there (the pin's LIST op 3), and the pattern opens
        .onChange(of: session.playing) { _, on in
            guard !on, list?.entryOn != p.entry else { return }
            Task { await store.send(.play(track: p.track, entry: p.entry)) }
        }
    }
}

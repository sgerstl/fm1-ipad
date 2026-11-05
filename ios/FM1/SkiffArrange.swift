import SloopKit
import SwiftUI

// Arrange on Skiff (vault skiff-arrange-spec.md; the canvas's board A): one bar ruler, a lane per track, a
// block per list entry as wide as it plays, the selected entry's inspector below and the pattern pool at the
// side. Entries play back to back, so every change is a rewrite of a track's list (SkiffSongStore); while
// playing, what Skiff can't take shows "Stop to rearrange" where it was tried.

struct SkiffArrangePage: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    @State private var selection: EntryRef?
    @State private var zoomBars: Int?
    @State private var allPatterns = false
    /// A pattern being dragged from the bin (set when the drag starts), and where it would go.
    @State private var dragPattern: Int?
    @State private var dropAt: DropSpot?
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let headerWidth: CGFloat = 152
    static let laneHeight: CGFloat = 80
    static let laneGap: CGFloat = 8
    static let binWidth: CGFloat = 272

    var body: some View {
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
                if let d = dropAt {
                    Text(d.text).font(.system(size: 13)).padding(.horizontal, 12).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
                        .padding(.leading, Self.headerWidth)
                } else if let r = store.refusal, r.entry == nil || selection == nil {
                    RefusalLine(refusal: r, session: session, store: store)
                }
                inspector
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            PatternBin(session: session, store: store, all: $allPatterns, selection: selection, dragPattern: $dragPattern)
                .frame(width: Self.binWidth)
        }
        .overlay(alignment: .top) { if store.offline { OfflineBar(session: session) } }
        .task(id: store.offline) { if !store.offline { await store.follow() } }
    }

    // MARK: Tool row: the song's length, the warning when lanes end apart, zoom

    private var songBars: Int { Int((store.laneEnds.max() ?? 0).rounded(.up)) }

    private var toolRow: some View {
        HStack(spacing: 12) {
            Text("Song").font(.system(size: 15, weight: .semibold)).accessibilityAddTraits(.isHeader)
            Text("\(songBars) bar\(songBars == 1 ? "" : "s") · \(session.trackCount) tracks")
                .foregroundStyle(Theme.textSecondary)
            // SONG: off loops each track's entry, on plays the lists, once plays them once and stops (LIST op 6)
            SegmentedKeys(label: "Song mode", options: ["Loop", "Song", "Once"], selected: store.song?.mode.rawValue ?? -1,
                          enabled: [!store.offline, !store.offline, !store.offline]) { k in
                Task { await store.send(.song(SongMode(rawValue: k) ?? .on)) }
            }
            Spacer(minLength: 8)
            if let w = loopApartWarning {
                Label(w, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.control))
            }
            zoom
        }
        .frame(height: 44)
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
                    ForEach(0..<session.trackCount, id: \.self) { t in LaneHeader(session: session, store: store, track: t) }
                }
                .frame(width: Self.headerWidth)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: Self.laneGap) {
                        Ruler(bars: Int(contentWidth / barWidth), barWidth: barWidth)
                        ForEach(0..<session.trackCount, id: \.self) { t in
                            Lane(session: session, store: store, track: t, barWidth: barWidth, width: contentWidth,
                                 selection: $selection, dragPattern: $dragPattern, dropAt: $dropAt, ui: ui)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        SongPlayhead(session: session, store: store, barWidth: barWidth,
                                     height: 24 + CGFloat(session.trackCount) * (Self.laneHeight + Self.laneGap))
                    }
                    .frame(width: contentWidth, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
            .opacity(store.offline ? 0.5 : 1)
        }
        .frame(height: 24 + CGFloat(session.trackCount) * (Self.laneHeight + Self.laneGap))
        .disabled(store.offline)
        // a keyboard: arrows move between blocks and lanes, + and − set REPS, Delete deletes, Return opens
        .focusable()
        .focusEffectDisabled()          // the selected block's ring is the focus
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .delete, .deleteForward, .return, .escape, "+", "=", "-"]) { k in
            key(k.key) ? .handled : .ignored
        }
    }

    // MARK: Keyboard

    private func key(_ k: KeyEquivalent) -> Bool {
        let edits = ArrangeEdits(session: session, store: store)
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
        case .escape: selection = nil
        default: return false
        }
        return true
    }

    // MARK: Inspector

    @ViewBuilder private var inspector: some View {
        if let sel = selection, let song = store.song, sel.track < song.tracks.count,
           let block = store.blocks(sel.track).first(where: { $0.entries.contains(sel.entry) }) {
            EntryInspector(session: session, store: store, ui: ui, track: sel.track, block: block,
                           list: song.tracks[sel.track], selection: $selection)
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
    /// Blocks are greys, told apart by the number on them: four tones, by pattern number.
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

    var body: some View {
        let tr = session.tracks[track]
        let used = store.song?.tracks[safe: track]?.used ?? 0
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
                Text("\(used) of 16 entries").font(.system(size: 12))
                    .foregroundStyle(used >= 16 ? Theme.text : Theme.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
        .padding(.trailing, 8)
        .frame(width: SkiffArrangePage.headerWidth, height: SkiffArrangePage.laneHeight, alignment: .topLeading)
    }
}

struct Ruler: View {
    let bars: Int
    let barWidth: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6).fill(Theme.panel)
            ForEach(Array(stride(from: 0, to: bars, by: 4)), id: \.self) { b in
                Text("\(b + 1)").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .offset(x: CGFloat(b) * barWidth + 6, y: 4)
            }
        }
        .frame(height: 24)
        .accessibilityHidden(true)
    }
}

struct Lane: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    let barWidth: CGFloat
    let width: CGFloat
    @Binding var selection: EntryRef?
    @Binding var dragPattern: Int?
    @Binding var dropAt: DropSpot?
    let ui: EditorUI
    /// A right edge being dragged: the block's last entry and the REPS it would get.
    @State private var stretch: (entry: Int, reps: Int)?
    @State private var stretchStart: Int = 1

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store) }
    private func x(_ ticks: Double) -> CGFloat { CGFloat(ticks / SongPlacement.ticksPerBar) * barWidth }

    var body: some View {
        var list = store.song?.tracks[safe: track] ?? SongList()
        if let s = stretch { list.entries[s.entry].reps = s.reps }
        let blocks = store.blocks(track, list: list)
        let selectedPattern: Int? = selection.flatMap { s in
            s.track == track ? list.entries[safe: s.entry]?.poolIndex : nil
        }
        let lastEnd = x(blocks.last?.end ?? 0)
        let spot = dropAt?.track == track ? dropAt : nil
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(Theme.well)
            // after the last block: a tap adds (repeat, new, rest, pick)
            addMenu(list: list)
                .frame(width: max(44, width - lastEnd - 4), height: SkiffArrangePage.laneHeight - 12)
                .offset(x: lastEnd + 2, y: 6)
            ForEach(blocks) { b in
                let bx = x(b.start) + (spot.map { b.entries.lowerBound >= $0.index ? x($0.ticks) : 0 } ?? 0)
                let w = max(8, x(b.length) - 4)
                let selected = selection?.track == track && b.entries.contains(selection?.entry ?? -1)
                let linked = !selected && selectedPattern != nil && b.entries.contains { list.entries[$0].poolIndex == selectedPattern }
                BlockView(session: session, track: track, block: b, list: list, width: w,
                          selected: selected, linked: linked, playing: session.playing && b.entries.contains(list.entryOn ?? -1))
                    .frame(width: w, height: SkiffArrangePage.laneHeight - 12)
                    .onTapGesture(count: 2) { open(b) }
                    .onTapGesture { selection = EntryRef(track: track, entry: b.entries.lowerBound) }
                    .contextMenu { holdMenu(b, list: list) }
                    // the edge grip sits outside the hold menu's view: its press would take the drag
                    .overlay(alignment: .trailing) { if b.kind != .gap { grip(b, list: list) } }
                    .overlay(alignment: .bottomTrailing) {
                        if stretch?.entry == b.entries.upperBound {
                            Text("×\(b.reps) · \(bars(b.length)) bars").font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8).frame(height: 24)
                                .elevated(.held, radius: 6)
                                .offset(x: 40, y: 30)
                        }
                    }
                    .offset(x: bx + 2, y: 6)
                    .accessibilityAction { selection = EntryRef(track: track, entry: b.entries.lowerBound) }
                    .accessibilityAction(named: "Edit pattern") { open(b) }
                    .accessibilityAction(named: "Play once more") { edits.setReps(track, b, b.reps + 1) }
                    .accessibilityAction(named: "Play once less") { edits.setReps(track, b, b.reps - 1) }
                    .accessibilityAction(named: "Duplicate after") { edits.duplicateAfter(track, b) }
                    .accessibilityAction(named: "Delete entry") { edits.delete(track, b) }
            }
            if let spot {
                // where the dragged pattern goes: a line, and its ghost lifted under the finger
                Rectangle().fill(Theme.text).frame(width: 2, height: SkiffArrangePage.laneHeight + 8)
                    .offset(x: x(spot.at) - 1, y: -4)
                Text(Entries.number(spot.pattern)).font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(width: max(44, x(spot.ticks) - 4), height: SkiffArrangePage.laneHeight - 12, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Entries.tone(spot.pattern)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.text, lineWidth: 2))
                    .elevationShadow(.held, Look())
                    .opacity(0.9)
                    .offset(x: x(spot.at) + 2, y: 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: SkiffArrangePage.laneHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onDrop(of: [.plainText], delegate: LaneDrop(lane: self, blocks: blocks))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(track + 1), \(Entries.trackName(track, session: session))")
    }

    private func bars(_ ticks: Double) -> String {
        let b = ticks / SongPlacement.ticksPerBar
        return b == b.rounded() ? "\(Int(b))" : String(format: "%.2g", b)
    }

    /// The edge you drag for REPS: drawn 8 pt, a 44 pt hit area; a pass at a time.
    private func grip(_ b: SongBlock, list: SongList) -> some View {
        let pass = max(1, x(b.pass))
        return Capsule().fill(Theme.text.opacity(0.35)).frame(width: 4, height: 28)
            .frame(width: 44, height: SkiffArrangePage.laneHeight - 12)
            .contentShape(Rectangle())
            .offset(x: 20)
            // from touch-down: a drag that waits for movement loses to the lanes' scroll view
            // measured globally: the grip moves with the edge it drags
            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { v in
                    if stretch == nil { stretchStart = list.entries[b.entries.upperBound].reps }
                    let n = max(1, min(16, stretchStart + Int((v.translation.width / pass).rounded())))
                    stretch = (b.entries.upperBound, n)
                }
                .onEnded { _ in
                    guard let s = stretch else { return }
                    stretch = nil
                    if s.reps != stretchStart, let blk = store.blocks(track).first(where: { $0.entries.contains(s.entry) }) {
                        edits.setReps(track, blk, s.reps)
                    }
                })
            .accessibilityHidden(true)
    }

    @ViewBuilder private func holdMenu(_ b: SongBlock, list: SongList) -> some View {
        if b.kind == .pattern { Button("Edit pattern", systemImage: "pencil") { open(b) } }
        if let p = list.entries[b.entries.lowerBound].poolIndex, !b.isChain {
            let n = edits.copyNumber(after: p).map { " (becomes \(Entries.number($0)))" } ?? ""
            Button("Make unique\(n)", systemImage: "square.on.square.dashed") { edits.makeUnique(track, b) }
                .disabled((store.pool?.free ?? 0) == 0)
        }
        Button("Duplicate after", systemImage: "plus.square.on.square") { edits.duplicateAfter(track, b) }
        if b.isChain {
            Button("Split the chain", systemImage: "scissors") { edits.split(track, b) }
        } else {
            Button("Chain into next", systemImage: "link") { edits.chainIntoNext(track, b) }
                .disabled(b.entries.upperBound >= 15 || list.entries[b.entries.upperBound + 1].isEmpty)
        }
        if b.kind == .pattern, store.sounds {
            Menu("Set sound…", systemImage: "waveform") { SoundItems(session: session, store: store, track: track, block: b) }
        }
        Button("Delete entr\(b.isChain ? "ies" : "y")", systemImage: "trash", role: .destructive) { edits.delete(track, b) }
    }

    /// After a lane's last block: repeat the last pattern, a new empty one, a rest, or pick one.
    private func addMenu(list: SongList) -> some View {
        let last = list.span.map { list.entries[$0.upperBound] }
        let kept = (0..<64).filter { (store.pool?.patterns[$0].length ?? 0) > 0 }
        return Menu {
            Section("T\(track + 1) · after the last entry") {
                if let last, let p = last.poolIndex {
                    Button("Repeat \(Entries.number(p + 1)) again") { edits.appendAtEnd(track, SongEntry(pattern: p + 1, reps: last.reps)) }
                }
                Button("New empty pattern") { edits.newPatternAtEnd(track) }.disabled((store.pool?.free ?? 0) == 0)
                Button("Rest") { edits.appendAtEnd(track, SongEntry(pattern: SongEntry.rest, reps: 1)) }
                Menu("Pick a pattern…") {
                    ForEach(kept, id: \.self) { p in
                        Button(Entries.number(p + 1)) { edits.appendAtEnd(track, SongEntry(pattern: p + 1, reps: 1)) }
                    }
                }
            }
        } label: {
            Color.clear.contentShape(Rectangle())
        }
        .accessibilityLabel("Add to track \(track + 1)")
        .disabled(store.offline || store.busy)
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
            ui.page = .sequencer
        }
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
}

/// The drop: the nearest block edge (entries play back to back, so a new one goes between two).
struct LaneDrop: DropDelegate {
    let lane: Lane
    let blocks: [SongBlock]

    private func spot(_ info: DropInfo) -> DropSpot? {
        guard let p = lane.dragPattern else { return nil }
        let ticks = Double(info.location.x / max(1, lane.barWidth)) * SongPlacement.ticksPerBar
        var edges: [(index: Int, at: Double)] = blocks.map { ($0.entries.lowerBound, $0.start) }
        let end = blocks.last.map { ($0.entries.upperBound + 1, $0.end) } ?? (lane.store.song?.tracks[safe: lane.track]?.span.map { $0.upperBound + 1 } ?? 0, 0)
        edges.append(end)
        guard let e = edges.min(by: { abs($0.at - ticks) < abs($1.at - ticks) }) else { return nil }
        let pass = lane.store.passTicks(p - 1, track: lane.track)
        let bar = Int(e.at / SongPlacement.ticksPerBar) + 1
        let after = blocks.filter { $0.entries.lowerBound >= e.index }
        var text = "Drop on T\(lane.track + 1): a new entry \(Entries.letter(e.index)) at bar \(bar)"
        if let f = after.first, let l = after.last {
            let shift = pass / SongPlacement.ticksPerBar
            let by = shift == shift.rounded() ? "\(Int(shift)) bar\(shift == 1 ? "" : "s")" : String(format: "%.2g bars", shift)
            let moved = f.entries.lowerBound == l.entries.upperBound ? Entries.letter(f.entries.lowerBound)
                : "\(Entries.letter(f.entries.lowerBound))–\(Entries.letter(l.entries.upperBound))"
            text += ", \(moved) move\(f.entries.lowerBound == l.entries.upperBound ? "s" : "") \(by) later"
        }
        if (lane.store.song?.tracks[safe: lane.track]?.span?.upperBound ?? -1) >= 15 {
            text = "T\(lane.track + 1) has all 16 entries, so \(Entries.number(p)) can't go in. Play one entry more times, or chain two, to free a slot"
        }
        return DropSpot(track: lane.track, index: e.index, at: e.at, ticks: pass, pattern: p, text: text)
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
        guard let s = spot(info) else { return false }
        lane.selection = EntryRef(track: lane.track, entry: s.index)
        ArrangeEdits(session: lane.session, store: lane.store).insert(lane.track, SongEntry(pattern: s.pattern, reps: 1), at: s.index)
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
    @Environment(\.look) private var look

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
        let shape = BlockShape(cut: sound != nil ? 12 : 0)
        let wide = width >= 56
        VStack(alignment: .leading, spacing: 2) {
            if wide {
                Text(Entries.letters(block.entries)).font(.system(size: 11)).foregroundStyle(isRest ? Theme.textSecondary : Theme.blockDim)
                Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(isRest ? Theme.textSecondary : Theme.text)
                Text(sub).font(.system(size: 12)).foregroundStyle(isRest ? Theme.textSecondary : Theme.blockDim)
            } else {
                Text(isRest ? "–" : label).font(.system(size: 13, weight: .semibold)).foregroundStyle(isRest ? Theme.textSecondary : Theme.text)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, wide ? 8 : 4).padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if isRest {
                shape.stroke(Theme.disabledOutline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else {
                shape.fill(Entries.tone(first.pattern))
                    .overlay { if block.isChain { ChainDividers(parts: block.parts, reps: block.reps) } }
            }
        }
        .overlay {
            if selected { shape.stroke(Theme.text, lineWidth: 2).padding(1) }
            else if linked { shape.stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).padding(4) }
        }
        .overlay(alignment: .bottomLeading) {
            // the entry the track is on, while playing: a bar along the bottom
            if playing { Capsule().fill(Theme.text).frame(width: min(24, width - 8), height: 3).padding(6) }
        }
        .compositingGroup()
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
        TimelineView(.animation(paused: !session.playing)) { _ in
            let ticks = session.clockTicks
            let songTicks = (store.laneEnds.max() ?? 0) * SongPlacement.ticksPerBar
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

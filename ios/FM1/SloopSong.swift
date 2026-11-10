import SloopKit
import SwiftUI

// SLOOP's Song tab in the Skiff layout (the SLOOP design pass, 2026-11-10; boards S2–S4, design/structure-map.md "SLOOP").
// SLOOP's own model, in Skiff's patterns: four tracks each playing one 64-step loop; sections A–D, each a snapshot of all
// four; a song order of section × bars; Loop / Song mode; SONG REC. On top, Pads (the track heads, the loop now, the
// sections as tall pads) or the Timeline (the order as blocks); under the divider the selected track's editor, on the
// panel with its tab and carets, at No grid · Half · Max as Skiff's. Nothing SLOOP lacks is drawn: no pattern numbers, no
// pool, no Solo, no launch quantize (a section always starts on the next bar).

/// Loop · Song (SLOOP's song mode, SAVE + key 13) where Skiff's playback mode sits in the top bar.
struct SloopSongModeKeys: View {
    let session: DeviceSession

    var body: some View {
        let rec = session.song.songRecording
        SegmentedKeys(label: "Song mode", options: ["Loop", "Song"], selected: session.song.songMode ? 1 : 0, enabled: [!rec, !rec]) { k in
            // song mode keeps the loop: PLAY puts it aside, STOP brings it back (arranger_scene.c)
            if (k == 1) != session.song.songMode { session.toggleSongMode() }
        }
        .accessibilityHint("Loop: the tracks loop and a section you tap replaces them. Song: PLAY runs the song order, and STOP brings your loop back.")
    }
}

struct SloopSongPage: View {
    let session: DeviceSession
    let ui: EditorUI
    /// The editor's place, shared with Skiff's Song tab (one divider for the app): No grid, Half (the default) or Max.
    @AppStorage(SongPosition.key) private var storedPosition = SongPosition.half.rawValue
    @State private var placed: SongPosition?
    @State private var dragTop: CGFloat?
    @State private var dragFrom: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.grid) private var grid

    private var position: SongPosition { placed ?? SongPosition(rawValue: storedPosition) ?? .half }
    private func place(_ p: SongPosition) { placed = p; storedPosition = p.rawValue }
    private var spring: Animation? {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: Labs.dividerResponse.value, dampingFraction: Labs.dividerDamping.value)
    }
    private var slide: Animation? { reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: max(0.2, Labs.songSlide.value)) }

    static let tool: CGFloat = 44, toolGap: CGFloat = 10
    /// Half: the four heads as lane rows (42, as Skiff's), the panel's tab line under them.
    static let halfTop: CGFloat = tool + toolGap + SloopPads.labels + 4 * PadsPage.rowHeight + 3 * PadsPage.compactRowGap + 12 + PadsPage.tabHeight
    /// Max: the tool row and one row of section keys.
    static let maxTop: CGFloat = tool + 8 + 64 + 12 + PadsPage.tabHeight

    private func tops(_ total: CGFloat) -> [SongPosition: CGFloat] {
        let half = max(Self.maxTop, min(Self.halfTop, total - SkiffSongPage.editorMin))
        return [.none: total - SkiffSongPage.lip, .half: half, .max: Self.maxTop]
    }

    var body: some View {
        GeometryReader { g in
            let total = g.size.height
            let tops = tops(total)
            let top = dragTop ?? tops[position] ?? total
            let layout: SloopPadsLayout = top >= (tops[.half]! + tops[.none]!) / 2 ? .full : top > (tops[.half]! + tops[.max]!) / 2 ? .half : .row
            let bottom = max(SkiffSongPage.editorMin, total - top)
            VStack(spacing: 0) {
                VStack(spacing: Self.toolGap) {
                    toolRow
                    ZStack(alignment: .topLeading) {
                        if ui.songView == .pads {
                            SloopPads(session: session, ui: ui, layout: layout)
                                .transition(reduceMotion ? .opacity : .move(edge: .top))
                        } else {
                            ScrollView { SongPage(session: session, ui: ui, lane: true) }
                                .scrollIndicators(.hidden)
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.bottom, PadsPage.tabHeight)        // the panel's tab under the heads
                    .animation(slide, value: ui.songView)
                }
                .frame(width: g.size.width, height: top, alignment: .top)
                .mask(alignment: .bottom) { Rectangle().padding(.top, -24) }
                editorPanel(width: g.size.width, height: bottom, shown: dragTop != nil || position != .none)
            }
            .frame(height: total, alignment: .top)
            .mask(alignment: .bottom) { Rectangle().padding(.top, -24) }
            .overlay(alignment: .topLeading) { tab(top: top, tops: tops) }
        }
        .onChange(of: ui.sampler) { _, r in
            if let r, !r.fromBrowse, position == .none { withAnimation(spring) { place(.half) } }
        }
    }

    // MARK: The tool row

    private var toolRow: some View {
        HStack(spacing: 12) {
            SongViewSwitch(ui: ui).frame(height: Self.tool)
            ToggleKey(name: session.song.songRecording ? "SONG REC: recording" : "SONG REC", on: session.song.songRecording) {
                session.toggleSongRec()
            }
            .accessibilityHint("From the next bar, every section you play, and for how long, becomes the song's order")
            if let m = session.songMessage {
                Text(m).font(.lupe(13, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Capsule().fill(Theme.tones[2]))
                    .transition(.opacity)
            } else if ui.songView == .timeline, let o = session.songOrder {
                Text(orderLine(o)).font(.lupe(13)).foregroundStyle(Theme.textSecondary).lineLimit(1).monospacedDigit()
            } else if ui.songView == .pads {
                Text(hint).font(.lupe(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if ui.songView == .timeline, let o = session.songOrder {
                if session.orderWaitingForStop {
                    Text("Saves to the FM-1 when you stop").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                }
                // the order's own setting: round and round, or stop at the end
                ToggleKey(name: "Loop the song", on: o.loop, enabled: !session.song.songPlaying && !session.song.songRecording) {
                    var n = o
                    n.loop.toggle()
                    session.setSongOrder(n)
                }
                .accessibilityHint("On: the song plays round and round. Off: it stops at the end")
            }
        }
        .frame(height: Self.tool)
        .animation(.easeOut(duration: 0.15), value: session.songMessage)
    }

    /// "4 steps · 20 bars · step 2 of 4, bar 3 of 4" (as the order panel's own line).
    private func orderLine(_ o: SongOrder) -> String {
        let s = session.song
        let n = o.steps.count, bars = o.steps.reduce(0) { $0 + $1.bars }
        let at = s.songPlaying ? " · step \(s.songStep + 1) of \(n), bar \(s.songBar + 1) of \(s.songStepBars)" : ""
        return "\(n) step\(n == 1 ? "" : "s") · \(bars) bars" + (s.songRecording ? " · SONG REC" : "") + at
    }

    private var hint: String {
        return session.playing ? "Tap a section: it plays from the next bar. Hold: store, add to the song, clear."
                               : "Tap a section: it loads as the loop. Hold: store, add to the song, clear."
    }

    // MARK: The editor panel, its tab and carets (as Skiff's: SkiffSongPage)

    private func editorPanel(width: CGFloat, height: CGFloat, shown: Bool) -> some View {
        let inset = SkiffSongPage.inset
        let shape = EditorPanelShape(tab: CGSize(width: PadsPage.panelTabWidth, height: PadsPage.tabHeight), inset: 0)
        return ZStack(alignment: .top) {
            shape.fill(SelectionTint.fill(session.selectedTrack))
                .animation(.easeOut(duration: 0.15), value: session.selectedTrack)
            if shown {
                ZStack(alignment: .top) {
                    if let r = ui.sampler, !r.fromBrowse {
                        SamplerPanel(session: session, ui: ui, request: r)
                            .frame(width: max(0, width - 2 * inset))
                            .padding(inset)
                            .geometryGroup()
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                            .zIndex(1)
                    } else {
                        SloopEditorPane(session: session, ui: ui, height: height - 2 * inset)
                            .environment(\.grid, inPanel)
                            .environment(\.flatPanels, true)
                            .padding(inset)
                            .geometryGroup()
                            .transition(reduceMotion ? .opacity : .move(edge: .leading))
                            .zIndex(1)
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .mask { shape }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.9), value: ui.sampler)
    }

    private var inPanel: GridMetrics {
        var g = grid
        g.stepWidth = grid.stepWidth - 2 * SkiffSongPage.inset / 16
        return g
    }

    /// The panel's tab: tapped, the next place (No grid → Half → No grid; Max → Half); dragged, the divider, snapping to
    /// the nearest place. The carets say which way it can go. VoiceOver: an adjustable, three values.
    private func tab(top: CGFloat, tops: [SongPosition: CGFloat]) -> some View {
        let ups: [Bool] = switch position {
        case .none: [true, true, true]
        case .half: [true, false, false]
        case .max: [false, false, false]
        }
        return Button {
            guard !ui.justPulled else { return }
            let next: SongPosition = switch position { case .none: .half; case .half: .none; case .max: .half }
            withAnimation(spring) { place(next) }
        } label: {
            TabCarets(ups: ups, colour: Theme.track[session.selectedTrack])
                .frame(width: PadsPage.panelTabWidth, height: PadsPage.tabHeight)
                .contentShape(Rectangle())
                .geometryGroup()
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in
                ui.pulledAt = Date()
                if dragTop == nil { dragFrom = tops[position] ?? 0 }
                let lo = tops[.max] ?? 0, hi = tops[.none] ?? 0
                dragTop = min(hi + 24, max(lo - 24, dragFrom + v.translation.height))
            }
            .onEnded { v in
                ui.pulledAt = Date()
                guard let at = dragTop else { return }
                var p = tops.min { abs($0.value - at) < abs($1.value - at) }?.key ?? .half
                // a flick goes one place on in its direction
                if abs(v.velocity.height) > Labs.flickSpeed.value {
                    let order: [SongPosition] = [.max, .half, .none]
                    let i = order.firstIndex(of: position) ?? 1
                    p = order[v.velocity.height < 0 ? max(0, i - 1) : min(2, i + 1)]
                }
                withAnimation(spring) { place(p); dragTop = nil }
            })
        .offset(y: top - PadsPage.tabHeight)
        .accessibilityLabel("Pattern editor")
        .accessibilityValue(position == .none ? "closed" : position == .half ? "half" : "largest")
        .accessibilityHint(position == .none ? "Opens the pattern editor" : position == .half ? "Closes the pattern editor" : "Makes the pattern editor smaller")
        .accessibilityAdjustableAction { d in
            let order: [SongPosition] = [.max, .half, .none]
            let i = order.firstIndex(of: position) ?? 1
            withAnimation(spring) { place(order[d == .increment ? min(2, i + 1) : max(0, i - 1)]) }
        }
    }
}

// MARK: - The editor under the divider

/// The selected track's loop: its piano roll or drum grid, the step panel and the whole track's knobs beside it. The
/// header names the track (SLOOP has no pattern number) and carries the selection's edits.
struct SloopEditorPane: View {
    let session: DeviceSession
    let ui: EditorUI
    let height: CGFloat
    static let header: CGFloat = 44

    var body: some View {
        let t = session.selectedTrack
        let editor = max(0, height - Self.header - 12)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TrackChip(track: t, selected: true).frame(width: 28, height: 28)
                Text(Entries.trackName(t, session: session)).font(.lupe(15, .semibold)).lineLimit(1)
                Text(lengthLine(t)).font(.lupe(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                Spacer(minLength: 0)
                SelectionBar(edits: StepEdits(session: session, ui: ui, track: t,
                                              rows: session.isKit(t) ? [] : PianoRoll.rows(session.tracks[t], keeping: ui.keptRows[t] ?? [])),
                             notes: !session.isKit(t), inline: true)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            .frame(height: Self.header)
            HStack(alignment: .top, spacing: 16) {
                // the step and the whole track, as Sequence had them; scrolls when the editor is short (Half)
                ScrollView {
                    VStack(spacing: 16) {
                        SelectedStepPanel(session: session, ui: ui).flashRing(ui, .stepPanel)
                        TrackPanel(session: session, ui: ui).flashRing(ui, .trackPanel)
                    }
                }
                .scrollIndicators(.automatic)
                .frame(width: Overview.boxWidth, height: editor)
                Group {
                    if session.isKit(t) { DrumGrid(session: session, ui: ui) } else { PianoRoll(session: session, ui: ui, track: t) }
                }
                .flashRing(ui, .grid)
            }
            .environment(\.editorHeight, editor)
            .environment(\.arrangeCompact, true)
        }
    }

    private func lengthLine(_ t: Int) -> String {
        let n = session.tracks[t].length
        return "\(n) step\(n == 1 ? "" : "s")"
    }
}

// MARK: - Pads: the heads, the loop now, the sections

enum SloopPadsLayout { case full, half, row }

struct SloopPads: View {
    let session: DeviceSession
    let ui: EditorUI
    let layout: SloopPadsLayout
    @State private var pressAt: CGPoint = .zero
    @State private var held: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let gap: CGFloat = 12
    /// The line over the columns ("The loop now", "Sections") and its gap.
    static let labels: CGFloat = 20
    private var headWidth: CGFloat { layout == .full ? 300 : PadsPage.compactStrip }
    private var loopWidth: CGFloat { layout == .full ? 200 : 150 }

    var body: some View {
        GeometryReader { g in
            let rowGap = layout == .full ? PadsPage.fullRowGap : PadsPage.compactRowGap
            let rowH = layout == .full ? min(176, max(PadsPage.cardHeight, (g.size.height - 20 - 3 * rowGap) / 4)) : PadsPage.rowHeight
            let rowsH = 4 * rowH + 3 * rowGap
            VStack(alignment: .leading, spacing: 4) {
                if layout != .row {
                    HStack(spacing: Self.gap) {
                        Color.clear.frame(width: headWidth, height: 1)
                        HStack(spacing: 6) {
                            Text("The loop now").foregroundStyle(Theme.textSecondary)
                            if session.tracksEdited {
                                Text("· edited").foregroundStyle(Theme.caution).transition(.opacity)
                            }
                        }
                        .font(.lupe(12)).frame(width: loopWidth, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        Text("Sections").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(height: 16)
                    .animation(.easeOut(duration: 0.15), value: session.tracksEdited)
                }
                HStack(alignment: .top, spacing: Self.gap) {
                    if layout != .row {
                        VStack(spacing: rowGap) {
                            ForEach(session.trackIndices, id: \.self) { t in
                                SloopHead(session: session, ui: ui, track: t, compact: layout != .full).frame(height: rowH)
                            }
                        }
                        .frame(width: headWidth)
                        VStack(spacing: rowGap) {
                            ForEach(session.trackIndices, id: \.self) { t in
                                SloopLoopCell(session: session, track: t).frame(height: rowH)
                            }
                        }
                        .frame(width: loopWidth)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("The loop now\(session.tracksEdited ? ", edited since the last section was stored or loaded" : "")")
                    }
                    HStack(spacing: Self.gap) {
                        ForEach(0..<4, id: \.self) { k in sectionPad(k) }
                    }
                    .frame(height: layout == .row ? 64 : rowsH)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9), value: layout)
            }
        }
        // -section-menu B: opens that section's hold menu (screenshots, as -sound-panel does for the panel)
        .task {
            let a = LaunchArgs.all
            guard let i = a.firstIndex(of: "-section-menu"), i + 1 < a.count, let k = ["A", "B", "C", "D"].firstIndex(of: a[i + 1]) else { return }
            try? await Task.sleep(for: .seconds(1.5))
            menu(k, at: CGPoint(x: 760 + CGFloat(k) * 260, y: 330))
        }
    }

    // MARK: A section

    private enum State: Equatable { case empty, stored, loaded, playing, edited, nextBar, songNext, song, recording }

    private func state(_ k: Int) -> State {
        let s = session.song
        if s.sectionPlaying == k {
            if s.songRecording, session.playing { return .recording }
            if s.songPlaying { return .song }
            if session.tracksEdited { return .edited }
            return session.playing ? .playing : .loaded
        }
        if s.sectionQueued == k { return .nextBar }
        if s.songPlaying, let o = session.songOrder, !o.steps.isEmpty {
            let n = s.songStep + 1
            let next = n < o.steps.count ? n : (o.loop ? 0 : nil)
            if let next, o.steps[next].section == k { return .songNext }
        }
        return s.stored(k) ? .stored : .empty
    }

    private func label(_ st: State) -> String {
        switch st {
        case .empty: "empty"
        case .stored: "stored"
        case .loaded: "loaded"
        case .playing: "playing"
        case .edited: "edited"
        case .nextBar: "next bar"
        case .songNext: "next"
        case .song: "song"
        case .recording: "recording"
        }
    }

    private func inTracks(_ st: State) -> Bool { [.loaded, .playing, .edited, .song, .recording].contains(st) }

    private func sectionPad(_ k: Int) -> some View {
        let st = state(k)
        let lit = inTracks(st)
        let colour = Theme.track[k]
        let compact = layout != .full
        let name = DeviceSession.sectionName(k)
        return Button {
            if held == k { held = nil; return }
            tap(k)
        } label: {
            Group {
                if layout == .row {
                    // one row over the largest editor: the letter and its word side by side, the bar under them
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(name).font(.lupeNumber(30, .bold))
                        Text(label(st)).font(.lupe(13, st == .nextBar || lit ? .semibold : .regular)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.lupeNumber(compact ? 30 : 64, .bold))
                        Text(label(st)).font(.lupe(13, st == .nextBar || lit ? .semibold : .regular)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
            .foregroundStyle(lit ? Theme.onColour : st == .empty ? Theme.textTertiary : Theme.text)
            .padding(.leading, st == .empty || lit ? 14 : 18).padding(.top, compact ? 6 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { face(st, colour: colour) }
            .overlay { outline(st) }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: st)
        }
        .buttonStyle(PressSink())
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { pressAt = $0.location })
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in held = k; menu(k, at: pressAt) })
        .accessibilityLabel("Section \(name)")
        .accessibilityValue(st == .nextBar ? "starts on the next bar" : st == .songNext ? "next in the song" : label(st))
        .accessibilityHint(session.song.stored(k) ? (session.playing ? "Plays from the next bar" : "Loads it as the loop") : "Empty")
        .accessibilityAction(named: "Section menu") { menu(k, at: .zero) }
    }

    @ViewBuilder private func face(_ st: State, colour: Color) -> some View {
        let r = RoundedRectangle(cornerRadius: 12)
        if inTracks(st) {
            r.fill(colour).overlay(alignment: .bottom) {
                if session.playing { BarProgress(session: session).padding(.horizontal, 12).padding(.bottom, 12) }
            }
        } else if st == .empty {
            r.fill(Theme.well).overlay(r.strokeBorder(Theme.control, lineWidth: 1))
        } else {
            // stored: the control grey, its colour as the band down its edge (the lanes' band, board 41)
            r.fill(Theme.control).overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12).fill(colour).frame(width: 6)
            }
        }
    }

    /// Waiting (asked for, lands on the next bar): the pads' waiting outline, traced round as the bar runs out. The song's
    /// next: a thin grey line. Reduce Motion: drawn whole.
    @ViewBuilder private func outline(_ st: State) -> some View {
        if st == .nextBar {
            TimelineView(.animation(paused: !session.playing || reduceMotion)) { tl in
                let f = session.playing && !reduceMotion ? BarProgress.fraction(session, tl.date) : 1
                ZStack {
                    RoundedRectangle(cornerRadius: 16).stroke(Theme.text.opacity(0.25), lineWidth: 2)
                    RoundedRectangle(cornerRadius: 16).trim(from: 0, to: f).stroke(Theme.text, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .padding(-4)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        } else if st == .songNext {
            RoundedRectangle(cornerRadius: 16).stroke(Theme.textSecondary, lineWidth: 1).padding(-4).allowsHitTesting(false)
        }
    }

    // MARK: Tap and hold

    private func tap(_ k: Int) {
        // in loop mode a section replaces the tracks and SLOOP keeps no copy: with edits, ask by the finger
        if session.tracksEdited, session.song.stored(k), !session.song.songMode, !session.song.songPlaying {
            let name = DeviceSession.sectionName(k)
            var items: [MenuItem] = [.note("Load \(name) over the tracks? They have changes that aren't in a section, and the FM-1 keeps no copy.")]
            if let e = (0..<4).first(where: { !session.song.stored($0) }) {
                items.append(MenuItem(title: "Store them in \(DeviceSession.sectionName(e)) first", icon: "square.and.arrow.down") {
                    session.storeLoop(in: e)
                    session.playSection(k)
                })
            }
            items.append(MenuItem(title: "Load \(name), replacing them", icon: "arrow.uturn.down") { session.playSection(k) })
            ui.menu = AppMenu(title: "Section \(name)", groups: { [items, [MenuItem(title: "Keep my tracks", icon: "xmark") {}]] },
                              at: pressAt, fan: true)
        } else {
            session.playSection(k)
        }
    }

    /// Held: store the loop here, add the section to the song, clear it. Each that loses work asks in its own row
    /// (DESIGN.md: the destructive confirm in place).
    private func menu(_ k: Int, at: CGPoint) {
        let name = DeviceSession.sectionName(k)
        let stored = session.song.stored(k)
        let order = session.songOrder
        let inSong = order?.steps.contains { $0.section == k } ?? false
        let canAdd = order != nil && (order?.steps.count ?? 16) < SongOrder.maxSteps && !session.song.songPlaying && !session.song.songRecording
        let store: MenuItem = stored
            ? .destructive(title: "Store the loop here", icon: "square.and.arrow.down",
                           confirm: "Replace section \(name) with the loop now (the FM-1 keeps no copy of \(name))") { session.storeLoop(in: k) }
            : MenuItem(title: "Store the loop here", icon: "square.and.arrow.down") { session.storeLoop(in: k) }
        var items = [store,
                     MenuItem(title: "Add to the song", icon: "text.append", enabled: canAdd) { add(k) }]
        if stored {
            items.append(.destructive(title: session.playing ? "Clear (stop first)" : "Clear section \(name)", enabled: !session.playing,
                                      confirm: "Clear section \(name), erasing it" + (inSong ? " (the song won't play until it holds tracks again)" : "")) {
                session.clearSection(k)
            })
        }
        let where_ = at == .zero ? CGPoint(x: 700 + CGFloat(k) * 160, y: 300) : at
        ui.menu = AppMenu(title: "Section \(name)" + (stored ? "" : " · empty"), groups: { [items] }, at: where_, fan: true)
    }

    private func add(_ k: Int) {
        guard let o = session.songOrder?.appending(section: k) else { return }
        session.setSongOrder(o)
    }
}

/// The bar running, as a capsule filling: SLOOP reports no bar count in loop mode, so the bar is track 1's playhead at
/// four beats a bar (as the top bar's bar · step).
struct BarProgress: View {
    let session: DeviceSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func fraction(_ session: DeviceSession, _ date: Date, interpolate: Bool = true) -> Double {
        let div = session.tracks[0].division
        let beats = Music.divisionBeats.indices.contains(div) ? Music.divisionBeats[div] : 0.25
        let perBar = max(1, 4 / beats)
        let p = session.playhead(track: 0, at: date, interpolate: interpolate)
        return p.truncatingRemainder(dividingBy: perBar) / perBar
    }

    var body: some View {
        TimelineView(.animation(paused: !session.playing || reduceMotion)) { tl in
            GeometryReader { g in
                Capsule().fill(Theme.onColour.opacity(0.22))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.onColour.opacity(0.85)).frame(width: max(6, g.size.width * Self.fraction(session, tl.date, interpolate: !reduceMotion)))
                    }
            }
            .frame(height: 5)
        }
        .accessibilityHidden(true)
    }
}

/// A track's head (board 43's H1, SLOOP's): the number, the sound's name as the way into the sounds panel, its chord or
/// arpeggio, where the loop is, and Mute. No Solo: SLOOP has none, so none is drawn. Tap: select; hold: the track menu.
struct SloopHead: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let compact: Bool

    var body: some View {
        let t = track
        let tr = session.tracks[t]
        let selected = session.selectedTrack == t
        let muted = tr.mute
        HStack(alignment: compact ? .center : .top, spacing: 8) {
            Button { session.select(track: t) } label: {
                HStack(alignment: compact ? .center : .top, spacing: compact ? 8 : 10) {
                    BigTrackChip(track: t, muted: muted, side: compact ? 30 : 44)
                    VStack(alignment: .leading, spacing: compact ? 0 : 4) {
                        SoundName(session: session, track: t, size: compact ? 14 : 17, weight: .semibold,
                                  colour: muted ? Theme.textSecondary : Theme.text)
                            .opacity(0)
                            .anchorPreference(key: SoundNameAnchor.self, value: .bounds) { $0 }
                        if !compact {
                            if let tag = tag(tr) {
                                Text(tag).font(.lupe(11, .semibold)).foregroundStyle(Theme.text)
                                    .padding(.horizontal, 6).frame(height: 20)
                                    .background(Capsule().fill(Theme.track[t].opacity(0.28)))
                            }
                            Spacer(minLength: 0)
                            if session.playing, !muted {
                                SmoothBar(track: Theme.well, ink: Theme.track[t]) { loopFraction(t) }.frame(height: 4)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(compact ? 6 : 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlayPreferenceValue(SoundNameAnchor.self) { a in
                SoundNameKey(session: session, ui: ui, track: t, anchor: a, size: compact ? 14 : 17, weight: .semibold,
                             colour: muted ? Theme.textSecondary : Theme.text)
            }
            .trackMenuPress(session: session, ui: ui, track: t)
            .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))\(selected ? ", selected" : "")")
            .accessibilityValue(tag(tr) ?? "")
            .accessibilityHint(selected ? "" : "Selects it: the editor and the FM-1's knobs follow")
            Button { session.toggleMute(track: t) } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: compact ? 15 : 18, weight: .semibold))
                    .foregroundStyle(muted ? Theme.onColour : Theme.text)
                    .frame(width: 44, height: compact ? 32 : 44)
                    .background { HeadKeySurface(on: muted, onColour: Theme.text) }
                    .contentShape(Rectangle())
                    .animation(.easeOut(duration: 0.15), value: muted)
            }
            .buttonStyle(PressSink())
            .padding(compact ? 5 : 12)
            .accessibilityLabel("Mute track \(t + 1)")
            .accessibilityValue(muted ? "muted" : "playing")
        }
        .background {
            RoundedRectangle(cornerRadius: 12).fill(selected ? Theme.tones[2] : Theme.panel)
                .overlay { if selected { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.text, lineWidth: 2) } }
                .animation(.easeOut(duration: 0.15), value: selected)
        }
        .accessibilityElement(children: .contain)
    }

    /// What the track's notes become: a chord or an arpeggio (as the track box's tags).
    private func tag(_ tr: TrackState) -> String? {
        guard !session.isDrums(track) else { return nil }
        if tr.arpMode > 0 { return "ARP " + (Music.arpModes[safe: tr.arpMode] ?? "") }
        if tr.chord > 0 { return Music.chordNames[safe: tr.chord] ?? "CHORD" }
        return nil
    }

    private func loopFraction(_ t: Int) -> Double {
        let len = max(1, Double(session.tracks[t].length))
        return session.playhead(track: t, at: .now).truncatingRemainder(dividingBy: len) / len
    }
}

/// The working loop of one track: its steps as cells (on in its colour), up to 64 in four rows of 16, with the playhead.
struct SloopLoopCell: View {
    let session: DeviceSession
    let track: Int

    var body: some View {
        let tr = session.tracks[track]
        Canvas { ctx, size in
            let cols = 16, rows = 4
            let gap: CGFloat = 2
            let w = (size.width - CGFloat(cols - 1) * gap) / CGFloat(cols)
            let h = min(10, (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows))
            let y0 = (size.height - (CGFloat(rows) * h + CGFloat(rows - 1) * gap)) / 2
            for i in 0..<min(64, tr.steps.count) {
                let r = CGRect(x: CGFloat(i % cols) * (w + gap), y: y0 + CGFloat(i / cols) * (h + gap), width: w, height: h)
                let on = i < tr.length && tr.isOn(i)
                let c: Color = i >= tr.length ? Theme.stepOutside : on ? Theme.track[track] : Theme.stepEmpty
                ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(c.opacity(tr.mute ? 0.45 : 1)))
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
        .accessibilityElement()
        .accessibilityLabel("Track \(track + 1) loop")
        .accessibilityValue("\(tr.length) steps, \((0..<min(tr.length, tr.steps.count)).filter { tr.isOn($0) }.count) with notes")
    }
}

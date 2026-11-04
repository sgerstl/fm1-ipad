import SloopKit
import SwiftUI
import UIKit

/// The song, as SLOOP holds it (GUIDE §14): four sections A–D (each a whole loop of the four tracks),
/// played live or in a song order of up to 16 steps; loop / song mode; SONG REC. Sections take the
/// track colours, as on the FM-1 (ui_layers.c: TE_COL[section]). The section keys sit right above the
/// song, so the parts and their order read as one thing.

/// Left column, under the track box: loop or song mode.
struct SongModePanel: View {
    let session: DeviceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            SegmentedKeys(label: "Mode", options: ["Loop", "Song"], selected: session.song.songMode ? 1 : 0) { k in
                // song mode keeps the loop: PLAY puts it aside, STOP brings it back (arranger_scene.c)
                if (k == 1) != session.song.songMode { session.toggleSongMode() }
            }
            Text(session.song.songMode ? "PLAY runs the song. STOP brings your loop back."
                                       : "The tracks loop. A section you tap replaces them.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}

/// A section's menu, by the finger: held, replace it or clear it (clearing asked again); tapped over
/// edited tracks, whether to load it over them.
struct SectionMenu: Equatable {
    enum Mode { case manage, confirmClear, confirmLoad }
    var section: Int
    var at: CGPoint
    var mode = Mode.manage
}

/// Above the song: the four sections as keys in a row, and SONG REC, which records what they play.
struct SectionsPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    /// Where the finger is on a key: a held stored section opens its menu there.
    @State private var pressAt = CGPoint.zero
    @State private var confirmRec = false
    /// The key just held: its release isn't a tap (a tap loads the section, over the tracks being saved).
    @State private var held: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Sections").font(.system(size: 17, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(session.playing ? "Tap: plays from the next bar, over the tracks. Hold: save the tracks here."
                                     : "Tap: loads it over the tracks. Hold: save the tracks here.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                ToggleKey(name: session.song.songRecording ? "SONG REC: recording" : "SONG REC", on: session.song.songRecording) {
                    // what SONG REC records replaces the whole order: ask when there is one
                    if !session.song.songRecording, !(session.songOrder?.steps.isEmpty ?? true) { confirmRec = true } else { session.toggleSongRec() }
                }
                .accessibilityHint("From the next bar, every section you play, and how long, becomes the song")
            }
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { k in sectionKey(k) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .confirmationDialog("SONG REC replaces the song", isPresented: $confirmRec, titleVisibility: .visible) {
            Button("Record over the song", role: .destructive) { session.toggleSongRec() }
            Button("Keep the song", role: .cancel) {}
        } message: {
            Text("The sections you play, and for how long, become the song's order. Its \(session.songOrder?.steps.count ?? 0) steps now are replaced, and the FM-1 keeps no copy.")
        }
    }

    /// What a section key shows: one state per key, each with a look and a word (never colour alone).
    /// Only one section is in the tracks at a time, so loaded, playing, edited, song and recording are
    /// one key's; next bar is another's.
    enum KeyState: Equatable {
        case empty, stored, loaded, playing, edited, nextBar, song, recording

        var label: String {
            switch self {
            case .empty: "empty · hold to save"
            case .stored: "stored"
            case .loaded: "loaded"
            case .playing: "playing"
            case .edited: "edited · hold to save"
            case .nextBar: "next bar"
            case .song: "song"
            case .recording: "recording"
            }
        }
        /// In the tracks now: the key is lit in its colour.
        var inTracks: Bool { [.loaded, .playing, .edited, .song, .recording].contains(self) }
        /// Sounding: a pill along the bottom fills through the bar.
        var sounding: Bool { [.playing, .song, .recording].contains(self) }
    }

    private func keyState(_ k: Int) -> KeyState {
        let s = session.song
        if s.sectionPlaying == k {
            if s.songRecording, session.playing { return .recording }
            if s.songPlaying { return .song }
            // the tracks changed since this section came in: picking another would lose that
            if session.tracksEdited { return .edited }
            return session.playing ? .playing : .loaded
        }
        if s.sectionQueued == k { return .nextBar }
        return s.stored(k) ? .stored : .empty
    }

    /// How far through the bar the FM-1 is, from track 1's playhead at 4 beats a bar (as the top bar's
    /// bar · step). SLOOP reports the song's bar only while a song plays, so this is the bar line in loop mode too.
    private func barFraction(_ date: Date) -> Double {
        let div = session.tracks[0].division
        let beats = Music.divisionBeats.indices.contains(div) ? Music.divisionBeats[div] : 0.25
        let perBar = max(1, 4 / beats)
        let p = session.playhead(track: 0, at: date, interpolate: !reduceMotion)
        return p.truncatingRemainder(dividingBy: perBar) / perBar
    }

    private func sectionKey(_ k: Int) -> some View {
        let state = keyState(k)
        let stored = session.song.stored(k)
        let colour = Theme.track[k]
        return Button {
            if held == k { held = nil; return }
            // a section picked in loop mode replaces the tracks (now, or on the next bar)
            // in loop mode a section replaces the tracks and SLOOP keeps no copy: with edits, ask by the finger
            if session.tracksEdited, stored, !session.song.songMode {
                ui.sectionMenu = SectionMenu(section: k, at: pressAt, mode: .confirmLoad)
            } else {
                session.playSection(k)
            }
        } label: {
            VStack(spacing: 2) {
                Text(DeviceSession.sectionName(k)).font(.system(size: 30, weight: .semibold))
                Text(state.label).font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(state.inTracks ? Theme.onColour : state == .empty ? Theme.textTertiary : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background { keyFace(state, colour: colour, k: k) }
            .overlay(alignment: .topTrailing) { keyBadge(state) }
            .overlay { if state == .nextBar { nextBarOutline(colour) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
            .onChanged { pressAt = $0.location })
        // hold: an empty section takes the tracks at once; a stored one offers replace or clear, by the finger
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            held = k
            if stored { ui.sectionMenu = SectionMenu(section: k, at: pressAt) } else { session.storeLoop(in: k) }
        })
        .accessibilityLabel("Section \(DeviceSession.sectionName(k))")
        .accessibilityValue(state == .nextBar ? "starts on the next bar" : state.label)
        .accessibilityHint(stored ? (session.playing ? "Plays from the next bar" : "Loads it as the loop") : "Empty: hold to store the loop here")
        .accessibilityAction(named: stored ? "Replace or clear" : "Store the loop here") {
            if stored { ui.sectionMenu = SectionMenu(section: k, at: CGPoint(x: 560 + CGFloat(k) * 220, y: 140)) } else { session.storeLoop(in: k) }
        }
    }

    @ViewBuilder
    private func keyFace(_ state: KeyState, colour: Color, k: Int) -> some View {
        if state.inTracks {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [look.flat ? colour : Theme.trackTop[k], colour], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottom) {
                    if state.sounding || (state == .edited && session.playing) {
                        // the bar passing, as the song blocks' pills
                        TimelineView(.animation(paused: !session.playing || reduceMotion)) { tl in
                            GeometryReader { g in
                                Capsule().fill(Theme.onColour.opacity(0.22))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Theme.onColour.opacity(0.8))
                                            .frame(width: max(6, g.size.width * barFraction(tl.date)))
                                    }
                            }
                            .frame(height: 6)
                        }
                        .padding(.horizontal, 18).padding(.bottom, 8)
                    }
                }
        } else if state == .empty {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        } else {
            // stored (and next bar, which is stored): the colour dim, its line along the bottom
            RoundedRectangle(cornerRadius: 12).fill(colour.opacity(0.22))
                .overlay(alignment: .bottom) { Capsule().fill(colour).frame(height: 3).padding(.horizontal, 18).padding(.bottom, 8) }
        }
    }

    @ViewBuilder
    private func keyBadge(_ state: KeyState) -> some View {
        switch state {
        case .edited:
            Circle().fill(Theme.onColour).frame(width: 8, height: 8).padding(10)
        case .song:
            Text("SONG").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Theme.onColour.opacity(0.85)))
                .padding(8)
        case .recording:
            HStack(spacing: 4) {
                Circle().fill(Color(hex: 0xFF2C34)).frame(width: 8, height: 8)
                Text("REC").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Theme.onColour.opacity(0.85)))
            .padding(8)
        default:
            EmptyView()
        }
    }

    /// Next bar: an outline in the section's own colour, drawn round as the bar runs out.
    private func nextBarOutline(_ colour: Color) -> some View {
        TimelineView(.animation(paused: !session.playing || reduceMotion)) { tl in
            let f = session.playing ? barFraction(tl.date) : 1
            ZStack {
                RoundedRectangle(cornerRadius: 15).stroke(colour.opacity(0.3), lineWidth: 2)
                RoundedRectangle(cornerRadius: 15).trim(from: 0, to: reduceMotion ? 1 : f).stroke(colour, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .padding(-4)
        }
    }
}

/// The main area: the section keys, then the song order as blocks you handle directly. Tap a block for
/// its menu (move, section, duplicate, delete) and its bars; press and drag to move it; flick it up to
/// delete it (Undo brings it back); drag its right edge to change its bars. The blocks
/// wrap onto more rows at the panel's edge. One view tree, one animation: the menu, the bars and the
/// blocks always move together.
struct SongPage: View {
    let session: DeviceSession
    let ui: EditorUI
    /// The phone's Arrange (2026-11-04): shorter blocks, the mode under the song, the page scrolls,
    /// and no flick-to-delete (too easy to set off on a phone; Delete is in the block's menu).
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.look) private var look

    /// A step in the order, with an identity that survives moves (two blocks can hold the same step).
    struct Slot: Identifiable, Equatable {
        var id = UUID()
        var step: SongOrder.Step
    }

    /// The finger on a block, from touch-down to lift.
    struct Press: Equatable {
        enum Mode { case undecided, lifted, swipe, resize, ignored }
        let id: UUID
        var mode: Mode
        var dx: CGFloat = 0, dy: CGFloat = 0
        let startBars: Int
        let startMid: CGPoint
        let start: CGPoint                  // where the finger came down: a new touch starts elsewhere
    }

    struct Undo: Equatable {
        let id = UUID()
        let slots: [Slot]
        let text: String
    }

    /// Where each slot sits (row coordinates), rows wrapping at the panel's width.
    struct Layout {
        var x: [CGFloat], y: [CGFloat], w: [CGFloat]
        var add: CGPoint?
        var height: CGFloat
        var blockHeight = SongPage.blockHeight
        func mid(_ i: Int) -> CGPoint { CGPoint(x: x[i] + w[i] / 2, y: y[i] + blockHeight / 2) }
    }

    @State private var slots: [Slot] = []
    @State private var loopDraft: Bool?
    @State private var draft: SongOrder?
    @State private var saving = false
    @State private var menu: UUID?
    @State private var press: Press?
    @State private var undo: Undo?
    /// Held while a menu is open or an edge is dragged, so changing one block's bars doesn't rescale the row under the finger.
    @State private var frozenUnit: CGFloat?
    @State private var rowWidth: CGFloat = 900
    @State private var pageWidth: CGFloat = 700        // compact: the scrolling page's width
    /// When the bar playing began, as the iPad saw it: the pills fill from it at the song's tempo.
    @State private var barStart = Date()

    /// The section keys' measures above (10 between keys, the panel's 16 padding, radius 12), so the
    /// song's edges and gaps line up with theirs. Blocks no narrower than 120: near square, room for the pills.
    static let blockHeight: CGFloat = 140, addWidth: CGFloat = 64, minBlock: CGFloat = 120
    static let gap: CGFloat = 10, rowGap: CGFloat = 10, inset: CGFloat = 0, hintRow: CGFloat = 44
    static let rowsSpace = "songRows"
    /// Points per bar: the song fills the row's width when it fits on one, never under 30 (then the blocks wrap).
    static let minUnit: CGFloat = 30
    private var blockHeight: CGFloat { compact ? 96 : Self.blockHeight }
    private var addWidth: CGFloat { compact ? 44 : Self.addWidth }
    private var minBlock: CGFloat { compact ? 72 : Self.minBlock }
    private var minUnit: CGFloat { compact ? 16 : Self.minUnit }
    private var barsWidth: CGFloat { compact ? 420 : BarsControl.width }

    private var steps: [SongOrder.Step] { slots.map(\.step) }
    private var loop: Bool { loopDraft ?? session.songOrder?.loop ?? false }
    private var editable: Bool { !session.song.songPlaying && !session.song.songRecording }
    /// A spring keeps its speed when a new tap retargets it mid-move, where an ease restarts from rest.
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86) }

    var body: some View {
        Group {
            if compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionsPanel(session: session, ui: ui)
                        orderPanel.zIndex(1)                    // a block's bars popup reaches over the mode below
                        SongModePanel(session: session)
                    }
                    .frame(width: max(0, pageWidth))           // the screen's width: the song's rows wrap to it
                }
                .scrollIndicators(.hidden)
                .frame(minWidth: 0, maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    SectionsPanel(session: session, ui: ui)
                    orderPanel
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: sync)
        .onChange(of: session.songOrder) { _, _ in sync() }
        .onChange(of: editable) { _, ok in if !ok { setMenu(nil); press = nil } }
        .onChange(of: [session.song.songStep, session.song.songBar, session.song.songPlaying ? 1 : 0]) { _, _ in barStart = .now }
        // save a second after the last change: every save writes the FM-1's flash
        .task(id: draft) {
            guard let d = draft else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, d == draft else { return }
            saving = true
            session.setSongOrder(d)
            try? await Task.sleep(for: .milliseconds(400))
            saving = false
            guard !Task.isCancelled else { return }
            draft = nil
            loopDraft = nil
            sync()
        }
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { undo = nil }
        }
    }

    // MARK: The order

    private var orderPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Song").font(.system(size: 22, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(position(session.song)).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).monospacedDigit()
                Spacer()
                if session.orderWaitingForStop {
                    Text("Saves to the FM-1 when you stop").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                } else if saving || draft != nil {
                    Text("Saving to the FM-1…").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                ToggleKey(name: "Loop the song", on: loop, enabled: editable) {
                    loopDraft = !loop
                    commit()
                }
            }
            if let m = session.songMessage {
                Text(m).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            arrangement(width: rowWidth)
                // minWidth 0: without it the frame is never narrower than the rows it holds, so the rows
                // could only grow (the phone stayed at the first guess, 900 pt, 2026-11-04)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        }
        .padding(16)
        .panel()
    }

    private func position(_ s: SongState) -> String {
        let n = steps.count
        let bars = steps.reduce(0) { $0 + $1.bars }
        let mode = s.songRecording ? "SONG REC" : s.songMode ? (s.songPlaying ? "song playing" : "song mode") : "loop mode"
        let where_ = s.songPlaying ? " · step \(s.songStep + 1) of \(n), bar \(s.songBar + 1) of \(s.songStepBars)" : ""
        return "\(n) step\(n == 1 ? "" : "s") · \(bars) bars · \(mode)\(where_)"
    }

    /// The menu above the rows, the blocks, the bars control below. The menu and bars bands keep their
    /// height, so opening a menu never moves a block.
    private func arrangement(width: CGFloat) -> some View {
        let u = unit(for: width)
        let lay = layout(unit: u, width: width)
        return VStack(alignment: .leading, spacing: 0) {
            hintRow(width: width)
            rows(lay: lay, unit: u, width: width)
                .frame(width: width, height: lay.height + 16, alignment: .topLeading)
        }
        // an edge being dragged follows the finger; everything else springs, all in one transaction
        .transaction { if press?.mode == .resize { $0.animation = nil } }
        .animation(motion, value: slots)
        .animation(motion, value: menu)
        .animation(motion, value: frozenUnit)
        .animation(motion, value: press?.id)
        .animation(motion, value: press?.mode)
        .animation(motion, value: undo)
    }

    private func unit(for width: CGFloat) -> CGFloat {
        if let f = frozenUnit { return f }
        let bars = steps.reduce(0) { $0 + $1.bars }
        let fixed = Self.inset * 2 + addWidth + Self.gap * CGFloat(slots.count)
        return max(minUnit, (width - fixed) / CGFloat(max(bars, 1)))
    }

    private func widths(unit u: CGFloat, width: CGFloat) -> [CGFloat] {
        slots.map { min(width - Self.inset * 2, max(minBlock, CGFloat($0.step.bars) * u)) }
    }

    /// Left to right, a new row when the next block wouldn't fit.
    private func flow(_ ws: [CGFloat], width: CGFloat, add: Bool) -> Layout {
        var x: [CGFloat] = [], y: [CGFloat] = []
        var cx = Self.inset, cy: CGFloat = 0
        let pitch = blockHeight + Self.rowGap
        for w in ws {
            if cx > Self.inset, cx + w > width - Self.inset { cx = Self.inset; cy += pitch }
            x.append(cx); y.append(cy)
            cx += w + Self.gap
        }
        var addAt: CGPoint?
        if add {
            if cx > Self.inset, cx + addWidth > width - Self.inset { cx = Self.inset; cy += pitch }
            addAt = CGPoint(x: cx, y: cy)
        }
        return Layout(x: x, y: y, w: ws, add: addAt, height: cy + blockHeight, blockHeight: blockHeight)
    }

    private func layout(unit u: CGFloat, width: CGFloat) -> Layout {
        flow(widths(unit: u, width: width), width: width, add: slots.count < SongOrder.maxSteps)
    }

    private func rows(lay: Layout, unit u: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle()).onTapGesture { setMenu(nil) }
            ForEach(Array(slots.enumerated()), id: \.element.id) { i, slot in
                slotView(i, slot, lay: lay, unit: u, width: width)
                    .zIndex(press?.id == slot.id ? 1 : 0)
            }
            if let at = lay.add {
                Button {
                    change { $0.append(Slot(step: .init(section: steps.last?.section ?? 0, bars: 4))) }
                    setMenu(slots.last?.id)
                } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                        .frame(width: addWidth, height: blockHeight).raisedKey(12)
                }
                .buttonStyle(PressSink())
                .disabled(!editable)
                .accessibilityLabel("Add a step")
                .offset(x: at.x, y: at.y + 8)
            }
            // the tapped block's menu just above it and its bars just below, over whatever is there
            if let id = menu, let i = slots.firstIndex(where: { $0.id == id }) {
                menuBar(i)
                    .offset(x: anchor(i, lay: lay, width: width, popup: 470), y: lay.y[i] + 8 - 56 - 10)
                    .zIndex(10)
                    .transition(.opacity)
                BarsControl(bars: slots[i].step.bars, enabled: editable) { b in
                    if let k = slots.firstIndex(where: { $0.id == id }) { change(refit: false) { $0[k].step.bars = b } }
                }
                .frame(width: barsWidth)
                .offset(x: anchor(i, lay: lay, width: width, popup: barsWidth), y: lay.y[i] + 8 + blockHeight + 10)
                .zIndex(10)
                .transition(.opacity)
            }
        }
        // drags are measured here, not on the block that moves under the finger (that made it shake)
        .coordinateSpace(name: Self.rowsSpace)
    }

    @ViewBuilder
    private func slotView(_ i: Int, _ slot: Slot, lay: Layout, unit u: CGFloat, width: CGFloat) -> some View {
        let p = press?.id == slot.id ? press : nil
        let lifted = p?.mode == .lifted
        let w = lay.w[i]
        // a lifted block sits under the finger; the rest sit in their places
        let at: CGPoint = lifted
            ? CGPoint(x: p!.startMid.x + p!.dx - w / 2, y: p!.startMid.y + p!.dy - blockHeight / 2)
            : CGPoint(x: lay.x[i], y: lay.y[i] + (p?.mode == .swipe ? min(0, p!.dy) : 0))
        slotFace(i, slot, width: w, lifted: lifted)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.rowsSpace))
                .onChanged { v in pressChanged(slot, index: i, value: v, width: w, unit: u, lay: lay, rowWidth: width) }
                .onEnded { v in pressEnded(slot, value: v) })
            .modifier(SlotAccessibility(page: self, i: i, slot: slot))
            .offset(x: at.x, y: at.y + 8)
            .transaction { if p != nil { $0.animation = nil } }       // the block under the finger follows it exactly
            .transition(.asymmetric(insertion: .opacity,
                                    removal: reduceMotion ? .opacity : .offset(y: -240).combined(with: .opacity)))
    }

    /// The block itself, with its lift.
    private func slotFace(_ i: Int, _ slot: Slot, width w: CGFloat, lifted: Bool) -> some View {
        block(i, slot.step, width: w, open: menu == slot.id)
        // the lift itself springs even while the block follows the finger (flat: elevation 3's scale and shadow)
        .animation(motion) {
            $0.scaleEffect(lifted ? (look.flat ? (reduceMotion ? 1 : 1.03) : 1.04) : 1)
                .shadow(color: .black.opacity(lifted ? (look.flat ? look.shadow(.held).opacity : 0.55) : 0),
                        radius: lifted ? (look.flat ? look.shadow(.held).radius : 12) : 0,
                        y: lifted ? (look.flat ? look.shadow(.held).y : 6) : 0)
        }
        .contentShape(Rectangle())
    }

    /// A block for VoiceOver and keyboards: a button that opens its menu, with the moves as actions.
    struct SlotAccessibility: ViewModifier {
        let page: SongPage, i: Int, slot: Slot
        func body(content: Content) -> some View {
            let open = page.menu == slot.id
            let st = slot.step
            let label = "Step \(i + 1), section \(DeviceSession.sectionName(st.section)), \(st.bars) bar\(st.bars == 1 ? "" : "s")"
            return content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(open ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint(page.editable ? "Opens its menu" : "Stop the song to change it")
                .accessibilityAction { if page.editable { page.toggleMenu(slot.id) } }
                .accessibilityAction(named: "Move earlier") { page.move(i, by: -1) }
                .accessibilityAction(named: "Move later") { page.move(i, by: 1) }
                .accessibilityAction(named: "Delete") { page.delete(i) }
        }
    }

    private func block(_ n: Int, _ step: SongOrder.Step, width w: CGFloat, open: Bool) -> some View {
        let s = session.song
        let live = s.songPlaying && s.songStep == n
        return VStack(alignment: .leading, spacing: 2) {
            Text(DeviceSession.sectionName(step.section)).font(.system(size: 22, weight: .semibold))
            Text(live ? "bar \(s.songBar + 1) of \(step.bars)" : "\(step.bars) bar\(step.bars == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            if live {
                // the bar playing fills at the tempo (4 beats a bar, as SLOOP counts them), beat by beat with Reduce Motion
                TimelineView(.animation(minimumInterval: reduceMotion ? 60 / Double(max(session.bpm, 20)) : nil)) { tl in
                    BarPills(count: step.bars, played: Double(s.songBar) + barFraction(at: tl.date), width: w - 20)
                }
            } else {
                BarPills(count: step.bars, played: s.songPlaying && n < s.songStep ? Double(step.bars) : 0, width: w - 20)
            }
        }
        .foregroundStyle(Theme.onColour)
        .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 10)
        .frame(width: w, height: blockHeight, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Theme.pad(step.section, flat: look.flat)))
        // the edge you drag for length
        .overlay(alignment: .trailing) {
            Capsule().fill(Theme.onColour.opacity(0.35)).frame(width: 4, height: 28).padding(.trailing, 4)
        }
        .overlay { if open { RoundedRectangle(cornerRadius: 15).stroke(Theme.text, lineWidth: 2).padding(-4) } }
    }

    /// How far through the bar playing the song is, from when the iPad saw the bar begin. Held at the
    /// end until the FM-1 reports the next bar; with Reduce Motion it moves a beat at a time.
    private func barFraction(at date: Date) -> Double {
        let bar = 240 / Double(max(session.bpm, 20))
        let f = min(max(date.timeIntervalSince(barStart) / bar, 0), 1)
        return reduceMotion ? min(1, (f * 4).rounded(.down) / 4 + 0.25) : f
    }

    // MARK: The finger on a block

    private func pressChanged(_ slot: Slot, index i: Int, value v: DragGesture.Value, width w: CGFloat, unit u: CGFloat,
                              lay: Layout, rowWidth: CGFloat) {
        // a new touch replaces whatever press was left over (a gesture cancelled without an end)
        guard var p = press, p.id == slot.id, p.start == v.startLocation else {
            // touch-down: the last 18 pt of a block is its edge; elsewhere, held still it lifts
            let grip = editable && v.startLocation.x - lay.x[i] > w - 18
            press = Press(id: slot.id, mode: !editable ? .ignored : grip ? .resize : .undecided,
                          startBars: slot.step.bars, startMid: lay.mid(i), start: v.startLocation)
            if grip { frozenUnit = u }
            if editable && !grip {
                let id = slot.id
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard press?.id == id, press?.start == v.startLocation, press?.mode == .undecided else { return }
                    press?.mode = .lifted
                    setMenu(nil)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            return
        }
        p.dx = v.translation.width
        p.dy = v.translation.height
        switch p.mode {
        case .undecided where hypot(p.dx, p.dy) > 10:
            // a quick upward flick takes the block out; any other quick move does nothing
            p.mode = !compact && slots.count > 1 && p.dy < 0 && abs(p.dy) > abs(p.dx) ? .swipe : .ignored
        case .lifted:
            reorder(slot.id, finger: CGPoint(x: p.startMid.x + p.dx, y: p.startMid.y + p.dy), ws: lay.w, width: rowWidth)
        case .resize:
            let bars = max(1, min(64, p.startBars + Int((p.dx / u).rounded())))
            if let k = slots.firstIndex(where: { $0.id == slot.id }), slots[k].step.bars != bars {
                slots[k].step.bars = bars
                commit()
            }
        default:
            break
        }
        press = p
    }

    private func pressEnded(_ slot: Slot, value v: DragGesture.Value) {
        guard let p = press, p.id == slot.id else { return }
        press = nil
        let still = hypot(p.dx, p.dy) <= 10
        switch p.mode {
        case .undecided:
            toggleMenu(slot.id)
        case .lifted where still:
            setMenu(slot.id)
        case .lifted:
            commit()
        case .swipe where p.dy < -70 || v.predictedEndTranslation.height < -220:
            if let k = slots.firstIndex(where: { $0.id == slot.id }) { delete(k) }
        case .resize:
            if menu == nil { frozenUnit = nil }
            commit()
        default:
            break
        }
    }

    /// Where the lifted block goes: the place, of all it could take, whose centre is nearest the finger.
    /// Worked out without the block itself, so the answer doesn't flip back and forth as blocks move aside.
    private func reorder(_ id: UUID, finger: CGPoint, ws: [CGFloat], width: CGFloat) {
        guard let i = slots.firstIndex(where: { $0.id == id }), ws.indices.contains(i) else { return }
        var others = ws
        let wl = others.remove(at: i)
        var best = i, bestD = CGFloat.infinity
        for t in 0...others.count {
            var trial = others
            trial.insert(wl, at: t)
            let l = flow(trial, width: width, add: false)
            let m = l.mid(t)
            let d = hypot(m.x - finger.x, (m.y - finger.y) * 1.5)      // rows count for more than columns
            if d < bestD { bestD = d; best = t }
        }
        guard best != i else { return }
        let s = slots.remove(at: i)
        slots.insert(s, at: best)
    }

    // MARK: The menu and the bars

    @ViewBuilder
    /// Above the rows: Undo after a delete, else how to use the blocks. A menu may sit over it.
    private func hintRow(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            if let u = undo {
                HStack(spacing: 12) {
                    Text(u.text).font(.system(size: 13, weight: .semibold))
                    Button("Undo") {
                        slots = u.slots
                        undo = nil
                        commit()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).frame(height: 36).raisedKey()
                    .buttonStyle(PressSink())
                }
                .padding(.leading, 14).padding(.trailing, 4).frame(height: 44)
                .background(Capsule().fill(Theme.raisedBottom))
                .transition(.opacity)
            } else {
                Text(editable ? (compact ? "Tap a block to change it. Press and drag to move it, drag its right edge for length."
                                         : "Tap a block to change it. Press and drag to move it, flick it up to delete it, drag its right edge for length.")
                              : "Stop the song to change its order, as on the FM-1.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .padding(.leading, Self.inset)
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: Self.hintRow, alignment: .topLeading)
    }

    /// A popup lines up with its block's left edge (which stays put while the block's bars change),
    /// kept inside the panel.
    private func anchor(_ i: Int, lay: Layout, width: CGFloat, popup: CGFloat) -> CGFloat {
        min(max(0, lay.x[i] - 4), max(0, width - popup))
    }

    private func menuBar(_ i: Int) -> some View {
        let slot = slots[i]
        return HStack(spacing: 6) {
            menuKey("chevron.left", "Move earlier", enabled: i > 0) { move(i, by: -1) }
            menuKey("chevron.right", "Move later", enabled: i < slots.count - 1) { move(i, by: 1) }
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28).padding(.horizontal, 2)
            ForEach(0..<4, id: \.self) { k in sectionChoice(k, at: i) }
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28).padding(.horizontal, 2)
            menuKey("plus.square.on.square", "Duplicate", enabled: slots.count < SongOrder.maxSteps) { duplicate(i) }
            menuKey("trash", "Delete the block", enabled: slots.count > 1) { delete(i) }
        }
        .padding(6)
        .fixedSize()
        .background {
            LookChoice {
                RoundedRectangle(cornerRadius: 14).fill(Theme.raisedBottom).shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            } flat: {
                Color.clear.elevated(.held)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Menu for step \(i + 1), section \(DeviceSession.sectionName(slot.step.section))")
    }

    private func menuKey(_ icon: String, _ label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44).raisedKey()
        }
        .buttonStyle(PressSink())
        .disabled(!enabled || !editable)
        .accessibilityLabel(label)
    }

    /// A section as the key it is above: its colour when stored, dark when empty (it can still go in
    /// the song; it plays silence).
    private func sectionChoice(_ k: Int, at i: Int) -> some View {
        let stored = session.song.stored(k)
        let current = slots[i].step.section == k
        return Button {
            change { $0[i].step.section = k }
        } label: {
            Text(DeviceSession.sectionName(k)).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(stored ? Theme.onColour : Theme.textTertiary)
                .frame(width: 48, height: 44)
                .background {
                    if stored {
                        RoundedRectangle(cornerRadius: 9).fill(Theme.pad(k, flat: look.flat))
                    } else {
                        RoundedRectangle(cornerRadius: 9).fill(Theme.well).recessed(9)
                    }
                }
                .overlay { if current { RoundedRectangle(cornerRadius: 12).stroke(Theme.text, lineWidth: 2).padding(-3) } }
        }
        .buttonStyle(PressSink())
        .disabled(!editable)
        .accessibilityLabel("Section \(DeviceSession.sectionName(k))")
        .accessibilityValue(stored ? "" : "empty")
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    // MARK: Changes

    private func toggleMenu(_ id: UUID) { setMenu(menu == id ? nil : id) }

    private func setMenu(_ id: UUID?) {
        if id != nil, frozenUnit == nil { frozenUnit = unit(for: rowWidth) }
        menu = id
        if id == nil, press?.mode != .resize { frozenUnit = nil }
    }

    private func move(_ i: Int, by d: Int) {
        let j = i + d
        guard slots.indices.contains(i), slots.indices.contains(j) else { return }
        change { $0.swapAt(i, j) }
    }

    private func duplicate(_ i: Int) {
        guard slots.indices.contains(i), slots.count < SongOrder.maxSteps else { return }
        let s = slots[i].step
        let copy = Slot(step: .init(section: s.section, bars: s.bars))
        change { $0.insert(copy, at: i + 1) }
        setMenu(copy.id)
    }

    private func delete(_ i: Int) {
        // SLOOP's order needs one step: the last block stays
        guard slots.indices.contains(i), slots.count > 1 else { return }
        let text = "Deleted a block of \(DeviceSession.sectionName(slots[i].step.section))"
        setMenu(nil)
        change(undoing: text) { $0.remove(at: i) }
    }

    /// A length change keeps the row's scale (the finger is on it); any other change fits the row again.
    private func change(undoing text: String? = nil, refit: Bool = true, _ f: (inout [Slot]) -> Void) {
        guard editable else { return }
        if let text { undo = Undo(slots: slots, text: text) }
        f(&slots)
        if refit, frozenUnit != nil {
            frozenUnit = nil
            frozenUnit = unit(for: rowWidth)
        }
        commit()
    }

    /// What the FM-1 should hold. Nothing is written when it holds that already.
    private func commit() {
        let o = SongOrder(steps: steps, loop: loop)
        draft = o.steps.isEmpty || o == session.songOrder ? nil : o
    }

    /// The FM-1's order, unless the iPad's blocks already say the same (their identities kept) or a save is pending.
    private func sync() {
        guard draft == nil else { return }
        let o = session.songOrder ?? .standard
        if steps != o.steps { slots = o.steps.map { Slot(step: $0) } }
    }
}

/// One pill per bar along the bottom of a block, filling as the song plays it (the bar playing fills
/// gradually); too many to draw apart, one bar that fills. Sized from the block's width, with no
/// geometry reader, so the pills move with the block in the same animation.
struct BarPills: View {
    let count: Int
    /// Bars played, the fraction of the one playing included (2.4: two full, the third 40 % through).
    let played: Double
    let width: CGFloat

    var body: some View {
        let n = max(count, 1)
        let gap: CGFloat = count > 16 ? 2 : 3
        let pw = (width - gap * CGFloat(n - 1)) / CGFloat(n)
        Group {
            if pw >= 3 {
                HStack(spacing: gap) {
                    ForEach(0..<n, id: \.self) { k in
                        pill(width: pw, fill: min(max(played - Double(k), 0), 1))
                    }
                }
            } else {
                pill(width: width, fill: min(max(played / Double(n), 0), 1))
            }
        }
        .frame(width: max(0, width), height: 6, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func pill(width w: CGFloat, fill: Double) -> some View {
        Capsule().fill(Theme.onColour.opacity(0.22))
            .overlay(alignment: .leading) {
                if fill > 0 {
                    Capsule().fill(Theme.onColour.opacity(0.8)).frame(width: max(6, w * CGFloat(fill)))
                }
            }
            .frame(width: max(0, w))
    }
}

/// A step's bars: − and + for one bar at a time (no drag needed, WCAG 2.5.7), and a slider whose
/// stops 1, 2, 4 … 64 sit evenly apart, snapping when the finger is near one.
struct BarsControl: View {
    let bars: Int
    var enabled = true
    let set: (Int) -> Void

    static let width: CGFloat = 540
    static let stops = [1, 2, 4, 8, 16, 32, 64]

    var body: some View {
        HStack(spacing: 10) {
            key("minus", "One bar fewer") { set(max(1, bars - 1)) }
                .disabled(!enabled || bars <= 1)
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Theme.well).frame(width: w - 24, height: 6).offset(x: 12, y: 13)
                    Capsule().fill(Theme.textSecondary).frame(width: max(6, pos(bars, w) - 12), height: 6).offset(x: 12, y: 13)
                    ForEach(Self.stops, id: \.self) { s in
                        Text("\(s)").font(.system(size: 11, weight: s == bars ? .semibold : .regular)).monospacedDigit()
                            .foregroundStyle(s == bars ? Theme.text : Theme.textSecondary)
                            .position(x: pos(s, w), y: 38)
                    }
                    Circle().fill(Theme.text).frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .position(x: pos(bars, w), y: 16)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    guard enabled else { return }
                    let b = value(at: v.location.x, w)
                    if b != bars { set(b) }
                })
                .accessibilityElement()
                .accessibilityLabel("Bars")
                .accessibilityValue("\(bars)")
                .accessibilityAdjustableAction { dir in
                    guard enabled else { return }
                    set(dir == .increment ? min(64, bars + 1) : max(1, bars - 1))
                }
            }
            .frame(height: 48)
            key("plus", "One bar more") { set(min(64, bars + 1)) }
                .disabled(!enabled || bars >= 64)
            Text("\(bars) bar\(bars == 1 ? "" : "s")").font(.system(size: 17, weight: .semibold)).monospacedDigit()
                .frame(width: 76, alignment: .leading)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background {
            LookChoice {
                RoundedRectangle(cornerRadius: 14).fill(Theme.raisedBottom).shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            } flat: {
                Color.clear.elevated(.held)
            }
        }
    }

    private func pos(_ b: Int, _ w: CGFloat) -> CGFloat { 12 + log2(CGFloat(max(1, b))) / 6 * (w - 24) }

    private func value(at x: CGFloat, _ w: CGFloat) -> Int {
        if let near = Self.stops.first(where: { abs(pos($0, w) - x) < 10 }) { return near }
        let p = min(max((x - 12) / (w - 24), 0), 1)
        return max(1, min(64, Int(pow(2, p * 6).rounded())))
    }

    private func key(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40).raisedKey()
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(label)
    }
}

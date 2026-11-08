import SloopKit
import SwiftUI
import UIKit

/// The song, as SLOOP holds it (GUIDE §14): four sections A–D (each a whole loop of the four tracks),
/// played live or in a song order of up to 16 steps; loop / song mode; SONG REC. Sections take the
/// track colours, as on the FM-1 (ui_layers.c: TE_COL[section]). The section keys sit right above the
/// song, so the parts and their order read as one thing.

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
        // the lift itself springs even while the block follows the finger (elevation 3's scale and shadow)
        .animation(motion) {
            $0.scaleEffect(lifted ? (reduceMotion ? 1 : 1.03) : 1)
                .shadow(color: .black.opacity(lifted ? Elevation.held.shadow.opacity : 0),
                        radius: lifted ? Elevation.held.shadow.radius : 0,
                        y: lifted ? Elevation.held.shadow.y : 0)
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
            .fill(Theme.pad(step.section)))
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
                .background(Capsule().fill(Theme.tones[1]))
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
            Color.clear.elevated(.held)
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
                        RoundedRectangle(cornerRadius: 9).fill(Theme.pad(k))
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

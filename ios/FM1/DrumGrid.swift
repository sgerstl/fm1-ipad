import SloopKit
import SwiftUI

/// The drum track: 16 lanes (Skiff: 8) by 64 steps, 12 lanes and one bar in view, a finger pans (hold to paint)
/// (settling on a bar), or move the view box on the timeline. On Skiff it's any track on a kit engine,
/// its lanes the hits each step carries.
struct DrumGrid: View {
    @Environment(\.grid) private var grid
    let session: DeviceSession
    let ui: EditorUI
    /// The drum track (SLOOP's track 4), or the selected kit track on Skiff.
    private var dt: Int { session.kitTrack ?? 0 }
    private var lanes: [String] { session.drumLanes }
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<DrumGridContent>.ScrollRequest?

    /// 568 = the piano roll's grid, gap and velocity lane (534 + 8 + 50) less the lane hint and its gap
    static let gridHeight: CGFloat = 568        // one bar wide (grid.barWidth)
    @Environment(\.editorHeight) private var editorHeight
    @Environment(\.arrangeCompact) private var inSongTab
    private var gridHeight: CGFloat { max(120, Self.gridHeight - (PianoRoll.panelHeight - editorHeight) + (inSongTab ? 40 : 0)) }

    var body: some View {
        let t = session.tracks[dt]
        let first = Int((offset.x / grid.stepWidth).rounded()) + 1
        let topLane = Int((offset.y / grid.rowHeight).rounded())
        let below = max(0, lanes.count - topLane - 12)      // 12 whole lanes in view

        VStack(spacing: 8) {
            if !inSongTab {
            EditorHeader(track: dt, title: t.mute ? "Drums · muted" : "Drums", muted: t.mute,
                         detail: "\(lanes.count) lanes · length \(t.length) · steps \(first)–\(min(session.stepCount, first + 15)) of \(session.stepCount)" + (session.song.songPlaying ? " · song playing: edits here end at STOP" : ""))
            }

            StepNumbers(steps: session.stepCount, offsetX: offset.x, selected: ui.selectedStep[dt],
                        motion: session.dialect == .skiff ? session.motion[dt]?.steps ?? [] : [],
                        // Skiff (a kit's steps are synth steps): steps picked along the numbers, for the bar's actions
                        picked: session.dialect == .skiff ? Binding(get: { ui.stepSel }, set: { ui.stepSel = $0 }) : nil) { ui.selectedStep[dt] = $0 }
                .padding(.leading, 88)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 0) {
                    ForEach(lanes.indices, id: \.self) { l in
                        AuditionLabel(text: lanes[l], spoken: lanes[l], bold: l == ui.selectedLane,
                                      select: { ui.selectedLane = l },
                                      down: { session.keyDown(l) }, up: { session.keyUp(l) })
                    }
                }
                .offset(y: -offset.y)
                .frame(width: 80, height: gridHeight, alignment: .top)
                .clipped()

                ZStack(alignment: .topLeading) {
                    TwoFingerScrollView(contentSize: CGSize(width: grid.drumContentSize.width, height: CGFloat(lanes.count) * grid.rowHeight), offset: $offset, request: request, snapX: grid.barWidth,
                                        holdRing: DrumGridContent.holdTime) {
                        DrumGridContent(grid: grid, session: session, ui: ui)
                    }
                    EditorPlayhead(session: session, track: dt, offsetX: offset.x, height: gridHeight)
                }
                .frame(width: grid.barWidth, height: gridHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .recessed()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Drum steps")
            }

            Text(below > 0 ? "\(below) more \(below == 1 ? "lane" : "lanes") below · drag to pan"
                 : topLane > 0 ? "\(topLane) \(topLane == 1 ? "lane" : "lanes") above · drag to pan" : " ")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 16)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(height: editorHeight)
        .panel()
        .overlay(alignment: .bottom) {
            if session.dialect == .skiff, !inSongTab { SelectionBar(edits: StepEdits(session: session, ui: ui, track: dt), notes: false).padding(.bottom, 12) }
        }
        .followsView(ui: ui, grid: grid, offset: offset) { request = .init(x: $0, id: $1) }
    }
}

struct DrumGridContent: View {
    /// Passed in, not read from the environment: it lives in a UIHostingController, which doesn't inherit it.
    var grid = GridMetrics.pad
    let session: DeviceSession
    let ui: EditorUI
    /// The drum track (SLOOP's track 4), or the selected kit track on Skiff.
    private var dt: Int { session.kitTrack ?? 0 }
    private var lanes: [String] { session.drumLanes }
    private var contentHeight: CGFloat { CGFloat(lanes.count) * grid.rowHeight }
    @State private var paintOn: Bool?          // a slide: lighting (true) or clearing (false) its lane
    @State private var painted: Set<Int> = []
    @State private var lifted = 0              // a light haptic as the hold takes
    /// The hold took: the lift that ends it isn't a tap.
    @State private var holdTook = false
    /// The hold before a slide paints (one finger pans, Scott 2026-11-07); the grid's ring fills over it.
    static let holdTime = PianoRollContent.holdTime

    var body: some View {
        let t = session.tracks[dt]
        let selected = ui.selectedStep[dt]
        let _ = ui.stepSel                         // read here: picking steps redraws the canvas
        ZStack(alignment: .topLeading) {
            WideCanvas(width: grid.drumContentSize.width, height: contentHeight, barWidth: grid.barWidth) { ctx, size in
                draw(ctx, size, t, selected, ui.selectedLane)
            }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { e in
                    if holdTook { holdTook = false; return }
                    // Scott's tap rules: an empty cell gets a hit, picked; the picked hit tapped again goes; a hit
                    // that isn't picked is picked, not cleared
                    let i = max(0, min(session.stepCount - 1, Int(e.location.x / grid.stepWidth)))
                    let l = max(0, min(lanes.count - 1, Int(e.location.y / grid.rowHeight)))
                    let has = session.tracks[dt].gridSteps[i].has(l)
                    let picked = ui.selectedStep[dt] == i && ui.selectedLane == l && ui.stepSel.isEmpty
                    ui.stepSel = []
                    ui.selectedStep[dt] = i
                    ui.selectedLane = l
                    if !has || picked { session.toggle(drumIndex: i, lane: l) }
                })
                // (alongside, not before: a long press first in an exclusive chain kept the tap from firing)
                .simultaneousGesture(paint)
                .sensoryFeedback(.impact(weight: .light), trigger: lifted)
                // a pan took the touch: the slide starts over
                .onReceive(NotificationCenter.default.publisher(for: .gridPanned)) { _ in paintOn = nil; painted = []; holdTook = false }
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                ForEach(session.stepIndices, id: \.self) { i in
                    Color.clear
                        .frame(width: grid.stepWidth, height: contentHeight)
                        .accessibilityElement()
                        .accessibilityLabel(StepLabels.drums(index: i, t, lanes: lanes))
                        .accessibilityAddTraits(i == selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { ui.selectedStep[dt] = i }
                        .accessibilityActions {
                            ForEach(lanes.indices, id: \.self) { l in
                                Button("\(lanes[l]) \(t.gridSteps[i].has(l) ? "off" : "on")") {
                                    ui.selectedStep[dt] = i; ui.selectedLane = l
                                    session.toggle(drumIndex: i, lane: l)
                                }
                            }
                        }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Hold, then slide along a lane: from an empty step it lights every step the finger passes, from a lit one
    /// it clears them, the held step first as the hold takes. The lane is the one the hold began in.
    private var paint: some Gesture {
        LongPressGesture(minimumDuration: Self.holdTime, maximumDistance: 8)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { v in
                guard case .second(true, let drag) = v else { return }
                if !holdTook { holdTook = true; lifted += 1 }   // (taken, still: its lift is no tap)
                guard let d = drag else { return }
                let l = max(0, min(lanes.count - 1, Int(d.startLocation.y / grid.rowHeight)))
                let a = max(0, min(63, Int(d.startLocation.x / grid.stepWidth)))
                let b = max(0, min(63, Int(d.location.x / grid.stepWidth)))
                if paintOn == nil { paintOn = !session.tracks[dt].gridSteps[a].has(l) }
                guard let on = paintOn else { return }
                for i in min(a, b)...max(a, b) where !painted.contains(i) {
                    painted.insert(i)
                    if session.tracks[dt].gridSteps[i].has(l) != on { session.toggle(drumIndex: i, lane: l) }
                }
                ui.selectedStep[dt] = b
                ui.selectedLane = l
            }
            .onEnded { _ in
                paintOn = nil; painted = []
                Task { @MainActor in try? await Task.sleep(for: .milliseconds(80)); holdTook = false }
            }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: TrackState, _ selected: Int, _ lane: Int) {
        // steps picked along the numbers: lit, with an edge
        for k in ui.stepSel {
            ctx.fill(Path(CGRect(x: CGFloat(k) * grid.stepWidth, y: 0, width: grid.stepWidth, height: size.height)), with: .color(.white.opacity(0.12)))
            ctx.fill(Path(CGRect(x: CGFloat(k) * grid.stepWidth, y: 0, width: grid.stepWidth, height: 2)), with: .color(Theme.text))
        }
        let w = grid.stepWidth, h = grid.rowHeight
        let steps = t.gridSteps
        for b in stride(from: 1, to: 16, by: 2) {
            ctx.fill(Path(CGRect(x: CGFloat(b * 4) * w, y: 0, width: 4 * w, height: size.height)), with: .color(.white.opacity(0.025)))
        }
        for bar in stride(from: 16, to: steps.count, by: 16) {
            ctx.fill(Path(CGRect(x: CGFloat(bar) * w, y: 0, width: 2, height: size.height)), with: .color(Color(hex: 0x34343C)))
        }
        // the selected step's column, lit faintly the whole height
        ctx.fill(Path(CGRect(x: CGFloat(selected) * w, y: 0, width: w, height: size.height)), with: .color(.white.opacity(0.07)))
        // empty cells: small wells, collected into one path and filled once (a fill and a path
        // subtraction per cell cost about a third of the main thread, 2026-11-02)
        var wells = Path()
        for i in steps.indices {
            let s = steps[i]
            for l in 0..<lanes.count {
                let x = CGFloat(i) * w, y = CGFloat(l) * h
                if s.has(l) {
                    let rect = CGRect(x: x + 4, y: y + 6, width: w - 8, height: h - 12)
                    let level = s.level(l)                       // 0 normal, 1 ghost, 2 soft, 3 hard
                    let ratchet = s.ratchet(l) + 1
                    drawPad(ctx, rect, track: dt, dim: level == 1 || level == 2 || i >= t.length,
                            selected: i == selected && l == lane)
                    // a second channel besides brightness: hard hits get a bright cap, ratchets split the pad
                    if level == 3 {
                        ctx.fill(Path(roundedRect: CGRect(x: rect.minX + 6, y: rect.minY + 4, width: rect.width - 12, height: 3), cornerRadius: 1.5),
                                 with: .color(.white.opacity(0.9)))
                    }
                    if ratchet > 1 {
                        for k in 1..<ratchet {
                            let ly = rect.minY + rect.height * CGFloat(k) / CGFloat(ratchet)
                            ctx.fill(Path(CGRect(x: rect.minX + 3, y: ly - 1, width: rect.width - 6, height: 2)), with: .color(Theme.onColour.opacity(0.6)))
                        }
                    }
                } else {
                    let r = CGRect(x: x + (w - 8) / 2, y: y + (h - 8) / 2, width: 8, height: 8)
                    wells.addEllipse(in: r)
                    if i == selected && l == lane {
                        ctx.stroke(Path(roundedRect: CGRect(x: x + 4, y: y + 6, width: w - 8, height: h - 12), cornerRadius: 6),
                                   with: .color(Theme.text), lineWidth: 2)
                    }
                }
            }
        }
        ctx.fill(wells, with: .color(Color(hex: 0x0B0B0D)))
        if t.length < steps.count {
            ctx.fill(Path(CGRect(x: CGFloat(t.length) * w, y: 0, width: CGFloat(steps.count - t.length) * w, height: size.height)),
                     with: .color(.black.opacity(0.4)))
        }
    }
}

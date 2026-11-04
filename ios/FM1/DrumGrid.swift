import SloopKit
import SwiftUI

/// The drum track: 16 lanes by 64 steps, 12 lanes and one bar in view, two fingers pan (settling on a
/// bar), or move the view box on the timeline.
struct DrumGrid: View {
    @Environment(\.grid) private var grid
    let session: DeviceSession
    let ui: EditorUI
    /// The drum track (SLOOP's track 4): this grid is shown only on firmware that has one.
    private var dt: Int { session.drumTrack ?? 0 }
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<DrumGridContent>.ScrollRequest?

    /// 568 = the piano roll's grid, gap and velocity lane (534 + 8 + 50) less the lane hint and its gap
    static let gridHeight: CGFloat = 568        // one bar wide (grid.barWidth)

    var body: some View {
        let t = session.tracks[dt]
        let first = Int((offset.x / grid.stepWidth).rounded()) + 1
        let topLane = Int((offset.y / grid.rowHeight).rounded())
        let below = max(0, 16 - topLane - 12)      // 12 whole lanes in view

        VStack(spacing: 8) {
            EditorHeader(track: dt, title: t.mute ? "Drums · muted" : "Drums", muted: t.mute,
                         detail: "16 lanes · length \(t.length) · steps \(first)–\(min(session.stepCount, first + 15)) of \(session.stepCount)" + (session.song.songPlaying ? " · song playing: edits here end at STOP" : ""))

            StepNumbers(steps: session.stepCount, offsetX: offset.x, selected: ui.selectedStep[dt]) { ui.selectedStep[dt] = $0 }
                .padding(.leading, 88)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 0) {
                    ForEach(0..<16, id: \.self) { l in
                        AuditionLabel(text: Music.drumLanes[l], spoken: Music.drumLanes[l], bold: l == ui.selectedLane,
                                      select: { ui.selectedLane = l },
                                      down: { session.keyDown(l) }, up: { session.keyUp(l) })
                    }
                }
                .offset(y: -offset.y)
                .frame(width: 80, height: Self.gridHeight, alignment: .top)
                .clipped()

                ZStack(alignment: .topLeading) {
                    TwoFingerScrollView(contentSize: grid.drumContentSize, offset: $offset, request: request, snapX: grid.barWidth) {
                        DrumGridContent(grid: grid, session: session, ui: ui)
                    }
                    EditorPlayhead(session: session, track: dt, offsetX: offset.x, height: Self.gridHeight)
                }
                .frame(width: grid.barWidth, height: Self.gridHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .recessed()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Drum steps")
            }

            Text(below > 0 ? "\(below) more \(below == 1 ? "lane" : "lanes") below · pan with two fingers"
                 : topLane > 0 ? "\(topLane) \(topLane == 1 ? "lane" : "lanes") above · pan with two fingers" : " ")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 16)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(height: PianoRoll.panelHeight)
        .panel()
        .followsView(ui: ui, grid: grid, offset: offset) { request = .init(x: $0, id: $1) }
    }
}

struct DrumGridContent: View {
    /// Passed in, not read from the environment: it lives in a UIHostingController, which doesn't inherit it.
    var grid = GridMetrics.pad
    let session: DeviceSession
    let ui: EditorUI
    /// The drum track (SLOOP's track 4): this grid is shown only on firmware that has one.
    private var dt: Int { session.drumTrack ?? 0 }
    @State private var paintOn: Bool?          // a slide: lighting (true) or clearing (false) its lane
    @State private var painted: Set<Int> = []

    var body: some View {
        let t = session.tracks[dt]
        let selected = ui.selectedStep[dt]
        ZStack(alignment: .topLeading) {
            WideCanvas(width: grid.drumContentSize.width, height: grid.drumContentSize.height, barWidth: grid.barWidth) { ctx, size in
                draw(ctx, size, t, selected, ui.selectedLane)
            }
                .contentShape(Rectangle())
                .gesture(paint.exclusively(before: SpatialTapGesture().onEnded { e in
                    // a tap turns that hit on or off, and selects it
                    let i = max(0, min(session.stepCount - 1, Int(e.location.x / grid.stepWidth)))
                    let l = max(0, min(15, Int(e.location.y / grid.rowHeight)))
                    ui.selectedStep[dt] = i
                    ui.selectedLane = l
                    session.toggle(drumIndex: i, lane: l)
                }))
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                ForEach(session.stepIndices, id: \.self) { i in
                    Color.clear
                        .frame(width: grid.stepWidth, height: grid.drumContentSize.height)
                        .accessibilityElement()
                        .accessibilityLabel(StepLabels.drums(index: i, t))
                        .accessibilityAddTraits(i == selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { ui.selectedStep[dt] = i }
                        .accessibilityActions {
                            ForEach(0..<16, id: \.self) { l in
                                Button("\(Music.drumLanes[l]) \(t.drumSteps[i].has(l) ? "off" : "on")") {
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

    /// A slide along a lane: from an empty step it lights every step the finger passes, from a lit one
    /// it clears them. The lane is the one the slide began in.
    private var paint: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { e in
                let l = max(0, min(15, Int(e.startLocation.y / grid.rowHeight)))
                let a = max(0, min(63, Int(e.startLocation.x / grid.stepWidth)))
                let b = max(0, min(63, Int(e.location.x / grid.stepWidth)))
                if paintOn == nil { paintOn = !session.tracks[dt].drumSteps[a].has(l) }
                guard let on = paintOn else { return }
                for i in min(a, b)...max(a, b) where !painted.contains(i) {
                    painted.insert(i)
                    if session.tracks[dt].drumSteps[i].has(l) != on { session.toggle(drumIndex: i, lane: l) }
                }
                ui.selectedStep[dt] = b
                ui.selectedLane = l
            }
            .onEnded { _ in paintOn = nil; painted = [] }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: TrackState, _ selected: Int, _ lane: Int) {
        let w = grid.stepWidth, h = grid.rowHeight
        for b in stride(from: 1, to: 16, by: 2) {
            ctx.fill(Path(CGRect(x: CGFloat(b * 4) * w, y: 0, width: 4 * w, height: size.height)), with: .color(.white.opacity(0.025)))
        }
        for bar in stride(from: 16, to: t.drumSteps.count, by: 16) {
            ctx.fill(Path(CGRect(x: CGFloat(bar) * w, y: 0, width: 2, height: size.height)), with: .color(Color(hex: 0x34343C)))
        }
        // the selected step's column, lit faintly the whole height
        ctx.fill(Path(CGRect(x: CGFloat(selected) * w, y: 0, width: w, height: size.height)), with: .color(.white.opacity(0.07)))
        // empty cells: small recessed wells, collected into two paths and filled once each (a fill and a
        // path subtraction per cell cost about a third of the main thread, 2026-11-02)
        var wells = Path(), lips = Path()
        for i in t.drumSteps.indices {
            let s = t.drumSteps[i]
            for l in 0..<16 {
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
                    lips.addEllipse(in: r.offsetBy(dx: 0, dy: 1))
                    if i == selected && l == lane {
                        ctx.stroke(Path(roundedRect: CGRect(x: x + 4, y: y + 6, width: w - 8, height: h - 12), cornerRadius: 6),
                                   with: .color(Theme.text), lineWidth: 2)
                    }
                }
            }
        }
        // the lip first, the well over it: the 1 pt of lip left showing below each well is its highlight
        ctx.fill(lips, with: .color(.white.opacity(0.05)))
        ctx.fill(wells, with: .color(Color(hex: 0x0B0B0D)))
        if t.length < t.drumSteps.count {
            ctx.fill(Path(CGRect(x: CGFloat(t.length) * w, y: 0, width: CGFloat(t.drumSteps.count - t.length) * w, height: size.height)),
                     with: .color(.black.opacity(0.4)))
        }
    }
}

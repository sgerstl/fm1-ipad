import SloopKit
import SwiftUI

/// The drum track: 16 lanes by 64 steps, 10 lanes and 32 steps in view, two fingers pan.
struct DrumGrid: View {
    let session: SloopSession
    let ui: EditorUI
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<DrumGridContent>.ScrollRequest?

    /// 568 = the piano roll's grid, gap and velocity lane (534 + 8 + 50) less the lane hint and its gap
    static let gridSize = CGSize(width: 1216, height: 568)
    static let contentSize = CGSize(width: 64 * Theme.stepWidth, height: 16 * Theme.rowHeight)

    var body: some View {
        let t = session.tracks[3]
        let first = Int((offset.x / Theme.stepWidth).rounded()) + 1
        let topLane = Int((offset.y / Theme.rowHeight).rounded())
        let below = max(0, 16 - topLane - 12)      // 12 whole lanes in view

        VStack(spacing: 8) {
            EditorHeader(track: 3, title: t.mute ? "Drums · muted" : "Drums", muted: t.mute,
                         detail: "16 lanes · length \(t.length) · steps \(first)–\(min(64, first + 31)) of 64")

            StepNumbers(offsetX: offset.x, selected: ui.selectedStep[3]) { ui.selectedStep[3] = $0 }
                .padding(.leading, 88)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 0) {
                    ForEach(0..<16, id: \.self) { l in
                        AuditionLabel(text: Music.drumLanes[l], spoken: Music.drumLanes[l], bold: l == ui.selectedLane,
                                      down: { session.keyDown(l) }, up: { session.keyUp(l) })
                    }
                }
                .offset(y: -offset.y)
                .frame(width: 80, height: Self.gridSize.height, alignment: .top)
                .clipped()

                ZStack(alignment: .topLeading) {
                    TwoFingerScrollView(contentSize: Self.contentSize, offset: $offset, request: request) {
                        DrumGridContent(session: session, ui: ui)
                    }
                    EditorPlayhead(session: session, track: 3, offsetX: offset.x, height: Self.gridSize.height)
                }
                .frame(width: Self.gridSize.width, height: Self.gridSize.height)
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
    }
}

struct DrumGridContent: View {
    let session: SloopSession
    let ui: EditorUI
    @State private var paintOn: Bool?          // a slide: lighting (true) or clearing (false) its lane
    @State private var painted: Set<Int> = []

    var body: some View {
        let t = session.tracks[3]
        let selected = ui.selectedStep[3]
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in draw(ctx, size, t, selected, ui.selectedLane) }
                .frame(width: DrumGrid.contentSize.width, height: DrumGrid.contentSize.height)
                .contentShape(Rectangle())
                .gesture(paint.exclusively(before: SpatialTapGesture().onEnded { e in
                    // a tap turns that hit on or off, and selects it
                    let i = max(0, min(63, Int(e.location.x / Theme.stepWidth)))
                    let l = max(0, min(15, Int(e.location.y / Theme.rowHeight)))
                    ui.selectedStep[3] = i
                    ui.selectedLane = l
                    session.toggle(drumIndex: i, lane: l)
                }))
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                ForEach(0..<64, id: \.self) { i in
                    Color.clear
                        .frame(width: Theme.stepWidth, height: DrumGrid.contentSize.height)
                        .accessibilityElement()
                        .accessibilityLabel(StepLabels.drums(index: i, t))
                        .accessibilityAddTraits(i == selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { ui.selectedStep[3] = i }
                        .accessibilityActions {
                            ForEach(0..<16, id: \.self) { l in
                                Button("\(Music.drumLanes[l]) \(t.drumSteps[i].has(l) ? "off" : "on")") {
                                    ui.selectedStep[3] = i; ui.selectedLane = l
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
                let l = max(0, min(15, Int(e.startLocation.y / Theme.rowHeight)))
                let a = max(0, min(63, Int(e.startLocation.x / Theme.stepWidth)))
                let b = max(0, min(63, Int(e.location.x / Theme.stepWidth)))
                if paintOn == nil { paintOn = !session.tracks[3].drumSteps[a].has(l) }
                guard let on = paintOn else { return }
                for i in min(a, b)...max(a, b) where !painted.contains(i) {
                    painted.insert(i)
                    if session.tracks[3].drumSteps[i].has(l) != on { session.toggle(drumIndex: i, lane: l) }
                }
                ui.selectedStep[3] = b
                ui.selectedLane = l
            }
            .onEnded { _ in paintOn = nil; painted = [] }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: TrackState, _ selected: Int, _ lane: Int) {
        let w = Theme.stepWidth, h = Theme.rowHeight
        for b in stride(from: 1, to: 16, by: 2) {
            ctx.fill(Path(CGRect(x: CGFloat(b * 4) * w, y: 0, width: 4 * w, height: size.height)), with: .color(.white.opacity(0.025)))
        }
        for bar in stride(from: 16, to: 64, by: 16) {
            ctx.fill(Path(CGRect(x: CGFloat(bar) * w, y: 0, width: 2, height: size.height)), with: .color(Color(hex: 0x34343C)))
        }
        for i in 0..<64 {
            let s = t.drumSteps[i]
            for l in 0..<16 {
                let x = CGFloat(i) * w, y = CGFloat(l) * h
                if s.has(l) {
                    let rect = CGRect(x: x + 4, y: y + 6, width: w - 8, height: h - 12)
                    let level = s.level(l)                       // 0 normal, 1 ghost, 2 soft, 3 hard
                    let ratchet = s.ratchet(l) + 1
                    drawPad(ctx, rect, track: 3, dim: level == 1 || level == 2 || i >= t.length,
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
                    // an empty cell: a small recessed well
                    let r = CGRect(x: x + 15, y: y + 19, width: 8, height: 8)
                    ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: 0x0B0B0D)))
                    ctx.fill(Path(ellipseIn: r.offsetBy(dx: 0, dy: 1)).subtracting(Path(ellipseIn: r)), with: .color(.white.opacity(0.05)))
                    if i == selected && l == lane {
                        ctx.stroke(Path(roundedRect: CGRect(x: x + 4, y: y + 6, width: w - 8, height: h - 12), cornerRadius: 6),
                                   with: .color(Theme.text), lineWidth: 2)
                    }
                }
            }
        }
        if t.length < 64 {
            ctx.fill(Path(CGRect(x: CGFloat(t.length) * w, y: 0, width: CGFloat(64 - t.length) * w, height: size.height)),
                     with: .color(.black.opacity(0.4)))
        }
    }
}

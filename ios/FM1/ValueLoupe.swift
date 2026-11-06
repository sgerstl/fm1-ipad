import SloopKit
import SwiftUI

// The loupe (Scott, 2026-11-06: "my fat fingers obscure the values"): while a value is being slid, a bigger copy of
// what's under the finger floats above it and follows it: a column's label, rolling digits and gauge, or a dial with
// its value. Columns (Shape, the sound panel, the Mixer's cards) and the Song tab's track knobs. It takes no touches
// and is hidden from VoiceOver (the control itself says its value). Its own observable state, read only here, so a
// finger moving redraws the loupe and nothing else (the Mix tab's lesson: one value re-laid out the whole tab).

@Observable @MainActor final class LoupeState {
    enum Face { case column(number: Int, tint: Color), dial }
    /// The control being slid: its spec read live, so the digits roll as the value moves.
    @ObservationIgnored private(set) var make: (() -> KnobSpec)?
    private(set) var face: Face = .dial
    private(set) var on = false
    /// The finger, in global points.
    var finger: CGPoint = .zero

    /// Settings' Magnifier off (2026-11-06): it never shows.
    func show(_ make: @escaping () -> KnobSpec, _ face: Face, at p: CGPoint) {
        guard Magnifier.on else { return }
        self.make = make; self.face = face; finger = p; on = true
    }
    func hide() { on = false }
}

/// Where the loupe draws: over the whole canvas, above the finger, kept on screen.
struct ValueLoupeLayer: View {
    let loupe: LoupeState
    @State private var frame: CGRect = .zero
    @State private var size = CGSize(width: 128, height: 70)      // the face's, unscaled (measured)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How much bigger than the control: enough to read past a fingertip, not so much it covers the next column.
    static let scale: CGFloat = 1.6
    /// Its bottom edge this far above the finger's point: clear of a fingertip (about 44 pt) with air.
    static let lift: CGFloat = 64

    var body: some View {
        GeometryReader { g in
            if loupe.on, let make = loupe.make {
                // global points to the canvas's own (it's scaled to fit the screen)
                let k = frame.width > 0 ? g.size.width / frame.width : 1
                let p = CGPoint(x: (loupe.finger.x - frame.minX) * k, y: (loupe.finger.y - frame.minY) * k)
                let w = size.width * Self.scale, h = size.height * Self.scale
                let x = min(max(12 + w / 2, p.x), g.size.width - 12 - w / 2)
                let y = max(12 + h / 2, p.y - Self.lift - h / 2)            // above the finger; near the top, as high as it goes
                LoupeFace(spec: make(), face: loupe.face)
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                    .scaleEffect(Self.scale)
                    .position(x: x, y: y)
                    // grows from and shrinks back into the finger (anchored in the layer, which .position fills: a
                    // .bottom anchor shrank it toward the foot of the screen, Scott, 2026-11-06)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.2, anchor: UnitPoint(x: p.x / max(g.size.width, 1),
                                                                                               y: p.y / max(g.size.height, 1)))
                                    .combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.9), value: loupe.on)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

/// What the loupe shows: the column as it is, or the dial with its label and value beside it, on a raised plate.
private struct LoupeFace: View {
    let spec: KnobSpec
    let face: LoupeState.Face
    private let look = Look()

    var body: some View {
        Group {
            switch face {
            case .column(let number, let tint):
                ColumnFace(spec: spec, number: number, tint: tint, hot: true)
                    .frame(width: 120, height: 62)
            case .dial:
                HStack(spacing: 8) {
                    Canvas { ctx, sz in
                        drawDial(ctx, sz, fraction: spec.fraction, colour: spec.colour, bipolar: spec.bipolar,
                                 radius: 13, line: 3, cap: 8)
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(spec.label).font(.system(size: 11)).foregroundStyle(Theme.textSecondaryRaised)
                        RollingText(text: spec.shown, size: 15).id(spec.id).foregroundStyle(Theme.text).lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 44)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10).fill(look.surface(.held)).elevationShadow(.held, look))
    }
}

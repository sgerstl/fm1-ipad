import SloopKit
import SwiftUI

// The selected track's four HOME controls at the right of the iPad's scene row (Scott, 2026-11-15, decision 50: they went
// with the track controls box, decision 31). Which four depends on the engine (ui.c home_param; on a NEON kit PITCH,
// TONE, DECAY, SNAP), read from SloopKit's table (`DeviceSession.homeKnobIDs`, the phones' too). Each is a small ring in
// the track's colour with its label and value; a slide turns it (the app's knob gesture, KnobControl), and the same
// knob's parameter on the FM-1. They follow the FM-1's own HOME knobs live, and the one the FM-1 turns lights. iPad only.

struct HomeKnobsStrip: View {
    let session: DeviceSession
    let ui: EditorUI
    let height: CGFloat
    @State private var marks = ShapeMarks()

    static let knobWidth: CGFloat = 104, spacing: CGFloat = 4
    /// The strip's width for `count` knobs (the scene row gives the scenes the rest).
    static func width(_ count: Int) -> CGFloat { count == 0 ? 0 : CGFloat(count) * knobWidth + CGFloat(count - 1) * spacing }

    var body: some View {
        let t = session.selectedTrack
        let ids = session.homeKnobIDs ?? []
        HStack(spacing: Self.spacing) {
            ForEach(Array(ids.enumerated()), id: \.offset) { k, id in
                let hot = marks.key == "s0.\(id)"
                KnobControl(ui: ui, column: (number: k + 1, tint: Theme.track[t], hot: hot),
                            face: { spec, dragging in
                                AnyView(HomeKnobFace(spec: spec, tint: Theme.track[t], hot: hot || dragging, height: height))
                            }) {
                    KnobSpec.param(session, scope: 0, id: id, slot: k)
                }
                .frame(width: Self.knobWidth, height: height)
            }
        }
        // the FM-1's own knob turned: its parameter lights here, as on the sound cards
        .background { TouchFollower(session: session) { if let k = session.lastTouched { marks.mark("s\(k.scope).\(k.id)") } } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(t + 1) HOME knobs")
    }
}

/// One HOME knob: a ring (the value's arc in the track's colour, white while it turns here or on the FM-1, from the centre
/// on a bipolar value) beside its label over its value, on the well. Sized to the scene row: 32 pt at Half, 56 at No grid.
struct HomeKnobFace: View {
    let spec: KnobSpec
    let tint: Color
    let hot: Bool
    let height: CGFloat

    var body: some View {
        let ring = max(20, height - 10), big = height >= 44
        HStack(spacing: 6) {
            Canvas { ctx, sz in
                let w: CGFloat = big ? 4 : 3, r = sz.width / 2 - w / 2 - 1
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                func arc(_ a: Double, _ b: Double) -> Path {
                    Path { p in p.addArc(center: c, radius: r, startAngle: .degrees(a), endAngle: .degrees(b), clockwise: false) }
                }
                let style = StrokeStyle(lineWidth: w, lineCap: .round)
                ctx.stroke(arc(135, 405), with: .color(Theme.stepEmpty), style: style)
                let f = min(max(spec.fraction, 0), 1), a = 135 + 270 * f, from = spec.bipolar ? 270.0 : 135.0
                if abs(a - from) > 0.5 { ctx.stroke(arc(min(from, a), max(from, a)), with: .color(hot ? Theme.text : tint), style: style) }
            }
            .frame(width: ring, height: ring)
            VStack(alignment: .leading, spacing: big ? 2 : 0) {
                Text(spec.label).font(.lupe(big ? 11 : 9, .medium)).foregroundStyle(Theme.textSecondaryRaised)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(spec.shown).font(.lupeNumber(big ? 16 : 13, .semibold)).monospacedDigit().foregroundStyle(Theme.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8).fill(Theme.well)
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(hot ? tint : .clear, lineWidth: 1.5) }
        }
        .opacity(spec.dead ? 0.5 : 1)
        .animation(.easeOut(duration: 0.15), value: hot)
    }
}

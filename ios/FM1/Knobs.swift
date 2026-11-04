import SloopKit
import SwiftUI

/// One of the FM-1's four knobs on the studio home screen for the selected track (firmware
/// ui_studio.c, studio_tracks_draw): swing (the global groove), level, steps, pan. Values are shown
/// as the device shows them.
struct KnobSpec {
    let id: String
    let colour: Color
    let label: String
    let value: Int
    let range: ClosedRange<Int>
    let stepperStep: Int
    let shown: String
    let spoken: String
    let bipolar: Bool
    let set: (Int) -> Void

    var fraction: Double {
        let span = range.upperBound - range.lowerBound
        return span > 0 ? Double(value - range.lowerBound) / Double(span) : 0     // (a fixed value: CPU)
    }

    @MainActor
    static func all(_ session: SloopSession) -> [KnobSpec] {
        let k = session.selectedTrack
        let t = session.tracks[k]
        let pct = t.level * 100 / 127
        return [
            KnobSpec(id: "home0", colour: Theme.knob[0], label: "SWING", value: session.swing, range: 0...100, stepperStep: 5,
                     shown: "\(session.swing)", spoken: "\(session.swing)", bipolar: false) { session.set(global: Global.swing, to: $0) },
            KnobSpec(id: "home1", colour: Theme.knob[1], label: "LEVEL", value: t.mute ? 0 : t.level, range: 0...127, stepperStep: 8,
                     shown: t.mute ? "0" : "\(pct)", spoken: t.mute ? "muted" : "\(pct) percent", bipolar: false) { v in
                // as on the device, turning LEVEL unmutes the track
                if t.mute { session.set(track: k, param: Param.mute, to: 0) }
                session.set(track: k, param: Param.level, to: v)
            },
            KnobSpec(id: "home2", colour: Theme.knob[2], label: "STEPS", value: t.length, range: 1...64, stepperStep: 1,
                     shown: "\(t.length)", spoken: "\(t.length) steps", bipolar: false) { session.set(track: k, param: Param.length, to: $0) },
            KnobSpec(id: "home3", colour: Theme.knob[3], label: "PAN", value: t.pan, range: -64...63, stepperStep: 4,
                     shown: "\(t.pan)", spoken: t.pan == 0 ? "centre" : t.pan < 0 ? "\(-t.pan) left" : "\(t.pan) right",
                     bipolar: true) { session.set(track: k, param: Param.pan, to: $0) },
        ]
    }
}

/// A held knob: the grown ring sits at `center`, just above the knob and fully on screen (drawn by
/// GrownKnobLayer over everything).
struct KnobGrab: Equatable {
    var id: String
    var center: CGPoint
}

struct KnobRow: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { k in
                KnobControl(ui: ui) { KnobSpec.all(session)[k] }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track knobs, as on the FM-1 screen")
    }
}

/// Touch a knob and a big ring appears around the finger (moved only as far as it must to stay on
/// screen); turn it by tracing round, clockwise for up. The turn is relative: the value moves by how
/// far the finger goes round and never jumps to where it lands, so touching never changes a value.
/// Works at any screen edge, which a vertical slide from the bottom row didn't. A quick tap without
/// moving opens − / + keys (WCAG 2.2, 2.5.7: a way in without dragging).
struct KnobControl: View {
    let ui: EditorUI
    var size: CGFloat = 40
    /// Builds the knob's description each time, so the grown ring shows live values.
    let make: () -> KnobSpec
    @State private var startValue = 0
    @State private var turned = 0.0           // in value units since the grab
    @State private var lastAngle: Double?
    @State private var showKeys = false
    @GestureState private var holding = false   // resets even when the system cancels the touch
    @State private var touchStart = Date()
    @Environment(\.canvasSize) private var canvas

    static let ringRadius: CGFloat = 80
    static let discRadius: CGFloat = 102      // the lifted disc around the ring

    var body: some View {
        let spec = make()
        let turn = DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
            .updating($holding) { _, state, _ in state = true }
            .onChanged { drag in
                if ui.knobGrab?.id != spec.id {
                    let edge = Self.discRadius + 4
                    let c = CGPoint(x: min(max(drag.startLocation.x, edge), canvas.width - edge),
                                    y: min(max(drag.startLocation.y, edge), canvas.height - edge))
                    ui.knobGrab = KnobGrab(id: spec.id, center: c)
                    ui.grabbedSpec = make
                    startValue = spec.value; turned = 0; lastAngle = nil; touchStart = drag.time
                }
                guard let c = ui.knobGrab?.center else { return }
                let dx = drag.location.x - c.x, dy = drag.location.y - c.y
                guard hypot(dx, dy) > 24 else { lastAngle = nil; return }      // too near the middle to read a direction
                let angle = atan2(Double(dx), Double(-dy)) * 180 / .pi         // 0 = up, clockwise positive
                if let last = lastAngle {
                    var d = angle - last
                    if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                    let span = Double(spec.range.upperBound - spec.range.lowerBound)
                    turned += d / 270 * span                                    // a full sweep = the knob's 270°
                    turned = min(max(turned, Double(spec.range.lowerBound - startValue)), Double(spec.range.upperBound - startValue))
                    let v = startValue + Int(turned.rounded())
                    if v != spec.value { spec.set(v) }
                }
                lastAngle = angle
            }
            .onEnded { drag in
                ui.knobGrab = nil; lastAngle = nil
                // a tap: barely moved and quick
                if hypot(drag.translation.width, drag.translation.height) < 8, drag.time.timeIntervalSince(touchStart) < 0.35 {
                    showKeys = true
                }
            }

        KnobDial(spec: spec, size: size)
            .opacity(ui.knobGrab?.id == spec.id ? 0.3 : 1)
            .contentShape(Rectangle())
            .gesture(turn)
            .onChange(of: holding) { _, h in if !h, ui.knobGrab?.id == spec.id { ui.knobGrab = nil; lastAngle = nil } }
            .popover(isPresented: $showKeys, arrowEdge: .top) {
                VStack(spacing: 8) {
                    Text(spec.label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    StepperKeys(label: spec.label.capitalized, value: spec.value, range: spec.range, step: spec.stepperStep,
                                format: { _ in spec.shown }) { spec.set($0) }
                }
                .padding(16)
                .presentationBackground(Theme.panelTop)
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spec.label.capitalized)
            .accessibilityValue(spec.spoken)
            .accessibilityAdjustableAction { dir in
                let d = dir == .increment ? spec.stepperStep : -spec.stepperStep
                spec.set(min(max(spec.value + d, spec.range.lowerBound), spec.range.upperBound))
            }
    }
}

/// The small dial: a coloured ring from the start (or the centre) to the needle, a raised cap.
struct KnobDial: View {
    let spec: KnobSpec
    var size: CGFloat = 40

    var body: some View {
        VStack(spacing: 3) {
            let k = size / 40
            Canvas { ctx, sz in drawDial(ctx, sz, fraction: spec.fraction, colour: spec.colour, bipolar: spec.bipolar, radius: 17 * k, line: 4 * k, cap: 11 * k) }
                .frame(width: size, height: size)
            Text(spec.label).font(.system(size: size > 40 ? 12 : 11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            Text(spec.shown).font(.system(size: size > 40 ? 15 : 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: size > 40 ? 88 : 56)
    }
}

func drawDial(_ ctx: GraphicsContext, _ size: CGSize, fraction: Double, colour: Color, bipolar: Bool,
              radius: CGFloat, line: CGFloat, cap: CGFloat) {
    let c = CGPoint(x: size.width / 2, y: size.height / 2)
    let f = min(max(fraction, 0), 1)
    func arc(_ a: Double, _ b: Double) -> Path {
        Path { p in p.addArc(center: c, radius: radius, startAngle: .degrees(a - 90), endAngle: .degrees(b - 90), clockwise: false) }
    }
    let style = StrokeStyle(lineWidth: line, lineCap: .round)
    ctx.stroke(arc(-135, 135), with: .color(Color(hex: 0x25252B)), style: style)
    let a = -135 + 270 * f
    let from = bipolar ? 0.0 : -135.0
    if abs(a - from) > 0.5 { ctx.stroke(arc(min(from, a), max(from, a)), with: .color(colour), style: style) }
    guard cap > 0 else { return }
    let capRect = CGRect(x: c.x - cap, y: c.y - cap, width: cap * 2, height: cap * 2)
    ctx.fill(Path(ellipseIn: capRect.offsetBy(dx: 0, dy: 1)), with: .color(.black.opacity(0.5)))
    ctx.fill(Path(ellipseIn: capRect), with: .radialGradient(Gradient(colors: [Color(hex: 0x5A5A63), Color(hex: 0x1F1F24)]),
                                                            center: CGPoint(x: capRect.minX + cap * 0.8, y: capRect.minY + cap * 0.6),
                                                            startRadius: 0, endRadius: cap * 1.5))
    ctx.stroke(Path(ellipseIn: capRect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.12)), lineWidth: 1)
    let rad = a * .pi / 180
    ctx.stroke(Path { p in p.move(to: c); p.addLine(to: CGPoint(x: c.x + cap * 0.82 * sin(rad), y: c.y - cap * 0.82 * cos(rad))) },
               with: .color(Theme.text), style: StrokeStyle(lineWidth: 2, lineCap: .round))
}

/// The grown ring of a held knob, drawn over the whole page: trace it to turn. The value sits in the
/// middle; a handle on the ring marks the setting, where the needle would point.
struct GrownKnobLayer: View {
    let session: SloopSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let g = ui.knobGrab, let make = ui.grabbedSpec {
                let spec = make()
                let r: CGFloat = 80
                ZStack {
                    // a lifted disc: it is being held, so it is raised off the panel
                    Circle()
                        .fill(LinearGradient(colors: [Theme.panelTop, Theme.panelBottom], startPoint: .top, endPoint: .bottom))
                        .overlay(Circle().inset(by: 0.5).stroke(.white.opacity(0.06), lineWidth: 1))
                        .frame(width: r * 2 + 44, height: r * 2 + 44)
                        .shadow(color: .black.opacity(0.55), radius: 2, y: 2)
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
                    Canvas { ctx, sz in
                        drawDial(ctx, sz, fraction: spec.fraction, colour: spec.colour, bipolar: spec.bipolar, radius: r, line: 12, cap: 0)
                        let a = (-135 + 270 * min(max(spec.fraction, 0), 1)) * .pi / 180
                        let p = CGPoint(x: sz.width / 2 + r * sin(a), y: sz.height / 2 - r * cos(a))
                        let handle = CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)
                        ctx.fill(Path(ellipseIn: handle.offsetBy(dx: 0, dy: 1)), with: .color(.black.opacity(0.5)))
                        ctx.fill(Path(ellipseIn: handle), with: .color(Theme.text))
                    }
                    .frame(width: r * 2 + 30, height: r * 2 + 30)
                    VStack(spacing: 0) {
                        Text(spec.shown).font(.system(size: 30, weight: .semibold))
                        Text(spec.label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .position(g.center)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ui.knobGrab?.id)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

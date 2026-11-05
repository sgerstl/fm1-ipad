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
    /// The parameter's default (DESC), for a double-tap; nil: none known.
    var defaultValue: Int? = nil
    /// Named choices (DESC format 8: waveforms, modes), for the value range's lowest up: the tap opens a list.
    var choices: [String]? = nil
    let set: (Int) -> Void

    var fraction: Double {
        let span = range.upperBound - range.lowerBound
        return span > 0 ? Double(value - range.lowerBound) / Double(span) : 0     // (a fixed value: CPU)
    }

    @MainActor
    static func all(_ session: DeviceSession) -> [KnobSpec] {
        let k = session.selectedTrack
        let t = session.tracks[k]
        let pct = t.level * 100 / 127
        return [
            KnobSpec(id: "home0", colour: Theme.text, label: "SWING", value: session.swing, range: 0...100, stepperStep: 5,
                     shown: "\(session.swing)", spoken: "\(session.swing)", bipolar: false, defaultValue: 0) { session.set(global: Global.swing, to: $0) },
            KnobSpec(id: "home1", colour: Theme.text, label: "LEVEL", value: t.mute ? 0 : t.level, range: 0...127, stepperStep: 8,
                     shown: t.mute ? "0" : "\(pct)", spoken: t.mute ? "muted" : "\(pct) percent", bipolar: false,
                     defaultValue: session.trackDesc(Param.level)?.defaultValue) { v in
                // as on the device, turning LEVEL unmutes the track
                if t.mute { session.set(track: k, param: Param.mute, to: 0) }
                session.set(track: k, param: Param.level, to: v)
            },
            KnobSpec(id: "home2", colour: Theme.text, label: "STEPS", value: t.length, range: 1...session.stepCount, stepperStep: 1,
                     shown: "\(t.length)", spoken: "\(t.length) steps", bipolar: false, defaultValue: 16) { session.set(track: k, param: Param.length, to: $0) },
            KnobSpec(id: "home3", colour: Theme.text, label: "PAN", value: t.pan, range: -64...63, stepperStep: 4,
                     shown: "\(t.pan)", spoken: t.pan == 0 ? "centre" : t.pan < 0 ? "\(-t.pan) left" : "\(t.pan) right",
                     bipolar: true, defaultValue: 0) { session.set(track: k, param: Param.pan, to: $0) },
        ]
    }
}

/// A knob being turned (Shape marks it): its id; `center` is where the finger started.
struct KnobGrab: Equatable {
    var id: String
    var center: CGPoint
}

struct KnobRow: View {
    let session: DeviceSession
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

/// The feel shared by the knob and its big control: a light tick at the ends and, on a knob centred on zero,
/// at the centre; a change clamped to the range.
enum KnobFeel {
    static func clamp(_ v: Int, _ s: KnobSpec) -> Int { min(max(v, s.range.lowerBound), s.range.upperBound) }
    /// Whether going from `a` to `b` reaches an end or crosses the centre.
    static func ticks(_ a: Int, _ b: Int, _ s: KnobSpec) -> Bool {
        guard a != b else { return false }
        if b == s.range.lowerBound || b == s.range.upperBound { return true }
        guard s.bipolar, s.range.contains(0) else { return false }
        return (a < 0) != (b < 0) || b == 0
    }
}

/// Press and hold (0.3 s, a light tap when it takes), then drag: up raises, down lowers, the whole range in about
/// 200 pt, finer the further the finger goes sideways; release to finish. While held the page doesn't scroll and a
/// bubble shows the value; a drag that starts before the hold takes is the page's scroll, so a knob never steals one
/// (Scott, 2026-11-05: "drag straight on" was terrible). Shape's columns turn on a horizontal drag instead. A tap opens
/// the big control at the finger (Done keeps, Cancel puts it back); a double-tap puts the default back (DESC). Light
/// ticks at the ends and a centred knob's middle.
struct KnobControl: View {
    let ui: EditorUI
    var size: CGFloat = 40
    /// The page around it (Shape), told on any touch: touching a knob makes its page the active one (on the FM-1
    /// too when linked), and the knob works at once (a first tap that only activated looked dead, 2026-11-05).
    var activate: (() -> Bool)? = nil
    /// Shape's face (Skiff's column): its number, the track's colour, and whether it's the knob just turned.
    var column: (number: Int, tint: Color, hot: Bool)? = nil
    /// Another face altogether (the mixer's fader), given the knob and whether it's being dragged.
    var face: ((KnobSpec, Bool) -> AnyView)? = nil
    /// Builds the knob's description each time, so it shows live values.
    let make: () -> KnobSpec
    @State private var startValue = 0
    @State private var turned = 0.0           // in value units since the drag began
    @State private var last: CGPoint?
    @State private var start: CGPoint = .zero
    @State private var dragging = false
    @State private var tick = 0
    @State private var engaged = 0             // the hold took: a light haptic

    /// Points of travel for the whole range, straight up.
    static let travel = 200.0
    /// A column's: across.
    static let columnTravel = 240.0

    var body: some View {
        let _ = BodyCounter.tick("KnobControl")
        let spec = make()
        Group {
            if let face {
                face(spec, dragging)
            } else if let c = column {
                ColumnFace(spec: spec, number: c.number, tint: c.tint, hot: c.hot || dragging)
            } else {
                KnobDial(spec: spec, size: size)
            }
        }
            .contentShape(Rectangle())
            // taps as SwiftUI tells them apart (a drag's end never comes for a plain tap in the page's scroll view):
            // a double-tap puts the default back, one alone opens the big control at the finger
            .onTapGesture(count: 2) {
                _ = activate?()
                if let d = spec.defaultValue { change(spec, to: d) }
            }
            .onTapGesture(coordinateSpace: .global) { at in
                _ = activate?()
                ui.knobPanelSpec = make
                ui.knobPanelAt = at
            }
            // a dial: hold, then drag (UIKit's long press: moving first fails it, and the page scrolls)
            .modifier(DialHold(on: column == nil, hold: HoldDrag(began: { p in
                dragging = true
                engaged += 1
                _ = activate?()
                startValue = make().value; turned = 0; last = p; start = p
                ui.knobGrab = KnobGrab(id: make().id, center: p)
            }, changed: { p in
                guard dragging, let l = last else { return }
                let s = make()
                let span = Double(s.range.upperBound - s.range.lowerBound)
                let fine = 1 / (1 + abs(Double(p.x - start.x)) / 60)
                turned += Double(l.y - p.y) / Self.travel * span * fine
                turned = min(max(turned, Double(s.range.lowerBound - startValue)), Double(s.range.upperBound - startValue))
                change(s, to: startValue + Int(turned.rounded()))
                last = p
            }, ended: {
                dragging = false; last = nil
                if ui.knobGrab?.id == make().id { ui.knobGrab = nil }
            })))
            // held: the value in a bubble above the knob
            .overlay(alignment: .top) {
                if dragging, column == nil, face == nil {
                    Text(spec.shown).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 10).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.text))
                        .fixedSize()
                        .offset(y: -34)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // a column: a horizontal pan of UIKit's, so the scroll view keeps every vertical drag
            .modifier(ColumnPan(on: column != nil, pan: HorizontalPan(began: { p in
                guard column != nil else { return }
                dragging = true
                _ = activate?()
                startValue = make().value; turned = 0; last = p
                ui.knobGrab = KnobGrab(id: make().id, center: p)
            }, changed: { p in
                guard column != nil, dragging, let l = last else { return }
                let s = make()
                let span = Double(s.range.upperBound - s.range.lowerBound)
                turned += Double(p.x - l.x) / Self.columnTravel * span     // right raises, the range in about 240 pt
                turned = min(max(turned, Double(s.range.lowerBound - startValue)), Double(s.range.upperBound - startValue))
                change(s, to: startValue + Int(turned.rounded()))
                last = p
            }, ended: {
                dragging = false; last = nil
                if ui.knobGrab?.id == make().id { ui.knobGrab = nil }
            })))
            .sensoryFeedback(.impact(weight: .light), trigger: tick)
            .sensoryFeedback(.impact(weight: .light), trigger: engaged)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spec.label.capitalized)
            .accessibilityValue(spec.spoken)
            .accessibilityAdjustableAction { dir in
                change(spec, to: spec.value + (dir == .increment ? spec.stepperStep : -spec.stepperStep))
            }
            .accessibilityAction(named: "Open") { ui.knobPanelSpec = make; ui.knobPanelAt = .zero }
            .accessibilityAction(named: "Reset to default") { if let d = spec.defaultValue { change(spec, to: d) } }
    }

    private func change(_ spec: KnobSpec, to v: Int) {
        let n = KnobFeel.clamp(v, spec)
        guard n != spec.value else { return }
        if KnobFeel.ticks(spec.value, n, spec) { tick += 1 }
        spec.set(n)
    }
}

/// The small dial: a coloured ring from the start (or the centre) to the needle, a raised cap.
struct KnobDial: View {
    let spec: KnobSpec
    var size: CGFloat = 40
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 3) {
            let k = size / 40
            Canvas { ctx, sz in drawDial(ctx, sz, fraction: spec.fraction, colour: spec.colour, bipolar: spec.bipolar, radius: 17 * k, line: 4 * k, cap: 11 * k, flat: look.flat) }
                .frame(width: size, height: size)
            Text(spec.label).font(.system(size: size > 40 ? 12 : 11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            Text(spec.shown).font(.system(size: size > 40 ? 15 : 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: size > 40 ? 88 : 56)
    }
}

func drawDial(_ ctx: GraphicsContext, _ size: CGSize, fraction: Double, colour: Color, bipolar: Bool,
              radius: CGFloat, line: CGFloat, cap: CGFloat, flat: Bool = false) {
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
    let rad = a * .pi / 180
    let needle = Path { p in p.move(to: c); p.addLine(to: CGPoint(x: c.x + cap * 0.82 * sin(rad), y: c.y - cap * 0.82 * cos(rad))) }
    if flat {
        // a flat cap on the ring: one tone, no shine, no contact shadow
        ctx.fill(Path(ellipseIn: capRect), with: .color(Theme.tones[2]))
        ctx.stroke(needle, with: .color(Theme.text), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        return
    }
    ctx.fill(Path(ellipseIn: capRect.offsetBy(dx: 0, dy: 1)), with: .color(.black.opacity(0.5)))
    ctx.fill(Path(ellipseIn: capRect), with: .radialGradient(Gradient(colors: [Color(hex: 0x5A5A63), Color(hex: 0x1F1F24)]),
                                                            center: CGPoint(x: capRect.minX + cap * 0.8, y: capRect.minY + cap * 0.6),
                                                            startRadius: 0, endRadius: cap * 1.5))
    ctx.stroke(Path(ellipseIn: capRect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.12)), lineWidth: 1)
    ctx.stroke(needle, with: .color(Theme.text), style: StrokeStyle(lineWidth: 2, lineCap: .round))
}

/// A pan that begins only when the finger moves more across than up or down (UIKit decides, before the scroll view
/// does): Shape's columns turn on a horizontal drag, and a vertical one is the page's scroll from the first point.
struct HorizontalPan: UIGestureRecognizerRepresentable {
    var began: (CGPoint) -> Void
    var changed: (CGPoint) -> Void
    var ended: () -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let p = g as? UIPanGestureRecognizer else { return true }
            let v = p.velocity(in: p.view)
            return abs(v.x) > abs(v.y)
        }
    }
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.delegate = context.coordinator
        g.maximumNumberOfTouches = 1
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UIPanGestureRecognizer, context: Context) {
        let p = context.converter.location(in: .global)
        switch g.state {
        case .began: began(p)
        case .changed: changed(p)
        case .ended, .cancelled, .failed: ended()
        default: break
        }
    }
}

/// The horizontal pan on a column only (a dial keeps its own drag, up and down with a sideways fine control).
private struct ColumnPan: ViewModifier {
    let on: Bool
    let pan: HorizontalPan
    func body(content: Content) -> some View {
        if on { content.gesture(pan) } else { content }
    }
}

/// Press and hold (0.3 s), then drag; moving more than 10 pt before it takes fails it, leaving the touch to the
/// page's scroll. Points are global.
struct HoldDrag: UIGestureRecognizerRepresentable {
    var began: (CGPoint) -> Void
    var changed: (CGPoint) -> Void
    var ended: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let g = UILongPressGestureRecognizer()
        g.minimumPressDuration = 0.3
        g.allowableMovement = 10
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UILongPressGestureRecognizer, context: Context) {
        let p = context.converter.location(in: .global)
        switch g.state {
        case .began: began(p)
        case .changed: changed(p)
        case .ended, .cancelled, .failed: ended()
        default: break
        }
    }
}

/// The hold on a dial only (a column turns by HorizontalPan).
private struct DialHold: ViewModifier {
    let on: Bool
    let hold: HoldDrag
    func body(content: Content) -> some View {
        if on { content.gesture(hold) } else { content }
    }
}

import SloopKit
import SwiftUI

// A knob tapped: a big control at the finger in Jib's own menu style (level 3), no stepper (Scott, 2026-11-05).
// Two to compare on the iPad, Developer › Knob tap: an arc of about 200 pt, its dot dragged anywhere round it,
// or a horizontal slider under the value shown large. A parameter of named choices opens a list instead. Both
// put the default back on a double-tap and from a key, and take a typed number where the value is a plain one.
// Done keeps the value (tapping outside does too, and Return); Cancel puts back the value it had when it opened
// (Escape too). Changes go to the FM-1 as they're made, so it previews live either way (Scott, 2026-11-05).

enum KnobTapStyle: String, CaseIterable, Identifiable {
    case arc, slider
    var id: String { rawValue }
    static let key = "knobTap"
}

/// Where the big control opens: under the finger that tapped, kept on screen.
struct KnobPanelLayer: View {
    @Bindable var ui: EditorUI
    @State private var frame: CGRect = .zero

    var body: some View {
        GeometryReader { g in
            if let at = ui.knobPanelAt, let make = ui.knobPanelSpec {
                let close = { ui.knobPanelAt = nil }
                ZStack(alignment: .topLeading) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                        .accessibilityHidden(true)
                    KnobPanel(make: make, close: close)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in
                            let x = at == .zero ? (g.size.width - d.width) / 2 : at.x - frame.minX - d.width / 2
                            return -min(max(16, x), g.size.width - d.width - 16)
                        }
                        .alignmentGuide(.top) { d in
                            // under the finger, or above it where it wouldn't fit
                            guard at != .zero else { return -(g.size.height - d.height) / 2 }
                            let y = at.y - frame.minY
                            return -(y + 24 + d.height <= g.size.height ? y + 24 : max(16, y - 24 - d.height))
                        }
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

struct KnobPanel: View {
    let make: () -> KnobSpec
    let close: () -> Void
    @AppStorage(KnobTapStyle.key) private var style = KnobTapStyle.arc
    @State private var typed = ""
    @State private var typedProblem: String?
    @State private var tick = 0
    @State private var lastTap: Date?
    @State private var opened: Int?              // the value when it opened, for Cancel
    @Environment(\.look) private var look

    var body: some View {
        let spec = make()
        VStack(alignment: .leading, spacing: 12) {
            Text(spec.label.capitalized).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            if let choices = spec.choices {
                choiceList(spec, choices)
            } else {
                switch style {
                case .arc: arc(spec)
                case .slider: slider(spec)
                }
                if spec.shown == "\(spec.value)" { field(spec) }
                if let d = spec.defaultValue, d != spec.value {
                    Button { change(spec, to: d) } label: {
                        Text("Back to the default").font(.system(size: 15)).frame(maxWidth: .infinity, minHeight: 44).raisedKey()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressSink())
                }
            }
            HStack(spacing: 8) {
                Button { cancel(spec) } label: {
                    Text("Cancel").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Puts back the value it had before")
                Button(action: close) {
                    Text("Done").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.onColour)
                        .frame(maxWidth: .infinity, minHeight: 44).raisedKey(primary: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: spec.choices == nil ? 280 : 260)
        // the one level-3 shadow, on the panel's shape
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .sensoryFeedback(.impact(weight: .light), trigger: tick)
        .onKeyPress(.escape) { cancel(spec); return .handled }
        .background {
            Button("Cancel") { cancel(spec) }.keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
        }
        .onAppear { if opened == nil { opened = spec.value } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(spec.label.capitalized)
        .accessibilityAction(.escape) { cancel(spec) }
    }

    /// Cancel: the value from before it opened, back on the FM-1 too, and closed.
    private func cancel(_ spec: KnobSpec) {
        if let o = opened, o != spec.value { spec.set(o) }
        close()
    }

    // MARK: Arc: the dot dragged anywhere round it, the value in the middle

    private func arc(_ spec: KnobSpec) -> some View {
        let r: CGFloat = 90
        return ZStack {
            Canvas { ctx, sz in
                drawDial(ctx, sz, fraction: spec.fraction, colour: spec.colour, bipolar: spec.bipolar, radius: r, line: 14, cap: 0)
                let a = (-135 + 270 * min(max(spec.fraction, 0), 1)) * .pi / 180
                let p = CGPoint(x: sz.width / 2 + r * sin(a), y: sz.height / 2 - r * cos(a))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)), with: .color(Theme.text))
            }
            Text(spec.shown).font(.system(size: 34, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5).frame(width: 2 * r - 40)
        }
        .frame(width: 2 * r + 30, height: 2 * r + 30)
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            // the angle round the centre, 0 = up, clockwise: the arc runs −135…135; below it, the nearer end
            let c = CGPoint(x: r + 15, y: r + 15)
            let dx = Double(v.location.x - c.x), dy = Double(v.location.y - c.y)
            guard hypot(dx, dy) > 20 else { return }
            let deg = atan2(dx, -dy) * 180 / .pi
            let f = (min(max(deg, -135), 135) + 135) / 270
            change(spec, to: value(spec, at: f))
        }.onEnded { _ in doubleTap(spec) })
        .accessibilityElement()
        .accessibilityLabel(spec.label.capitalized)
        .accessibilityValue(spec.spoken)
        .accessibilityAdjustableAction { dir in change(spec, to: spec.value + (dir == .increment ? spec.stepperStep : -spec.stepperStep)) }
    }

    // MARK: Slider: the value large, a wide track under it

    private func slider(_ spec: KnobSpec) -> some View {
        VStack(spacing: 12) {
            Text(spec.shown).font(.system(size: 40, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5).frame(maxWidth: .infinity)
            GeometryReader { g in
                let w = g.size.width, f = CGFloat(min(max(spec.fraction, 0), 1))
                let from: CGFloat = spec.bipolar ? w / 2 : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.well).frame(height: 10)
                    Capsule().fill(spec.colour).frame(width: abs(w * f - from), height: 10).offset(x: min(from, w * f))
                    Circle().fill(Theme.text).frame(width: 28, height: 28).offset(x: w * f - 14)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    change(spec, to: value(spec, at: Double(min(max(v.location.x / max(1, w), 0), 1))))
                }.onEnded { _ in doubleTap(spec) })
            }
            .frame(height: 44)
            .accessibilityElement()
            .accessibilityLabel(spec.label.capitalized)
            .accessibilityValue(spec.spoken)
            .accessibilityAdjustableAction { dir in change(spec, to: spec.value + (dir == .increment ? spec.stepperStep : -spec.stepperStep)) }
        }
    }

    // MARK: A parameter of named choices: a list

    private func choiceList(_ spec: KnobSpec, _ names: [String]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(names.indices, id: \.self) { k in
                    let v = spec.range.lowerBound + k
                    Button {
                        change(spec, to: v)
                        close()
                    } label: {
                        HStack {
                            Text(names[k]).font(.system(size: 17))
                            Spacer(minLength: 0)
                            if v == spec.value { Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)) }
                        }
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 12).frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(v == spec.value ? .isSelected : [])
                }
            }
        }
        .frame(height: min(CGFloat(names.count) * 52, 52 * 8))
    }

    // MARK: A number typed in (plain values only)

    private func field(_ spec: KnobSpec) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("\(spec.range.lowerBound)–\(spec.range.upperBound)", text: $typed)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.system(size: 17)).monospacedDigit()
                    .onSubmit { setTyped(spec) }
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
                    .accessibilityLabel("\(spec.label.capitalized), \(spec.range.lowerBound) to \(spec.range.upperBound)")
                Button { setTyped(spec) } label: {
                    Text("Set").font(.system(size: 15, weight: .semibold)).padding(.horizontal, 16).frame(minHeight: 44).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(typed.isEmpty)
            }
            if let p = typedProblem {
                Label(p, systemImage: "exclamationmark.circle").font(.system(size: 13)).foregroundStyle(Theme.text)
            }
        }
    }

    private func setTyped(_ spec: KnobSpec) {
        guard let v = Int(typed.trimmingCharacters(in: .whitespaces)) else {
            typedProblem = "Type a whole number, \(spec.range.lowerBound) to \(spec.range.upperBound)"; return
        }
        guard spec.range.contains(v) else { typedProblem = "\(v) is outside \(spec.range.lowerBound)–\(spec.range.upperBound)"; return }
        typedProblem = nil; typed = ""
        change(spec, to: v)
    }

    // MARK: Shared

    private func value(_ spec: KnobSpec, at f: Double) -> Int {
        spec.range.lowerBound + Int((Double(spec.range.upperBound - spec.range.lowerBound) * f).rounded())
    }

    /// A second touch on the dial or slider within 0.3 s: the default back.
    private func doubleTap(_ spec: KnobSpec) {
        let now = Date()
        if let t = lastTap, now.timeIntervalSince(t) < 0.3, let d = spec.defaultValue { lastTap = nil; change(spec, to: d); return }
        lastTap = now
    }

    private func change(_ spec: KnobSpec, to v: Int) {
        let n = KnobFeel.clamp(v, spec)
        guard n != spec.value else { return }
        if KnobFeel.ticks(spec.value, n, spec) { tick += 1 }
        spec.set(n)
    }
}

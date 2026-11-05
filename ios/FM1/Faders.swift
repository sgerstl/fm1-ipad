import SwiftUI

/// The Mixer's sticky fader (Scott, 2026-11-05: simpler than the knobs' hold-then-drag). It takes the finger at
/// once and follows it, one point of finger for one point of travel, from wherever it lands: touching the cap
/// keeps the cap under the finger, touching the track moves the value from where it was, never jumping to the
/// finger. The strips don't scroll, so there's no scroll to wait out. A tap nudges one step toward the side
/// tapped (a jump on a stray touch is a loud surprise while the FM-1 plays; the nudge is safe and fine, and
/// the double-tap is the big move); a double-tap puts the default back. Light ticks at the default (0 dB, the
/// centre) and at the ends; while held the value reads out inverted. Vertical for LEVEL, across for PAN and
/// the sends.
struct Fader: View {
    enum Axis { case vertical, horizontal }

    let axis: Axis
    let spec: KnobSpec
    var tint: Color
    /// One tap's step, in value units (LEVEL: 2, one dB).
    var nudge: Int = 1
    /// Where the haptic tick and the track's mark sit (LEVEL's 0 dB); nil: the default.
    var detent: Int? = nil
    /// Told on every touch (linked, the strips' page goes to the FM-1).
    var touched: () -> Void = {}
    @State private var startValue: Int?
    @State private var moved = false
    @State private var lastTap = Date.distantPast
    @State private var length: CGFloat = 1
    @State private var tick = 0

    private var mark: Int? { detent ?? spec.defaultValue }

    var body: some View {
        Group {
            switch axis {
            case .vertical: vertical
            case .horizontal: horizontal
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tick)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spec.label.capitalized)
        .accessibilityValue(spec.spoken)
        .accessibilityAdjustableAction { dir in
            change(to: spec.value + (dir == .increment ? spec.stepperStep : -spec.stepperStep))
        }
        .accessibilityAction(named: "Reset to default") { if let d = spec.defaultValue { change(to: d) } }
    }

    // MARK: Faces

    private var vertical: some View {
        VStack(spacing: 8) {
            GeometryReader { g in
                let h = g.size.height - Self.cap.height, f = CGFloat(spec.fraction) * h
                ZStack(alignment: .bottom) {
                    Capsule().fill(Theme.stepEmpty).frame(width: 8)
                    Capsule().fill(tint).frame(width: 8, height: max(0, f + Self.cap.height / 2))
                    if let m = mark {
                        // the default's mark, both sides of the track (LEVEL's 0 dB)
                        HStack(spacing: 16) {
                            Rectangle().fill(Theme.textTertiary).frame(width: 10, height: 1)
                            Rectangle().fill(Theme.textTertiary).frame(width: 10, height: 1)
                        }
                        .offset(y: -(CGFloat(fraction(m)) * h + Self.cap.height / 2))
                    }
                    RoundedRectangle(cornerRadius: 3).fill(Theme.text)
                        .frame(width: Self.cap.width, height: Self.cap.height)
                        .offset(y: -f)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .onAppear { length = max(1, h) }
                .onChange(of: h) { _, n in length = max(1, n) }
            }
            .frame(minHeight: 80)
            .contentShape(Rectangle())
            .gesture(drag)
            readout(size: 15)
        }
        .frame(maxWidth: .infinity)
    }

    private var horizontal: some View {
        VStack(spacing: 4) {
            HStack {
                Text(spec.label).font(.system(size: 11, weight: .semibold)).tracking(0.4).foregroundStyle(Theme.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                readout(size: 13)
            }
            GeometryReader { g in
                let w = g.size.width - Self.knob.width, x = CGFloat(spec.fraction) * w
                let from = spec.bipolar ? CGFloat(fraction(0)) * w : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.stepEmpty).frame(height: 6)
                    let lo = spec.bipolar ? min(x, from) + Self.knob.width / 2 : 0, hi = max(x, from) + Self.knob.width / 2
                    Capsule().fill(tint).frame(width: max(0, hi - lo), height: 6).offset(x: lo)
                    if let m = mark {
                        Rectangle().fill(Theme.textTertiary).frame(width: 1, height: 22)
                            .offset(x: CGFloat(fraction(m)) * w + Self.knob.width / 2)
                    }
                    RoundedRectangle(cornerRadius: 3).fill(Theme.text)
                        .frame(width: Self.knob.width, height: Self.knob.height)
                        .offset(x: x)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { length = max(1, w) }
                .onChange(of: w) { _, n in length = max(1, n) }
            }
            .frame(height: 32)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())           // the label's row takes the finger too: about 52 pt high
        .gesture(drag)
    }

    /// The value, inverted while held (the knobs' bubble, in place).
    private func readout(size: CGFloat) -> some View {
        let held = startValue != nil
        return Text(spec.shown).font(.system(size: size, weight: .semibold)).monospacedDigit()
            .lineLimit(1).fixedSize()                   // whole, however narrow the strip: the label gives way
            .foregroundStyle(held ? Theme.onColour : spec.value == spec.range.lowerBound && axis == .vertical ? Theme.textTertiary : Theme.text)
            .padding(.horizontal, held ? 8 : 0).frame(minHeight: size + 9)
            .background(RoundedRectangle(cornerRadius: 6).fill(held ? Theme.text : .clear))
            .accessibilityHidden(true)
    }

    static let cap = CGSize(width: 40, height: 10)
    static let knob = CGSize(width: 10, height: 24)

    // MARK: The touch

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { g in
                if startValue == nil { startValue = spec.value; moved = false; touched() }
                let d = axis == .vertical ? -g.translation.height : g.translation.width
                if !moved, abs(d) < 3, abs(axis == .vertical ? g.translation.width : g.translation.height) < 10 { return }
                moved = true
                let span = Double(spec.range.upperBound - spec.range.lowerBound)
                change(to: (startValue ?? spec.value) + Int((Double(d) / Double(length) * span).rounded()))
            }
            .onEnded { g in
                defer { startValue = nil; moved = false }
                guard !moved else { return }
                let now = Date()
                if now.timeIntervalSince(lastTap) < 0.3, let d = spec.defaultValue {
                    lastTap = .distantPast
                    change(to: d)
                    return
                }
                lastTap = now
                // the side of the cap the tap was on
                let at = axis == .vertical ? length + Self.cap.height - g.location.y - Self.cap.height / 2
                                           : g.location.x - Self.knob.width / 2
                change(to: spec.value + (at > CGFloat(spec.fraction) * length ? nudge : -nudge))
            }
    }

    private func fraction(_ v: Int) -> Double {
        let span = spec.range.upperBound - spec.range.lowerBound
        return span > 0 ? Double(v - spec.range.lowerBound) / Double(span) : 0
    }

    private func change(to v: Int) {
        let n = KnobFeel.clamp(v, spec), a = spec.value
        guard n != a else { return }
        let atEnd = n == spec.range.lowerBound || n == spec.range.upperBound
        let crossed = mark.map { m in n == m || (a != m && (a < m) != (n < m)) } ?? false
        if atEnd || crossed { tick += 1 }
        spec.set(n)
    }
}

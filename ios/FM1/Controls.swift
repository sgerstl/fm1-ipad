import SwiftUI

// Keys you can press: raised (chiclets, on the flat look). A segmented choice sits in a recessed track
// with the chosen segment raised. A toggle sinks in and lights its LED when on.

/// One of several, as raised segments in a well. `selected` -1 means none (shown, but nothing raised).
struct SegmentedKeys: View {
    let label: String
    let options: [String]
    let selected: Int
    var enabled: [Bool]? = nil
    var minWidth: CGFloat = 0
    let choose: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { k, name in
                let on = k == selected
                let ok = enabled?[k] ?? true
                Button { choose(k) } label: {
                    Text(name)
                        .fontWeight(on ? .semibold : .regular)
                        .foregroundStyle(on ? Theme.text : ok ? Theme.textSecondary : Theme.textTertiary)
                        .padding(.horizontal, 12)
                        .frame(minWidth: minWidth, minHeight: 40)
                        .background { if on { Color.clear.raisedKey() } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(!ok)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// On or off: raised when off, sunk with a lit LED when on.
struct ToggleKey: View {
    let name: String
    let on: Bool
    var enabled = true
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                LED(on: on)
                Text(name).fontWeight(on ? .semibold : .regular)
            }
            .foregroundStyle(enabled ? Theme.text : Theme.textTertiary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .latchedKey(on)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: on))
        .disabled(!enabled)
        .accessibilityLabel(name)
        .accessibilityValue(on ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// A top-bar toggle as an icon: off, a grey outline on the bar; on, the filled symbol in white on a
/// raised key (shape and brightness both change, so "on" isn't told by colour alone). No LED: the top
/// bar's text buttons are the tabs, nothing else (2026-11-03).
struct IconKey: View {
    let label: String
    let symbol: String              // the outline symbol; on uses its .fill unless onSymbol says otherwise
    var onSymbol: String?
    let on: Bool
    var enabled = true
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: on ? onSymbol ?? "\(symbol).fill" : symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(!enabled ? Theme.textTertiary : on ? Theme.text : Theme.textSecondary)
                .frame(width: 44, height: 44)
                .background {
                    // flat: on is a latched chiclet, down on its edge
                    if on { LookChoice { Color.clear.raisedKey() } flat: { Color.clear.latchedKey(true) } }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: on))
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// − value + : a number set with taps (WCAG 2.5.7: no drag needed), and swipe up/down with VoiceOver.
struct StepperKeys: View {
    let label: String
    let value: Int
    let range: ClosedRange<Int>
    var step = 8
    var enabled = true
    var format: (Int) -> String = { "\($0)" }
    let set: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            key("minus", "Lower \(label)") { set(max(range.lowerBound, value - step)) }
                .disabled(!enabled || value <= range.lowerBound)
            Text(enabled ? format(value) : "–")
                .font(.system(size: 17, weight: .semibold))
                .frame(minWidth: 48)
                .accessibilityHidden(true)
            key("plus", "Raise \(label)") { set(min(range.upperBound, value + step)) }
                .disabled(!enabled || value >= range.upperBound)
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(enabled ? format(value) : "none")
        .accessibilityAdjustableAction { dir in
            guard enabled else { return }
            set(dir == .increment ? min(range.upperBound, value + step) : max(range.lowerBound, value - step))
        }
    }

    private func key(_ icon: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .raisedKey()
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(a11y)
    }
}

/// Pressing sinks a key a little; disabled keys fade. Flat look: the key drops 2 pt onto its edge
/// (60 ms in, 100 ms out, instant with Reduce Motion), and a `latched` key (a toggle that's on) stays
/// down. Disabled, a flat key loses its edge and top (RaisedKey draws the outline) and its label greys.
struct PressSink: ButtonStyle {
    var latched = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        if look.flat {
            configuration.label
                .environment(\.keyPressed, down)
                .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.textTertiary))
                .offset(y: down || latched ? 2 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: down ? 0.06 : 0.1), value: down)
        } else {
            configuration.label
                .environment(\.keyPressed, down)
                .offset(y: down ? 1 : 0)
                .brightness(down ? -0.06 : 0)
                .opacity(enabled ? 1 : 0.45)
        }
    }
}

/// Developer settings, in debug builds only: the look experiment's switch (2026-11-05). Sits at the foot
/// of the connection menu on the iPad and the ⋯ menu on the phone, the app's only settings menus.
struct DeveloperMenu: View {
    @AppStorage(Look.styleKey) private var style = LookStyle.flat
    @Environment(FirmwareCentre.self) private var firmware

    var body: some View {
        #if DEBUG
        Menu("Developer") {
            Button("Install firmware…") { firmware.pickerNote = nil; firmware.showPicker = true }
            Picker("Look", selection: $style) {
                Text("Flat").tag(LookStyle.flat)
                Text("Physical").tag(LookStyle.physical)
            }
        }
        #endif
    }
}

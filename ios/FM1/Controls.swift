import SwiftUI

// Keys you can press: raised. A segmented choice sits in a recessed track with the chosen segment
// raised (as the tabs). A toggle sinks in and lights its LED when on.

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
            .background {
                if on { RoundedRectangle(cornerRadius: 9).fill(Theme.pressed).recessed(9) } else { Color.clear.raisedKey() }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!enabled)
        .accessibilityLabel(name)
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

/// Pressing sinks a key a little; disabled keys fade.
struct PressSink: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .opacity(enabled ? 1 : 0.45)
    }
}

import SloopKit
import SwiftUI

// The tempo, from the top bar's BPM: a panel at the readout in Lupe's own menu style (level 3). The BPM is a column like
// every other value (Scott, 2026-11-09, option A): slide it to set, tap the number for a keypad in the panel; beside it
// a big square Tap. Following another clock (CLOCK / SYNC = USB or TRS) it's all off, and says why. BPM LOCK doesn't stop
// it: that only makes the FM-1's SELECT knob need GLO held (Skiff ui_input.c).

/// Where the tempo panel opens (global): under the readout that was tapped. It grows out of the readout and shrinks
/// back into it (Scott, 2026-11-06: it used to pop in): scale and opacity anchored at the readout, a short spring in
/// and a quicker ease out; Reduce Motion, a fade. Only the transform and opacity move: the panel's one shadow is on
/// its plain background shape, so nothing re-blurs per frame on a 120 Hz iPad.
struct TempoOverlay: View {
    let session: DeviceSession
    @Bindable var ui: EditorUI
    @State private var frame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The panel's width (TempoPanel's frame) and half the top bar's readout (ReadoutLabel's 112 + 16): where it
    /// grows from. The phone's readout is narrower; a few points off at that size and speed don't show.
    private static let width: CGFloat = 300, readoutHalf: CGFloat = 64

    var body: some View {
        let open = ui.tempoAt != nil
        GeometryReader { g in
            // the panel conditional on its own (not inside the catcher's stack), so its transition is the one that runs
            ZStack(alignment: .topLeading) {
                Color.clear.allowsHitTesting(false)   // the layer's full size, for the placement; takes no touches
                if let at = ui.tempoAt {
                    let left = min(max(16, at.x - frame.minX), g.size.width - Self.width - 16)
                    // the readout's middle, over the panel's top edge
                    let anchor = UnitPoint(x: min(1, max(0, (at.x - frame.minX + Self.readoutHalf - left) / Self.width)), y: 0)
                    TempoPanel(session: session, ui: ui) { ui.tempoAt = nil }
                        .fixedSize()
                        .closesOnOutsideTouch { ui.tempoAt = nil }
                        .alignmentGuide(.leading) { _ in -left }
                        .alignmentGuide(.top) { _ in -(at.y - frame.minY + 8) }
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.2, anchor: anchor).combined(with: .opacity))
                }
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        .animation(reduceMotion ? .easeOut(duration: open ? 0.15 : 0.1)
                                : open ? .spring(duration: 0.25, bounce: 0.12) : .easeIn(duration: 0.15), value: open)
        .globalFrame($frame)
    }
}

struct TempoPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    let close: () -> Void
    /// The keypad's open, and the digits typed so far.
    @State private var typing = false
    @State private var typed = ""
    @State private var typedProblem: String?
    @State private var taps: [Date] = []

    private var range: ClosedRange<Int> { session.bpmRange }
    private var following: String? { session.externalClock }
    static let tapSide: CGFloat = 76

    var body: some View {
        let off = following != nil
        VStack(alignment: .leading, spacing: 12) {
            // (no heading: the column says TEMPO)
            HStack(spacing: 8) {
                KnobControl(ui: ui, tapped: { if !off { openKeypad() } }, column: (number: 0, tint: Theme.text, hot: false)) { spec }
                    .frame(height: Self.tapSide)
                    .overlay { if typing { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.text, lineWidth: 2).allowsHitTesting(false) } }
                    .disabled(off)
                    .opacity(off ? 0.5 : 1)
                    .accessibilityHint("Slide to set it. Tap to type a number")
                Button(action: tap) {
                    Text("Tap").font(.lupe(17, .semibold))
                        .frame(width: Self.tapSide, height: Self.tapSide).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(off || typing)
                .accessibilityLabel("Tap tempo")
                .accessibilityHint("Tap in time: the tempo follows the last few taps")
            }
            if typing { keypad }
            if let p = typedProblem {
                Label(p, systemImage: "exclamationmark.circle").font(.lupe(13)).foregroundStyle(Theme.text)
            }
            if let f = following {
                Label("Following \(f) clock: the tempo comes from the other device. Set CLOCK to INT on the FM-1 to set it here.",
                      systemImage: "metronome")
                    .font(.lupe(13)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !typing {
                Text("\(range.lowerBound)–\(range.upperBound) BPM · slide, or tap to type")
                    .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(width: 300)
        // the one level-3 shadow, the panel's: on its shape, not the stack (which would shade every row and key)
        .elevated(.held, radius: 12)
        .task { await session.refreshTempo() }
        .onKeyPress(.upArrow) { session.setBPM(session.bpm + 1); return .handled }
        .onKeyPress(.downArrow) { session.setBPM(session.bpm - 1); return .handled }
        .onKeyPress(.escape) { if typing { typing = false } else { close() }; return .handled }
        .background {
            Button("Close tempo", action: close).keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tempo")
        .accessibilityAction(.escape) { close() }
    }

    /// The tempo as a column (the sound panel's): what's typed while the keypad is open, else the BPM.
    private var spec: KnobSpec {
        let shown = typing ? (typed.isEmpty ? "–" : typed) : "\(session.bpm)"
        return KnobSpec(id: "tempo", colour: Theme.text, label: "TEMPO", value: session.bpm, range: range, stepperStep: 1,
                        shown: "\(shown) BPM", spoken: "\(session.bpm) BPM", bipolar: false, defaultValue: 120) { session.setBPM($0) }
    }

    /// The panel's own keypad (not the system keyboard, which would cover the page): digits, delete, Set.
    private var keypad: some View {
        let keys: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "Set"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(keys, id: \.self) { k in
                Button { press(k) } label: {
                    Group {
                        if k == "⌫" { Image(systemName: "delete.left") } else { Text(k) }
                    }
                    .font(.lupe(k == "Set" ? 15 : 19, .semibold)).monospacedDigit()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .raisedKey(primary: k == "Set")
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(k == "Set" && typed.isEmpty)
                .accessibilityLabel(k == "⌫" ? "Delete" : k == "Set" ? "Set tempo" : k)
            }
        }
        .transition(.opacity)
    }

    private func openKeypad() {
        typed = ""
        typedProblem = nil
        typing = true
    }

    private func press(_ k: String) {
        switch k {
        case "⌫": typed = String(typed.dropLast()); typedProblem = nil
        case "Set": setTyped()
        default: if typed.count < 3 { typed += k; typedProblem = nil }
        }
    }

    /// Tap tempo: the average of the last few intervals (four at most); a pause of 2 s starts over.
    private func tap() {
        let now = Date()
        if let last = taps.last, now.timeIntervalSince(last) > 2 { taps = [] }
        taps = Array((taps + [now]).suffix(5))
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        let avg = gaps.reduce(0, +) / Double(gaps.count)
        session.setBPM(Int((60 / avg).rounded()))
    }

    /// The typed number, checked on Set: in range, or said what's wrong (the keypad stays open to fix it).
    private func setTyped() {
        guard let v = Int(typed) else { return }
        guard range.contains(v) else {
            typedProblem = "\(v) is outside \(range.lowerBound)–\(range.upperBound) BPM"
            return
        }
        typedProblem = nil
        typed = ""
        typing = false
        session.setBPM(v)
    }
}

import SloopKit
import SwiftUI

// The tempo, from the top bar's BPM (Scott, 2026-11-05): a panel at the finger in Jib's own menu style
// (level 3, as the Arrange hold menu): the BPM large between − and + (hold to repeat, speeding up), Tap tempo,
// a number typed in with its range. Following another clock (CLOCK / SYNC = USB or TRS) it's all off, and says
// why. BPM LOCK doesn't stop it: that only makes the FM-1's SELECT knob need GLO held (Skiff ui_input.c).

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
                if open {
                    Color.clear.contentShape(Rectangle()).onTapGesture { ui.tempoAt = nil }
                        .accessibilityHidden(true)
                }
                if let at = ui.tempoAt {
                    let left = min(max(16, at.x - frame.minX), g.size.width - Self.width - 16)
                    // the readout's middle, over the panel's top edge
                    let anchor = UnitPoint(x: min(1, max(0, (at.x - frame.minX + Self.readoutHalf - left) / Self.width)), y: 0)
                    TempoPanel(session: session) { ui.tempoAt = nil }
                        .fixedSize()
                        .alignmentGuide(.leading) { _ in -left }
                        .alignmentGuide(.top) { _ in -(at.y - frame.minY + 8) }
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.2, anchor: anchor).combined(with: .opacity))
                }
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        .animation(reduceMotion ? .easeOut(duration: open ? 0.15 : 0.1)
                                : open ? .spring(duration: 0.25, bounce: 0.12) : .easeIn(duration: 0.15), value: open)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

struct TempoPanel: View {
    let session: DeviceSession
    let close: () -> Void
    @State private var typed = ""
    @State private var typedProblem: String?
    @State private var taps: [Date] = []
    @FocusState private var fieldFocused: Bool
    @Environment(\.look) private var look

    private var range: ClosedRange<Int> { session.bpmRange }
    private var following: String? { session.externalClock }

    var body: some View {
        let off = following != nil
        VStack(alignment: .leading, spacing: 12) {
            Text("Tempo").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                RepeatKey(symbol: "minus", label: "Slower", enabled: !off && session.bpm > range.lowerBound) { session.setBPM(session.bpm - 1) }
                Text("\(session.bpm)").font(.system(size: 44, weight: .semibold)).monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(off ? Theme.textSecondary : Theme.text)
                    .accessibilityElement()
                    .accessibilityLabel("Tempo")
                    .accessibilityValue("\(session.bpm) BPM")
                    .accessibilityAdjustableAction { dir in
                        guard !off else { return }
                        session.setBPM(session.bpm + (dir == .increment ? 1 : -1))
                    }
                RepeatKey(symbol: "plus", label: "Faster", enabled: !off && session.bpm < range.upperBound) { session.setBPM(session.bpm + 1) }
            }
            if let f = following {
                Label("Following \(f) clock: the tempo comes from the other device. Set CLOCK to INT on the FM-1 to set it here.",
                      systemImage: "metronome")
                    .font(.system(size: 13)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(range.lowerBound)–\(range.upperBound) BPM").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            Button(action: tap) {
                Text(taps.count >= 2 ? "Tap tempo · \(taps.count) taps" : taps.count == 1 ? "Tap again…" : "Tap tempo")
                    .font(.system(size: 17)).frame(maxWidth: .infinity, minHeight: 52).raisedKey()
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(off)
            .accessibilityHint("Tap in time: the tempo follows the last few taps")
            HStack(spacing: 8) {
                TextField("Type a BPM", text: $typed)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17)).monospacedDigit()
                    .focused($fieldFocused)
                    .onSubmit(setTyped)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
                    .accessibilityLabel("Tempo in BPM, \(range.lowerBound) to \(range.upperBound)")
                Button(action: setTyped) {
                    Text("Set").font(.system(size: 15, weight: .semibold)).padding(.horizontal, 16).frame(minHeight: 44).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(typed.isEmpty)
                .accessibilityLabel("Set tempo")
            }
            .disabled(off)
            if let p = typedProblem {
                Label(p, systemImage: "exclamationmark.circle").font(.system(size: 13)).foregroundStyle(Theme.text)
            }
        }
        .padding(16)
        .frame(width: 300)
        // the one level-3 shadow, the panel's: on its shape, not the stack (which would shade every row and key)
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .task { await session.refreshTempo() }
        .onKeyPress(.upArrow) { session.setBPM(session.bpm + 1); return .handled }
        .onKeyPress(.downArrow) { session.setBPM(session.bpm - 1); return .handled }
        .onKeyPress(.escape) { close(); return .handled }
        .background {
            Button("Close tempo", action: close).keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Tempo")
        .accessibilityAction(.escape) { close() }
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

    /// The typed number, checked on Set (or Return): in range, or said what's wrong.
    private func setTyped() {
        guard let v = Int(typed.trimmingCharacters(in: .whitespaces)) else {
            typedProblem = "Type a whole number, \(range.lowerBound) to \(range.upperBound)"
            return
        }
        guard range.contains(v) else {
            typedProblem = "\(v) is outside \(range.lowerBound)–\(range.upperBound) BPM"
            return
        }
        typedProblem = nil
        typed = ""
        fieldFocused = false
        session.setBPM(v)
    }
}

/// − or +: a press steps once; held, it repeats, faster the longer it's held (0.4 s, then every 0.15 s, every
/// 0.05 s after 1.5 s). A chiclet that sinks while pressed, as PressSink's do.
struct RepeatKey: View {
    let symbol: String
    let label: String
    var enabled = true
    let step: () -> Void
    @State private var pressed = false
    @State private var repeating: Task<Void, Never>?

    var body: some View {
        Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
            .foregroundStyle(enabled ? Theme.text : Theme.textTertiary)
            .frame(width: 52, height: 52)
            .raisedKey()
            .environment(\.keyPressed, pressed)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 30, maximumDistance: 44, perform: {}) { down in
                guard enabled else { return }
                pressed = down
                repeating?.cancel()
                guard down else { return }
                step()
                repeating = Task { @MainActor in
                    let start = Date()
                    try? await Task.sleep(for: .milliseconds(400))
                    while !Task.isCancelled {
                        step()
                        try? await Task.sleep(for: .milliseconds(Date().timeIntervalSince(start) > 1.5 ? 50 : 150))
                    }
                }
            }
            .onDisappear { repeating?.cancel() }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { step() } }
    }
}

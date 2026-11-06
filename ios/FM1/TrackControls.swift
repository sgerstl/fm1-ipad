import SloopKit
import SwiftUI

// The Song tab's whole-track controls. 2026-11-05: SWING, LEVEL, STEPS and PAN in a popover under the selected lane's
// header. 2026-11-06 (Scott): no popover and no key for it; a small grey box with the knobs sits at the right end of
// the timeline just under the selected lane (above it on the last lanes), no header, no title, and a knob turns on a
// slide up or down from the first touch. SWING is left out: it sets every track, so in a box under one lane it read as
// that track's; it stays on the Mixer's Global card. The FM-1's PATTERN button lights the box (its flash ring).

/// LEVEL, STEPS and PAN of the selected track, at the timeline's right end (SkiffArrangePage places it).
struct TrackKnobBox: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.look) private var look

    static let height: CGFloat = 52
    /// KnobSpec.all's LEVEL, STEPS, PAN (0 is SWING, global).
    static let knobs = 1..<4

    var body: some View {
        let t = session.selectedTrack
        HStack(spacing: 4) {
            ForEach(Self.knobs, id: \.self) { k in
                SlideKnob(ui: ui) { KnobSpec.all(session)[k] }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: Self.height)
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .flashRing(ui, .trackPanel)
        // the SEQ pad's TRACK page still asks for the popover by name (SoundPanel): light the box instead
        .onChange(of: ui.trackControlsOpen) { _, open in
            guard open else { return }
            ui.trackControlsOpen = false
            ui.flash = Flash(target: .trackPanel, id: (ui.flash?.id ?? 0) + 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(t + 1) knobs")
    }
}

/// A small dial with its name and value beside it. Slide up to raise, down to lower, from the first point: the whole
/// range in about 200 pt, finer the further the finger goes sideways. The box sits outside the lanes' horizontal
/// scroll and the top half doesn't scroll up and down, so the drag takes nothing from a scroll. A tap opens the big
/// control at the finger (the way without a drag), a double-tap puts the default back; light ticks at the ends and a
/// centred knob's middle.
struct SlideKnob: View {
    let ui: EditorUI
    let make: () -> KnobSpec
    @State private var from: Int?
    @State private var tick = 0
    @Environment(\.look) private var look

    var body: some View {
        let spec = make()
        HStack(spacing: 6) {
            Canvas { ctx, sz in
                drawDial(ctx, sz, fraction: spec.fraction, colour: spec.colour, bipolar: spec.bipolar, radius: 13, line: 3, cap: 8, flat: look.flat)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(spec.label).font(.system(size: 11)).foregroundStyle(Theme.textSecondaryRaised)
                Text(spec.shown).font(.system(size: 13, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 40, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        // turning: the knob's own place lifts a tone
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.tones[3]).opacity(from == nil ? 0 : 1))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if let d = spec.defaultValue { change(spec, to: d) } }
        .onTapGesture(coordinateSpace: .global) { at in
            ui.knobPanelSpec = make
            ui.knobPanelAt = at
        }
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { v in
                let s = make()
                if from == nil { from = s.value }
                let span = Double(s.range.upperBound - s.range.lowerBound)
                let fine = 1 / (1 + abs(Double(v.translation.width)) / 60)
                change(s, to: (from ?? s.value) + Int((-Double(v.translation.height) / KnobControl.travel * span * fine).rounded()))
            }
            .onEnded { _ in from = nil })
        .sensoryFeedback(.impact(weight: .light), trigger: tick)
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

/// A lane header's chip, which mutes (Scott, 2026-11-06, as SLOOP's Song tab did): on the selected track a tap mutes
/// and unmutes, on another it selects. To VoiceOver it's the track's mute switch on every lane (the name beside it
/// selects), so muting another track is one action there too.
struct MuteChip: View {
    let session: DeviceSession
    let track: Int
    let selected: Bool
    var size: CGFloat = 28

    var body: some View {
        Toggle(isOn: Binding(get: { session.tracks[track].mute },
                             set: { if $0 != session.tracks[track].mute { session.toggleMute(track: track) } })) {
            Text("Mute track \(track + 1)")
        }
        .toggleStyle(MuteChipStyle(track: track, selected: selected, size: size) { session.select(track: track) })
    }
}

private struct MuteChipStyle: ToggleStyle {
    let track: Int
    let selected: Bool
    let size: CGFloat
    let select: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        Button { selected ? configuration.isOn.toggle() : select() } label: {
            TrackChip(track: track, size: size, muted: configuration.isOn, selected: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: configuration.isOn))
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

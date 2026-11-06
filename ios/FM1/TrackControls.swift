import SloopKit
import SwiftUI

// The Song tab's whole-track controls. 2026-11-05: SWING, LEVEL, STEPS and PAN in a popover under the selected lane's
// header. 2026-11-06 (Scott): no popover and no key for it; a small grey box with the knobs sits at the right end of
// the timeline just under the selected lane (above it on the last lanes), no header, no title, and a knob turns on a
// slide up or down from the first touch. SWING is left out: it sets every track, so in a box under one lane it read as
// that track's; it stays on the Mixer's Global card. The FM-1's PATTERN button lights the box (its flash ring).

/// The selected track's knobs at the timeline's right end (SkiffArrangePage places it): HOME's four, then LEVEL, STEPS, PAN.
struct TrackKnobBox: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.look) private var look

    /// Two rows (Scott, 2026-11-06): the FM-1's four knobs as HOME has them for this sound, then LEVEL, STEPS, PAN.
    static let height: CGFloat = 100
    /// KnobSpec.all's LEVEL, STEPS, PAN (0 is SWING, global).
    static let knobs = 1..<4

    /// What KNOB 1…4 turn on Skiff's HOME: the engine's four main parameters (Skiff 2.2, each eng_*.c's `.knob`).
    /// 0…7 are the engine's own (P_E0…P_E7, from INFO's first engine parameter); ATK and REL are the shared envelope's.
    enum HomeParam { case e(Int), atk, rel }
    static let homeKnobs: [[HomeParam]] = [
        [.e(4), .e(5), .atk, .rel],          // 0 ANALOG
        [.e(4), .e(5), .e(6), .rel],         // 1 DIGITAL (retired)
        [.e(2), .e(3), .e(4), .rel],         // 2 PHASE
        [.e(1), .e(2), .e(3), .rel],         // 3 LOFI
        [.e(0), .e(4), .atk, .rel],          // 4 SAMPLE
        [.e(0), .e(4), .e(5), .e(2)],        // 5 VOICE
        [.e(5), .e(6), .e(7), .e(1)],        // 6 TRIO
        [.e(0), .e(4), .e(6), .e(7)],        // 7 WHEEL
        [.e(1), .e(2), .e(3), .e(5)],        // 8 GRAIN
        [.e(1), .e(2), .e(3), .e(4)],        // 9 PHYS
        [.e(1), .e(2), .e(3), .e(4)],        // 10 DRUM
        [.e(2), .e(3), .e(1), .rel],         // 11 NOISE
        [.e(2), .e(3), .e(4), .e(7)],        // 12 FM6
        [.e(0), .e(1), .e(3), .e(6)],        // 13 SLICE
        [.e(0), .e(1), .e(2), .e(3)],        // 14 DRUM-X
    ]
    static func homeIDs(_ session: DeviceSession) -> [Int] {
        guard session.dialect == .skiff, let e0 = session.info?.firstEngineParam,
              let row = homeKnobs[safe: session.tracks[session.selectedTrack].engine] else { return [] }
        return row.map { switch $0 { case .e(let n): e0 + n; case .atk: 1; case .rel: 4 } }
    }

    var body: some View {
        let t = session.selectedTrack
        let home = Self.homeIDs(session)
        VStack(alignment: .leading, spacing: 4) {
            // HOME's four, in the FM-1's knob colours; turning one turns that knob's parameter on the FM-1 too
            if !home.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(home.enumerated()), id: \.offset) { k, id in
                        SlideKnob(ui: ui) { KnobSpec.param(session, scope: 0, id: id, slot: k) }
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(Self.knobs, id: \.self) { k in
                    SlideKnob(ui: ui) { KnobSpec.all(session)[k] }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(height: Self.homeIDs(session).isEmpty ? 52 : Self.height)
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
                Text(spec.label).font(.system(size: 11)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1).minimumScaleFactor(0.8)
                Text(spec.shown).font(.system(size: 13, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 56, alignment: .leading)          // RELEASE, CUTOFF on one line (HOME's names are longer)
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
        .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)      // (global: the loupe follows the finger)
            .onChanged { v in
                let s = make()
                if from == nil { from = s.value; ui.loupe.show(make, .dial, at: v.location) } else { ui.loupe.finger = v.location }
                let span = Double(s.range.upperBound - s.range.lowerBound)
                let fine = 1 / (1 + abs(Double(v.translation.width)) / 60)
                change(s, to: (from ?? s.value) + Int((-Double(v.translation.height) / KnobControl.travel * span * fine).rounded()))
            }
            .onEnded { _ in from = nil; ui.loupe.hide() })
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

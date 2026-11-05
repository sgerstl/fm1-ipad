import SloopKit
import SwiftUI

// Skiff's GLO pages as the Mixer tab (Scott, 2026-11-05: "we might want a mixer tab"; it replaced the bottom panel
// and the mixer key beside the tempo). Song · Shape · Mixer · Browse. The six tracks' strips (Skiff's MIXER, GR_TRK)
// given the room, then the shared Delay, Reverb, Chorus and Global as Shape's cards (their columns over GR_DELAY,
// GR_REVERB, GR_CHORUS, GR_GLOBAL). GLO on the FM-1 (or its pad here) lands here, and again steps the sections;
// linked, a section touched here shows its page on the FM-1.

struct MixerPage: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var marks = ShapeMarks()

    var body: some View {
        let shared = SoundPage.pages(session).filter { $0.family == .glo }
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        header("MIXER", lit: ui.mixerSection == .mixer)
                        MixerStrips(session: session, ui: ui)
                            .frame(height: 452)
                            .padding(16)
                            .panel()
                            .overlay(alignment: .top) { DeviceEdge(on: onDevice(30)) }
                            .contentShape(Rectangle())
                            .onTapGesture { show(.mixer) }
                            .accessibilityAction(named: "Show on the FM-1") { show(.mixer) }
                    }
                    .id(SkiffButtonMap.MixerTab.mixer)
                    if !shared.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            header("SHARED", lit: ui.mixerSection != .mixer)
                            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                                ForEach(Array(stride(from: 0, to: shared.count, by: 2)), id: \.self) { i in
                                    GridRow(alignment: .top) {
                                        card(shared[i], shared)
                                        if i + 1 < shared.count { card(shared[i + 1], shared) }
                                        else { Color.clear.gridCellUnsizedAxes([.vertical]) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: ui.mixerSection) { _, t in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(t, anchor: .top) }
            }
            .onAppear { proxy.scrollTo(ui.mixerSection, anchor: .top) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func card(_ p: SoundPage, _ pages: [SoundPage]) -> some View {
        SoundCard(session: session, ui: ui, rows: [p], pages: pages, marks: marks).equatable()
            .id(SkiffButtonMap.MixerTab.allCases.first { $0.pageTitle == p.title })
    }

    private func header(_ title: String, lit: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold)).tracking(0.6)
                .foregroundStyle(lit ? Theme.text : Theme.textSecondary)
            Rectangle().fill(Theme.stepEmpty).frame(height: 1)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func onDevice(_ page: Int) -> Bool {
        session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == page } == true
    }

    private func show(_ t: SkiffButtonMap.MixerTab) {
        ui.mixerSection = t
        if session.screenLinked, ui.followDevice, !onDevice(t.page) { session.showOnDevice(page: t.page) }
    }
}

/// The page on the FM-1's screen: a lit edge along a panel's top, as Shape's cards have it.
struct DeviceEdge: View {
    let on: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5).fill(Theme.text)
            .frame(height: 3)
            .padding(.horizontal, 14)
            .offset(y: 1)
            .glow(Theme.text.opacity(0.7), radius: 6)
            .opacity(on ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: on)
            .accessibilityHidden(true)
    }
}

// MARK: Mixer: six strips (ui_graph.c mix_strip)

/// Skiff's MIXER as six strips side by side: the number and the sound's first word, LEVEL a fader in the track's
/// colour (its dB under it, OFF at 0), PAN (L, C, R), the REVERB send, MUTE. Every track's REVERB is read when the
/// tab opens and every few seconds while it's up (the protocol doesn't push another track's parameters).
struct MixerStrips: View {
    let session: DeviceSession
    let ui: EditorUI

    private var revID: Int? { SoundPage.pages(session).first { $0.title == "FX" }?.ids[safe: 3] ?? nil }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(session.trackIndices), id: \.self) { t in strip(t) }
        }
        .task(id: revID) {
            guard let id = revID else { return }
            while !Task.isCancelled {
                await session.readEveryTrack(id: id)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func strip(_ t: Int) -> some View {
        let track = session.tracks[t], colour = Theme.track[t], selected = t == session.selectedTrack
        // the sound's first word, as Skiff names a strip (ACID, PAD, PULSE)
        let sound = track.presetName.isEmpty ? track.displayName : track.presetName.capitalized
        let name = sound.split(separator: " ").first.map(String.init) ?? ""
        return VStack(spacing: 8) {
            Button { session.select(track: t) } label: {
                HStack(spacing: 6) {
                    Text("\(t + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.onColour)
                        .frame(width: 24, height: 24).background(RoundedRectangle(cornerRadius: 6).fill(colour))
                    Text(name).font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(track.mute ? Theme.textTertiary : Theme.text).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track \(t + 1), \(track.displayName)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            KnobControl(ui: ui, face: { spec, dragging in
                AnyView(FaderFace(spec: spec, tint: track.mute ? Theme.textTertiary : colour, hot: dragging))
            }) { levelSpec(t) }
            .frame(maxHeight: .infinity)
            HStack(spacing: 4) {
                KnobControl(ui: ui, size: 40) { panSpec(t) }
                if let id = revID { KnobControl(ui: ui, size: 40) { revSpec(t, id) } }
            }
            Button { session.set(track: t, param: Param.mute, to: track.mute ? 0 : 1) } label: {
                Text("MUTE").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(track.mute ? Theme.onColour : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(track.mute ? Theme.text : Theme.control))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel("Mute track \(t + 1)")
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(track.mute ? "muted" : "playing")
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(selected ? colour.opacity(0.14) : Theme.well))
        .accessibilityElement(children: .contain)
    }

    /// LEVEL as Skiff writes it under the fader: its dB ((v − 112) / 2), OFF at 0.
    static func dB(_ v: Int) -> String {
        guard v > 0 else { return "OFF" }
        let d = (v - 112) * 5
        return "\((d + (d < 0 ? -5 : 5)) / 10) dB"
    }
    /// PAN as Skiff writes it (pan_txt): C, L100…, R100 at the top.
    static func pan(_ p: Int) -> String { p == 0 ? "C" : p < 0 ? "L\(-p * 100 / 64)" : "R\(p * 100 / 63)" }

    private func levelSpec(_ t: Int) -> KnobSpec {
        let tr = session.tracks[t]
        return KnobSpec(id: "mix.level\(t)", colour: Theme.track[t], label: "LEVEL", value: tr.level, range: 0...127, stepperStep: 8,
                        shown: Self.dB(tr.level), spoken: tr.level == 0 ? "off" : Self.dB(tr.level).replacingOccurrences(of: "dB", with: "decibels"),
                        bipolar: false, defaultValue: session.trackDesc(Param.level)?.defaultValue) { v in
            session.set(track: t, param: Param.level, to: v)
        }
    }
    private func panSpec(_ t: Int) -> KnobSpec {
        let p = session.tracks[t].pan
        return KnobSpec(id: "mix.pan\(t)", colour: Theme.track[t], label: "PAN", value: p, range: -64...63, stepperStep: 4,
                        shown: Self.pan(p), spoken: p == 0 ? "centre" : p < 0 ? "\(-p) left" : "\(p) right",
                        bipolar: true, defaultValue: 0) { session.set(track: t, param: Param.pan, to: $0) }
    }
    private func revSpec(_ t: Int, _ id: Int) -> KnobSpec {
        let v = t == session.selectedTrack && id < session.params.count ? session.params[id] : session.everyTrack[id]?[t] ?? 0
        let d = session.trackDesc(id), f = formatValue(d, v)
        return KnobSpec(id: "mix.rev\(t)", colour: Theme.track[t], label: "REV", value: v, range: (d?.min ?? 0)...(d?.max ?? 127),
                        stepperStep: 8, shown: f.shown, spoken: f.spoken, bipolar: false, defaultValue: d?.defaultValue) {
            session.set(track: t, param: id, to: $0)
        }
    }
}

/// The fader: the track from the foot, filled to LEVEL in the track's colour, a white cap; the dB under it.
private struct FaderFace: View {
    let spec: KnobSpec
    let tint: Color
    let hot: Bool

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { g in
                let h = g.size.height, f = CGFloat(min(max(spec.fraction, 0), 1)) * h
                ZStack(alignment: .bottom) {
                    Capsule().fill(Theme.stepEmpty).frame(width: 8)
                    Capsule().fill(tint).frame(width: 8, height: max(0, f))
                    RoundedRectangle(cornerRadius: 2).fill(hot ? Theme.text : Theme.text.opacity(0.9))
                        .frame(width: 30, height: 5).offset(y: -max(0, f - 2.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(minHeight: 60)
            Text(spec.shown).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                .foregroundStyle(spec.value == 0 ? Theme.textTertiary : Theme.text)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Where the FM-1's buttons land (SkiffButtonMap)

enum SkiffNavigator {
    /// The FM-1 changed screen: go where its button lands in Jib (linked only; on stock Skiff nothing moves).
    @MainActor static func follow(_ s: UIState, session: DeviceSession, ui: EditorUI) {
        guard ui.followDevice, session.screenLinked, let place = SkiffButtonMap.place(for: s) else { return }
        if case .mixer(let t) = place { if ui.mixerSection != t { ui.mixerSection = t }; go(.mixer, ui); return }
        switch place {
        case .home: go(.sequencer, ui)
        case .shape(let p):
            if s.layer == SkiffButtonMap.keysLayer { ui.soundFamily = .sel }
            else if let page = SoundPage.page(session, fw: p) { ui.soundFamily = page.family }
            ui.pageFromDevice = true
            go(.sound, ui)
        case .sequence(let f):
            go(.sequencer, ui)
            flash(f == .pattern ? .trackPanel : f == .automation ? .grid : .stepPanel, ui)
        case .arrange(let patterns):
            go(.song, ui)
            if patterns { flash(.patternBin, ui) }
        case .browse: go(.library, ui)
        case .projects:
            // the Projects sheet, where this firmware has projects (SLOOP's backups; Skiff 2.2 has none)
            if session.capabilities.contains(.projects) { ui.projectsOpen = true }
        case .mixer: break
        }
    }

    @MainActor private static func go(_ p: Page, _ ui: EditorUI) { if ui.page != p { ui.pageFromDevice = true; ui.page = p } }

    @MainActor static func flash(_ t: FlashTarget, _ ui: EditorUI) {
        // the Song tab keeps the whole-track controls in a popover: PATTERN opens it
        if t == .trackPanel, ui.songTab { ui.trackControlsOpen = true; return }
        ui.flash = Flash(target: t, id: (ui.flash?.id ?? 0) + 1)
    }
}

/// A ring around the place the FM-1 just sent Jib to, fading after a moment.
struct FlashRing: ViewModifier {
    let ui: EditorUI
    let target: FlashTarget
    @State private var lit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.text, lineWidth: 2).opacity(lit ? 1 : 0).allowsHitTesting(false) }
            .onChange(of: ui.flash) { _, f in
                guard f?.target == target else { return }
                lit = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1200))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { lit = false }
                }
            }
    }
}

extension View {
    func flashRing(_ ui: EditorUI, _ t: FlashTarget) -> some View { modifier(FlashRing(ui: ui, target: t)) }
}

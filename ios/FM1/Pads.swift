import SloopKit
import SwiftUI

/// The FM-1's function pads, two rows of six in its own order (SLOOP panel.c B_*): FX SEL ENV LFO EDIT
/// GLO over HOME SAVE ARP SEQ PLAY REC. They do what the device's buttons do: a sound button opens its
/// pages and, pressed again, steps to the next one; HOME is the sequencer, SAVE the library. With the
/// screen link the FM-1's screen moves with them. The active pad sinks and its label lights, as the
/// FM-1 lights the active button.
/// A pad, as the keyboard's keys: a chiclet, latched down while active (its button style holds it down).
struct PadSurface: View {
    var pressed: Bool
    @Environment(\.keyPressed) private var underFinger
    var body: some View {
        Chiclet(radius: 10, down: underFinger, edge: !pressed && !underFinger, top: Theme.control)
    }
}

struct FunctionPads: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var heldSave = false

    enum Pad: String, CaseIterable, Identifiable {
        case fx = "FX", sel = "SEL", env = "ENV", lfo = "LFO", edit = "EDIT", glo = "GLO"
        case home = "HOME", save = "SAVE", arp = "ARP", seq = "SEQ", play = "PLAY", rec = "REC"
        var id: String { rawValue }
        var family: SoundFamily? {
            switch self {
            case .fx: .fx
            case .sel: .sel
            case .env: .env
            case .lfo: .lfo
            case .edit: .edit
            case .glo: .glo
            case .arp: .arp
            default: nil
            }
        }
    }

    static let rows: [[Pad]] = [[.fx, .sel, .env, .lfo, .edit, .glo], [.home, .save, .arp, .seq, .play, .rec]]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(Self.rows[r]) { pad in key(pad) }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1A1A1D)).recessed(16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FM-1 buttons")
    }

    private func key(_ pad: Pad) -> some View {
        let on = isActive(pad)
        let usable = isUsable(pad)
        return Button { press(pad) } label: {
            Text(pad == .play && session.playing ? "STOP" : pad.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? Theme.text : usable && hasPages(pad) ? Theme.textSecondary : Theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background { if usable { PadSurface(pressed: on) } else { RoundedRectangle(cornerRadius: 9).fill(Theme.control.opacity(0.5)) } }
                .overlay(alignment: .topTrailing) {
                    if pad == .rec { LED(on: session.recording, colour: Theme.knob[3]).padding(6) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: on))
        // held, SAVE is the song, as holding SAVE on the FM-1 brings up its song layer
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            guard pad == .save else { return }
            heldSave = true
            openSong()
        })
        .disabled(!usable)
        .accessibilityLabel(pad == .play && session.playing ? "Stop" : pad.rawValue.capitalized)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityValue(pad == .rec && session.recording ? "recording" : usable ? "" : SoundPanelControl.noPages(pad.family, session))
    }

    /// Lit: the button whose screen is up, on the FM-1 when linked, else in the app.
    private func isActive(_ pad: Pad) -> Bool {
        switch pad {
        case .play: return session.playing
        case .rec: return session.recording
        case .home: return ui.page == .sequencer
        case .save: return ui.page == .library || ui.page == .song
        case .glo where session.dialect == .skiff: return ui.page == .mixer
        case .seq:
            if session.screenLinked, let s = session.deviceScreen { return !s.home && [ScreenMap.of(session).notes, ScreenMap.of(session).pattern].contains(s.page) && ui.page != .library }
            return ui.page == .sound && ui.soundFamily == .seq
        default:
            if let f = pad.family, ui.soundPanel?.family == f { return true }     // its pages on the sound panel
            guard ui.page == .sound, let f = pad.family else { return false }
            return ui.soundFamily == f
        }
    }

    /// Every pad presses. On the drum track SEL, ENV, LFO, EDIT and ARP have no pages: they open an
    /// explanation instead (DrumNoPages) and keep a dim label as a hint.
    /// On Skiff a button with no pages for the selected track's engine (DRUM and DRUM-X: SEL, ENV; FM6: ENV; …) is
    /// disabled, as on the rail: pressed it does nothing (Scott, 2026-11-06). SLOOP's drum track keeps its explanation.
    private func isUsable(_ pad: Pad) -> Bool { !(ui.songTab && !hasPages(pad)) }
    private func hasPages(_ pad: Pad) -> Bool {
        guard let f = pad.family else { return true }
        return !SoundPage.shown(session, f).isEmpty
    }

    private func openSong() {
        ui.page = .song
        if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).song) }
    }

    private func press(_ pad: Pad) {
        if pad == .save, heldSave { heldSave = false; return }    // the release after a hold isn't a press
        switch pad {
        case .play: session.setPlaying(!session.playing)
        case .rec: session.toggleRec()
        case .home:
            ui.page = .sequencer
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).home) }
        case .save where session.dialect == .skiff && ui.songTab:
            SkiffNavigator.save(session: session, ui: ui)
        case .save:
            // as the FM-1's SAVE: the presets first; pressed again, the song (SLOOP's SECTION page)
            if ui.page == .library { openSong() } else {
                ui.page = .library
                if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).presets) }
            }
        case .glo where session.dialect == .skiff:
            // the Mixer tab; pressed again, its next section, as GLO steps the FM-1's pages (MIXER … GLOBAL)
            ui.mixerSection = ui.page == .mixer ? SkiffButtonMap.MixerTab(rawValue: (ui.mixerSection.rawValue + 1) % 5)! : .mixer
            ui.page = .mixer
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: ui.mixerSection.page) }
        case .seq where ui.songTab:
            // as the rail's SEQ: the Song tab's places, NOTES first (from Mix or Sounds, the Song tab)
            ui.soundPanel = nil
            if ui.page != .song { ui.page = .song }
            let now = session.deviceScreen.flatMap { s in s.home ? nil : SeqKey.pages.firstIndex(of: s.page) }
            let p = SeqKey.pages[now.map { ($0 + 1) % SeqKey.pages.count } ?? 0]
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: p) }
            SeqKey.focus(p, ui)
        case .seq where session.dialect == .skiff:
            // NOTES (Sequence, the step panel); pressed again, PATTERN (the whole-track controls)
            let again = ui.page == .sequencer && session.deviceScreen?.page == 41
            ui.page = .sequencer
            SkiffNavigator.flash(again ? .trackPanel : .stepPanel, ui)
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: again ? 43 : 41) }
        case .seq:
            // as on the FM-1: SEQ opens the notes (the sequencer), again for PATTERN
            if ui.page == .sequencer {
                ui.page = .sound; ui.soundFamily = .seq
                if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).pattern) }
            } else {
                ui.page = .sequencer
                if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).notes) }
            }
        default:
            guard let f = pad.family else { return }
            // the Mixer tab keeps its place: the button's pages come in on the sound panel, as from its rail
            if ui.songTab, SoundPanelControl.families.contains(f) {
                SoundPanelControl.press(f, session: session, ui: ui)
                return
            }
            // on the drum track a button without drum pages still opens its pages on the FM-1 ("DRUM
            // TRACK" there), so both screens show the same button
            let pages = SoundPage.reached(session, f)
            let again = ui.page == .sound && ui.soundFamily == f
            ui.page = .sound
            ui.soundFamily = f
            // pressed again: the next page of the button, round and round, as the FM-1 does; its card comes forward
            if again { SoundPanelControl.step(f, session: session, ui: ui); return }
            guard let first = pages.first else { return }
            ui.focus(first)
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: first.fw) }
        }
    }
}

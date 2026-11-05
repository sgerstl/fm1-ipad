import SloopKit
import SwiftUI

/// The FM-1's function pads, two rows of six in its own order (SLOOP panel.c B_*): FX SEL ENV LFO EDIT
/// GLO over HOME SAVE ARP SEQ PLAY REC. They do what the device's buttons do: a sound button opens its
/// pages and, pressed again, steps to the next one; HOME is the sequencer, SAVE the library. With the
/// screen link the FM-1's screen moves with them. The active pad sinks and its label lights, as the
/// FM-1 lights the active button.
/// A rubber pad, as the keyboard's keys: raised; pressed in when it is the active one. Flat look: a
/// chiclet, latched down while active (its button style holds it down).
struct PadSurface: View {
    var pressed: Bool
    @Environment(\.look) private var look
    @Environment(\.keyPressed) private var underFinger
    var body: some View {
        if look.flat {
            Chiclet(radius: 10, down: underFinger, edge: !pressed && !underFinger, top: Theme.control)
        } else {
            rubber
        }
    }

    private var rubber: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(pressed ? Color(hex: 0x1C1D20) : Color(hex: 0x26272B))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(pressed ? 0.6 : 0.45), lineWidth: 6).blur(radius: 5)
                .clipShape(RoundedRectangle(cornerRadius: 10)))
            .shadow(color: .black.opacity(pressed ? 0.2 : 0.55), radius: pressed ? 1 : 4, y: pressed ? 0 : 3)
    }
}

struct FunctionPads: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var heldSave = false
    @Environment(\.look) private var look

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
                .shadow(color: on && !look.flat ? Theme.text.opacity(0.8) : .clear, radius: 5)   // flat: lit, no glow
                .frame(maxWidth: .infinity, minHeight: 44)
                .background { PadSurface(pressed: on) }
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
        .accessibilityValue(pad == .rec && session.recording ? "recording" : "")
    }

    /// Lit: the button whose screen is up, on the FM-1 when linked, else in the app.
    private func isActive(_ pad: Pad) -> Bool {
        switch pad {
        case .play: return session.playing
        case .rec: return session.recording
        case .home: return ui.page == .sequencer
        case .save: return ui.page == .library || ui.page == .song
        case .glo where session.dialect == .skiff: return ui.mixerTab != nil
        case .seq:
            if session.screenLinked, let s = session.deviceScreen { return !s.home && [ScreenMap.of(session).notes, ScreenMap.of(session).pattern].contains(s.page) && ui.page != .library }
            return ui.page == .sound && ui.soundFamily == .seq
        default:
            guard ui.page == .sound, let f = pad.family else { return false }
            return ui.soundFamily == f
        }
    }

    /// Every pad presses. On the drum track SEL, ENV, LFO, EDIT and ARP have no pages: they open an
    /// explanation instead (DrumNoPages) and keep a dim label as a hint.
    private func isUsable(_ pad: Pad) -> Bool { true }
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
        // any other button closes the mixer panel, as on the FM-1 (PLAY and REC leave it)
        if session.dialect == .skiff, ![.glo, .play, .rec].contains(pad) { ui.mixerTab = nil }
        switch pad {
        case .play: session.setPlaying(!session.playing)
        case .rec: session.toggleRec()
        case .home:
            ui.page = .sequencer
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).home) }
        case .save:
            // as the FM-1's SAVE: the presets first; pressed again, the song (SLOOP's SECTION page)
            if ui.page == .library { openSong() } else {
                ui.page = .library
                if session.screenLinked, ui.followDevice { session.showOnDevice(page: ScreenMap.of(session).presets) }
            }
        case .glo where session.dialect == .skiff:
            // the mixer panel; pressed again, its next tab, as GLO steps the FM-1's pages (MIXER … GLOBAL)
            ui.mixerTab = ui.mixerTab.map { SkiffButtonMap.MixerTab(rawValue: ($0.rawValue + 1) % 5)! } ?? .mixer
        case .seq where session.dialect == .skiff:
            // NOTES (Sequence, the step panel); pressed again, PATTERN (the whole-track controls)
            ui.mixerTab = nil
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
            // on the drum track a button without drum pages still opens its pages on the FM-1 ("DRUM
            // TRACK" there), so both screens show the same button
            let pages = SoundPage.reached(session, f)
            let again = ui.page == .sound && ui.soundFamily == f
            ui.page = .sound
            ui.soundFamily = f
            guard session.screenLinked, ui.followDevice, !pages.isEmpty else { return }
            // pressed again: the next page of the button, round and round, as the FM-1 does
            var next = pages[0]
            if again, let s = session.deviceScreen, let k = pages.firstIndex(where: { $0.fw == s.page }) {
                next = pages[(k + 1) % pages.count]
            }
            session.showOnDevice(page: next.fw)
        }
    }
}

import SloopKit
import SwiftUI

/// The FM-1's function pads, two rows of six in its own order (SLOOP panel.c B_*): FX SEL ENV LFO EDIT
/// GLO over HOME SAVE ARP SEQ PLAY REC. They do what the device's buttons do: a sound button opens its
/// pages and, pressed again, steps to the next one; HOME is the sequencer, SAVE the library. With the
/// screen link the FM-1's screen moves with them. The active pad sinks and its label lights, as the
/// FM-1 lights the active button.
struct FunctionPads: View {
    let session: SloopSession
    let ui: EditorUI

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
                .foregroundStyle(on ? Theme.text : usable ? Theme.textSecondary : Theme.textTertiary)
                .shadow(color: on ? Theme.text.opacity(0.8) : .clear, radius: 5)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    // rubber, as the keyboard's keys: raised; the active one pressed in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(on ? Color(hex: 0x1C1D20) : Color(hex: 0x26272B))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(on ? 0.6 : 0.45), lineWidth: 6).blur(radius: 5)
                            .clipShape(RoundedRectangle(cornerRadius: 10)))
                        .shadow(color: .black.opacity(on ? 0.2 : 0.55), radius: on ? 1 : 4, y: on ? 0 : 3)
                }
                .overlay(alignment: .topTrailing) {
                    if pad == .rec { LED(on: session.recording, colour: Theme.knob[3]).padding(6) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
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
        case .save: return ui.page == .library
        case .seq:
            if session.screenLinked, let s = session.deviceScreen { return !s.home && [34, 35, 36].contains(s.page) && ui.page != .library }
            return ui.page == .sound && ui.soundFamily == .seq
        default:
            guard ui.page == .sound, let f = pad.family else { return false }
            return ui.soundFamily == f
        }
    }

    private func isUsable(_ pad: Pad) -> Bool {
        guard let f = pad.family else { return true }
        return !SoundPage.shown(session, f).isEmpty
    }

    private func press(_ pad: Pad) {
        switch pad {
        case .play: session.setPlaying(!session.playing)
        case .rec: session.toggleRec()
        case .home:
            ui.page = .sequencer
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: SoundPage.home) }
        case .save:
            ui.page = .library
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: SoundPage.presets) }
        case .seq:
            // as on the FM-1: SEQ opens the notes (the sequencer), again for PATTERN
            if ui.page == .sequencer {
                ui.page = .sound; ui.soundFamily = .seq
                if session.screenLinked, ui.followDevice { session.showOnDevice(page: 35) }
            } else {
                ui.page = .sequencer
                if session.screenLinked, ui.followDevice { session.showOnDevice(page: 34) }
            }
        default:
            guard let f = pad.family else { return }
            let pages = SoundPage.shown(session, f)
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

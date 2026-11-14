import SloopKit
import SwiftUI

// Settings (Scott, 2026-11-06): the top-left menu keeps the source, Install firmware… and "Settings…"; what you set
// once and leave goes here. How a column turns on a slide, the magnifier over the finger, and playing through the
// iPad (moved from the menu), with one line under it only when the FM-1 or iOS needs the user to do something. The
// lines that only reported (what's playing, the route) went: the speaker key in the top bar already says it.

struct SettingsSheet: View {
    let session: DeviceSession
    @Environment(AudioThrough.self) private var through
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Labs.holdToMenu.key) private var holdToMenu = Labs.holdToMenu.standard
    @AppStorage(Labs.columnTravel.key) private var columnTravel = Labs.columnTravel.standard
    @AppStorage(PadsPage.confirmClearKey) private var confirmPadClear = true
    @AppStorage(SlideToTurn.key) private var slideToTurn = SlideToTurn.sideways
    @AppStorage(Magnifier.key) private var magnifier = true
    @AppStorage(PadPreviews.key) private var padPreviews = true
    @AppStorage(ThemeColours.key) private var themeColours = true
    @AppStorage(SoundButtons.key) private var soundButtons = SoundButtons.standard
    @AppStorage(Handedness.key) private var handedness = Handedness.right
    @AppStorage(ShowGraphics.key) private var showGraphics = ShowGraphics.standard
    private var phone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Slide to turn", selection: $slideToTurn) {
                        ForEach(SlideToTurn.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Slide to turn")
                } footer: {
                    Text(slideToTurn == .sideways
                         ? "Slide a column right to raise it, left to lower it. Up and down scrolls the panel."
                         : "With Up and down or Both, a slide on a column turns it, so panels scroll from the gaps between columns.")
                }

                Section {
                    Picker("Handedness", selection: $handedness) {
                        ForEach(Handedness.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Handedness")
                } footer: {
                    Text(handedness == .right
                         ? "Menus open to the left of your finger, so your hand doesn't cover them. The sound buttons sit on the right."
                         : "Menus open to the right of your finger, so your hand doesn't cover them. The sound buttons sit on the left.")
                }

                // Touch (Scott, 2026-11-10): what you set once to suit your hands, out of Labs for good
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Hold before a menu")
                            Spacer()
                            Text(String(format: "%.2f s", holdToMenu)).monospacedDigit().foregroundStyle(Theme.textSecondary)
                        }
                        Slider(value: Binding(get: { holdToMenu }, set: { holdToMenu = ($0 / 0.05).rounded() * 0.05 }), in: Labs.holdToMenu.range)
                            .accessibilityLabel("Hold before a menu")
                            .accessibilityValue(String(format: "%.2f seconds", holdToMenu))
                        Text("How long you press a pad, block or track before its menu opens. Shorter is quicker but easier to set off by accident.")
                            .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Slide for a full turn")
                        Picker("Slide for a full turn", selection: Binding(get: { SlideLength.nearest(columnTravel) }, set: { columnTravel = $0.rawValue })) {
                            ForEach(SlideLength.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Slide for a full turn")
                        Text("How far you slide a value across its whole range. Fine is longer and more exact.")
                            .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                    }
                    Toggle("Confirm before clearing a pad", isOn: $confirmPadClear)
                } header: {
                    Text("Touch")
                } footer: {
                    Text("Clearing a pad whose pattern nothing else uses erases that pattern, and it can't be undone. With the confirm on, Lupe asks first; \u{201C}Don't ask again\u{201D} turns it off.")
                }

                // the phone (decision 33): Show graphics joins Sound buttons, the union of both phones' options
                if phone {
                    Section {
                        Toggle("Show graphics", isOn: $showGraphics)
                    } header: {
                        Text("Sound pages")
                    } footer: {
                        Text("Each sound page shows its picture under its four dials, and the Mix pages show theirs. Off: dials only.")
                    }
                }
                Section {
                    Toggle("Sound buttons", isOn: $soundButtons)
                } footer: {
                    Text("Off, pages open from the FM-1's own buttons, and an open panel shows all twelve along its foot, laid out as on the FM-1. On, the FX to SEQ buttons stay down the side so you can open a page from the screen, and the panel leaves them out.")
                }

                Section {
                    Toggle("Track colours from the FM-1's theme", isOn: $themeColours)
                } footer: {
                    Text("The tracks take the colours the FM-1's theme gives them (SKIFF, CRYPT, NEON, QUARK or your custom set). A colour too dark to read on Lupe's page keeps Lupe's own. HI-CON and PAPER have no track colours of their own, so Lupe keeps its.")
                }

                Section {
                    Toggle("Show every pattern on the pads", isOn: $padPreviews)
                } footer: {
                    Text("While the song is stopped, Lupe reads the FM-1's stored patterns so each pad shows its pattern before you play it. Off, a pad shows its pattern once it has played. A trial until 16 November.")
                }

                // MENU › CONTROL on the FM-1 (Skiff 2.5): shown only when the FM-1 offers it (editor menu id 21)
                if let keep = session.keepSends {
                    Section {
                        Toggle("Keep sends when loading a sound", isOn: Binding(get: { keep }, set: { session.setKeepSends($0) }))
                    } header: {
                        Text("FM-1 · Control")
                    } footer: {
                        Text("KEEP SENDS on the FM-1. On, loading a sound keeps the track's chorus, delay and reverb sends, as it keeps its level and pan. Off, the sound brings its own.")
                    }
                }

                Section {
                    Toggle("Magnifier", isOn: $magnifier)
                } footer: {
                    Text("While you slide a value, a bigger copy of it shows above your finger.")
                }

                Section {
                    Toggle(phone ? "Play through the iPhone" : "Play through the iPad", isOn: Binding(get: { through.enabled }, set: { through.enabled = $0 }))
                    if let line = Self.audioAction(session: session, through: through) {
                        Label(line, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Theme.text)
                            .accessibilityLabel(line)
                    }
                } footer: {
                    Text("Plays the FM-1's sound on the \(phone ? "iPhone" : "iPad")'s speakers or headphones.")
                }
                LabsSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    /// The one line under "Play through the iPad", only when the user has something to do (2026-11-06): nil when all
    /// is well or Lupe is still setting the FM-1 up on its own.
    @MainActor static func audioAction(session: DeviceSession, through: AudioThrough) -> String? {
        guard through.enabled else { return nil }
        switch through.state {
        case .denied:
            return "Turn on Microphone for Lupe in Settings"
        case .noInput:
            return session.canQuietSpeaker ? "Plug in the FM-1 (USB AUDIO on)"
                                           : "No sound from the FM-1 over USB: plug it in, or unplug it and plug it in again"
        case .failed(let why):
            return why
        case .playing:
            if let problem = session.usbAudioProblem { return problem }
            // Skiff: Lupe can't turn its MASTER (the knob alone sets it), so the speaker is the user's to quiet
            if !session.canQuietSpeaker, session.usbAudioFull == true { return "Turn the FM-1's MASTER down to quiet its speaker" }
            return nil
        case .off, .starting:
            return nil
        }
    }
}

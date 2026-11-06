import SloopKit
import SwiftUI

// Settings (Scott, 2026-11-06): the top-left menu keeps the source, Install firmware… and "Settings…"; what you set
// once and leave goes here. How a column turns on a slide, the magnifier over the finger, and playing through the
// iPad (moved from the menu), with one line under it only when the FM-1 or iOS needs the user to do something. The
// lines that only reported (what's playing, the route) went: the speaker key in the top bar already says it.

/// How a column turns (KnobControl with a column face: Shape, the sound panel, the Mix cards, HOME's four in the
/// track box). Stored with @AppStorage under `key`.
enum SlideToTurn: String, CaseIterable, Identifiable {
    /// A sideways slide, right raises (the default): a vertical drag is always the panel's scroll.
    case sideways
    /// An up and down slide, up raises: a panel scrolls from the gaps between columns, not from a column.
    case vertical
    /// Whichever way the finger first goes, for that slide: up or right raises.
    case both

    static let key = "slideToTurn"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sideways: "Sideways"
        case .vertical: "Up and down"
        case .both: "Both"
        }
    }
}

/// The value loupe's switch (ValueLoupe.swift). On by default; off, LoupeState.show does nothing.
enum Magnifier {
    static let key = "magnifier"
    static var on: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

struct SettingsSheet: View {
    let session: DeviceSession
    @Environment(AudioThrough.self) private var through
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SlideToTurn.key) private var slideToTurn = SlideToTurn.sideways
    @AppStorage(Magnifier.key) private var magnifier = true

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
                    Toggle("Magnifier", isOn: $magnifier)
                } footer: {
                    Text("While you slide a value, a bigger copy of it shows above your finger.")
                }

                Section {
                    Toggle("Play through the iPad", isOn: Binding(get: { through.enabled }, set: { through.enabled = $0 }))
                    if let line = Self.audioAction(session: session, through: through) {
                        Label(line, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Theme.text)
                            .accessibilityLabel(line)
                    }
                } footer: {
                    Text("Plays the FM-1's sound on the iPad's speakers or headphones.")
                }
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

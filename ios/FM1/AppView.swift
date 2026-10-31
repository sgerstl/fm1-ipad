import SloopKit
import SwiftUI

struct AppView: View {
    let session: SloopSession
    let ui: EditorUI
    @Binding var useDemo: Bool

    var body: some View {
        VStack(spacing: 16) {
            TopBar(session: session, ui: ui, useDemo: $useDemo)
            switch ui.page {
            case .sequencer:
                if case .connected = session.status {
                    SequencerPage(session: session, ui: ui)
                } else {
                    ConnectionState(status: session.status, useDemo: $useDemo)
                }
            case .sound:
                ComingLater(title: "Sound", detail: "Shaping the selected track's sound comes in pass 1, step 4.")
            case .library:
                ComingLater(title: "Library", detail: "Browsing presets by name comes in pass 1, step 3.")
            }
        }
        .padding(24)
        .foregroundStyle(Theme.text)
        .font(.system(size: 15))
        .monospacedDigit()
    }
}

struct SequencerPage: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        let t = session.selectedTrack
        VStack(spacing: 16) {
            Overview(session: session)
            if t == 3 {
                DrumGrid(session: session, ui: ui)
            } else {
                PianoRoll(session: session, ui: ui, track: t)
            }
            SelectedStepPanel(session: session, ui: ui)
        }
    }
}

/// Every state that isn't "connected": what happened, and what to do.
struct ConnectionState: View {
    let status: ConnectionStatus
    @Binding var useDemo: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(title).font(.system(size: 28, weight: .semibold))
            Text(detail)
                .font(.system(size: 17))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            if showDemoButton {
                Button { useDemo = true } label: {
                    Text("Use the demo FM-1").fontWeight(.semibold).padding(.horizontal, 20).frame(height: 44).raisedKey()
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch status {
        case .searching: "Plug in the FM-1"
        case .connecting: "Reading the FM-1…"
        case .connected: ""
        case .wrongFirmware: "This FM-1 runs other firmware"
        case .lost: "FM-1 disconnected"
        }
    }

    private var detail: String {
        switch status {
        case .searching:
            "Connect it with a USB-C cable. It has to be running SLOOP 2.8.4."
        case .connecting:
            "Reading all four tracks. This takes about a second."
        case .connected: ""
        case .wrongFirmware(let found, let proto):
            "It reports “\(found)”, editor protocol \(proto). This app only works with FELUCCA SLOOP 2.8.4, protocol 12. Install SLOOP 2.8.4 from the firmware hub, then plug the FM-1 in again."
        case .lost(let why):
            "\(why). Plug it back in and the app picks up where it was."
        }
    }

    private var showDemoButton: Bool {
        switch status {
        case .connecting: false
        default: true
        }
    }
}

struct ComingLater: View {
    var title: String
    var detail: String
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.system(size: 28, weight: .semibold))
            Text(detail).font(.system(size: 17)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
    }
}

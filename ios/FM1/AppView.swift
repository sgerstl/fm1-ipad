import SloopKit
import SwiftUI

struct AppView: View {
    static let space = "canvas"
    let session: SloopSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            TopBar(session: session, ui: ui, useDemo: $useDemo)
            if case .connected = session.status {
                pages.animation(pageAnimation, value: ui.page)
            } else {
                ConnectionState(status: session.status, useDemo: $useDemo)
            }
        }
        .padding(24)
        .overlay(alignment: .bottom) { keyboard }
        .overlay { GrownKnobLayer(session: session, ui: ui) }
        .coordinateSpace(name: Self.space)
        .foregroundStyle(Theme.text)
        .font(.system(size: 15))
        .monospacedDigit()
    }
}

extension AppView {
    /// The track selector sits on top, always in the same place; each page leaves room for its
    /// chips-and-names box (top left) and, on the Sequencer, for the timeline beside it.
    @ViewBuilder var pages: some View {
        ZStack(alignment: .topLeading) {
            // The Sequencer stays alive underneath and only fades, so coming back to it never rebuilds
            // its scroll views mid-animation; its playheads pause while it's hidden.
            let onSequencer = ui.page == .sequencer
            VStack(spacing: 16) {
                Color.clear.frame(height: Overview.height)
                SequencerPage(session: session, ui: ui)
            }
            .opacity(onSequencer ? 1 : 0)
            .allowsHitTesting(onSequencer)
            .accessibilityHidden(!onSequencer)
            .environment(\.pageVisible, onSequencer)
            Group {
                switch ui.page {
                case .sequencer:
                    EmptyView()
                case .library:
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn { if session.selectedTrack < 3 { LibraryEngines(session: session, ui: ui) } }
                        LibraryPage(session: session, ui: ui)
                    }
                case .sound:
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn { EmptyView() }
                        ComingLater(title: "Sound", detail: "Shaping the selected track's sound comes in pass 1, step 4.")
                    }
                }
            }
            .transition(.opacity)
            .id(ui.page)
            Overview(session: session, expanded: ui.page == .sequencer)
        }
    }

    /// The left column under the track box.
    private func leftColumn<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 16) {
            Color.clear.frame(height: Overview.height)
            content()
            Spacer(minLength: 0)
        }
        .frame(width: Overview.boxWidth)
    }

    /// Matches the track strip's accordion, so the page and the strip move as one.
    var pageAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.3) }

    /// The keyboard comes up from the bottom over the step panel; two fingers still pan the grid above it.
    @ViewBuilder var keyboard: some View {
        ZStack(alignment: .bottom) {
            if ui.keyboardOpen, case .connected = session.status {
                KeyboardDrawer(session: session, ui: ui)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: ui.keyboardOpen)
    }
}

extension EnvironmentValues {
    /// False while a page is kept alive but hidden: its animations pause.
    @Entry var pageVisible = true
}

struct SequencerPage: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        let t = session.selectedTrack
        VStack(spacing: 16) {
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

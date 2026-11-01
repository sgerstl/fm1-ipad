import SloopKit
import SwiftUI

struct AppView: View {
    static let space = "canvas"
    let session: SloopSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var isConnected: Bool { if case .connected = session.status { true } else { false } }

    var body: some View {
        VStack(spacing: 16) {
            TopBar(session: session, ui: ui, useDemo: $useDemo)
            if case .connected = session.status {
                pages.animation(pageAnimation, value: ui.page)
                    // a button pressed on the FM-1 brings up the tab that shows its screen
                    .onChange(of: session.deviceScreen) { _, s in
                        guard ui.followDevice, let s, let tab = SoundPage.tab(for: s), tab != ui.page else { return }
                        ui.page = tab
                    }
            } else {
                ConnectionState(status: session.status, useDemo: $useDemo)
            }
        }
        // no sleeping mid-session: the screen stays on while an FM-1 is connected, and may sleep otherwise
        .onChange(of: isConnected, initial: true) { _, on in UIApplication.shared.isIdleTimerDisabled = on }
        .padding(24)
        .overlay(alignment: .bottom) { keyboard }
        .overlay(alignment: .bottom) { undoToast }
        .overlay { trackMenuLayer }
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
            SequencerPage(session: session, ui: ui)
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
                        leftColumn {
                            FunctionPads(session: session, ui: ui)
                            if session.selectedTrack < 3 { LibraryEngines(session: session, ui: ui) }
                        }
                        LibraryPage(session: session, ui: ui)
                    }
                case .song:
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn {
                            FunctionPads(session: session, ui: ui)
                            SectionsPanel(session: session, ui: ui)
                        }
                        SongPage(session: session, ui: ui)
                    }
                case .sound:
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn {
                            FunctionPads(session: session, ui: ui)
                            FollowCard(session: session, ui: ui)
                        }
                        SoundTab(session: session, ui: ui)
                    }
                }
            }
            .transition(.opacity)
            .id(ui.page)
            Overview(session: session, ui: ui, expanded: ui.timelineOpen)
        }
        .onChange(of: ui.page) { _, _ in ui.timelineOpen = false }
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

    /// A long-pressed track's menu, by the finger. A tap anywhere else closes it.
    @ViewBuilder var trackMenuLayer: some View {
        ZStack(alignment: .topLeading) {
            if let m = ui.trackMenu {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { ui.trackMenu = nil }
                    .accessibilityHidden(true)
                let empty = (0..<64).allSatisfy { !session.tracks[m.track].isOn($0) }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TrackChip(track: m.track, size: 24)
                        Text("Track \(m.track + 1)").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    }
                    Button {
                        ui.lastClear = session.clearAll(track: m.track)
                        ui.trackMenu = nil
                    } label: {
                        Label("Clear all steps", systemImage: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(empty ? Theme.textTertiary : Color(hex: 0xFF6B6B))
                            .padding(.horizontal, 14).frame(minWidth: 200, minHeight: 44, alignment: .leading)
                            .raisedKey()
                    }
                    .buttonStyle(PressSink())
                    .disabled(empty)
                    .accessibilityHint(empty ? "The track has no steps" : "Clears all 64 steps; Undo appears for a few seconds")
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelTop)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 2).shadow(color: .black.opacity(0.45), radius: 18, y: 10))
                // beside the finger (to its right, centred on it), kept on screen
                .offset(x: min(max(m.at.x + 28, 12), Theme.canvas.width - 260), y: min(max(m.at.y - 50, 12), Theme.canvas.height - 120))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                .accessibilityAddTraits(.isModal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ui.trackMenu)
    }

    /// After Clear all: what happened and a way back, for 8 seconds.
    @ViewBuilder var undoToast: some View {
        ZStack {
            if let c = ui.lastClear {
                HStack(spacing: 16) {
                    TrackChip(track: c.track)
                    Text("Cleared track \(c.track + 1)").font(.system(size: 15, weight: .semibold))
                    Button {
                        session.undo(c)
                        ui.lastClear = nil
                    } label: {
                        Text("Undo clear").fontWeight(.semibold).padding(.horizontal, 16).frame(height: 44).raisedKey()
                    }
                    .buttonStyle(PressSink())
                }
                .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelTop)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 2).shadow(color: .black.opacity(0.4), radius: 16, y: 8))
                .padding(.bottom, 132)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: c) {
                    try? await Task.sleep(for: .seconds(8))
                    if ui.lastClear == c { ui.lastClear = nil }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Cleared track \(c.track + 1)")
            }
        }
        .animation(pageAnimation, value: ui.lastClear)
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
            // beside the track box: the selected step and the knobs (the timeline opens over them)
            HStack(alignment: .top, spacing: 16) {
                Color.clear.frame(width: Overview.boxWidth, height: Overview.height)
                SelectedStepPanel(session: session, ui: ui)
                    .frame(height: Overview.height)
            }
            if t == 3 {
                DrumGrid(session: session, ui: ui)
            } else {
                PianoRoll(session: session, ui: ui, track: t)
            }
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

import SloopKit
import SwiftUI

struct AppView: View {
    static let space = "canvas"
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(AudioThrough.self) private var through
    @Environment(ProjectStore.self) private var projects
    @Environment(\.scenePhase) private var scenePhase

    /// The iPad is playing the FM-1's sound, in front: the FM-1's own speaker goes quiet. Anything else
    /// (the switch off, no input, the app in the background) gives its MASTER knob back.
    /// The iPad plays the FM-1's sound (whatever the scene): the app is Now Playing.
    private var audioThrough: Bool {
        guard isConnected, case .playing = through.state else { return false }
        return true
    }

    private var speakerQuiet: Bool {
        guard isConnected, scenePhase == .active, case .playing = through.state else { return false }
        return true
    }

    private var isConnected: Bool { if case .connected = session.status { true } else { false } }

    var body: some View {
        VStack(spacing: 16) {
            TopBar(session: session, ui: ui, useDemo: $useDemo)
            if case .connected = session.status {
                pages.animation(pageAnimation, value: ui.page)
                    // a button pressed on the FM-1 brings up the tab that shows its screen
                    .onChange(of: session.deviceScreen) { _, s in
                        guard ui.followDevice, let s, let tab = SoundPage.tab(for: s), tab != ui.page else { return }
                        ui.pageFromDevice = true
                        ui.page = tab
                    }
            } else if ui.page == .song, let store = session.skiffSong, store.song != nil, store.offline {
                // disconnected on Arrange: the last song stays, dimmed and read-only, under a status bar
                SkiffArrangePage(session: session, store: store, ui: ui)
            } else {
                ConnectionState(status: session.status, useDemo: $useDemo)
            }
        }
        // what the FM-1 holds: matched against the saved projects at connect, re-checked at each stop
        .onChange(of: isConnected, initial: true) { _, on in if on { projects.connected() } }
        .onChange(of: session.playing) { _, on in projects.playingChanged(on) }
        // no sleeping mid-session: the screen stays on while an FM-1 is connected, and may sleep otherwise
        .onChange(of: isConnected, initial: true) { _, on in
            UIApplication.shared.isIdleTimerDisabled = on
            if on { through.recheck() }
        }
        .onChange(of: speakerQuiet, initial: true) { _, quiet in session.muteSpeaker(quiet) }
        // iPad audio left on from last time: look again once the app is in front, as when the FM-1 connects
        .onChange(of: scenePhase) { _, p in if p == .active { through.recheck() } }
        .onChange(of: [audioThrough ? 1 : 0, session.playing ? 1 : 0, session.song.songMode ? 1 : 0], initial: true) { _, _ in
            NowPlaying.shared.update(active: audioThrough, session: session)
        }
        .padding(24)
        .overlay(alignment: .bottom) { keyboard }
        .overlay(alignment: .bottom) { undoToast }
        .overlay { TrackMenuLayer(session: session, ui: ui) }
        .overlay { sectionMenuLayer }
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
                            if !session.selectedIsDrums { LibraryEngines(session: session, ui: ui) }
                        }
                        LibraryPage(session: session, ui: ui)
                    }
                case .song:
                    HStack(alignment: .top, spacing: 16) {
                        if session.capabilities.contains(.sloopSong) {
                            leftColumn {
                                FunctionPads(session: session, ui: ui)
                                SongModePanel(session: session)
                            }
                            SongPage(session: session, ui: ui)
                        } else if let store = session.skiffSong {
                            // Skiff's song: the whole page, lanes carrying their own track headers (board A)
                            SkiffArrangePage(session: session, store: store, ui: ui)
                        } else {
                            leftColumn { FunctionPads(session: session, ui: ui) }
                            NotOnThisFirmware.arrange(session)
                        }
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
            // the Presets panel: from the right, over the page; the page dims and a tap on it closes the
            // panel, while the track box stays lit and live above the dimming, to switch tracks
            if ui.presetsPanel {
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture { ui.presetsPanel = false }
                    .accessibilityLabel("Close the presets")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
                    .zIndex(1)
            }
            if !skiffArrange {
                Overview(session: session, ui: ui, expanded: ui.page == .sequencer || ui.timelineOpen)
                    .zIndex(2)
            }
            if let r = ui.sampler, r.fromBrowse {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .transition(.opacity).zIndex(4)
                    .accessibilityHidden(true)
                SamplerPanel(session: session, ui: ui, request: r)
                    .frame(height: PianoRoll.panelHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    .zIndex(5)
            }
            if ui.presetsPanel {
                PresetsPanel(session: session, ui: ui)
                    .geometryGroup()                      // moves as one piece: nothing inside trails it
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                    // on top while it leaves too: without an order a leaving view drops behind the rest
                    .zIndex(3)
            }
        }
        .animation(slide(in: ui.presetsPanel), value: ui.presetsPanel)
        .animation(slide(in: ui.sampler?.fromBrowse == true), value: ui.sampler)
        .onChange(of: ui.page) { _, _ in
            ui.timelineOpen = false
            ui.presetsPanel = false
        }
    }

    /// Arrange on Skiff has its own lane headers: no track box over it.
    private var skiffArrange: Bool { ui.page == .song && session.skiffSong != nil }

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
    /// A held stored section: replace it with the tracks, or clear it (asked again, with what clearing
    /// costs). Beside the finger, as the track menu; a tap anywhere else closes it.
    @ViewBuilder var sectionMenuLayer: some View {
        ZStack(alignment: .topLeading) {
            if let m = ui.sectionMenu {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { ui.sectionMenu = nil }
                    .accessibilityHidden(true)
                let name = DeviceSession.sectionName(m.section)
                let inSong = session.songOrder?.steps.contains { $0.section == m.section } ?? false
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.onColour)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.track[m.section]))
                        Text("Section \(name)").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    }
                    if m.mode == .confirmLoad {
                        Text("Load \(name) over the tracks?").font(.system(size: 13, weight: .semibold))
                            .frame(width: 240, alignment: .leading)
                        Text("They have changes that aren't in a section. Loading \(name) replaces them, and the FM-1 keeps no copy.")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            .frame(width: 240, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        if let e = (0..<4).first(where: { !session.song.stored($0) }) {
                            menuItem("Save them to \(DeviceSession.sectionName(e)) first", icon: "square.and.arrow.down") {
                                session.storeLoop(in: e)
                                session.playSection(m.section)
                                ui.sectionMenu = nil
                            }
                        }
                        menuItem("Load it, replacing them", icon: "arrow.uturn.down", destructive: true) {
                            session.playSection(m.section)
                            ui.sectionMenu = nil
                        }
                        menuItem("Keep my tracks", icon: "xmark") { ui.sectionMenu = nil }
                    } else if m.mode == .confirmClear {
                        Text("Clear \(name)? The FM-1 keeps no copy.")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 220, alignment: .leading)
                        if inSong {
                            Text("It's in the song, which won't play until \(name) holds tracks again.")
                                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                                .frame(width: 220, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        }
                        menuItem("Clear \(name)", icon: "trash", destructive: true) {
                            session.clearSection(m.section)
                            ui.sectionMenu = nil
                        }
                        menuItem("Keep it", icon: "xmark") { ui.sectionMenu = nil }
                    } else {
                        menuItem("Replace with the sequence", icon: "square.and.arrow.down") {
                            session.storeLoop(in: m.section)
                            ui.sectionMenu = nil
                        }
                        .accessibilityHint("The FM-1 has no undo for this")
                        menuItem(session.playing ? "Clear (stop first)" : "Clear section", icon: "trash", destructive: true,
                                 enabled: !session.playing) {
                            ui.sectionMenu?.mode = .confirmClear
                        }
                        .accessibilityHint(session.playing ? "SLOOP clears a section only when stopped" : "Asks before clearing")
                        Text("Neither has an undo on the FM-1.")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(10)
                .elevated(.held)
                // beside the finger (to its right, centred on it), kept on screen
                .offset(x: min(max(m.at.x + 28, 12), Theme.canvas.width - 290), y: min(max(m.at.y - 60, 12), Theme.canvas.height - 300))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                .accessibilityAddTraits(.isModal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ui.sectionMenu)
    }

    private func menuItem(_ title: String, icon: String, destructive: Bool = false, enabled: Bool = true,
                          _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(!enabled ? Theme.textTertiary : destructive ? Color(hex: 0xFF6B6B) : Theme.text)
                .padding(.horizontal, 14).frame(minWidth: 220, minHeight: 44, alignment: .leading)
                .raisedKey()
        }
        .buttonStyle(PressSink())
        .disabled(!enabled)
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
                .background {
                    LookChoice {
                        RoundedRectangle(cornerRadius: 14).fill(Theme.panelTop)
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 2).shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                    } flat: {
                        Color.clear.elevated(.panel)
                    }
                }
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
                    .geometryGroup()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .animation(slide(in: ui.keyboardOpen), value: ui.keyboardOpen)
    }

    /// A panel sliding in springs (about 0.4 s); sliding out it eases, a little quicker but never a snap.
    func slide(in opening: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        return opening ? .spring(response: 0.42, dampingFraction: 0.9) : .easeInOut(duration: 0.32)
    }
}

extension EnvironmentValues {
    /// False while a page is kept alive but hidden: its animations pause.
    @Entry var pageVisible = true
}

struct SequencerPage: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var back: SamplerRequest?        // on the card's back, kept while it turns back
    @State private var turned = false
    /// 0.4 s to turn (a panel-sized change); with Reduce Motion, a quick fade at the halfway point.
    private var turn: Animation { reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.4) }

    var body: some View {
        let t = session.selectedTrack
        // the track box and its timeline (always open here) across the top; under the box, the selected
        // step and the whole track's knobs; the grid, one bar wide, takes the rest (2026-11-02)
        VStack(spacing: 16) {
            Color.clear.frame(height: Overview.height)
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    SelectedStepPanel(session: session, ui: ui)
                    TrackPanel(session: session, ui: ui)
                }
                .frame(width: Overview.boxWidth, height: PianoRoll.panelHeight)
                // a track's Record sample turns the grid over: the sampler is on its back. The back goes in
                // first, facing away, then the card turns (inserted already turned, it just appeared)
                ZStack {
                    Group {
                        if session.isDrums(t) {
                            DrumGrid(session: session, ui: ui)
                        } else {
                            PianoRoll(session: session, ui: ui, track: t)
                        }
                    }
                    .modifier(FlipFace(angle: turned ? (reduceMotion ? 90 : 180) : 0))
                    if let r = back {
                        SamplerPanel(session: session, ui: ui, request: r)
                            .frame(height: PianoRoll.panelHeight)
                            .modifier(FlipFace(angle: turned ? 0 : (reduceMotion ? -90 : -180)))
                    }
                }
                .onChange(of: ui.sampler) { _, r in
                    if let r, !r.fromBrowse {
                        back = r
                        Task { @MainActor in withAnimation(turn) { turned = true } }
                    } else if back != nil {
                        withAnimation(turn) { turned = false } completion: { back = nil }
                    }
                }
            }
        }
    }
}

/// A tab whose feature the connected firmware doesn't have in Jib yet: what's missing, and what to do
/// meanwhile. Drawn as the connection states are.
struct NotOnThisFirmware: View {
    let title: String
    let detail: String

    /// Arrange is SLOOP's sections and song order; Skiff's song (lists, the pattern pool, scenes) is
    /// another model, its Arrange still being designed (vault skiff-plan.md, phase 4).
    @MainActor static func arrange(_ session: DeviceSession) -> NotOnThisFirmware {
        NotOnThisFirmware(title: "Arrange isn't on Skiff yet",
                          detail: "Skiff keeps a song as each track's list of patterns, with scenes, not SLOOP's four sections. "
                              + "Jib's Arrange for that is still being designed. Until then, arrange on the FM-1 itself.")
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(title).font(.system(size: 28, weight: .semibold))
            Text(detail)
                .font(.system(size: 17))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
        .accessibilityElement(children: .combine)
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
            "Connect it with a USB-C cable. It has to be running SLOOP 2.8.4 or Skiff 2.2."
        case .connecting:
            "Reading every track. This takes about a second."
        case .connected: ""
        case .wrongFirmware(let found, let proto):
            "It reports “\(found)”, editor protocol \(proto). Jib works with \(FirmwareDialect.known). Install one of those, then plug the FM-1 in again."
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

/// A track's menu, beside the finger (long-press a track): its sound, a sample, clearing its steps.
/// Shared by the iPad's track box and the phone's track chips; kept inside `canvasSize`.
struct TrackMenuLayer: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.canvasSize) private var canvas

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let m = ui.trackMenu {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { ui.trackMenu = nil }
                    .accessibilityHidden(true)
                let empty = session.stepIndices.allSatisfy { !session.tracks[m.track].isOn($0) }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TrackChip(track: m.track, size: 24)
                        Text("Track \(m.track + 1)").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    }
                    // the sound, from here: the Presets panel slides out over the page
                    Button {
                        session.select(track: m.track)
                        ui.timelineOpen = false            // the open timeline would run under the panel
                        ui.presetsPanel = true
                        ui.trackMenu = nil
                    } label: {
                        Label(session.isDrums(m.track) ? "Kits…" : "Presets…", systemImage: "square.grid.2x2")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 14).frame(minWidth: 200, minHeight: 44, alignment: .leading)
                            .raisedKey()
                    }
                    .buttonStyle(PressSink())
                    .accessibilityHint("Pick this track's sound without leaving the page")
                    if !session.isDrums(m.track), session.capabilities.contains(.samples) {
                        // the grid turns over to the sampler; Use on track puts the take on this track
                        Button {
                            session.select(track: m.track)
                            ui.presetsPanel = false
                            ui.timelineOpen = false
                            ui.page = .sequencer
                            ui.sampler = SamplerRequest(track: m.track)
                            ui.trackMenu = nil
                        } label: {
                            Label("Record sample…", systemImage: "mic")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 14).frame(minWidth: 200, minHeight: 44, alignment: .leading)
                                .raisedKey()
                        }
                        .buttonStyle(PressSink())
                        .accessibilityHint("Records the \(UIDevice.current.model)'s microphone into a sample slot for this track")
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
                    .accessibilityHint(empty ? "The track has no steps" : "Clears all \(session.stepCount) steps; Undo appears for a few seconds")
                }
                .padding(10)
                .elevated(.held)
                // beside the finger (to its right, centred on it), kept on screen
                .offset(x: min(max(m.at.x + 28, 12), canvas.width - 260), y: min(max(m.at.y - 50, 12), canvas.height - 180))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                .accessibilityAddTraits(.isModal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ui.trackMenu)
    }
}

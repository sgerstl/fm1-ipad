import SloopKit
import SwiftUI

struct TopBar: View {
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(AudioThrough.self) private var through
    @Environment(ProjectStore.self) private var projects
    @Environment(FirmwareCentre.self) private var firmware
    @State private var connectionFrame: CGRect = .zero
    private var projectsOpen: Binding<Bool> { Binding(get: { ui.projectsOpen }, set: { ui.projectsOpen = $0 }) }
    @State private var naming: NamePrompt?
    @State private var readoutFrame: CGRect = .zero
    @State private var settingsOpen = false

    var body: some View {
        let _ = BodyCounter.tick("TopBar")
        Group {
            if ui.songTab, let store = session.skiffSong {
                // Skiff: the playback mode sits beside play and stop, so the bar is one row (centred tabs would
                // collide with it)
                HStack(spacing: 12) {
                    connection
                    skiffProjectsKey
                    Spacer(minLength: 12)
                    tabs
                    Spacer(minLength: 12)
                    SongModeKeys(store: store).fixedSize()
                    transport
                }
            } else {
                // the tabs sit in the middle of the bar whatever the two sides hold
                ZStack {
                    HStack(spacing: 0) {
                        connection
                        // projects are SLOOP's backup objects: firmware without them (Skiff) shows none
                        if session.dialect == nil || session.capabilities.contains(.projects) { project }
                        Spacer(minLength: 12)
                        transport
                    }
                    tabs
                }
            }
        }
        .frame(height: 64)
        .zIndex(1)              // the play key's "Playing from the start" tag hangs below the bar, over the page
        .sheet(isPresented: projectsOpen) { ProjectsSheet(store: projects, session: session) }
        .namePrompt($naming, store: projects)
    }

    /// Skiff's folder: the Projects sheet, its 4 slots on the FM-1 beside the iPad's projects (SAVE > PROJECT).
    private var skiffProjectsKey: some View {
        Button { ui.projectsOpen = true } label: {
            Image(systemName: "folder").font(.system(size: 17)).foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Projects")
        .accessibilityValue(session.skiffProjects.flatMap { p in p.name.isEmpty ? nil : p.name.capitalized + (p.changed ? ", changed" : "") } ?? "")
        .accessibilityHint("The FM-1's project slots and the projects on this iPad")
    }

    // MARK: Connection: tap for the device / demo choice

    private var connection: some View {
        Button {
            ui.menu = JibMenu(title: "FM-1", groups: { connectionGroups }, at: CGPoint(x: connectionFrame.minX, y: connectionFrame.maxY))
        } label: {
            HStack(spacing: 10) {
                LED(on: isConnected, colour: Theme.text)
                    .frame(width: 8, height: 8)
                // a real FM-1 is just the dot; words for the demo and for trouble (the version is in the menu)
                if let s = shortStatus {
                    Text(s).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { connectionFrame = $0 }
        .accessibilityLabel("\(statusLine), \(versionLine)")
        .accessibilityHint("Choose the FM-1 or a demo, install firmware, or open Settings")
        .sheet(isPresented: $settingsOpen) { SettingsSheet(session: session).environment(through) }
    }

    /// The connection menu (Jib's own, 2026-11-05). Scott, 2026-11-06, cut to four things: one line of status, the
    /// source (the FM-1 over USB, or a demo FM-1 running Skiff or SLOOP), Install firmware… and Settings…. Gone: the
    /// "Follow the FM-1's screen" switch (it always follows now), the iPad's audio and its lines (Settings has them),
    /// the diagnostics line and the Developer submenu (its look switch with it).
    private var connectionGroups: [[MenuItem]] {
        let demo = useDemo
        return [
            [.note("\(statusLine) · \(versionLine)")],
            [MenuItem(title: "FM-1 over USB", icon: "cable.connector", checked: !demo) { useDemo = false },
             MenuItem(title: "Skiff demo", icon: "play.rectangle", checked: demo && ui.demoSkiff) { ui.demoSkiff = true; useDemo = true },
             MenuItem(title: "SLOOP demo", icon: "play.rectangle", checked: demo && !ui.demoSkiff) { ui.demoSkiff = false; useDemo = true }],
            [MenuItem(title: "Install firmware…", icon: "arrow.down.circle") { firmware.pickerNote = nil; firmware.showPicker = true },
             MenuItem(title: "Settings…", icon: "gearshape") { settingsOpen = true }],
        ]
    }

    private var isConnected: Bool { if case .connected = session.status { true } else { false } }

    private var shortStatus: String? {
        switch session.status {
        case .connected: session.isDemo ? "Demo" : nil
        default: statusLine
        }
    }

    // MARK: The project on the FM-1: tap for the Projects sheet; Save when there's something to save

    private var project: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Theme.ledOff).frame(width: 1, height: 24).padding(.horizontal, 12)
                .accessibilityHidden(true)
            Button { ui.projectsOpen = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder").font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                    Text(projectName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(projectNamed ? Theme.text : Theme.textSecondary)
                        .lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: 170, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(projectAccessibility)
            .accessibilityHint("Opens your projects")
            // Save as an icon that stays put; the dot on it is the "edited" mark (2026-11-03: the word
            // "edited" and the Save text key took more room than the name)
            if isConnected, projects.busy == nil {
                let dirty = projects.needsSaving
                Button {
                    if projects.canSaveInPlace { Task { await projects.save() } } else { naming = .saveAs(projects.nextName()) }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(dirty ? Theme.text : Theme.textTertiary)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if dirty { Circle().fill(Theme.text).frame(width: 7, height: 7).padding(8) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(!dirty)
                .accessibilityLabel(projects.canSaveInPlace ? "Save \(projectName)" : "Save as a new project")
                .accessibilityValue(dirty ? "unsaved changes" : "saved")
            } else if projects.busy != nil {
                ProgressView().controlSize(.small).frame(width: 44, height: 44)
                    .accessibilityLabel(projects.busy?.label ?? "Working")
            }
        }
    }

    private var projectName: String {
        switch projects.state {
        case .project(let n): n
        case .untitled: "Untitled"
        case .unknown: "Not saved · on FM-1"
        case .offline(let n): n ?? "Projects"
        }
    }

    private var projectNamed: Bool { if case .project = projects.state { true } else { false } }

    private var projectAccessibility: String {
        switch projects.state {
        case .project(let n): projects.edited ? "Project \(n), edited" : "Project \(n)"
        case .untitled: projects.edited ? "Untitled project, edited" : "Untitled project"
        case .unknown: "What's on the FM-1 isn't saved as a project"
        case .offline(let n): n.map { "Project \($0)" } ?? "Projects"
        }
    }

    private var statusLine: String {
        switch session.status {
        case .searching: "No FM-1"
        case .connecting: "Connecting…"
        case .connected: session.isDemo ? "Demo FM-1" : "FM-1 connected"
        case .wrongFirmware: "Wrong firmware"
        case .lost: "FM-1 disconnected"
        }
    }

    private var versionLine: String {
        switch session.status {
        case .connected(let v): session.screenLinked ? "\(v) · screen link" : v
        case .wrongFirmware(let found, _): found.replacingOccurrences(of: "FELUCCA ", with: "")
        default: "needs SLOOP 2.8.4"
        }
    }

    // MARK: Tabs: tap only (two fingers pan the grid on this page)

    // MARK: Tabs (three raised keys were tried 2026-11-01 and didn't work: back to the tabs)

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(ui.songTab ? Page.skiffTabs : Page.sloopTabs) { p in
                let current = ui.page == p
                Button {
                    ui.page = p
                    Self.driveDevice(session: session, ui: ui, to: p)
                } label: {
                    Text(p.title(skiff: ui.songTab))
                        .fontWeight(current ? .semibold : .regular)
                        .foregroundStyle(current ? Theme.text : Theme.textSecondary)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background { if current { Color.clear.selectedKey() } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(current ? [.isSelected] : [])
            }
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    /// A tab tapped on the iPad: the FM-1's screen goes to the same place (HOME, the preset browser,
    /// or the Sound tab's button), when linked and following.
    /// A tab picked here moves the FM-1 to the screen that tab shows (with the screen link). Shared with
    /// the phone's top bar.
    static func driveDevice(session: DeviceSession, ui: EditorUI, to p: Page) {
        guard session.screenLinked, ui.followDevice else { return }
        if let s = session.deviceScreen, SoundPage.tab(for: s, session) == p { return }    // already there
        switch p {
        case .sequencer: session.showOnDevice(page: ScreenMap.of(session).home)
        case .library: session.showOnDevice(page: ScreenMap.of(session).presets)
        case .song: session.showOnDevice(page: ScreenMap.of(session).song)
        case .sound:
            if let first = SoundPage.shown(session, ui.soundFamily).first { session.showOnDevice(page: first.fw) }
        case .mixer: session.showOnDevice(page: ui.mixerSection.page)
        }
    }

    // MARK: Position, tempo, play / stop

    /// iPad audio and Keys as icons, then one transport group: REC, play / stop, and the position over
    /// the tempo. Recording turns the group red (the REC key filled, the well tinted, "REC" in the
    /// readout); nothing else in the bar changes for it (a red line under the whole bar was tried in
    /// the mockup and dropped, 2026-11-03).
    private var transport: some View {
        HStack(spacing: 8) {
            AudioThroughKey(through: through)
            IconKey(label: "Keys", symbol: "pianokeys", onSymbol: "pianokeys.inverse", on: ui.keyboardOpen, enabled: isConnected) {
                ui.keyboardOpen.toggle()
            }
            .accessibilityHint("Shows the FM-1's keyboard")
            transportGroup.padding(.leading, 4)
        }
        .fixedSize()            // the controls keep their size; the connection label gives way
    }

    private var recording: Bool { session.recording || session.song.songRecording }

    private var transportGroup: some View {
        HStack(spacing: 4) {
            recKey
            playKey
            readout
        }
        .padding(4)
        .background {
            if recording { RoundedRectangle(cornerRadius: 12).fill(Theme.recWell) } else { Color.clear.recessed(12) }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: recording)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var recKey: some View {
        Button { session.toggleRec() } label: {
            Circle().fill(recording ? Theme.text : Theme.rec).frame(width: 14, height: 14)
                .frame(width: 44, height: 44)
                .background { if recording { RoundedRectangle(cornerRadius: 9).fill(Theme.rec) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!isConnected)
        .opacity(isConnected ? 1 : 0.4)
        .accessibilityLabel("Record")
        .accessibilityValue(session.song.songRecording ? "song recording" : session.recording ? "recording" : "off")
        .accessibilityAddTraits(.isToggle)
    }

    /// Tap: play or stop. Hold (half a second): play from the start, as the FM-1's GLO + PLAY (Scott, 2026-11-06):
    /// every track from its first entry with SONG on, the patterns from their first step with it off. A hold shows
    /// nothing until it happens, so it has three other ways in: the VoiceOver action "Play from the start", ⇧Space,
    /// and the pointer's tooltip; and when it happens a tag under the key says so. Skiff only: SLOOP's editor can't
    /// restart, so there the hold, the action and the shortcut aren't there.
    ///
    /// One press gesture decides tap or hold, not a Button with a long press beside it: whether the Button still
    /// fired on the release that ended a hold changed from press to press in the simulator (2026-11-06), so a hold
    /// sometimes stopped what it had just started. Here a release is a tap only if the hold hadn't fired and the
    /// finger stayed on the key. The key sinks as PressSink's do.
    private var playKey: some View {
        let canHold = session.canPlayFromStart && isConnected
        return Image(systemName: session.playing ? "stop.fill" : "play.fill")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Theme.text)
        .frame(width: 44, height: 44)
        .background { if session.playing { Color.clear.raisedKey() } }
        .environment(\.keyPressed, playDown)
        .offset(y: playDown ? (look.flat ? 2 : 1) : 0)
        .brightness(!look.flat && playDown ? -0.06 : 0)
        .animation(reduceMotion || !look.flat ? nil : .easeOut(duration: playDown ? 0.06 : 0.1), value: playDown)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard isConnected else { return }
                if !pressing {
                    pressing = true
                    holdFired = false
                    playDown = true
                    if canHold {
                        holdTimer = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            guard !Task.isCancelled, playDown else { return }
                            holdFired = true
                            playFromStart()
                        }
                    }
                } else if abs(v.translation.width) > 44 || abs(v.translation.height) > 44 {
                    // dragged off the key: neither a tap nor a hold
                    playDown = false
                    holdTimer?.cancel()
                }
            }
            .onEnded { _ in
                holdTimer?.cancel()
                let tap = pressing && playDown && !holdFired
                pressing = false
                playDown = false
                if tap { session.setPlaying(!session.playing) }
            })
        .disabled(!isConnected)
        .opacity(isConnected ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .medium), trigger: fromStartCount)
        .overlay(alignment: .top) {
            if fromStartShown {
                Text("Playing from the start")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    .fixedSize()
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(look.surface(.held)).elevationShadow(.held, look))
                    .offset(y: 52)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -4)))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)              // VoiceOver hears it as an announcement
            }
        }
        .background {
            Button("Play from the start", action: playFromStart)
                .keyboardShortcut(.space, modifiers: .shift)
                .disabled(!canHold)
                .opacity(0).accessibilityHidden(true)
        }
        .help(canHold ? "Tap to play or stop · hold to play from the start (⇧Space)" : "Play or stop")
        .accessibilityElement()
        .accessibilityLabel(session.playing ? "Stop" : session.song.songMode ? "Play the song" : "Play")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if isConnected { session.setPlaying(!session.playing) } }
        .accessibilityHint(canHold ? "Hold to play from the start" : "")
        .accessibilityActions {
            if canHold { Button("Play from the start", action: playFromStart) }
        }
    }

    @State private var pressing = false
    @State private var playDown = false
    @State private var holdFired = false
    @State private var holdTimer: Task<Void, Never>?
    @State private var fromStartShown = false
    @State private var fromStartCount = 0
    @State private var fromStartHide: Task<Void, Never>?
    @Environment(\.look) private var look

    private func playFromStart() {
        guard session.canPlayFromStart, isConnected else { return }
        session.playFromStart()
        fromStartCount += 1
        AccessibilityNotification.Announcement("Playing from the start").post()
        withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.15)) { fromStartShown = true }
        fromStartHide?.cancel()
        fromStartHide = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.12)) { fromStartShown = false }
        }
    }

    /// Position over tempo; a tap opens the tempo. In song mode the tempo line says SONG (PLAY plays the
    /// song order and loads sections over the tracks, so it shows on every page).
    private var readout: some View {
        // a tap opens the tempo under it (2026-11-05; it used to open Arrange in song mode, a tab away)
        Button {
            ui.tempoAt = CGPoint(x: readoutFrame.minX, y: readoutFrame.maxY)
        } label: {
            ReadoutLabel(session: session, recording: recording)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { readoutFrame = $0 }
        .accessibilityHint("Opens the tempo")
        .accessibilityAddTraits(.isButton)
    }
}

/// The position over the tempo: a view of its own, so the step moving (8 times a second at 120 BPM) redraws this,
/// not the whole bar.
private struct ReadoutLabel: View {
    let session: DeviceSession
    let recording: Bool

    var body: some View {
        let pos = session.positions[session.selectedTrack]
        let song = session.song.songMode
        let position = session.playing ? "\(pos.step / 16 + 1) · \(pos.step % 16 + 1)" : "– · –"
        let mode = session.song.songRecording ? "SONG REC" : session.recording ? "REC" : song ? "SONG" : nil
        VStack(alignment: .leading, spacing: 0) {
            Text(position).font(.system(size: 20, weight: .semibold)).monospacedDigit().lineLimit(1)
                .foregroundStyle(recording ? Theme.recText : Theme.text)
            HStack(spacing: 4) {
                if let m = mode {
                    Text(m).fontWeight(.semibold).foregroundStyle(recording ? Theme.recText : Theme.text)
                    Text("·")
                }
                Text("\(session.bpm) BPM").monospacedDigit()
            }
            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .frame(width: 112, alignment: .leading)         // "SONG REC · 120 BPM" at its widest: nothing moves
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([mode.map { $0 == "REC" ? "Recording" : $0 == "SONG REC" ? "Song recording" : "Song mode" },
                             session.playing ? "bar \(pos.step / 16 + 1), step \(pos.step % 16 + 1)" : "stopped",
                             "\(session.bpm) BPM"].compactMap { $0 }.joined(separator: ", "))
    }
}

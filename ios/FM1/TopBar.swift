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

    var body: some View {
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
        .frame(height: 64)
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
        .accessibilityHint("Choose the FM-1 or the demo")
    }

    /// The connection menu (Jib's own, 2026-11-05: the system's was cramped): the source, the screen link, the
    /// iPad's audio and what it says, the diagnostics, Developer.
    private var connectionGroups: [[MenuItem]] {
        var g: [[MenuItem]] = [[.note("\(statusLine) · \(versionLine)")]]
        g.append([MenuItem(title: "FM-1 over USB", icon: "cable.connector", checked: !useDemo) { useDemo = false },
                  MenuItem(title: "Demo FM-1 (no device)", icon: "play.rectangle", checked: useDemo) { useDemo = true }])
        if session.screenLinked {
            g.append([MenuItem(title: "Follow the FM-1's screen", icon: "rectangle.on.rectangle", checked: ui.followDevice) { ui.followDevice.toggle() }])
        }
        var audio: [MenuItem] = [MenuItem(title: "Play through the iPad", icon: "speaker.wave.2", checked: through.enabled) { through.enabled.toggle() }]
        if through.enabled { audio.append(.note(through.summary)) }
        if through.enabled, !through.route.isEmpty { audio.append(.note(through.route)) }
        if case .playing = through.state {
            if let problem = session.usbAudioProblem {
                audio.append(.note(problem))
            } else if session.canQuietSpeaker {
                audio.append(.note(session.usbAudioFull == true ? "The FM-1's speaker is off; turn its MASTER to bring it back if you unplug"
                                                                : "Setting the FM-1's USB AUDIO to FULL…"))
            } else {
                // Skiff: Jib can't turn its MASTER (the knob alone sets it), so the level goes FIXED instead
                audio.append(.note(session.usbAudioFull == true ? "USB LEVEL is FIXED: turn the FM-1's MASTER down to quiet its speaker. The iPad keeps the full level"
                                                                : "Setting the FM-1's USB LEVEL to FIXED…"))
            }
        }
        if through.state == .noInput {
            audio.append(.note(session.canQuietSpeaker ? "Plug in the FM-1 (USB AUDIO on)" : "No sound from the FM-1 over USB: plug it in, or unplug it and plug it in again"))
        }
        if through.state == .denied { audio.append(.note("Turn on Microphone for Lupe in Settings")) }
        g.append(audio)
        if isConnected {
            // diagnostics for the feel test: are pushes arriving, or is the re-sync doing the work?
            let s = session.stats
            g.append([.note("Since connecting: step pushes \(s.stepPushes) · all pushes \(s.pushes) · steps fixed by re-sync \(s.resyncFixes) · "
                            + String(format: "LIVE %.1f a second · timeouts %d", s.pollsPerSecond, s.timeouts))])
        }
        if let dev = DeveloperItems.item(firmware: firmware) { g.append([dev]) }
        return g
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
        .sheet(isPresented: projectsOpen) { ProjectsSheet(store: projects, session: session) }
        .namePrompt($naming, store: projects)
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
                    Text(ui.songTab && p == .song ? "Song" : p.rawValue)
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

    private var playKey: some View {
        Button { session.setPlaying(!session.playing) } label: {
            Image(systemName: session.playing ? "stop.fill" : "play.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background { if session.playing { Color.clear.raisedKey() } }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!isConnected)
        .opacity(isConnected ? 1 : 0.4)
        .accessibilityLabel(session.playing ? "Stop" : session.song.songMode ? "Play the song" : "Play")
    }

    /// Position over tempo; a tap opens the tempo. In song mode the tempo line says SONG (PLAY plays the
    /// song order and loads sections over the tracks, so it shows on every page).
    private var readout: some View {
        let pos = session.positions[session.selectedTrack]
        let song = session.song.songMode
        let position = session.playing ? "\(pos.step / 16 + 1) · \(pos.step % 16 + 1)" : "– · –"
        let mode = session.song.songRecording ? "SONG REC" : session.recording ? "REC" : song ? "SONG" : nil
        // a tap opens the tempo under it (2026-11-05; it used to open Arrange in song mode, a tab away)
        return Button {
            ui.tempoAt = CGPoint(x: readoutFrame.minX, y: readoutFrame.maxY)
        } label: {
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
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { readoutFrame = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([mode.map { $0 == "REC" ? "Recording" : $0 == "SONG REC" ? "Song recording" : "Song mode" },
                             session.playing ? "bar \(pos.step / 16 + 1), step \(pos.step % 16 + 1)" : "stopped",
                             "\(session.bpm) BPM"].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Opens the tempo")
        .accessibilityAddTraits(.isButton)
    }
}

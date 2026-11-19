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
    @State private var readoutFrame: CGRect = .zero
    @State private var settingsOpen = LaunchArgs.all.contains("-settings")      // (-settings: open on Settings, for captures)

    var body: some View {
        let _ = BodyCounter.tick("TopBar")
        Group {
            if ui.songTab, let store = session.skiffSong {
                // Skiff: everything above the pads in one row (Scott, 2026-11-10, board 47 direction b): where you are
                // (the FM-1 and its menu, the tabs, Pads / Timeline), what launches (the Song tab's tools), the transport.
                // Projects and the iPad's audio are in the FM-1 menu; the playback mode is under the tempo, its word in
                // the readout. The fixed parts keep their size; the tools give way in their own order (SongTools).
                HStack(spacing: 12) {
                    connection.fixedSize()
                    // Pads · Timeline · Mix (Scott, 2026-11-10: the phone's split, in place of Song · Mix and the
                    // Pads / Timeline switch); the tools after them follow the tab
                    if store.performs { songTabs } else { tabs }
                    if ui.page == .song {
                        SongTools(session: session, store: store, ui: ui)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(-1)
                    } else {
                        Spacer(minLength: 12)
                    }
                    skiffTransport
                }
            } else {
                // the tabs sit in the middle of the bar whatever the two sides hold
                ZStack {
                    HStack(spacing: 0) {
                        connection
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
            ui.menu = AppMenu(title: "FM-1", groups: { connectionGroups }, at: CGPoint(x: connectionFrame.minX, y: connectionFrame.maxY), fromKey: true)
        } label: {
            HStack(spacing: 10) {
                // waiting on the FM-1 (a song edit going in) for more than a moment: the dot turns into a spinner
                WaitingDot(on: session.isConnected, waiting: session.skiffSong?.busy == true)
                // a real FM-1 is just the dot; words for the demo and for trouble (the version is in the menu)
                if let s = shortStatus {
                    Text(s).font(.lupe(15, .semibold)).lineLimit(1)
                }
                // Skiff: its menu holds Projects and the iPad's audio too, so it says it opens
                if ui.shell { Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary) }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .globalFrame($connectionFrame)
        .accessibilityLabel("\(statusLine), \(versionLine)")
        .accessibilityHint("Choose the FM-1 or a demo, install firmware, or open Settings")
        .sheet(isPresented: $settingsOpen) { SettingsSheet(session: session).environment(through) }
    }

    /// Skiff's keys after the tools: Keys, then REC, play / stop and the readout (the iPad's audio is in the FM-1 menu).
    private var skiffTransport: some View {
        HStack(spacing: 8) {
            IconKey(label: "Keys", symbol: "pianokeys", onSymbol: "pianokeys.inverse", on: ui.keyboardOpen, enabled: session.isConnected) {
                ui.keyboardOpen.toggle()
            }
            .accessibilityHint("Shows the FM-1's keyboard")
            transportGroup.padding(.leading, 4)
        }
        .fixedSize()
    }

    /// The connection menu (Lupe's own, 2026-11-05). Scott, 2026-11-06, cut to four things: one line of status, the
    /// source (the FM-1 over USB, or the demo FM-1), Install firmware… and Settings…. Gone: the
    /// "Follow the FM-1's screen" switch (it always follows now), the iPad's audio and its lines (Settings has them),
    /// the diagnostics line and the Developer submenu (its look switch with it).
    private var connectionGroups: [[MenuItem]] {
        let demo = useDemo
        return [
            [.note("\(statusLine) · \(versionLine)")],
            [MenuItem(title: "FM-1 over USB", icon: "cable.connector", checked: !demo) { useDemo = false },
             MenuItem(title: "Demo", icon: "play.rectangle", checked: demo) { useDemo = true }],
            // Skiff: what's set once moved here from the top bar (Scott, 2026-11-10, board 47): Projects, the iPad's audio
            ui.shell ? [MenuItem(title: "Projects…", icon: "folder") { ui.projectsOpen = true },
                          MenuItem(title: "Play through the iPad", icon: through.enabled ? "speaker.wave.2.fill" : "speaker.wave.2",
                                   checked: through.enabled) { through.enabled.toggle() }] : [],
            [MenuItem(title: "Install firmware…", icon: "arrow.down.circle") { firmware.pickerNote = nil; firmware.showPicker = true },
             MenuItem(title: "Settings…", icon: "gearshape") { settingsOpen = true }],
        ].filter { !$0.isEmpty }
    }


    private var shortStatus: String? {
        switch session.status {
        case .connected: session.isDemo ? "Demo" : nil
        default: statusLine
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
        default: "needs \(SkiffFirmware.spoken)"
        }
    }

    // MARK: Tabs: tap only (the grid pans on this page)

    // MARK: Tabs (three raised keys were tried 2026-11-01 and didn't work: back to the tabs)

    /// The page tabs as one tab on a line (Scott, 2026-11-09, board 44): the current page's tab rises, grey, from a
    /// 3 pt line with round ends that runs under them all; picking another, the old tab sinks into the line as the new
    /// one rises out of it, together.
    private var tabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(ui.songTab ? Page.skiffPadTabs : Page.classicTabs) { p in
                    let current = ui.page == p
                    Button {
                        ui.page = p
                        Self.driveDevice(session: session, ui: ui, to: p)
                    } label: {
                        Text(p.title(skiff: ui.shell))
                            .fontWeight(current ? .semibold : .regular)
                            .foregroundStyle(current ? Theme.text : Theme.textSecondary)
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .background(alignment: .bottom) {
                                TabRise(rise: current ? 1 : 0).fill(Self.tabGrey)
                                    .animation(reduceMotionTabs ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.3), value: current)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(current ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, TabRise.fillet)      // (the line runs a fillet past the outer tabs, so their curves land on it)
            Capsule().fill(Self.tabGrey).frame(height: 3)
        }
        .fixedSize(horizontal: true, vertical: false)      // (the line as long as the tabs, not the bar's room)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }
    /// Skiff on the iPad: Pads · Timeline · Mix, as the phone has them. Pads and Timeline are the Song page's two views,
    /// so going between them is the same slide as before, the editor staying put under them; the tab line is the same.
    private var songTabs: some View {
        let tabs: [(title: String, current: Bool, pick: () -> Void)] = [
            ("Pads", ui.page == .song && ui.songView == .pads, { pickSong(.pads) }),
            ("Timeline", ui.page == .song && ui.songView == .timeline, { pickSong(.timeline) }),
            ("Mix", ui.page == .mixer, { ui.page = .mixer; Self.driveDevice(session: session, ui: ui, to: .mixer) }),
        ]
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(tabs.indices, id: \.self) { k in
                    let t = tabs[k]
                    Button { t.pick() } label: {
                        Text(t.title)
                            .fontWeight(t.current ? .semibold : .regular)
                            .foregroundStyle(t.current ? Theme.text : Theme.textSecondary)
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .background(alignment: .bottom) {
                                TabRise(rise: t.current ? 1 : 0).fill(Self.tabGrey)
                                    .animation(reduceMotionTabs ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.3), value: t.current)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(t.current ? [.isSelected] : [])
                    .accessibilityHint(k == 0 ? "Every track's entries to launch, the scenes under them"
                                       : k == 1 ? "Every track's entries along the bars" : "Levels, sends and the effects")
                }
            }
            .padding(.horizontal, TabRise.fillet)
            Capsule().fill(Self.tabGrey).frame(height: 3)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    private func pickSong(_ v: SongView) {
        if ui.page != .song { ui.page = .song; Self.driveDevice(session: session, ui: ui, to: .song) }
        ui.songView = v
    }

    /// The tab and its line: a step lighter than the control grey (on the page, the control grey as a thin line all
    /// but vanished: board 44).
    static let tabGrey = Theme.tones[2]
    @Environment(\.accessibilityReduceMotion) private var reduceMotionTabs

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
        case .mixer:
            session.showOnDevice(page: ui.mixerSection.page)
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
            IconKey(label: "Keys", symbol: "pianokeys", onSymbol: "pianokeys.inverse", on: ui.keyboardOpen, enabled: session.isConnected) {
                ui.keyboardOpen.toggle()
            }
            .accessibilityHint("Shows the FM-1's keyboard")
            transportGroup.padding(.leading, 4)
        }
        .fixedSize()            // the controls keep their size; the connection label gives way
    }

    private var recording: Bool { session.isRecordingAnything }

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
        .disabled(!session.isConnected)
        .opacity(session.isConnected ? 1 : 0.4)
        .accessibilityLabel("Record")
        .accessibilityValue(session.recording ? "recording" : "off")
        .accessibilityAddTraits(.isToggle)
    }

    /// Tap: play or stop. Hold (half a second): play from the start, as the FM-1's GLO + PLAY (Scott, 2026-11-06):
    /// every track from its first entry with SONG on, the patterns from their first step with it off. A hold shows
    /// nothing until it happens, so it has three other ways in: the VoiceOver action "Play from the start", ⇧Space,
    /// and the pointer's tooltip; and when it happens a tag under the key says so.
    ///
    /// One press gesture decides tap or hold, not a Button with a long press beside it: whether the Button still
    /// fired on the release that ended a hold changed from press to press in the simulator (2026-11-06), so a hold
    /// sometimes stopped what it had just started. Here a release is a tap only if the hold hadn't fired and the
    /// finger stayed on the key. The key sinks as PressSink's do.
    private var playKey: some View {
        let canHold = session.canPlayFromStart && session.isConnected
        return Image(systemName: session.playing ? "stop.fill" : "play.fill")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Theme.text)
        .frame(width: 44, height: 44)
        .background { if session.playing { Color.clear.raisedKey() } }
        .environment(\.keyPressed, playDown)
        .offset(y: playDown ? 2 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: playDown ? 0.06 : 0.1), value: playDown)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard session.isConnected else { return }
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
        .disabled(!session.isConnected)
        .opacity(session.isConnected ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .medium), trigger: fromStartCount)
        .background {
            Button("Play from the start", action: playFromStart)
                .keyboardShortcut(.space, modifiers: .shift)
                .disabled(!canHold)
                .opacity(0).accessibilityHidden(true)
        }
        .help(canHold ? "Tap to play or stop · hold to play from the start (⇧Space)" : "Play or stop")
        .accessibilityElement()
        .accessibilityLabel(session.playing ? "Stop" : "Play")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if session.isConnected { session.setPlaying(!session.playing) } }
        .accessibilityHint(canHold ? "Hold to play from the start" : "")
        .accessibilityActions {
            if canHold { Button("Play from the start", action: playFromStart) }
        }
    }

    @State private var pressing = false
    @State private var playDown = false
    @State private var holdFired = false
    @State private var holdTimer: Task<Void, Never>?
    @State private var fromStartCount = 0

    private func playFromStart() {
        guard session.canPlayFromStart, session.isConnected else { return }
        session.playFromStart()
        fromStartCount += 1
        ui.confirm("Playing from the start")       // the app strip, 4 s (messages rule, 2026-11-17)
    }

    /// Position over tempo; a tap opens the tempo. In song mode the tempo line says SONG (PLAY plays the
    /// song order and loads sections over the tracks, so it shows on every page).
    private var readout: some View {
        // a tap opens the tempo under it (2026-11-05; it used to open Arrange in song mode, a tab away)
        Button {
            // (a tap on it while the tempo is open is the one that closed it: it stays shut)
            if !OutsideTouch.justClosed { ui.tempoAt = CGPoint(x: readoutFrame.minX, y: readoutFrame.maxY) }
        } label: {
            ReadoutLabel(session: session, recording: recording)
        }
        .buttonStyle(.plain)
        .globalFrame($readoutFrame)
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
        let position = session.playing ? "\(pos.step / 16 + 1) · \(pos.step % 16 + 1)" : "– · –"
        // Skiff: the playback mode's word, always (its keys are in the tempo panel since 2026-11-10, board 47)
        let skiffMode: String? = session.skiffSong?.song.map { ["Loop", "Song", "Once"][safe: $0.mode.rawValue] ?? "Song" }
        let mode = session.recording ? "REC" : skiffMode
        VStack(alignment: .leading, spacing: 0) {
            Text(position).font(.lupe(20, .semibold)).monospacedDigit().lineLimit(1)
                .foregroundStyle(recording ? Theme.recText : Theme.text)
            HStack(spacing: 4) {
                if let m = mode {
                    Text(m).fontWeight(.semibold).foregroundStyle(recording ? Theme.recText : Theme.text)
                    Text("·")
                }
                Text("\(session.bpm) BPM").monospacedDigit()
            }
            .font(.lupe(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .frame(width: 112, alignment: .leading)         // "SONG REC · 120 BPM" at its widest: nothing moves
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        // a fixed label and the moving part as the value, marked as changing often: VoiceOver reads it when asked
        // instead of chasing it eight times a second (2026-11-10)
        .accessibilityLabel("Position")
        .accessibilityValue([mode.map { $0 == "REC" ? "Recording" : $0 == "SONG REC" ? "Song recording" : "Song mode" },
                             session.playing ? "bar \(pos.step / 16 + 1), step \(pos.step % 16 + 1)" : "stopped",
                             "\(session.bpm) BPM"].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(session.playing ? .updatesFrequently : [])
    }
}

/// The connection dot, or a small spinner while the app waits on the FM-1 (Scott, 2026-11-09: "things pause for a second"):
/// shown only after 0.3 s, so a quick edit never flickers it.
struct WaitingDot: View {
    let on: Bool
    let waiting: Bool
    @State private var shown = false

    var body: some View {
        ZStack {
            if shown {
                ProgressView().controlSize(.mini).tint(Theme.text)
                    .accessibilityLabel("Waiting for the FM-1")
            } else {
                LED(on: on, colour: Theme.text).frame(width: 8, height: 8)
            }
        }
        .frame(width: 14, height: 14)
        .task(id: waiting) {
            guard waiting else { shown = false; return }
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { shown = true }
        }
    }
}


/// A page tab rising out of the line under it (TopBar.tabs): `rise` 0 flat, 1 its full height; top corners `r`,
/// concave fillets where its sides meet the line. Animatable, so a tab sinks and another rises.
struct TabRise: Shape {
    var rise: CGFloat
    static let r: CGFloat = 10, fillet: CGFloat = 6
    var animatableData: CGFloat { get { rise } set { rise = newValue } }

    func path(in rect: CGRect) -> Path {
        let h = rect.height, w = rect.width, H = h * max(0, min(1, rise))
        var p = Path()
        guard H > 0.5 else { return p }
        let y0 = h - H, r = min(Self.r, H / 2, w / 2), f = min(Self.fillet, H)
        p.move(to: CGPoint(x: -f, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h - f), control: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: y0 + r))
        p.addArc(tangent1End: CGPoint(x: 0, y: y0), tangent2End: CGPoint(x: r, y: y0), radius: r)
        p.addLine(to: CGPoint(x: w - r, y: y0))
        p.addArc(tangent1End: CGPoint(x: w, y: y0), tangent2End: CGPoint(x: w, y: y0 + r), radius: r)
        p.addLine(to: CGPoint(x: w, y: h - f))
        p.addQuadCurve(to: CGPoint(x: w + f, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: w + f, y: h + 0.5))       // (half a point into the line: no hairline)
        p.addLine(to: CGPoint(x: -f, y: h + 0.5))
        p.closeSubpath()
        return p
    }
}

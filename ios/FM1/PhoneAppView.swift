import SloopKit
import SwiftUI

/// The iPhone layout (landscape, 2026-11-04): one 44 pt top bar, then one job at a time. Designed in the
/// mockups (vault: Projects/Dev/fm1-ipad/iphone-adaptation.md) and built screen by screen: Sequence
/// first, then Shape, Browse and Arrange. Never the iPad's canvas shrunk onto the phone.
struct PhoneAppView: View {
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(AudioThrough.self) private var through
    @Environment(ProjectStore.self) private var projects
    @Environment(\.scenePhase) private var scenePhase
    @State private var size = CGSize(width: 852, height: 393)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isConnected: Bool { if case .connected = session.status { true } else { false } }
    private var audioThrough: Bool {
        guard isConnected, case .playing = through.state else { return false }
        return true
    }
    private var speakerQuiet: Bool {
        guard isConnected, scenePhase == .active, case .playing = through.state else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 8) {
            PhoneTopBar(session: session, ui: ui, useDemo: $useDemo)
            if isConnected {
                Group {
                    switch ui.page {
                    case .sequencer: PhoneSequence(session: session, ui: ui)
                    case .sound: PhoneShape(session: session, ui: ui)
                    case .library: PhoneBrowse(session: session, ui: ui)
                    case .song: SongPage(session: session, ui: ui, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // a button pressed on the FM-1 brings up the tab that shows its screen, as on the iPad
                .onChange(of: session.deviceScreen) { _, s in
                    guard ui.followDevice, let s, let tab = SoundPage.tab(for: s), tab != ui.page else { return }
                    ui.pageFromDevice = true
                    ui.page = tab
                }
            } else {
                ConnectionState(status: session.status, useDemo: $useDemo)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        // a held knob's full-size ring, over everything and kept on the screen, as on the iPad
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .environment(\.canvasSize, size)
        // the presets popover (a track's menu › Presets…), over the page with a dimmed tap-to-close beside it
        .overlay {
            ZStack(alignment: .trailing) {
                if ui.presetsPanel {
                    Color.black.opacity(0.35).ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { ui.presetsPanel = false }
                        .accessibilityLabel("Close the presets")
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)
                    PhonePresetsPopover(session: session, ui: ui)
                        .padding(.top, 52)
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                }
            }
            .animation(reduceMotion ? nil : ui.presetsPanel ? .spring(response: 0.42, dampingFraction: 0.9) : .easeInOut(duration: 0.32), value: ui.presetsPanel)
        }
        // the sampler (a track's menu › Record sample…, or an empty sample slot), full screen
        .overlay {
            if let r = ui.sampler {
                SamplerPanel(session: session, ui: ui, request: r)
                    .background(Theme.page)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: ui.sampler)
        .overlay { TrackMenuLayer(session: session, ui: ui) }
        .overlay { GrownKnobLayer(session: session, ui: ui) }
        .coordinateSpace(name: AppView.space)
        // the same upkeep as the iPad's AppView: projects, the screen staying on, audio, Now Playing
        .onChange(of: isConnected, initial: true) { _, on in if on { projects.connected() } }
        .onChange(of: session.playing) { _, on in projects.playingChanged(on) }
        .onChange(of: isConnected, initial: true) { _, on in
            UIApplication.shared.isIdleTimerDisabled = on
            if on { through.recheck() }
        }
        .onChange(of: speakerQuiet, initial: true) { _, quiet in session.muteSpeaker(quiet) }
        .onChange(of: scenePhase) { _, p in if p == .active { through.recheck() } }
        .onChange(of: [audioThrough ? 1 : 0, session.playing ? 1 : 0, session.song.songMode ? 1 : 0], initial: true) { _, _ in
            NowPlaying.shared.update(active: audioThrough, session: session)
        }
        .foregroundStyle(Theme.text)
        .font(.system(size: 15))
        .monospacedDigit()
    }
}

// MARK: - The top bar

/// One 44 pt row: the four tracks, the four jobs, then REC, play / stop and the position. iPad audio
/// and the demo go into the ⋯ menu.
struct PhoneTopBar: View {
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(AudioThrough.self) private var through
    @Environment(\.look) private var look

    private var isConnected: Bool { if case .connected = session.status { true } else { false } }
    private var recording: Bool { session.recording || session.song.songRecording }
    @State private var chipFrames: [Int: CGRect] = [:]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) { ForEach(session.trackIndices, id: \.self) { chip($0) } }
                .disabled(!isConnected)
                .opacity(isConnected ? 1 : 0.45)
            if isConnected { tabs } else { Spacer() }
            transport
            more
        }
        .frame(height: 44)
    }

    // A track: the selected one lit in its colour (dark number on it, as the iPad's chip), the others
    // raised with a bar of their colour under the number.
    private func chip(_ t: Int) -> some View {
        let on = session.selectedTrack == t
        return Button { session.select(track: t) } label: {
            VStack(spacing: 5) {
                Text("\(t + 1)").font(.system(size: 15, weight: .semibold))
                Capsule().fill(on ? Theme.onColour.opacity(0.5) : Theme.track[t]).frame(width: 16, height: 3)
            }
            .foregroundStyle(on ? Theme.onColour : Theme.text)
            .frame(width: 40, height: 44)
            .background {
                if on {
                    // flat: lit in its colour and lifted (elevation 2, with the ring), so it reads as selected
                    LookChoice {
                        RoundedRectangle(cornerRadius: 9).fill(Theme.pad(t))
                    } flat: {
                        RoundedRectangle(cornerRadius: 8).fill(Theme.track[t])
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, lineWidth: 2))
                            .elevationShadow(.selected, look)
                    }
                } else { Color.clear.raisedKey() }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        // held: the track's menu (its sound, a sample, clearing), beside the chip
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            let f = chipFrames[t] ?? .zero
            ui.trackMenu = TrackMenu(track: t, at: CGPoint(x: f.midX, y: f.maxY + 50))
        })
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(AppView.space)) } action: { chipFrames[t] = $0 }
        .accessibilityLabel("Track \(t + 1)" + (session.isDrums(t) ? ", drums" : ""))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityAction(named: "Track menu") {
            let f = chipFrames[t] ?? .zero
            ui.trackMenu = TrackMenu(track: t, at: CGPoint(x: f.midX, y: f.maxY + 50))
        }
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(Page.allCases) { p in
                let current = ui.page == p
                Button {
                    ui.page = p
                    TopBar.driveDevice(session: session, ui: ui, to: p)
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(current ? Theme.text : Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background { if current { Color.clear.selectedKey(8) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(current ? [.isSelected] : [])
            }
        }
        .padding(4)
        .recessed(10)
    }

    private var transport: some View {
        let pos = session.positions[session.selectedTrack]
        return HStack(spacing: 2) {
            Button { session.toggleRec() } label: {
                Circle().fill(recording ? Theme.text : Theme.rec).frame(width: 14, height: 14)
                    .frame(width: 44, height: 44)
                    .background { if recording { RoundedRectangle(cornerRadius: 9).fill(Theme.rec) } }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel("Record")
            .accessibilityValue(session.song.songRecording ? "song recording" : session.recording ? "recording" : "off")
            Button { session.setPlaying(!session.playing) } label: {
                Image(systemName: session.playing ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 36)
                    .background { Color.clear.raisedKey() }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel(session.playing ? "Stop" : "Play")
            VStack(alignment: .leading, spacing: 2) {
                Text(session.playing ? "\(pos.step / 16 + 1).\(pos.step % 16 / 4 + 1).\(pos.step % 4 + 1)" : "–")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(recording ? Theme.recText : Theme.text)
                Text(recording ? "REC" : "\(session.bpm) BPM").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 62, alignment: .leading)
            .padding(.leading, 6)
            .accessibilityElement(children: .combine)
        }
        .padding(.trailing, 4)
        .frame(height: 44)
        .background {
            if recording { RoundedRectangle(cornerRadius: 10).fill(Theme.recWell) } else { Color.clear.recessed(10) }
        }
        .disabled(!isConnected)
        .opacity(isConnected ? 1 : 0.45)
    }

    private var more: some View {
        Menu {
            Toggle("Play through the iPhone", isOn: Binding(get: { through.enabled }, set: { through.enabled = $0 }))
            if through.enabled { Text(through.summary) }
            Button(useDemo ? "Use the FM-1" : "Use the demo FM-1") { useDemo.toggle() }
            DeveloperMenu()
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background { Color.clear.raisedKey() }
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }
}

// MARK: - Sequence

/// The selected track's grid across the screen, a whole bar wide; the selected step's panel slides in
/// over the grid's right side (from the Step key), as in the mockups.
struct PhoneSequence: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var stepPanel = false
    @State private var velocity = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var width: CGFloat = 0
    @State private var gridArea = CGSize.zero

    var body: some View {
        let t = session.selectedTrack
        // the step fits the screen: a whole bar across, never wider than the iPad's 55 pt
        let label: CGFloat = session.isDrums(t) ? 64 : 44
        let step = max(24, min(55, ((width - label - 2) / 16).rounded(.down)))
        let metrics = GridMetrics(stepWidth: step, rowHeight: 46, labelWidth: label)
        // the width and the grid's height are measured, then handed to the grid
        VStack(spacing: 6) {
            ruler(t)
                .frame(height: 28)
            Group {
                if width > 100, gridArea.height > 100 {
                    if session.isDrums(t) {
                        PhoneDrumGrid(session: session, ui: ui, height: gridArea.height)
                    } else {
                        PhonePianoRoll(session: session, ui: ui, track: t, velocity: velocity, height: gridArea.height)
                    }
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { gridArea = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .environment(\.grid, metrics)
        .overlay(alignment: .topTrailing) {
            if stepPanel { panel.transition(reduceMotion ? .opacity : .move(edge: .trailing)) }
        }
    }

    /// The panel slides in and out with the iPad's side-panel timing.
    private func setPanel(_ open: Bool) {
        withAnimation(reduceMotion ? nil : open ? .spring(response: 0.42, dampingFraction: 0.9) : .easeInOut(duration: 0.32)) { stepPanel = open }
    }

    private func ruler(_ t: Int) -> some View {
        let track = session.tracks[t]
        let i = ui.selectedStep[t]
        let scale = track.scale == 0 ? "chromatic" : "\(Music.noteNames[track.root % 12]) \(Music.scales[min(track.scale, 15)].spoken)"
        let detail = session.isDrums(t) ? "Drums · length \(track.length)" : "Track \(t + 1) · \(scale) · length \(track.length)"
        return HStack(spacing: 8) {
            Text(detail).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            Spacer(minLength: 8)
            Button { setPanel(!stepPanel) } label: {
                Text("Step \(i + 1)").font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).frame(height: 28)
                    .latchedKey(stepPanel, 8, sunkFill: nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink(latched: stepPanel))
            .accessibilityLabel("Step \(i + 1) panel")
            .accessibilityAddTraits(stepPanel ? .isSelected : [])
            if !session.isDrums(t) {
                Button { velocity.toggle() } label: {
                    HStack(spacing: 6) {
                        LED(on: velocity)
                        Text("Velocity").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .latchedKey(velocity, 8, sunkFill: nil)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink(latched: velocity))
                .accessibilityAddTraits(velocity ? .isSelected : [])
            }
        }
    }

    // The iPad's selected-step panel, scrolling inside a narrower overlay; × closes it.
    private var panel: some View {
        ScrollView {
            SelectedStepPanel(session: session, ui: ui)
        }
        .scrollIndicators(.hidden)
        .frame(width: Overview.boxWidth)        // the iPad column's width, so its keys lay out as there
        .overlay(alignment: .topTrailing) {
            Button { setPanel(false) } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background { Color.clear.raisedKey() }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .padding(8)
            .accessibilityLabel("Close the step panel")
        }
        .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
        .padding(.top, 34)
    }
}

/// The piano roll for the phone: the iPad's rows, cells, playhead and two-finger pan, without the
/// header and step numbers (the ruler above says where you are); the velocity lane on a toggle.
struct PhonePianoRoll: View {
    @Environment(\.grid) private var grid
    @Environment(\.look) private var look
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let velocity: Bool
    let height: CGFloat
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<PianoRollContent>.ScrollRequest?

    var body: some View {
        let t = session.tracks[track]
        let rows = PianoRoll.rows(t, keeping: ui.keptRows[track] ?? [])
        let lane = velocity ? PianoRoll.velocityHeight + 6 : 0
        let h = height - lane
        let inner = { var m = grid; m.gridHeight = h; return m }()
        VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 2) {
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.self) { n in
                            AuditionLabel(text: Music.noteName(n) + (Music.inScale(n, root: t.root, scale: t.scale) ? "" : " ∗"),
                                          spoken: Music.spokenNoteName(n),
                                          down: { session.noteDown(n) }, up: { session.noteUp(n) })
                        }
                    }
                    .offset(y: -offset.y)
                    .frame(width: grid.labelWidth, height: h, alignment: .top)
                    .clipped()
                    ZStack(alignment: .topLeading) {
                        TwoFingerScrollView(contentSize: CGSize(width: CGFloat(session.stepCount) * grid.stepWidth, height: max(h, CGFloat(rows.count) * grid.rowHeight)),
                                            offset: $offset, request: request,
                                            rowKeys: rows, rowHeight: grid.rowHeight, snapX: grid.barWidth) {
                            PianoRollContent(grid: inner, look: look, session: session, ui: ui, track: track, rows: rows)
                        }
                        EditorPlayhead(session: session, track: track, offsetX: offset.x, height: h)
                    }
                    .frame(width: grid.barWidth, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background { Color.clear.recessed() }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Track \(track + 1) steps")
                }
                if velocity {
                    HStack(spacing: 2) {
                        Text("Vel").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            .frame(width: grid.labelWidth, alignment: .trailing)
                        VelocityLane(track: t, selected: ui.selectedStep[track])
                            .offset(x: -offset.x)
                            .frame(width: grid.barWidth, height: PianoRoll.velocityHeight, alignment: .leading)
                            .clipped()
                            .recessed()
                            .accessibilityHidden(true)
                    }
                }
        }
        .followsView(ui: ui, grid: grid, offset: offset) { request = .init(x: $0, id: $1) }
        .onChange(of: rows) { _, r in ui.keptRows[track] = Set(r) }
        .onChange(of: track) { _, _ in ui.keptRows = [:] }
    }
}

/// The drum grid for the phone: as many lanes as fit, the rest scroll with two fingers (no pinned lane,
/// Scott 2026-11-04). Lane names play the sound and pick the lane, as on the iPad.
struct PhoneDrumGrid: View {
    @Environment(\.grid) private var grid
    @Environment(\.look) private var look
    let session: DeviceSession
    let ui: EditorUI
    let height: CGFloat
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<DrumGridContent>.ScrollRequest?

    var body: some View {
        let h = height
        HStack(alignment: .top, spacing: 2) {
                VStack(spacing: 0) {
                    ForEach(0..<16, id: \.self) { l in
                        AuditionLabel(text: Music.drumLanes[l], spoken: Music.drumLanes[l], bold: l == ui.selectedLane,
                                      select: { ui.selectedLane = l },
                                      down: { session.keyDown(l) }, up: { session.keyUp(l) })
                    }
                }
                .offset(y: -offset.y)
                .frame(width: grid.labelWidth, height: h, alignment: .top)
                .clipped()
                ZStack(alignment: .topLeading) {
                    TwoFingerScrollView(contentSize: grid.drumContentSize, offset: $offset, request: request, snapX: grid.barWidth) {
                        DrumGridContent(grid: grid, look: look, session: session, ui: ui)
                    }
                    EditorPlayhead(session: session, track: session.drumTrack ?? 0, offsetX: offset.x, height: h)
                }
                .frame(width: grid.barWidth, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .background { Color.clear.recessed() }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Drum steps")
        }
        .followsView(ui: ui, grid: grid, offset: offset) { request = .init(x: $0, id: $1) }
    }
}

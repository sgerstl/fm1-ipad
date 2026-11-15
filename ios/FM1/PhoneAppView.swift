import SloopKit
import SwiftUI

/// The iPhone layout (landscape, 2026-11-04): one 44 pt top bar, then one job at a time. Designed in the
/// mockups (vault: Projects/Dev/fm1-ipad/iphone-adaptation.md) and built screen by screen: Sequence
/// first, then Shape, Browse and Arrange. Never the iPad's canvas shrunk onto the phone.
struct PhoneAppView: View {
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @State private var size = CGSize(width: 852, height: 393)
    @State private var padsReturn: Page?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AudioThrough.self) private var through
    @Environment(ProjectStore.self) private var projects

    /// A tab's page (Pads · Edit · Timeline, decision 28). SLOOP's song has one Song page for Pads and the Timeline.
    @ViewBuilder private func tabPage(_ t: PhoneTab) -> some View {
        switch t {
        case .edit: PhoneSequence(session: session, ui: ui)
        case .mix:
            // the six tracks' levels, pans, sends, mutes and meters (GLO's MIXER); the shared pages are the pop-up's
            PhoneMixerRows(session: session, ui: ui).padding(.leading, 8)
        case .pads, .timeline:
            if session.capabilities.contains(.sloopSong) { SongPage(session: session, ui: ui, compact: true) }
            else if let store = session.skiffSong {
                if t == .pads {
                    // Skiff's Pads, the grid (board 40, 46): six rows, the scenes under them
                    PadsPage(session: session, store: store, ui: ui, layout: .phone)
                } else {
                    PhoneTimeline(session: session, store: store, ui: ui)
                }
            } else { NotOnThisFirmware.arrange(session) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PhoneHeader(session: session, ui: ui, useDemo: $useDemo)
            // the hairline that ends the header runs the full width
            Rectangle().fill(Theme.control).frame(height: 1).padding(.horizontal, -8).accessibilityHidden(true)
            if session.isConnected {
                Group {
                    let pager = PhoneTabPager(tab: ui.phoneTab, colour: Theme.track[session.selectedTrack]) { t in tabPage(t) }
                    // Skiff: the sound panel comes in from the right over every tab, the FM-1's sound keys (and the
                    // rail, Settings › Sound buttons) opening it, as on the iPad (Scott, 2026-11-10)
                    if ui.songTab {
                        PhoneSoundHost(session: session, ui: ui) { pager }
                    } else {
                        pager
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // a button pressed on the FM-1 brings up the tab that shows its screen, as on the iPad
                .onChange(of: session.deviceScreen) { _, s in
                    if session.dialect == .skiff { SeqCursor.follow(s, session: session, ui: ui) }
                    guard ui.followDevice, let s, let tab = SoundPage.tab(for: s, session), tab != ui.page else { return }
                    ui.pageFromDevice = true
                    ui.page = tab
                }
            } else {
                ConnectionState(status: session.status, useDemo: $useDemo)
            }
        }
        // ARP held on the FM-1 (Skiff's PERFORM) shows Pads while it's held, then goes back (as the iPad, 2026-11-07)
        .onChange(of: session.screenLinked && session.deviceScreen?.layer == SkiffButtonMap.performLayer) { _, held in
            guard session.skiffSong?.performs == true, ui.followDevice else { return }
            if held {
                padsReturn = ui.page
                if ui.page != .song { ui.pageFromDevice = true; ui.page = .song }
            } else if let r = padsReturn {
                ui.page = r
                padsReturn = nil
            }
        }
        // another tab closes the sound panel (the FM-1's key or the rail brings it back)
        .onChange(of: ui.phoneTab) { _, _ in if ui.songTab { ui.soundPanel = nil } }
        // GLO on the FM-1: its MIXER page is the Mix tab; DELAY, REVERB, CHORUS and GLOBAL open the pop-up over it
        .onChange(of: ui.mixerSection) { _, sec in
            guard ui.pageFromDevice, ui.songTab else { return }
            ui.mixPopup = sec != .mixer
        }
        .padding(.horizontal, 8)
        .padding(.top, 0)
        // a held knob's full-size ring, over everything and kept on the screen, as on the iPad
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .environment(\.canvasSize, size)
        // the sheets that rise from the foot (decision 33): Sounds (a head's hold menu, SAVE), Mix (GLO), Projects (Skiff's four)
        .overlay {
            PhoneSheetFrame(open: ui.presetsPanel, height: 330, label: "Sounds", close: { ui.presetsPanel = false }) {
                PhoneSoundsSheet(session: session, ui: ui)
            }
        }
        .overlay {
            PhoneSheetFrame(open: ui.mixPopup, height: 320, label: "Mix", close: { ui.mixPopup = false }) {
                PhoneMixPopup(session: session, ui: ui)
            }
        }
        .overlay {
            PhoneSheetFrame(open: ui.patternsSheet != nil && session.skiffSong != nil, height: 376, label: "Patterns", close: { ui.patternsSheet = nil }) {
                if let store = session.skiffSong { PhonePatternsSheet(session: session, store: store, ui: ui, mode: ui.patternsSheet ?? .manage) }
            }
        }
        .overlay {
            PhoneSheetFrame(open: ui.projectsOpen && session.dialect == .skiff, height: 330, label: "Projects", close: { ui.projectsOpen = false }) {
                PhoneProjectsSheet(session: session, ui: ui)
            }
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
        // the sheets the song-name menu and the FM-1 open (decision 33)
        .sheet(isPresented: Binding(get: { ui.phoneSettingsOpen }, set: { ui.phoneSettingsOpen = $0 })) {
            SettingsSheet(session: session).environment(through)
        }
        .sheet(isPresented: Binding(get: { ui.projectsOpen && session.dialect != .skiff }, set: { ui.projectsOpen = $0 })) {
            ProjectsSheet(store: projects, session: session)
        }
        .overlay { EdgeWells(ui: ui) }        // (a dragged pad's Clear, Edit and Duplicate wells, on the screen's edges)
        .overlay { TrackMenuLayer(session: session, ui: ui) }
        .overlay { TrackPickerLayer(session: session, ui: ui) }
        .overlay { KnobPanelLayer(ui: ui) }
        .overlay(alignment: .bottom) { RecordingKnobsBar(session: session).padding(.bottom, 12).padding(.horizontal, 12) }
        .coordinateSpace(name: AppView.space)
        .sessionUpkeep(session)        // the same upkeep as the iPad's AppView
        .foregroundStyle(Theme.text)
        .font(.lupe(15))
        .monospacedDigit()
    }
}

// MARK: - Launch at (Skiff)

/// Skiff's Launch at and Cancel waiting, which the iPad keeps in the Pads tool row: no room for that row on the phone,
/// so a key in the top bar (board 46): the launch point and how many launches wait; tapped, a menu of the four points,
/// what waits and Cancel waiting (board 47, as a menu).
struct PhoneLaunchKey: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    @State private var frame: CGRect = .zero

    private var launch: SongPlayback.Launch { store.perform?.launch ?? session.launchMode }
    /// Launches and mutes waiting for the launch point (as PadsPage counts them).
    private var waiting: Int {
        let launches = session.trackIndices.filter { store.marks($0, launchIn: nil).queued != nil }.count
        return launches + (store.perform?.staged.filter { $0 != .none }.count ?? 0)
    }
    static func name(_ l: SongPlayback.Launch) -> String { ["Loop", "Bar", "Beat", "Now"][l.rawValue] }

    var body: some View {
        // (redrawn with the pads' clock: what waits changes as launches land)
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let w = waiting
            // a word with ⌄ beside the readout (decision 29), what waits under it, as Android's
            HeaderWord(text: Self.name(launch), size: 14, primary: false, sub: w > 0 ? "\(w) waiting" : nil) {
                if !OutsideTouch.justClosed { open() }
            }
            .globalFrame($frame)
            .disabled(store.offline)
            .accessibilityLabel("Launch at")
            .accessibilityValue(Self.name(launch) + (w > 0 ? ", \(w) waiting" : ""))
            .accessibilityHint("Where a pad, a scene or a mute lands while playing, and Cancel waiting")
        }
    }

    private func open() {
        ui.menu = AppMenu(title: "Launch at", groups: {
            var g: [[MenuItem]] = []
            g.append(SongPlayback.Launch.allCases.map { l in
                MenuItem(title: Self.name(l), checked: l == launch) {
                    Task { if await store.performOp(.launch(l)) { session.adoptLaunch(l) } }
                }
            })
            let w = waiting
            g.append([MenuItem(title: w > 0 ? "\(w) waiting for the launch point" : "Nothing waiting", note: true),
                      MenuItem(title: w > 0 ? "Cancel \(w) waiting" : "Cancel waiting", icon: "xmark", enabled: w > 0) {
                          Task { await store.performOp(.cancel) }
                      }])
            return g
        }, at: CGPoint(x: frame.minX, y: frame.maxY), fromKey: true)
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
                    if session.isKit(t) {
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
            .phoneTrackAnchor()       // the tab change's track thread lands on the step grid
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .environment(\.grid, metrics)
        .overlay(alignment: .topTrailing) {
            if stepPanel { panel.transition(reduceMotion ? .opacity : .move(edge: .trailing)) }
        }
        // Skiff's SEQ (NOTES, FEEL) on the FM-1 or the rail: the step panel comes in (SeqKey.focus flashes it)
        .onChange(of: ui.flash) { _, f in if f?.target == .stepPanel { ui.flash = nil; if !stepPanel { setPanel(true) } } }
        .onAppear { if ui.flash?.target == .stepPanel { ui.flash = nil; stepPanel = true } }
    }

    /// The panel slides in and out with the iPad's side-panel timing.
    private func setPanel(_ open: Bool) {
        withAnimation(reduceMotion ? nil : open ? .spring(response: 0.42, dampingFraction: 0.9) : .easeInOut(duration: 0.32)) { stepPanel = open }
    }

    private func ruler(_ t: Int) -> some View {
        let track = session.tracks[t]
        let i = ui.selectedStep[t]
        let scale = track.scale == 0 ? "chromatic" : "\(Music.noteNames[track.root % 12]) \(Music.scales[min(track.scale, 15)].spoken)"
        var detail = session.isDrums(t) ? "Drums · length \(track.length)" : "Track \(t + 1) · \(scale) · length \(track.length)"
        // Skiff (the Edit tab, board 50): the track, the entry it's on and its pattern, the pattern Skiff edits
        if let store = session.skiffSong, let list = store.song?.tracks[safe: t], let on = list.entryOn, let e = list.entries[safe: on] {
            detail = "\(t + 1) \(Entries.trackName(t, session: session)) · \(Entries.letter(on)) · " + (e.isRest ? "REST" : "pattern \(e.label)")
                + (session.isKit(t) ? "" : " · \(scale)") + " · \(track.length) steps"
        }
        return HStack(spacing: 8) {
            Text(detail).font(.lupe(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            Spacer(minLength: 8)
            // STEPS, the pattern's LENGTH (batch item 9; decision 31 moved it here from the track controls box): slides as
            // every value does, double tap back to 16
            KnobControl(ui: ui, column: (0, Theme.track[t], false), face: { spec, dragging in
                AnyView(HStack(spacing: 6) {
                    Text("STEPS").font(.lupe(11, .medium)).foregroundStyle(Theme.textSecondaryRaised)
                    Text(spec.shown).font(.lupeNumber(15, .semibold)).monospacedDigit().foregroundStyle(Theme.text)
                }
                .padding(.horizontal, 10).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(dragging ? Theme.tones[2] : Theme.control))
                .overlay(alignment: .bottom) {
                    // how far through its range, in the track's colour
                    GeometryReader { g in
                        Capsule().fill(Theme.track[t]).frame(width: g.size.width * CGFloat(spec.fraction), height: 2)
                    }
                    .frame(height: 2).padding(.horizontal, 8).padding(.bottom, 2)
                })
            }) { KnobSpec.all(session)[2] }
            .fixedSize()
            Button { setPanel(!stepPanel) } label: {
                HStack(spacing: 6) {
                    Text("Step \(i + 1)").font(.lupe(12, .semibold))
                    // Skiff: the inspector's own ‹ › sit where the panel's × would, so this key closes it (board 50)
                    if stepPanel, skiffInspector { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                }
                    .padding(.horizontal, 10).frame(height: 28)
                    .latchedKey(stepPanel, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink(latched: stepPanel))
            .accessibilityLabel("Step \(i + 1) panel")
            .accessibilityHint(stepPanel ? "Closes the step panel" : "Opens the step panel")
            .accessibilityAddTraits(stepPanel ? .isSelected : [])
            if !session.isDrums(t) {
                Button { velocity.toggle() } label: {
                    HStack(spacing: 6) {
                        LED(on: velocity)
                        Text("Velocity").font(.lupe(12, .semibold))
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .latchedKey(velocity, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink(latched: velocity))
                .accessibilityAddTraits(velocity ? .isSelected : [])
            }
        }
    }

    /// Skiff's step inspector rather than SLOOP's panel (a melodic Skiff track).
    private var skiffInspector: Bool { session.dialect == .skiff && !session.isKit(session.selectedTrack) }

    // The iPad's selected-step panel, scrolling inside a narrower overlay; × closes it.
    private var panel: some View {
        ScrollView {
            // Skiff's melodic tracks: its own step inspector (NOTES, FEEL, the sound at the step), as the iPad's editor
            if skiffInspector { SkiffStepInspector(session: session, ui: ui) }
            else { SelectedStepPanel(session: session, ui: ui) }
        }
        .scrollIndicators(.hidden)
        .frame(width: Overview.boxWidth)        // the iPad column's width, so its keys lay out as there
        .overlay(alignment: .topTrailing) {
            if !skiffInspector {
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
        }
        .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
        .padding(.top, 34)
    }
}

/// The piano roll for the phone: the iPad's rows, cells, playhead and pan, without the
/// header and step numbers (the ruler above says where you are); the velocity lane on a toggle.
struct PhonePianoRoll: View {
    @Environment(\.grid) private var grid
    @Environment(\.soundPanelRoom) private var panelRoom      // the sound panel over the grid: it scrolls on under it
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
        let lane = (velocity ? PianoRoll.velocityHeight + 6 : 0) + (panelRoom > 0 ? 10 : 0)
        let h = height - lane
        let inner = { var m = grid; m.gridHeight = h; return m }()
        VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 2) {
                    VStack(spacing: 0) {
                        // the piano edge (board 75, decision 31): white and black keys, C named; a key plays its note
                        ForEach(rows, id: \.self) { n in
                            PianoEdgeKey(note: n, inScale: Music.inScale(n, root: t.root, scale: t.scale),
                                         down: { session.noteDown(n) }, up: { session.noteUp(n) })
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.trailing, 4)
                    .offset(y: -offset.y)
                    .frame(width: grid.labelWidth, height: h, alignment: .top)
                    .clipped()
                    ZStack(alignment: .topLeading) {
                        TwoFingerScrollView(contentSize: CGSize(width: CGFloat(session.stepCount) * grid.stepWidth + panelRoom, height: max(h, CGFloat(rows.count) * grid.rowHeight)),
                                            offset: $offset, request: request,
                                            rowKeys: rows, rowHeight: grid.rowHeight, snapX: grid.barWidth,
                                            holdRing: PianoRollContent.holdTime,
                                            panFrom: { PianoRollContent.grip(at: $0, session.tracks[track].steps, rows, inner) == nil }) {
                            PianoRollContent(grid: inner, session: session, ui: ui, track: track, rows: rows)
                        }
                        EditorPlayhead(session: session, track: track, offsetX: offset.x, height: h)
                    }
                    .frame(width: grid.barWidth, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background { Color.clear.recessed() }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Track \(track + 1) steps")
                }
                // the sound panel over the grid (decision 35): a scroll indicator under it says how far the steps run on
                if panelRoom > 0 {
                    let content = CGFloat(session.stepCount) * grid.stepWidth + panelRoom
                    GeometryReader { g in
                        let w = g.size.width, thumb = max(24, w * grid.barWidth / content)
                        Capsule().fill(Theme.stepEmpty)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.textSecondary).frame(width: thumb)
                                    .offset(x: (w - thumb) * min(1, max(0, offset.x / max(1, content - grid.barWidth))))
                            }
                    }
                    .frame(width: grid.barWidth - panelRoom - 8, height: 4)
                    .padding(.leading, grid.labelWidth + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                }
                if velocity {
                    HStack(spacing: 2) {
                        Text("Vel").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
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

/// The drum grid for the phone: as many lanes as fit, the rest scroll (no pinned lane,
/// Scott 2026-11-04). Lane names play the sound and pick the lane, as on the iPad.
struct PhoneDrumGrid: View {
    @Environment(\.grid) private var grid
    @Environment(\.soundPanelRoom) private var panelRoom
    let session: DeviceSession
    let ui: EditorUI
    let height: CGFloat
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<DrumGridContent>.ScrollRequest?

    var body: some View {
        let h = height
        HStack(alignment: .top, spacing: 2) {
                VStack(spacing: 0) {
                    ForEach(session.drumLanes.indices, id: \.self) { l in
                        AuditionLabel(text: session.drumLanes[l], spoken: session.drumLanes[l], bold: l == ui.selectedLane,
                                      select: { ui.selectedLane = l },
                                      down: { session.keyDown(l) }, up: { session.keyUp(l) })
                    }
                }
                .offset(y: -offset.y)
                .frame(width: grid.labelWidth, height: h, alignment: .top)
                .clipped()
                ZStack(alignment: .topLeading) {
                    TwoFingerScrollView(contentSize: CGSize(width: grid.drumContentSize.width + panelRoom, height: CGFloat(session.drumLanes.count) * grid.rowHeight), offset: $offset, request: request, snapX: grid.barWidth,
                                        holdRing: DrumGridContent.holdTime) {
                        DrumGridContent(grid: grid, session: session, ui: ui)
                    }
                    EditorPlayhead(session: session, track: session.kitTrack ?? 0, offsetX: offset.x, height: h)
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

/// The phone's tracks, by the finger that tapped the one chip: each track a chiclet, the current one lit
/// in its colour and lifted; a tap picks it, a tap anywhere else closes. Elevation 3, as any popup at the
/// finger. Kept on the screen.
struct TrackPickerLayer: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.canvasSize) private var canvas
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let at = ui.trackPicker {
                let width = CGFloat(session.trackCount) * 48 + 12
                HStack(spacing: 4) {
                    ForEach(session.trackIndices, id: \.self) { t in
                        Button {
                            session.select(track: t)
                            ui.trackPicker = nil
                        } label: {
                            TrackChip(track: t, size: 32, selected: session.selectedTrack == t)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressSink())
                        .accessibilityLabel("Track \(t + 1), \(session.tracks[t].displayName)")
                        .accessibilityAddTraits(session.selectedTrack == t ? .isSelected : [])
                    }
                }
                .padding(6)
                .elevated(.held, radius: 12)
                .closesOnOutsideTouch { ui.trackPicker = nil }       // (and the touch still reaches the page)
                // beside the finger: just under it, starting at it, inside the screen
                .offset(x: min(max(at.x - 24, 8), canvas.width - width - 8), y: min(at.y + 28, canvas.height - 64))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Tracks")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ui.trackPicker)
    }
}

/// One key of the phone's piano edge (board 75): a white key in light grey, a black key's dark bar across 62 % of it from
/// the left, a hairline under a white key, every C named. Pressed, it plays its note (as the note names did) and dims.
/// Board 75's own greys: the app's tokens have no piano-key colours (a token gap, noted in the device check).
struct PianoEdgeKey: View {
    @Environment(\.grid) private var grid
    let note: Int
    let inScale: Bool
    let down: () -> Void
    let up: () -> Void
    @State private var pressed = false

    static let white = Color(hex: 0xC9C9CF), black = Color(hex: 0x1E1E22), edge = Color(hex: 0x8A8A92), ink = Color(hex: 0x3A3A40)
    static func isBlack(_ n: Int) -> Bool { [1, 3, 6, 8, 10].contains(((n % 12) + 12) % 12) }

    var body: some View {
        let blackKey = Self.isBlack(note)
        ZStack(alignment: .leading) {
            Self.white
            Rectangle().fill(Self.edge).frame(height: 1).frame(maxHeight: .infinity, alignment: .bottom)
            if blackKey {
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 3, topTrailingRadius: 3)
                    .fill(Self.black)
                    .frame(width: (grid.labelWidth - 4) * 0.62)
                    .padding(.vertical, -1)
            }
            if note % 12 == 0 {
                Text(Music.noteName(note)).font(.lupe(10, .semibold)).foregroundStyle(Self.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 4)
            }
            Color.black.opacity(pressed ? 0.25 : 0)
        }
        .frame(width: grid.labelWidth - 4, height: grid.rowHeight)
        .animation(.easeOut(duration: pressed ? 0.06 : 0.15), value: pressed)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { pressed = true; down() } }
            .onEnded { _ in pressed = false; up() })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Play \(Music.spokenNoteName(note))" + (inScale ? "" : ", outside the scale"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            down()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { up() }
        }
    }
}

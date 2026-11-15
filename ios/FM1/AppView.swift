import SloopKit
import SwiftUI

struct AppView: View {
    static let space = "canvas"
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// The Song tab's view before ARP was held on the FM-1 (the Pads while it's held), to go back to.
    @State private var padsReturn: SongView?
    /// Connected at least once this launch: a loss then holds the page instead of swapping it (board 42, option A).
    @State private var everConnected = false
    /// The FM-1 lost (or found again and being read) after it was connected: the page stays where it was, faded back
    /// and grey, read-only, with the card over it (Scott, 2026-11-09: "A").
    private var held: Bool {
        guard everConnected, !session.isConnected else { return false }
        switch session.status { case .lost, .connecting: return true; default: return false }
    }

    var body: some View {
        VStack(spacing: 16) {
            TopBar(session: session, ui: ui, useDemo: $useDemo)
            if session.isConnected || held {
                pages.animation(pageAnimation, value: ui.page)
                    // held: faded back and grey, touches off; back to itself when the FM-1 is read again
                    .allowsHitTesting(!held)
                    .grayscale(held ? 0.85 : 0)
                    .opacity(held ? 0.45 : 1)
                    // ...and out of VoiceOver's reach while held: allowsHitTesting stops fingers, not VoiceOver's
                    // double-tap, so the read-only page could still be pressed (2026-11-10, WCAG 4.1.2). The card
                    // (the overlay, below) stays readable.
                    .accessibilityHidden(held)
                    .animation(.easeOut(duration: held ? 0.3 : 0.25), value: held)
                    .overlay(alignment: .top) {
                        if held {
                            LostCard(status: session.status)
                                .padding(.top, 8)
                                .transition(reduceMotion ? .opacity.animation(.easeOut(duration: 0.15))
                                            : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity).animation(.easeOut(duration: 0.25)),
                                                          removal: .move(edge: .top).combined(with: .opacity).animation(.easeIn(duration: 0.2))))
                        }
                    }
                    .animation(.easeOut(duration: 0.25), value: held)
                    // a button pressed on the FM-1 brings up the tab that shows its screen
                    .onChange(of: session.deviceScreen) { _, s in
                        // Skiff: every button lands somewhere (SkiffButtonMap), GLO in the mixer panel
                        if session.dialect == .skiff {
                            SeqCursor.follow(s, session: session, ui: ui)
                            // the FM-1's page is the one brought forward (its card scrolls up and lights)
                            if let s, !s.home, s.layer == 0, let p = SoundPage.page(session, fw: s.page), ui.focusedPage?.id != p.id { ui.focus(p) }
                            if let s, !SoundPanelControl.follow(s, session: session, ui: ui) { SkiffNavigator.follow(s, session: session, ui: ui) }
                            return
                        }
                        guard ui.followDevice, let s, let tab = SoundPage.tab(for: s, session), tab != ui.page else { return }
                        ui.pageFromDevice = true
                        ui.page = tab
                    }
            } else {
                ConnectionState(status: session.status, useDemo: $useDemo)
                    .transition(.opacity.animation(.easeOut(duration: 0.3)))
            }
        }
        .sessionUpkeep(session)
        .onChange(of: session.isConnected, initial: true) { _, on in if on { everConnected = true } }
        // Skiff: Sequence and Arrange are one Song tab (Scott, 2026-11-05)
        .onChange(of: session.dialect == .skiff && session.skiffSong != nil, initial: true) { _, on in ui.songTab = on }
        // the card is said when it comes and when the FM-1 is back, once each (4.1.3: a status message reaches
        // VoiceOver without moving focus; the card's own line blends, which VoiceOver doesn't hear)
        .onChange(of: held) { was, now in
            if now, !was { AccessibilityNotification.Announcement("FM-1 disconnected. Plug it back in; nothing is lost.").post() }
            else if was, !now, session.isConnected { AccessibilityNotification.Announcement("FM-1 back").post() }
        }
        // FREE TAKE kept on the FM-1 (Skiff 2.5, level 1): the Timeline, where a take gets chopped, even though Pads are
        // the default (batch list item 4); the block is selected there and the strip says how to undo it
        // the FREE TAKE picker opened (v7): the Song tab's Timeline too, where it lands, with the picker in the editor's place
        .onChange(of: session.takePicker != nil) { _, open in
            guard open, ui.songTab, ui.followDevice else { return }
            if ui.songView != .timeline { ui.songView = .timeline }
            if ui.page != .song { ui.pageFromDevice = true; ui.page = .song }
        }
        .onChange(of: session.freeTake?.id) { _, id in
            guard id != nil, ui.songTab, ui.followDevice else { return }
            if ui.songView != .timeline { ui.songView = .timeline }
            if ui.page != .song { ui.pageFromDevice = true; ui.page = .song }
        }
        // ARP held on the FM-1 (PERFORM) shows the Pads while it's held (Scott, 2026-11-07). (The view no longer
        // follows the playback mode to the timeline: Pads are the default, the timeline is the user's to pick, 2026-11-09)
        .onChange(of: session.screenLinked && session.deviceScreen?.layer == SkiffButtonMap.performLayer) { _, held in
            guard session.skiffSong?.performs == true, ui.followDevice else { return }
            if held {
                padsReturn = ui.songView
                ui.songView = .pads
                if ui.page != .song { ui.pageFromDevice = true; ui.page = .song }
            } else if let r = padsReturn {
                ui.songView = r
                padsReturn = nil
            }
        }
        .padding(24)
        .overlay(alignment: .bottom) { keyboard }
        .overlay(alignment: .bottom) { undoToast }
        .overlay(alignment: .bottom) { RecordingKnobsBar(session: session).padding(.bottom, 32) }
        .overlay { ListUndoStrip(session: session, ui: ui) }   // (a pad cleared or blocks deleted: Undo)
        .overlay { EdgeWells(session: session, ui: ui) }        // (a dragged pad's Clear, Edit and Duplicate wells, on the screen's edges)
        .overlay { TrackMenuLayer(session: session, ui: ui) }
        .overlay { KnobPanelLayer(ui: ui) }
        .overlay { ValueLoupeLayer(loupe: ui.loupe) }
        .coordinateSpace(name: Self.space)
        .foregroundStyle(Theme.text)
        .font(.lupe(15))
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
            // (Skiff has no Sequence page: its Song tab carries the editor)
            if !ui.shell {
                SequencerPage(session: session, ui: ui)
                .opacity(onSequencer ? 1 : 0)
                .allowsHitTesting(onSequencer)
                .accessibilityHidden(!onSequencer)
                .environment(\.pageVisible, onSequencer)
            }
            Group {
                switch ui.page {
                case .sequencer:
                    EmptyView()
                case .library:
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn {
                            // Skiff: no pads here (Scott, 2026-11-06): the rail beside the presets has the same keys
                            if !ui.songTab { FunctionPads(session: session, ui: ui) }
                            if !session.selectedIsDrums { LibraryEngines(session: session, ui: ui) }
                        }
                        // Skiff: a function button's sound panel pushes the browse area (four columns to two)
                        if ui.songTab {
                            SoundPanelHost(session: session, ui: ui, makesRoom: true) { LibraryPage(session: session, ui: ui) }
                        } else {
                            LibraryPage(session: session, ui: ui)
                        }
                    }
                case .song:
                    HStack(alignment: .top, spacing: 16) {
                        if let store = session.skiffSong {
                            // Skiff's Song tab: Arrange's lanes over the pattern editor, a divider between (boards 19, 20)
                            SoundPanelHost(session: session, ui: ui) {
                                SkiffSongPage(session: session, store: store, ui: ui)
                            }
                        } else {
                            leftColumn { FunctionPads(session: session, ui: ui) }
                            NotOnThisFirmware.arrange(session)
                        }
                    }
                case .sound:
                    HStack(alignment: .top, spacing: 16) {
                        leftColumn {
                            FunctionPads(session: session, ui: ui)
                            // ("Last turned on the FM-1" was here; Scott doesn't need it, 2026-11-05: the space stays empty)
                        }
                        SoundTab(session: session, ui: ui)
                    }
                case .mixer:
                    // full width (Scott, 2026-11-06): a strip's name selects its track, so no left column; a button's
                    // panel pushes the strips and the carousel narrower and gives the width back when it closes
                    SoundPanelHost(session: session, ui: ui, makesRoom: true) {
                        MixerPage(session: session, ui: ui)
                    }
                }
            }
            .transition(.opacity)
            .id(ui.page)
            // the Presets panel: from the right, over the page, which no longer dims and stays live beside it (Scott,
            // 2026-11-10, when the Sounds tab went): pads, the track heads and the sound panel all still answer. Done, SAVE,
            // another tab or Escape close it.
            // (none over Skiff's Song tab or the Mixer: their own rows select a track)
            if !skiffArrange, ui.page != .mixer {
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
                    // over a dimmed page: VoiceOver stays in it, and the scrub closes it (2026-11-10, 1.3.1, 2.4.3)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { ui.sampler = nil }
                    .zIndex(5)
            }
            if ui.presetsPanel {
                PresetsPanel(session: session, ui: ui)
                    .geometryGroup()                      // moves as one piece: nothing inside trails it
                    // beside the sound panel (ENV, LFO…) when that's open, so a sound can be picked and shaped together:
                    // the panel's width, the rail's when it's on the right, and their gaps (780 + 442 + 68 fits 1376)
                    .padding(.trailing, presetsRoom)
                    .animation(reduceMotion ? nil : SoundPanelHost<EmptyView>.slide, value: presetsRoom)
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
            ui.soundPanel = nil
        }
    }

    /// How far in from the right the Presets panel sits: clear of the sound panel and the rail when they're there.
    private var presetsRoom: CGFloat {
        guard ui.soundPanel != nil, ui.shell, ui.page == .song || ui.page == .mixer else { return 0 }
        // (read here, not as @AppStorage: this is an extension of AppView; Settings changes them only between uses)
        let d = UserDefaults.standard
        let showRail = d.object(forKey: SoundButtons.key) as? Bool ?? SoundButtons.standard
        let hand = d.string(forKey: RailSide.key).flatMap(RailSide.init(rawValue:)) ?? .right
        let rail = showRail && hand == .right ? SoundRail.width + 12 : 0
        // a flush panel runs over the page margin to the screen edge, so it takes that much less room
        let flush = !showRail || hand == .left
        return SoundPanel.width + 12 + rail - (flush ? SoundPanelHost<EmptyView>.pageMargin : 0)
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

    /// After Clear all: what happened and a way back, for 8 seconds.
    @ViewBuilder var undoToast: some View {
        ZStack {
            if let c = ui.lastClear {
                HStack(spacing: 16) {
                    TrackChip(track: c.track)
                    Text("Cleared track \(c.track + 1)").font(.lupe(15, .semibold))
                    Button {
                        StepClear.undo(session, c)
                        ui.lastClear = nil
                    } label: {
                        Text("Undo clear").fontWeight(.semibold).padding(.horizontal, 16).frame(height: 44).raisedKey()
                    }
                    .buttonStyle(PressSink())
                }
                .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
                .background { Color.clear.elevated(.panel) }
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

    /// The keyboard comes up from the bottom over the step panel; the grid above it still pans.
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
                    Group {
                        if !session.isKit(t) { SkiffStepInspector(session: session, ui: ui) }
                        else { SelectedStepPanel(session: session, ui: ui) }
                    }
                    .flashRing(ui, .stepPanel)
                    TrackPanel(session: session, ui: ui).flashRing(ui, .trackPanel)
                }
                .frame(width: Overview.boxWidth, height: PianoRoll.panelHeight)
                // a track's Record sample turns the grid over: the sampler is on its back. The back goes in
                // first, facing away, then the card turns (inserted already turned, it just appeared)
                ZStack {
                    Group {
                        if session.isKit(t) {
                            DrumGrid(session: session, ui: ui)
                        } else {
                            PianoRoll(session: session, ui: ui, track: t)
                        }
                    }
                    .flashRing(ui, .grid)
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

/// A tab whose feature the connected firmware doesn't have in Lupe yet: what's missing, and what to do
/// meanwhile. Drawn as the connection states are.
struct NotOnThisFirmware: View {
    let title: String
    let detail: String

    /// A Skiff that lands here has no song lists (older than 2.0),
    /// so Lupe's Song tab can't show its song: say how to get it (2026-11-06, was "still being designed").
    @MainActor static func arrange(_ session: DeviceSession) -> NotOnThisFirmware {
        NotOnThisFirmware(title: "Update Skiff to use the Song tab",
                          detail: "This Skiff is older than 2.0, so it can't share its song with Lupe. "
                              + "Install Skiff 2.2 from the menu (Install firmware…) to arrange here.")
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(title).font(.lupe(28, .semibold))
            Text(detail)
                .font(.lupe(17))
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
            Text(title).font(.lupe(28, .semibold))
            Text(detail)
                .font(.lupe(17))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            if looking { LookingForFM1().padding(.top, 8) }
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
            "Connect it with a USB-C cable and switch it on. It has to be running Skiff 2.2 or 2.5.1."
        case .connecting:
            "Reading every track. This takes about a second."
        case .connected: ""
        case .wrongFirmware(let found, _) where FirmwareDialect.isSLOOP(found):
            "It runs \(FirmwareCentre.sloopName(found)), which Lupe no longer works with. Lupe works with \(FirmwareDialect.known): install Skiff-Lupe, which Lupe offers, then plug the FM-1 in again."
        case .wrongFirmware(let found, let proto):
            "It reports “\(found)”, editor protocol \(proto). Lupe works with \(FirmwareDialect.known). Install one of those, then plug the FM-1 in again."
        case .lost(let why):
            // (Scott, 2026-11-07: a state that says to reconnect or turn the FM-1 on)
            "\(why). Check the USB-C cable and that the FM-1 is switched on. Lupe picks up where it was as soon as it's back; if it's plugged in and on, unplug it and plug it in again."
        }
    }

    /// Lupe looks for the FM-1 every second (DeviceSession.run): said, so the wait doesn't read as stuck.
    private var looking: Bool {
        switch status {
        case .searching, .lost: true
        default: false
        }
    }

    private var showDemoButton: Bool {
        switch status {
        case .connecting: false
        default: true
        }
    }
}

/// "Looking for the FM-1…" with the system's spinner: the app is retrying, there's nothing to press.
/// The FM-1 lost while it was in use: a card from under the top bar over the held page (board 42, option A). Lost:
/// what happened, what to do, that Lupe is looking; found again: "Back", reading it. The two blend.
struct LostCard: View {
    let status: ConnectionStatus
    private var back: Bool { if case .connecting = status { true } else { false } }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: back ? "cable.connector" : "cable.connector.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(back ? Theme.knob[1] : Theme.caution)
                .frame(width: 48, height: 48)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 8) {
                Text(back ? "Back" : "FM-1 disconnected").font(.lupe(22, .semibold))
                    .contentTransition(.opacity)
                Text(back ? "Reading the FM-1. A second." : "Plug it back in, or check it’s switched on. Lupe picks up where you were: nothing here is lost.")
                    .font(.lupe(15)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if back {
                    ProgressView().progressViewStyle(.linear).tint(Theme.text).padding(.top, 4)
                        .transition(.opacity)
                } else {
                    LookingForFM1().transition(.opacity)
                }
            }
        }
        .padding(24)
        .frame(width: 520, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.control).elevationShadow(.held))
        .animation(.easeOut(duration: 0.15), value: back)
        // (no .updatesFrequently: the card changes twice, and AppView announces each change; 2026-11-10)
        .accessibilityElement(children: .combine)
    }
}

struct LookingForFM1: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Theme.textSecondary)
            Text("Looking for the FM-1…").font(.lupe(15)).foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Skiff records every knob move on the selected track, the iPad's included, while it's armed and playing
/// (EDITOR_PROTOCOL.md "Motion"): Scott recorded edits without knowing (2026-11-05). Said plainly while it
/// happens, with a way to stop. Floats at the foot of the screen, so nothing moves when it comes and goes.
struct RecordingKnobsBar: View {
    let session: DeviceSession

    var body: some View {
        if session.recordingKnobs {
            HStack(spacing: 12) {
                Image(systemName: "record.circle").foregroundStyle(Theme.rec).accessibilityHidden(true)
                Text("Recording knob moves on T\(session.selectedTrack + 1): every change, here or on the FM-1, goes into its steps.")
                    .font(.lupe(13)).fixedSize(horizontal: false, vertical: true)
                Button { session.toggleRec() } label: {
                    Text("Stop recording").font(.lupe(13, .semibold))
                        .padding(.horizontal, 12).frame(minHeight: 44).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 4)
            .frame(maxWidth: 640)
            .elevated(.held, radius: 12)
            .accessibilityElement(children: .contain)
        }
    }
}

import SloopKit
import SwiftUI

@main
struct FM1App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
        }
    }
}

/// Owns the session. Switching between the FM-1 and the demo makes a new one.
struct RootView: View {
    @State private var useDemo = ProcessInfo.processInfo.arguments.contains("-demo")
    @State private var session: DeviceSession
    @State private var ui = EditorUI()
    @State private var through = AudioThrough()
    @State private var projects = ProjectStore()
    @State private var firmware = FirmwareCentre()
    @AppStorage(Look.styleKey) private var lookStyle = LookStyle.flat

    init() {
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        let s = DeviceSession(demo: demo, skiff: DeviceSession.launchedSkiffDemo)
        _session = State(initialValue: s)
        TrackColours.session = s
    }

    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass

    /// A phone (landscape is compact height; a Pro Max is regular width there) or a compact window:
    /// the phone layout. Size classes decide, not the device (2026-11-04).
    private var compact: Bool { heightClass == .compact || widthClass == .compact }

    /// -no-intro: straight to the app (layout checks and screenshots).
    @State private var introOver = ProcessInfo.processInfo.arguments.contains("-no-intro")

    var body: some View {
        Group {
            if compact {
                PhoneAppView(session: session, ui: ui, useDemo: $useDemo)
                    .environment(\.grid, .phone)
                    .environment(through)
                    .environment(projects)
            } else {
                // the iPad: one canvas at the 13-inch iPad Air's size, scaled to fit the screen
                GeometryReader { geo in
                    let s = min(geo.size.width / Theme.canvas.width, geo.size.height / Theme.canvas.height)
                    AppView(session: session, ui: ui, useDemo: $useDemo)
                        .environment(through)
                        .environment(projects)
                        .frame(width: Theme.canvas.width, height: Theme.canvas.height)
                        .scaleEffect(s)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
            }
        }
        .background(Theme.page)
        .environment(firmware)
        .overlay { TempoOverlay(session: session, ui: ui) }
        .overlay { JibMenuLayer(menu: $ui.menu) }
        .modifier(SaveSoundPrompt(session: session, ui: ui))
        .overlay { FirmwareLayer(centre: firmware, session: session) }    // installing firmware: over everything
        // Lupe's intro on every cold launch, over the app, which starts (and connects) underneath it
        .overlay { if !introOver { LaunchIntro { introOver = true } } }
        .environment(\.look, Look(style: lookStyle))
        .onAppear { TouchShow.installIfAsked() }       // -show-touches: screen recordings
        // the source (Scott, 2026-11-06): the FM-1 over USB, the Skiff demo or the SLOOP demo; a change makes a new session
        .task(id: SessionRun(demo: useDemo, skiff: ui.demoSkiff, paused: firmware.holdsDevice)) {
            if session.isDemo != useDemo || (useDemo && session.demoSkiff != ui.demoSkiff) {
                session = DeviceSession(demo: useDemo, skiff: ui.demoSkiff); TrackColours.session = session
            }
            guard !firmware.holdsDevice else { return }      // the firmware installer has the FM-1 to itself
            projects.attach(session)
            await session.run()
        }
        .task(id: ObjectIdentifier(session)) { await firmware.watch(session) }
    }
}

/// The session runs per source, and not while a firmware install holds the FM-1.
private struct SessionRun: Equatable { var demo: Bool, skiff: Bool, paused: Bool }

enum Page: String, CaseIterable, Identifiable {
    // labels name what each tab is for (2026-11-02): sequence a pattern, shape its sound, arrange the song, browse sounds
    case sequencer = "Sequence", sound = "Shape", song = "Arrange", library = "Browse"
    /// Skiff's GLO pages (its Song tab's firmware only): the strips and the shared effects.
    case mixer = "Mixer"
    var id: String { rawValue }
    /// The tabs on SLOOP (no Mixer: its GLO pages are Shape's).
    static let sloopTabs: [Page] = [.sequencer, .sound, .song, .library]
    /// The tabs on Skiff: Song · Shape · Mixer · Browse.
    static let skiffTabs: [Page] = [.song, .mixer, .library]
    /// A tab's name: Skiff's are Song · Mix · Sounds (2026-11-06).
    func title(skiff: Bool) -> String {
        guard skiff else { return rawValue }
        switch self {
        case .song: return "Song"
        case .mixer: return "Mix"
        case .library: return "Sounds"
        default: return rawValue
        }
    }
}

struct ViewJump: Equatable {
    var bar: Int
    var id: Int
}

/// What the iPad alone decides: which step is selected (per track), which drum lane, which page.
@MainActor @Observable
final class EditorUI {
    /// -page sound|song|library|sequencer opens on that page (screenshots and layout checks, 2026-11-04)
    var page: Page = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-page"), i + 1 < a.count else { return .sequencer }
        return ["sound": .sound, "song": .song, "library": .library, "mixer": .mixer][a[i + 1]] ?? .sequencer
    }() {
        // Skiff: Sequence and Arrange are one Song tab; whatever asks for Sequence (HOME, SEQ, a tab) lands there.
        // And there's no Shape tab (Scott, 2026-11-06): whatever asks for Shape brings the button's pages in on the
        // sound panel, over the tab that was up
        didSet {
            if songTab, page == .sequencer { page = .song }
            if songTab, page == .sound {
                page = oldValue == .sound ? .song : oldValue
                if SoundPanelControl.families.contains(soundFamily) { soundPanel = SoundPanelState(family: soundFamily) }
            }
        }
    }
    /// Skiff: the Song tab (Arrange's lanes over the pattern editor) stands for Sequence and Arrange.
    var songTab = false {
        didSet { if songTab, page == .sequencer || page == .sound { page = .song } }
    }
    /// The Song tab: the entry the editor is pinned to (a block tapped); nil follows what each track plays.
    var pinnedEntry: EntryRef?
    /// The Song tab: the pattern pool's drawer is open.
    var poolOpen = false
    /// A pattern being dragged from the pool (set as the drag starts), shared by the drawer and the lanes.
    var dragPattern: Int?
    /// Step editing: the notes picked (a tap, or a lasso) and the steps picked (along the step numbers), on this
    /// track; what was copied; the last change that can be undone, and what it said.
    var noteSel: Set<NoteRef> = []
    var stepSel: Set<Int> = []
    var selTrack = 0
    var clip: [SynthStep]?
    var patternUndo: PatternUndo?
    var selectedStep = Array(repeating: 0, count: 8)      // per track: room for every firmware's tracks
    /// The tempo panel, open under this point (global), from the top bar's BPM.
    var tempoAt: CGPoint?
    /// A Jib menu open over the app (the connection menu, the phone's ⋯, Library's slots).
    var menu: JibMenu?
    /// A sound waiting on its name before it goes to a user slot (Skiff's SAVE > USER).
    var saveSound: SaveSoundRequest?
    var selectedLane = 0
    var keptRows: [Int: Set<Int>] = [:]
    var knobGrab: KnobGrab?
    /// The value being slid, magnified above the finger (ValueLoupe.swift); only the loupe reads it.
    let loupe = LoupeState()
    /// A knob's big control, open under this point (global; .zero: VoiceOver's "Open", centred).
    var knobPanelAt: CGPoint?
    @ObservationIgnored var knobPanelSpec: (() -> KnobSpec)?
    /// -family EDIT (a button's name) opens Shape on that button (screenshots)
    var soundFamily: SoundFamily = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-family"), i + 1 < a.count else { return .fx }
        return SoundFamily(rawValue: a[i + 1]) ?? .fx
    }()
    var keyboardOpen = false
    /// The tabs follow the FM-1's screen (and tapping a tab moves it), when the screen link is there. Always, since
    /// Scott took the switch out of the menu (2026-11-06); kept as a property so what reads it stays as it was.
    var followDevice: Bool { true }
    /// Which firmware the demo FM-1 pretends to run: Skiff, or SLOOP (the menu's "Skiff demo" / "SLOOP demo",
    /// 2026-11-06). Starts from the launch flag (-demo-skiff) so screenshots and tests open where they did.
    var demoSkiff = DeviceSession.launchedSkiffDemo
    /// The track box's timeline, pulled open with its handle on the other tabs; shut again on a page change.
    /// On Sequence it is always open.
    var timelineOpen = false
    /// The grid's first step in view (fractional while panning): the view box on the timeline follows it.
    var viewStep: CGFloat = 0
    /// A bar picked on the timeline: the grid scrolls there.
    var viewJump: ViewJump?
    var trackMenu: TrackMenu?                    // a long-pressed track's menu, where the finger was
    var trackPicker: CGPoint?                    // the phone's one chip tapped (more than four tracks): the tracks, there
    var sectionMenu: SectionMenu?                // a held stored section's menu, where the finger was
    var lastClear: DeviceSession.ClearedTrack?   // offered for undo for a few seconds
    var librarySection: LibrarySection = ProcessInfo.processInfo.arguments.contains("-library-user") ? .user : .engine(0)
    /// The Presets panel is up on the Sequencer, in place of the step panel and knobs.
    var presetsPanel = false
    /// The sampler is open: flipped in place of the grid (from a track's menu) or up from the bottom (Browse).
    var sampler: SamplerRequest?
    /// The last page change came from the FM-1 (its button pressed), not from a tab or pad here.
    var pageFromDevice = false
    /// Skiff's GLO pages: the Mixer tab's section (the strips, Delay, Reverb, Chorus, Global), as GLO steps them.
    var mixerSection: SkiffButtonMap.MixerTab = .mixer
    /// The Song tab's whole-track controls (SWING LEVEL STEPS PAN): open under the selected lane's control, whose
    /// frame (global) the lane header keeps here.
    var trackControlsOpen = false
    var trackControlsAnchor: CGRect = .zero
    /// Motion lanes added with + Lane, per track (parameters with no records yet).
    var addedLanes: [Int: [Int]] = [:]
    /// The motion lanes hidden from the pattern header's chip (they show whenever there's motion otherwise).
    var motionHidden = false
    /// The motion lane opened into its editor (one at a time): its track and parameter. -motion-lane 36 opens that
    /// lane on the selected track (screenshots).
    var openLane: OpenLane? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-motion-lane"), i + 1 < a.count, let id = Int(a[i + 1]) else { return nil }
        return OpenLane(track: 0, id: id)
    }()
    struct OpenLane: Equatable { var track: Int, id: Int }
    /// What a touch on the open lane writes: false a recorded change that holds, true a lock on that step only.
    var motionWritesLocks = false
    /// The page last brought forward (FocusedPage).
    var focusedPage: FocusedPage?
    func focus(_ p: SoundPage) { focusedPage = FocusedPage(id: p.id, n: (focusedPage?.n ?? 0) + 1) }
    /// The Song tab's sound panel (a button's Shape cards from the right); nil: closed. -sound-panel LFO opens it.
    var soundPanel: SoundPanelState? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-sound-panel"), i + 1 < a.count, let f = SoundFamily(rawValue: a[i + 1]) else { return nil }
        return SoundPanelState(family: f)
    }()
    var projectsOpen = false
    /// A place the FM-1 sent Jib to, lit for a moment (the whole-track controls for PATTERN, and so on).
    var flash: Flash?
}

enum FlashTarget: Equatable { case stepPanel, trackPanel, grid, patternBin }
/// The page a button's press (here or on the FM-1) last brought forward: its card scrolls to the top of the panel or
/// the Shape tab and is lit. `n` makes a press of the same page again count.
struct FocusedPage: Equatable {
    var id: String
    var n: Int
}

struct Flash: Equatable {
    var target: FlashTarget
    var id: Int
}

/// A pattern change that can be undone: the steps and LENGTH before it, and what it said ("steps 9–16 added, length
/// 8 → 16").
struct PatternUndo: Equatable {
    var track: Int
    var steps: [SynthStep]
    var length: Int
    var said: String
}

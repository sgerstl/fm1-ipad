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
        let s = DeviceSession(demo: demo)
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
        .overlay { FirmwareLayer(centre: firmware, session: session) }    // installing firmware: over everything
        // Lupe's intro on every cold launch, over the app, which starts (and connects) underneath it
        .overlay { if !introOver { LaunchIntro { introOver = true } } }
        .environment(\.look, Look(style: lookStyle))
        .onAppear { TouchShow.installIfAsked() }       // -show-touches: screen recordings
        .task(id: SessionRun(demo: useDemo, paused: firmware.holdsDevice)) {
            if session.isDemo != useDemo { session = DeviceSession(demo: useDemo); TrackColours.session = session }
            guard !firmware.holdsDevice else { return }      // the firmware installer has the FM-1 to itself
            projects.attach(session)
            await session.run()
        }
        .task(id: ObjectIdentifier(session)) { await firmware.watch(session) }
    }
}

/// The session runs per source, and not while a firmware install holds the FM-1.
private struct SessionRun: Equatable { var demo: Bool, paused: Bool }

enum Page: String, CaseIterable, Identifiable {
    // labels name what each tab is for (2026-11-02): sequence a pattern, shape its sound, arrange the song, browse sounds
    case sequencer = "Sequence", sound = "Shape", song = "Arrange", library = "Browse"
    var id: String { rawValue }
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
        return ["sound": .sound, "song": .song, "library": .library][a[i + 1]] ?? .sequencer
    }()
    var selectedStep = Array(repeating: 0, count: 8)      // per track: room for every firmware's tracks
    /// The tempo panel, open under this point (global), from the top bar's BPM.
    var tempoAt: CGPoint?
    /// A Jib menu open over the app (the connection menu, the phone's ⋯, Library's slots).
    var menu: JibMenu?
    var selectedLane = 0
    var keptRows: [Int: Set<Int>] = [:]
    var knobGrab: KnobGrab?
    /// A knob's big control, open under this point (global; .zero: VoiceOver's "Open", centred).
    var knobPanelAt: CGPoint?
    @ObservationIgnored var knobPanelSpec: (() -> KnobSpec)?
    var soundFamily: SoundFamily = .fx
    var keyboardOpen = false
    /// The tabs follow the FM-1's screen (and tapping a tab moves it), when the screen link is there.
    var followDevice = true
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
    var librarySection: LibrarySection = .engine(0)
    /// The Presets panel is up on the Sequencer, in place of the step panel and knobs.
    var presetsPanel = false
    /// The sampler is open: flipped in place of the grid (from a track's menu) or up from the bottom (Browse).
    var sampler: SamplerRequest?
    /// The last page change came from the FM-1 (its button pressed), not from a tab or pad here.
    var pageFromDevice = false
    /// Skiff's GLO pages: the mixer panel, open on this tab over the page (nil: closed).
    var mixerTab: SkiffButtonMap.MixerTab?
    /// Motion lanes added with + Lane, per track (parameters with no records yet).
    var addedLanes: [Int: [Int]] = [:]
    var projectsOpen = false
    /// A place the FM-1 sent Jib to, lit for a moment (the whole-track controls for PATTERN, and so on).
    var flash: Flash?
}

enum FlashTarget: Equatable { case stepPanel, trackPanel, grid, patternBin }
struct Flash: Equatable {
    var target: FlashTarget
    var id: Int
}

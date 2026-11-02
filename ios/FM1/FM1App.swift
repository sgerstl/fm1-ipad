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
    @State private var session: SloopSession
    @State private var ui = EditorUI()
    @State private var through = AudioThrough()
    @State private var projects = ProjectStore()

    init() {
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        _session = State(initialValue: SloopSession(demo: demo))
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / Theme.canvas.width, geo.size.height / Theme.canvas.height)
            AppView(session: session, ui: ui, useDemo: $useDemo)
                .environment(through)
                .environment(projects)
                .frame(width: Theme.canvas.width, height: Theme.canvas.height)
                .scaleEffect(s)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Theme.page)
        .ignoresSafeArea()
        .onAppear { TouchShow.installIfAsked() }       // -show-touches: screen recordings
        .task(id: useDemo) {
            if session.isDemo != useDemo { session = SloopSession(demo: useDemo) }
            projects.attach(session)
            await session.run()
        }
    }
}

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
    var page: Page = .sequencer
    var selectedStep = [0, 0, 0, 0]
    var selectedLane = 0
    var keptRows: [Int: Set<Int>] = [:]
    var knobGrab: KnobGrab?
    @ObservationIgnored var grabbedSpec: (() -> KnobSpec)?
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
    var sectionMenu: SectionMenu?                // a held stored section's menu, where the finger was
    var lastClear: SloopSession.ClearedTrack?   // offered for undo for a few seconds
    var librarySection: LibrarySection = .engine(0)
    /// The Presets panel is up on the Sequencer, in place of the step panel and knobs.
    var presetsPanel = false
    /// The last page change came from the FM-1 (its button pressed), not from a tab or pad here.
    var pageFromDevice = false
}

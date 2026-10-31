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

    init() {
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        _session = State(initialValue: SloopSession(demo: demo))
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / Theme.canvas.width, geo.size.height / Theme.canvas.height)
            AppView(session: session, ui: ui, useDemo: $useDemo)
                .frame(width: Theme.canvas.width, height: Theme.canvas.height)
                .scaleEffect(s)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Theme.page)
        .ignoresSafeArea()
        .task(id: useDemo) {
            if session.isDemo != useDemo { session = SloopSession(demo: useDemo) }
            await session.run()
        }
    }
}

enum Page: String, CaseIterable, Identifiable {
    case sequencer = "Sequencer", sound = "Sound", library = "Library"
    var id: String { rawValue }
}

/// What the iPad alone decides: which step is selected (per track), which drum lane, which page.
@MainActor @Observable
final class EditorUI {
    var page: Page = .sequencer
    var selectedStep = [0, 0, 0, 0]
    var selectedLane = 0
    var handPannedAt = Date.distantPast
    var keptRows: [Int: Set<Int>] = [:]
    var knobGrab: KnobGrab?
    var keyboardOpen = false
    var librarySection: LibrarySection = .engine(0)
}

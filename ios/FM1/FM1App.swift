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
    @State private var useDemo = LaunchArgs.all.contains("-demo")
    @State private var session: DeviceSession
    @State private var ui = EditorUI()
    @State private var through = AudioThrough()
    @State private var projects = ProjectStore()
    @State private var firmware = FirmwareCentre()

    init() {
        let demo = LaunchArgs.all.contains("-demo")
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
    @State private var introOver = LaunchArgs.all.contains("-no-intro")

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
        .overlay { AppMenuLayer(menu: $ui.menu) }
        .modifier(SaveSoundPrompt(session: session, ui: ui))
        .overlay { TextPromptLayer(prompt: $ui.textPrompt) }
        .background(TouchPointWatch())               // where a confirm a gesture didn't open opens: the last finger
        .overlay { FirmwareLayer(centre: firmware, session: session) }    // installing firmware: over everything
        // Lupe's intro on every cold launch, over the app, which starts (and connects) underneath it
        .overlay { if !introOver { LaunchIntro { introOver = true } } }
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

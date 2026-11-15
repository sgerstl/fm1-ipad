import SloopKit
import SwiftUI

/// What the app keeps doing for the session whichever root view is up (the iPad's AppView, the phone's PhoneAppView):
/// matching what the FM-1 holds against the saved projects, keeping the screen on while connected, quieting the FM-1's
/// own speaker while the iPad plays its sound, and Now Playing.
struct SessionUpkeep: ViewModifier {
    let session: DeviceSession
    @Environment(AudioThrough.self) private var through
    @Environment(ProjectStore.self) private var projects
    @Environment(\.scenePhase) private var scenePhase

    /// The iPad plays the FM-1's sound (whatever the scene): the app is Now Playing.
    private var audioThrough: Bool {
        guard session.isConnected, case .playing = through.state else { return false }
        return true
    }

    /// The iPad is playing the FM-1's sound, in front: the FM-1's own speaker goes quiet. Anything else (the switch off,
    /// no input, the app in the background) gives its MASTER knob back.
    private var speakerQuiet: Bool {
        guard session.isConnected, scenePhase == .active, case .playing = through.state else { return false }
        return true
    }

    func body(content: Content) -> some View {
        content
            // what the FM-1 holds: matched against the saved projects at connect, re-checked at each stop
            .onChange(of: session.isConnected, initial: true) { _, on in if on { projects.connected() } }
            // no sleeping mid-session: the screen stays on while an FM-1 is connected, and may sleep otherwise
            .onChange(of: session.isConnected, initial: true) { _, on in
                UIApplication.shared.isIdleTimerDisabled = on
                if on { through.recheck() }
            }
            .onChange(of: speakerQuiet, initial: true) { _, quiet in session.muteSpeaker(quiet) }
            // iPad audio left on from last time: look again once the app is in front, as when the FM-1 connects
            .onChange(of: scenePhase) { _, p in if p == .active { through.recheck() } }
            .onChange(of: [audioThrough ? 1 : 0, session.playing ? 1 : 0], initial: true) { _, _ in
                NowPlaying.shared.update(active: audioThrough, session: session)
            }
    }
}

extension View {
    func sessionUpkeep(_ session: DeviceSession) -> some View { modifier(SessionUpkeep(session: session)) }
}

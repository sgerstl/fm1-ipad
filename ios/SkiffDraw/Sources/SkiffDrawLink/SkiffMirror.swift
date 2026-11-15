// SkiffMirror (spike, decision 45): fills SkiffScreen's copy of the firmware state from what DeviceSession already
// reads over the editor link. Nothing new is asked of the FM-1: DUMP's selected-track parameters and globals, the
// per-track reads (level, pan, mute, engine), TRANSPORT, the playheads, SCREEN (page, track), METER and SCOPE.
//
// What the session doesn't hold, the mirror can't give (see qa/scope-spike-2026-11-15.md, "How much state"):
// the other tracks' full parameters (only the selected track's are dumped), their preset names, the steps, the FM-1's
// THEME (chosen here by hand), and the firmware's own animation clocks (fm1_ms: the mirror's is the app's).
import SkiffDraw
import SloopKit
import Foundation

@MainActor
public final class SkiffMirror {
    public struct Stats: Equatable, Sendable {
        public var globals = 0, selectedParams = 0, otherTrackParams = 0, engines = 0
        public var scopePoints = 0, meters = 0
    }

    public let screen: SkiffScreen
    /// Follow the FM-1's own page (SCREEN), or draw `page` as set here.
    public var followDevice = false
    public private(set) var stats = Stats()
    private var engines: [Int: Int] = [:]
    private let started = Date.now

    public init(screen: SkiffScreen = .shared) { self.screen = screen }

    /// Copies the session's state into the mirror. Cheap (a few hundred stores); call it before each frame.
    public func fill(from s: DeviceSession, palette: Int? = nil) {
        var st = Stats()
        let ids = s.ids
        // engines first: set_engine_of resets a track's engine parameters, as a sound load does
        for t in s.trackIndices where t < screen.trackCount {
            let e = s.tracks[t].engine
            if engines[t] != e { screen.setEngine(t, e); engines[t] = e; st.engines += 1 }
        }
        for t in s.trackIndices where t < screen.trackCount {
            let tr = s.tracks[t]
            screen.setTrackParam(t, ids.level, tr.level)
            screen.setTrackParam(t, ids.pan, tr.pan)
            screen.setTrackParam(t, ids.mute, tr.mute ? 1 : 0)
            st.otherTrackParams += 3
            screen.setPlayhead(track: t, step: t < s.positions.count ? s.positions[t].step : 0)
        }
        let sel = s.deviceScreen?.track ?? s.selectedTrack
        screen.select(track: sel)
        screen.setTrackParams(sel, s.params)
        st.selectedParams = min(s.params.count, screen.trackParamCount)
        screen.setGlobals(s.globals)
        st.globals = min(s.globals.count, screen.globalCount)
        screen.setPlaying(s.playing)
        if s.clockTicks >= 0 { screen.setBarStep(s.clockTicks / 6 % 16) }
        let lv = s.trackIndices.map { Int((s.meters.level(track: $0, muted: s.tracks[$0].mute) * 127).rounded()) }
        screen.setMeters(lv)
        st.meters = lv.count
        let f = s.scope.frame
        screen.setScope(f)
        st.scopePoints = f.count
        screen.setClock(ms: UInt32(truncatingIfNeeded: Int(Date.now.timeIntervalSince(started) * 1000)))
        if let palette { screen.setPalette(palette) }
        if followDevice, let ui = s.deviceScreen {
            if ui.home { screen.showHome(scope: (ui.flags ?? 0) & 1 != 0) } else { screen.show(page: ui.page) }
        }
        stats = st
    }
}

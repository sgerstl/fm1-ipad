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
    // what was last copied in, so a frame copies only what changed (an animated picture asks ~20 times a second, on the
    // main thread, where the core's own updates wait: the Pixel's rail went dead under the full copy, 2026-11-15)
    private var lastVals: [Int: [Int]] = [:], lastSteps: [Int: [SynthStep]] = [:]
    private var lastSel = -1, lastParams: [Int] = [], lastGlobals: [Int] = []
    private let started = Date.now

    public init(screen: SkiffScreen? = nil) { self.screen = screen ?? .shared }

    /// Copies the session's state into the mirror. Cheap (a few hundred stores); call it before each frame.
    public func fill(from s: DeviceSession, palette: Int? = nil) {
        var st = Stats()
        let ids = s.ids
        // engines first: set_engine_of resets a track's engine parameters, as a sound load does
        for t in s.trackIndices where t < screen.trackCount {
            let e = s.tracks[t].engine
            if engines[t] != e {
                screen.setEngine(t, e); engines[t] = e; st.engines += 1
                lastVals[t] = nil; lastParams = []           // (set_engine_of resets the track's values)
            }
        }
        for t in s.trackIndices where t < screen.trackCount {
            let tr = s.tracks[t]
            // every track's values the session reads for every track (ParamIDs.trackReads): SCALE, CHORD and FOLLOW
            // read the followed track's, DUCK its source's, the MIXER all of them
            var vals: [(Int?, Int)] = [(ids.level, tr.level), (ids.pan, tr.pan), (ids.mute, tr.mute ? 1 : 0), (ids.root, tr.root),
                                       (ids.scale, tr.scale), (ids.quant, tr.quant), (ids.transpose, tr.transpose),
                                       (ids.length, tr.length), (ids.division, tr.division), (ids.chord, tr.chord),
                                       (ids.arpMode, tr.arpMode)]
            vals += [(ids.direction, tr.direction), (ids.swing, tr.swing), (ids.slicer, tr.slicer), (ids.duck, tr.duck),
                     (ids.follow, tr.follow)]
            let flat = vals.map { ($0.0 ?? -1) * 100000 + $0.1 }
            if lastVals[t] != flat {
                for case let (id?, v) in vals { screen.setTrackParam(t, id, v); st.otherTrackParams += 1 }
                lastVals[t] = flat
            }
            // the steps (DUCK draws its source's hits; NOTES and FEEL the track's own): only those that changed
            let old = lastSteps[t] ?? []
            for (i, step) in tr.steps.enumerated() where i >= old.count || old[i] != step {
                screen.setStep(track: t, index: i, step.encoded)
            }
            lastSteps[t] = tr.steps
            screen.setPlayhead(track: t, step: t < s.positions.count ? s.positions[t].step : 0)
        }
        let sel = s.selectedTrack                         // (DUMP's parameters are its; the session adopts SCREEN's track)
        if sel != lastSel { screen.select(track: sel); lastSel = sel; lastParams = [] }
        if s.params != lastParams { screen.setTrackParams(sel, s.params); lastParams = s.params }
        st.selectedParams = min(s.params.count, screen.trackParamCount)
        if s.globals != lastGlobals { screen.setGlobals(s.globals); lastGlobals = s.globals }
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
            if ui.home { screen.showHome(scope: (ui.flags ?? 0) & 1 != 0) } else if let d = SkiffFirmware.v2_5_1.pageMap.device(ui.page) { screen.show(page: d) }   // (SCREEN speaks Lupe's numbers)
        }
        stats = st
    }
}

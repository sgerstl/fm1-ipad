// The sound panel's pictures drawn by Skiff's own code (decision 46, Scott 2026-11-15; Android first, iOS once Skiff's
// authors allow the App Store): the FM-1's picture panel for the page the FM-1 shows, from the session's mirror.
// Only on the build SkiffDraw was copied from (SkiffDrawBuild), only for the pages listed here; anything else answers
// nil and the app draws its own picture.
import SkiffDraw
import SloopKit
import Foundation

@MainActor
public final class SkiffPictures {
    /// One picture: 234 × 138 RGBA (SkiffScreen.panelSize), and whether it moves on its own (the LFO, the scope's
    /// sea) so the caller asks again about 30 times a second while it shows.
    public struct Picture: Sendable {
        public var width: Int, height: Int
        public var rgba: [UInt8]
        public var animated: Bool
    }

    /// Scott's order (decision 46): GLO's four and FX › DELAY, REVERB first, then ENV, LFO, OSC / EDIT, FILTER, FM6.
    /// Firmware page titles (params.c PAGES).
    public static let pages: Set<String> = ["DELAY", "REVERB", "CHORUS", "GLOBAL", "ENV", "ENV 2", "LFO", "LFO 2",
                                            "EDIT 1", "EDIT 2", "OPERATOR", "ALL OPS", "OP1 ENV", "OP2 ENV", "OP3 ENV",
                                            "OP4 ENV", "OP LEVEL"]
    /// Engines whose EDIT pages draw what the mirror doesn't hold: SAMPLE's waveform, read from the FM-1's flash
    /// (ui_graph.c graph_sample). DRUM, DRUM-X and SLICE draw the scope there (the sea), so they're SkiffDraw's.
    public static let ownEditEngines: Set<Int> = [4]

    public let mirror: SkiffMirror
    public init(mirror: SkiffMirror? = nil) { self.mirror = mirror ?? SkiffMirror() }

    /// Whether the connected FM-1 runs the build SkiffDraw draws for.
    public static func canDraw(_ s: DeviceSession) -> Bool {
        guard s.isConnected, s.dialect == .skiff, let i = s.info else { return false }
        return SkiffDrawBuild.accepts(version: i.version, screenLink: s.screenLinkVersion, paramCount: i.paramCount,
                                      globalCount: i.globalCount)
    }

    /// The device's page for a page in Lupe's numbers (SkiffPageMap), if SkiffDraw draws it on this track.
    public func devicePage(_ s: DeviceSession, lupePage: Int) -> Int? {
        guard let d = SkiffFirmware.v2_5_1.pageMap.device(lupePage), d >= 0, d < mirror.screen.pageCount else { return nil }
        let title = mirror.screen.pageName(d)
        guard Self.pages.contains(title) else { return nil }
        let fam = mirror.screen.pageFamily(d)
        if fam == 5, Self.ownEditEngines.contains(s.tracks[s.selectedTrack].engine) { return nil }   // FAM_EDIT
        return d
    }

    /// The FM-1's picture for `lupePage`; nil: draw the app's own. `gloInk`: GLO's shared pages (decision 34) draw the
    /// selected track's colour as this grey (0xRRGGBB), white staying white; track pages keep the FM-1's own colours.
    public func picture(_ s: DeviceSession, lupePage: Int, gloInk: UInt32, surface: UInt32? = nil) -> Picture? {
        guard Self.canDraw(s), let d = devicePage(s, lupePage: lupePage) else { return nil }
        let sc = mirror.screen
        mirror.followDevice = false
        mirror.fill(from: s, palette: 0)                         // SKIFF (decision 46: the FM-1 on SKIFF)
        let sel = s.deviceScreen?.track ?? s.selectedTrack
        let theme = s.themeTrackColours                          // the FM-1's own (CUSTOM's too), else SKIFF's
        for t in 0..<sc.trackCount { sc.setTrackColour(t, theme.flatMap { t < $0.count ? $0[t] : nil }) }
        sc.setSurface(surface)                                   // the app's picture background: no second frame
        let glo = sc.pageFamily(d) == 6                          // FAM_GLO
        if glo { sc.setTrackColour(sel, gloInk) }
        if let p = s.skiffEdit?.patches[sel] { sc.setFM6Patch(track: sel, p.bytes) }
        let title = sc.pageName(d)
        let lfo = title == "LFO" || title == "LFO 2"
        if lfo { sc.setLFO(track: sel, seconds: Self.lfoSeconds(s, track: sel)) }
        sc.show(page: d)
        let (w, h) = sc.panelSize
        let scope = sc.pageFamily(d) == 5 && !Self.hasOwnChart(engine: s.tracks[sel].engine, title: title)
        return Picture(width: w, height: h, rgba: sc.renderPanel(), animated: lfo || scope)
    }

    /// EDIT pages with a chart of their own (ANALOG's OSC and FLT, DIGITAL's, WHEEL's, FM6's): static. The rest draw
    /// the scope, which on SKIFF is the sea of the tracks' levels, moving with them (flat when all are silent).
    static func hasOwnChart(engine: Int, title: String) -> Bool {
        [0, 1, 7, 12].contains(engine) || title.hasPrefix("OP") || title == "ALL OPS"
    }

    /// Seconds since the LFO last restarted: the track's last note while the clock runs (TRIG NOTE), else since PLAY,
    /// else since the app's own start.
    static func lfoSeconds(_ s: DeviceSession, track: Int) -> Double {
        let now = Date.now
        if let r = s.lfoClock.restarts[track]?.at { return now.timeIntervalSince(r) }
        if let st = s.lfoClock.startedAt { return now.timeIntervalSince(st) }
        return now.timeIntervalSince(started)
    }
    private static let started = Date.now
}

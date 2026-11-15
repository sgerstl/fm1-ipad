// SkiffScreen (spike, decision 45): the FM-1's screen drawn by Skiff's own code (CSkiffDraw). The app keeps the
// mirror current (song.g, the selected track's parameters, the page, the theme, METER and SCOPE) and asks for a
// frame: 240 × 240 RGBA, exactly the pixels the FM-1's panel gets. The C side is one global firmware state, so there is
// one SkiffScreen per process; main actor only.
import CSkiffDraw

@MainActor
public final class SkiffScreen {
    public static let shared = SkiffScreen()
    public static let width = Int(SKD_W), height = Int(SKD_H)

    private init() { skd_reset() }

    public func reset() { skd_reset() }

    // MARK: the mirror
    public var globalCount: Int { Int(skd_global_count()) }
    public var trackParamCount: Int { Int(skd_track_param_count()) }
    public var trackCount: Int { Int(skd_track_count()) }

    /// song.g, by the firmware's G_ id (the link's global ids are the same numbers).
    public func setGlobals(_ g: [Int]) { for (i, v) in g.enumerated() where i < globalCount { skd_set_global(Int32(i), Int32(v)) } }
    public func setGlobal(_ id: Int, _ v: Int) { skd_set_global(Int32(id), Int32(v)) }
    public func global(_ id: Int) -> Int { Int(skd_get_global(Int32(id))) }
    /// trk[t].p, by P_ id (the link's whole track ids: from 128 as they arrive as scope 2).
    public func setTrackParams(_ t: Int, _ p: [Int]) { for (i, v) in p.enumerated() where i < trackParamCount { skd_set_track_param(Int32(t), Int32(i), Int32(v)) } }
    public func setTrackParam(_ t: Int, _ id: Int, _ v: Int) { skd_set_track_param(Int32(t), Int32(id), Int32(v)) }
    public func trackParam(_ t: Int, _ id: Int) -> Int { Int(skd_get_track_param(Int32(t), Int32(id))) }
    public func setEngine(_ t: Int, _ e: Int) { skd_set_engine(Int32(t), Int32(e)) }
    public func select(track t: Int) { skd_select_track(Int32(t)) }
    public func setPlaying(_ on: Bool) { skd_set_playing(on ? 1 : 0) }
    public func setPlayhead(track t: Int, step: Int) { skd_set_playhead(Int32(t), Int32(step)) }
    /// The bar's 1/16 (0…15) the clock is on: the header's metronome.
    public func setBarStep(_ step: Int) { skd_set_bar_step(Int32(step)) }
    public func setPalette(_ p: Int) { skd_set_palette(Int32(p)) }
    public var paletteNames: [String] { (0..<Int(skd_palette_count())).map { String(cString: skd_palette_name(Int32($0))) } }
    public func setClock(ms: UInt32) { skd_set_ms(ms) }

    // MARK: pages (params.c PAGES[])
    public var pageCount: Int { Int(skd_page_count()) }
    public func pageName(_ i: Int) -> String { String(cString: skd_page_name(Int32(i))) }
    public func pageFamily(_ i: Int) -> Int { Int(skd_page_family(Int32(i))) }
    /// The `nth` page called `name` (FX › DELAY is DELAY 0, GLO › DELAY is DELAY 1).
    public func page(named name: String, nth: Int = 0) -> Int? {
        let i = Int(skd_page_find(name, Int32(nth)))
        return i < 0 ? nil : i
    }
    public func show(page i: Int) { skd_goto_page(Int32(i)) }
    public func showHome(scope: Bool) { skd_goto_home(scope ? 1 : 0) }

    // MARK: the screen link's live data
    /// SCOPE (93): 120 points 1…127, 64 the centre. Empty: silence.
    public func setScope(_ f: [UInt8]) {
        let pts = f.isEmpty ? [UInt8](repeating: 64, count: 120) : f
        pts.withUnsafeBufferPointer { skd_set_scope($0.baseAddress, Int32($0.count)) }
    }
    /// METER (92): each track 0…127.
    public func setMeters(_ m: [Int]) {
        let b = m.map { UInt8(clamping: $0) }
        b.withUnsafeBufferPointer { skd_set_meters($0.baseAddress, Int32($0.count)) }
    }

    // MARK: a frame
    /// The whole screen, RGBA8888, row by row from the top (240 × 240 × 4 bytes).
    public func render() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
        out.withUnsafeMutableBufferPointer { skd_render_rgba($0.baseAddress) }
        return out
    }
    /// Microseconds the last frame took to draw.
    public var lastDrawMicroseconds: Int { Int(skd_draw_cost_us()) }
}

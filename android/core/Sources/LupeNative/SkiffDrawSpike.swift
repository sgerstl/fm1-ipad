// Decision 45's spike (2026-11-15): the FM-1's screen drawn by Skiff's own UI code (ios/SkiffDraw), fed by the
// session's mirror, for the developer-only SkiffDrawDebugActivity. Not part of the app's screens.
import CAndroid
import SkiffDraw
import SkiffDrawLink

nonisolated(unsafe) private var skiffMirror: SkiffMirror?

/// One frame, RGBA (240 × 240 × 4), of `page` (0 GLO › DELAY, 1 GLO › REVERB, 2 EDIT 1, 3 HOME's scope, 4 the FM-1's
/// own page) in theme `palette`. Connected: from the session's mirror. Not connected (the emulator): the power-on
/// state with GLO › DELAY at the board's delay_a settings, so the frame can be compared with
/// design/boards/fm1-screens. Also returns the draw time in µs as the last 4 bytes (little-endian).
@_cdecl("Java_com_scottgerstl_lupe_core_LupeNative_skiffFrame")
public func skiffFrame(_ env: UnsafeMutablePointer<JNIEnv?>, _ cls: jclass?, _ page: jint, _ palette: jint) -> jbyteArray? {
    let bytes: [UInt8] = MainActor.assumeIsolated {
        let m = skiffMirror ?? SkiffMirror()
        skiffMirror = m
        let s = m.screen
        if let core, core.session.isConnected {
            m.followDevice = page == 4
            m.fill(from: core.session, palette: Int(palette))
        } else {
            s.reset()
            s.setPlaying(true); s.setGlobal(0, 124); s.setBarStep(8)
            for t in 0..<s.trackCount { s.setPlayhead(track: t, step: 5) }
            for (id, v) in [(4, 1), (5, 60), (6, 70), (7, 90), (27, 1)] { s.setGlobal(id, v) }   // G_DTIME … G_DMODE
            if page == 2 { s.select(track: 2) }               // LOFI: EDIT 1 is the scope
            s.setPalette(Int(palette))
        }
        switch page {
        case 0: s.show(page: s.page(named: "DELAY", nth: 1) ?? 0)
        case 1: s.show(page: s.page(named: "REVERB", nth: 1) ?? 0)
        case 2: s.show(page: s.page(named: "EDIT 1") ?? 0)
        case 3: s.showHome(scope: true)
        default: break
        }
        var f = s.render()
        let us = UInt32(s.lastDrawMicroseconds)
        f += [UInt8(us & 255), UInt8(us >> 8 & 255), UInt8(us >> 16 & 255), UInt8(us >> 24)]
        return f
    }
    let e = env.pointee!.pointee
    guard let arr = e.NewByteArray(env, jsize(bytes.count)) else { return nil }
    bytes.withUnsafeBufferPointer { b in
        b.withMemoryRebound(to: jbyte.self) { e.SetByteArrayRegion(env, arr, 0, jsize(b.count), $0.baseAddress) }
    }
    return arr
}

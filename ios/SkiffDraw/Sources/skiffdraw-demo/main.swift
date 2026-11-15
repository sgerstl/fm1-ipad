// skiffdraw-demo (spike, decision 45): SkiffDraw on any platform its Swift builds for (the Mac, Android via adb shell).
// Renders GLO › DELAY at the board's delay_a settings and an EDIT page's scope from a SCOPE frame, writes PPMs, and
// prints the draw cost.   skiffdraw-demo OUT_DIR
import SkiffDraw
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#else
import Darwin
#endif

func writePPM(_ path: String, _ rgba: [UInt8]) {
    guard let f = fopen(path, "wb") else { print("cannot write \(path)"); return }
    let head = Array("P6\n240 240\n255\n".utf8)
    _ = head.withUnsafeBufferPointer { fwrite($0.baseAddress!, 1, $0.count, f) }
    var rgb = [UInt8](); rgb.reserveCapacity(240 * 240 * 3)
    for i in 0..<(240 * 240) { rgb += rgba[(4 * i)..<(4 * i + 3)] }
    _ = rgb.withUnsafeBufferPointer { fwrite($0.baseAddress!, 1, $0.count, f) }
    fclose(f)
}

@MainActor func run() {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
    let s = SkiffScreen.shared
    s.reset()
    s.setPlaying(true); s.setGlobal(0, 124); s.setBarStep(8)
    for t in 0..<s.trackCount { s.setPlayhead(track: t, step: 5) }
    s.show(page: s.page(named: "DELAY", nth: 1)!)
    for (id, v) in [(4, 1), (5, 60), (6, 70), (7, 90), (27, 1)] { s.setGlobal(id, v) }   // G_DTIME … G_DMODE
    writePPM(out + "/delay_a_default_1-8_fb60_mix90_stereo.ppm", s.render())
    print("GLO › DELAY: \(s.lastDrawMicroseconds) µs")
    s.reset()
    s.select(track: 2); s.setPalette(1)
    s.show(page: s.page(named: "EDIT 1")!)
    var worst = 0
    for k in 0..<60 {                                  // two seconds of SCOPE at 30 a second
        let pts = (0..<120).map { i -> UInt8 in
            let x = Double(i) / 120 * 2 * Double.pi * 3
            return UInt8(64 + Int(48 * sin(x) + 10 * sin(3 * x + Double(k) / 5)))
        }
        s.setScope(pts)
        let f = s.render()
        worst = max(worst, s.lastDrawMicroseconds)
        if k == 59 { writePPM(out + "/scope_edit1_HI-CON.ppm", f) }
    }
    print("EDIT 1 scope, 60 frames: worst \(worst) µs")
}
MainActor.assumeIsolated { run() }

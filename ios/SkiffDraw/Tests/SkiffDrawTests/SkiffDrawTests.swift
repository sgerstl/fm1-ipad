// The spike's checks (decision 45): Skiff's own drawing, driven through SkiffScreen as the app drives it, against
// design/boards/fm1-screens (made by Skiff 2.5.1's render harness), pixel for pixel.
import Foundation
import Testing
@testable import SkiffDraw

/// The firmware's G_ ids (core.h), which are the link's global ids.
private enum G { static let bpm = 0, dtime = 4, dfdbk = 5, dcolor = 6, dmix = 7, rsize = 8, rdamp = 9, rtype = 24, dmode = 27 }

@MainActor
private func frame(page: String, nth: Int, globals: [(Int, Int)]) -> [UInt8] {
    let s = SkiffScreen.shared
    s.reset()
    s.setPlaying(true)                     // the header as the board's renders have it: playing, 124, the bar's 3rd beat
    s.setGlobal(G.bpm, 124)
    s.setBarStep(8)
    for t in 0..<s.trackCount { s.setPlayhead(track: t, step: 5) }
    s.show(page: s.page(named: page, nth: nth)!)
    for (id, v) in globals { s.setGlobal(id, v) }
    return s.render()
}

private func reference(_ name: String) throws -> [UInt8] {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "rgb", subdirectory: "Fixtures"))
    return [UInt8](try Data(contentsOf: url))
}

/// Pixels that differ between an RGBA frame and an RGB reference.
private func differing(_ rgba: [UInt8], _ rgb: [UInt8]) -> Int {
    var n = 0
    for i in 0..<(240 * 240) {
        let a = 4 * i, b = 3 * i
        if rgba[a] != rgb[b] || rgba[a + 1] != rgb[b + 1] || rgba[a + 2] != rgb[b + 2] { n += 1 }
    }
    return n
}

@MainActor @Suite struct SkiffDrawTests {
    @Test func gloDelayMatchesTheFM1PixelForPixel() throws {
        let a = frame(page: "DELAY", nth: 1, globals: [(G.dtime, 1), (G.dfdbk, 60), (G.dcolor, 70), (G.dmix, 90), (G.dmode, 1)])
        #expect(differing(a, try reference("delay_a_default_1-8_fb60_mix90_stereo")) == 0)
        let b = frame(page: "DELAY", nth: 1, globals: [(G.dtime, 0), (G.dfdbk, 100), (G.dcolor, 70), (G.dmix, 127), (G.dmode, 2)])
        #expect(differing(b, try reference("delay_b_1-4_fb100_mix127_ping")) == 0)
    }

    @Test func gloReverbSpringMatches() throws {
        let f = frame(page: "REVERB", nth: 1, globals: [(G.rtype, 1), (G.rsize, 90), (G.rdamp, 60)])
        #expect(differing(f, try reference("reverb_c_spring_size90_damp60")) == 0)
    }

    @Test func pageTableIsSkiff251s() {
        let s = SkiffScreen.shared
        #expect(s.pageCount == 47)
        #expect(s.page(named: "DELAY", nth: 1) == 32)      // GLO › DELAY (FX › DELAY is 6)
        #expect(s.globalCount == 28 && s.trackParamCount == 148 && s.trackCount == 6)
        #expect(s.paletteNames.prefix(3) == ["SKIFF", "HI-CON", "PAPER"])
    }

    @Test func scopeFromTheLinkDrawsATrace() {
        let s = SkiffScreen.shared
        s.reset()
        s.select(track: 2)                                    // LOFI: EDIT 1 is the scope
        s.setPalette(1)                                       // HI-CON draws the trace (SKIFF draws the sea)
        s.show(page: s.page(named: "EDIT 1")!)
        let flat = s.render()
        s.setScope((0..<120).map { UInt8(64 + Int(50 * sin(Double($0) / 120 * 2 * .pi * 3))) })
        let wave = s.render()
        #expect(differing(wave, stride(from: 0, to: flat.count, by: 4).flatMap { Array(flat[$0..<$0 + 3]) }) > 300)
    }

    @Test func drawCostIsSmall() {
        let s = SkiffScreen.shared
        s.show(page: s.page(named: "REVERB", nth: 1)!)
        var worst = 0
        for _ in 0..<20 { _ = s.render(); worst = max(worst, s.lastDrawMicroseconds) }
        #expect(worst < 5_000)                                // a 60 Hz frame is 16,667 µs
    }

    // MARK: decision 46

    @Test func panelIsTheFramesPictureArea() {
        let s = SkiffScreen.shared
        let full = frame(page: "DELAY", nth: 1, globals: [(G.dtime, 1), (G.dfdbk, 60), (G.dmix, 90)])
        let (w, h) = s.panelSize
        #expect(w == 234 && h == 138)                         // the FM-1's 936 : 552 at 4×
        let p = s.renderPanel()
        var off = 0
        for y in 0..<h { for x in 0..<w {
            let a = 4 * (y * w + x), b = 4 * ((76 + y) * 240 + 3 + x)
            if p[a + 3] == 255, p[a] != full[b] || p[a + 1] != full[b + 1] || p[a + 2] != full[b + 2] { off += 1 }
        } }
        #expect(off == 0)
        #expect(p[3] == 0 && p[4 * (w - 1) + 3] == 0)          // outside the rounded corners: transparent
        #expect(p[4 * (h / 2 * w + w / 2) + 3] == 255)
    }

    @Test func gloInkReplacesTheTrackColourOnly() {
        let s = SkiffScreen.shared
        let colour = frame(page: "DELAY", nth: 1, globals: [(G.dtime, 1), (G.dfdbk, 60), (G.dmix, 90)])
        s.setTrackColour(0, 0xC4C4CC)                         // the panel's grey ink (Tok.text2Raised)
        let grey = s.render()
        s.setTrackColour(0, nil)
        let back = s.render()
        #expect(back == colour)                               // taken away: the theme's own again
        func px(_ f: [UInt8], _ x: Int, _ y: Int) -> [UInt8] { Array(f[(4 * (y * 240 + x))..<(4 * (y * 240 + x) + 3)]) }
        // the dry hit (white, x 14..) stays white; echo 1 (orange on SKIFF) turns grey: no channel apart from the others
        #expect(px(grey, 16, 190) == px(colour, 16, 190))
        let e = px(grey, 70, 190), o = px(colour, 70, 190)
        #expect(o[0] > o[2] + 60)                             // orange
        #expect(abs(Int(e[0]) - Int(e[1])) < 16 && abs(Int(e[1]) - Int(e[2])) < 16)
    }

    @Test func buildCheckAcceptsOnlyThisBuild() {
        #expect(SkiffDrawBuild.version == "FELUCCA v2.5.1")
        #expect(SkiffDrawBuild.accepts(version: "FELUCCA v2.5.1", screenLink: 6, paramCount: 148, globalCount: 28))
        #expect(SkiffDrawBuild.accepts(version: "FELUCCA v2.5.1", screenLink: 7, paramCount: 148, globalCount: 28))
        #expect(!SkiffDrawBuild.accepts(version: "FELUCCA v2.5.1", screenLink: 4, paramCount: 148, globalCount: 28))   // an older link
        #expect(!SkiffDrawBuild.accepts(version: "FELUCCA v2.5.1", screenLink: nil, paramCount: 148, globalCount: 28)) // upstream 2.5.1
        #expect(!SkiffDrawBuild.accepts(version: "FELUCCA v2.2", screenLink: 6, paramCount: 140, globalCount: 27))
        #expect(!SkiffDrawBuild.accepts(version: "FELUCCA v2.6", screenLink: 6, paramCount: 148, globalCount: 28))
        #expect(!SkiffDrawBuild.accepts(version: "FELUCCA v2.5.1", screenLink: 8, paramCount: 148, globalCount: 28))
    }

    @Test func lfoMovesWithItsTime() {
        let s = SkiffScreen.shared
        s.reset()
        s.show(page: s.page(named: "LFO")!)
        s.setLFO(track: 0, seconds: 0.2)
        let a = s.renderPanel()
        s.setLFO(track: 0, seconds: 0.9)
        #expect(s.renderPanel() != a)
    }
}


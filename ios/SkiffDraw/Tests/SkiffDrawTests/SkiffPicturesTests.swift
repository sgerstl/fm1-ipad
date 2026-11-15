// Decision 46: the sound panel's pictures from a session, against SloopKit's strict FakeSkiff on the 2.5.1 fixture
// (recorded from skiff-sim on Skiff-Lupe 2.5.1, 737e3fb).
import Foundation
import Testing
@testable import SloopKit
@testable import SkiffDraw
@testable import SkiffDrawLink

@Suite(.serialized) @MainActor struct SkiffPicturesTests {
    private func connect(link version: Int?) async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load(.v2_5_1))
        fake.screenLink = version != nil
        fake.screenLinkVersion = version ?? 1
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        let t0 = Date()
        while !(s.isConnected && (version == nil || s.screenLinked)) {
            guard Date().timeIntervalSince(t0) < 10 else { Issue.record("not connected"); break }
            try await Task.sleep(for: .milliseconds(20))
        }
        return (s, fake, run)
    }

    @Test func drawsGlosAndTrackPagesOnTheBuildItWasCopiedFrom() async throws {
        let (s, fake, run) = try await connect(link: 6)
        defer { run.cancel() }
        #expect(s.screenLinkVersion == 6)
        #expect(SkiffPictures.canDraw(s))
        let p = SkiffPictures()
        let delay = try #require(p.picture(s, lupePage: 31, gloInk: 0xC4C4CC))        // GLO › DELAY (Lupe's 31)
        #expect(delay.width == 234 && delay.height == 138 && !delay.animated)
        // GLO in grey: no pixel of the panel has the SKIFF track colours' hue (red well above blue)
        var coloured = 0
        for i in stride(from: 0, to: delay.rgba.count, by: 4) where delay.rgba[i + 3] == 255 {
            if Int(delay.rgba[i]) > Int(delay.rgba[i + 2]) + 40 { coloured += 1 }
        }
        #expect(coloured == 0)
        #expect(p.picture(s, lupePage: 0, gloInk: 0xC4C4CC) != nil)                    // ENV, the track's colour
        #expect(p.picture(s, lupePage: SkiffPageMap.fxDelay, gloInk: 0xC4C4CC) != nil) // FX › DELAY
        let lfo = try #require(p.picture(s, lupePage: 2, gloInk: 0))                   // LFO: it moves
        #expect(lfo.animated)
        #expect(p.picture(s, lupePage: 41, gloInk: 0) == nil)                          // NOTES: not SkiffDraw's
        #expect(p.picture(s, lupePage: 30, gloInk: 0) == nil)                          // MIXER: Lupe's own Mix tab
        #expect(fake.unanswered.isEmpty, "\(fake.unanswered)")
        // SKIFFDRAW_OUT=dir: the pictures as the phone gets them, for review (qa/skiffdraw-android-2026-11-15)
        if let out = ProcessInfo.processInfo.environment["SKIFFDRAW_OUT"] {
            for (name, page, ink) in [("glo-delay", 31, 0xC4C4CC), ("glo-reverb", 32, 0xC4C4CC), ("glo-chorus", 33, 0xC4C4CC),
                                      ("glo-global", 34, 0xC4C4CC), ("fx-delay", SkiffPageMap.fxDelay, 0), ("fx-reverb", SkiffPageMap.fxReverb, 0),
                                      ("env", 0, 0), ("lfo", 2, 0), ("edit1-osc", 14, 0), ("edit2-flt", 15, 0)] {
                guard let pic = p.picture(s, lupePage: page, gloInk: UInt32(ink)) else { continue }
                var ppm = Array("P7\nWIDTH \(pic.width)\nHEIGHT \(pic.height)\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n".utf8)
                ppm += pic.rgba
                try Data(ppm).write(to: URL(fileURLWithPath: "\(out)/\(name)-track\(s.selectedTrack + 1)-engine\(s.tracks[s.selectedTrack].engine).pam"))
            }
        }
    }

    @Test func anotherScreenLinkBuildGetsTheHandDrawnPicture() async throws {
        let (s, _, run) = try await connect(link: 4)
        defer { run.cancel() }
        #expect(!SkiffPictures.canDraw(s))
        #expect(SkiffPictures().picture(s, lupePage: 31, gloInk: 0xC4C4CC) == nil)
    }

    @Test func noScreenLinkNoPicture() async throws {
        let (s, _, run) = try await connect(link: nil)
        defer { run.cancel() }
        #expect(SkiffPictures().picture(s, lupePage: 0, gloInk: 0) == nil)
    }
}

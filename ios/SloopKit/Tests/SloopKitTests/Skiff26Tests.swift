import Foundation
import Testing
@testable import SloopKit

/// Stock Skiff 2.6 (2026-11-12): 2.5.1 plus CAST (editor cmd 83, INFO 59 01), nothing else Lupe uses. Lupe speaks it as
/// 2.5.1. Played by FakeSkiff on the 2.5.1 fixture with INFO's version string changed, no screen link (stock).
@Suite(.serialized) @MainActor struct Skiff26Tests {
    /// The 2.5.1 fixture as stock 2.6 would answer INFO: the same bytes, "FELUCCA v2.6" in the version field.
    static func fixture26() throws -> SkiffFixture {
        var fx = try SkiffFixture.load(.v2_5_1)
        let old = Array("FELUCCA v2.5.1".utf8), new = Array("FELUCCA v2.6".utf8)   // (null-terminated: two bytes shorter)
        let at = try #require(fx.info.indices.first { fx.info[$0...].starts(with: old) })
        fx.info.replaceSubrange(at..<(at + old.count), with: new)
        return fx
    }

    @Test func theVersionIsKnown() {
        #expect(SkiffFirmware(version: "FELUCCA v2.6") == .v2_6)
        #expect(SkiffFirmware.v2_6.short == "2.6")
        #expect(SkiffFirmware.v2_6.pageMap == SkiffFirmware.v2_5_1.pageMap)
        #expect(SkiffFirmware.v2_6.undoLevels == 6 && SkiffFirmware.v2_6.hasSendPages && SkiffFirmware.v2_6.hasFreeTake)
        #expect(SkiffFirmware.v2_6.isNewerThanLupe && !SkiffFirmware.v2_5_1.isNewerThanLupe)
        #expect(SkiffProjectData.blank(for: .v2_6).firmware == SkiffFirmware.v2_5_1.rawValue)
    }

    @Test func aStock26UnitConnects() async throws {
        let fx = try Self.fixture26()
        #expect(SkiffInfo(fx.info)?.firmware == .v2_6)
        let fake = FakeSkiff(fx)
        fake.screenLink = false
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { run.cancel() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        #expect(s.dialect == .skiff)
        #expect(s.skiffFirmware == .v2_6)
        #expect(!s.screenLinked)
        #expect(s.tracks.count == 6)
    }
}

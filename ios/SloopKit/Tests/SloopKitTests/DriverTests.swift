import Foundation
import Testing
@testable import SloopKit

/// The firmware seam: INFO picks the driver, the driver gives the session its shape and capabilities.
@Suite(.serialized) @MainActor struct DriverTests {
    private func info(_ version: String, protocol p: Int = 12) -> DeviceInfo {
        DeviceInfo(version: version, engines: ["ANALOG"], paramCount: 61, globalCount: 47, stepCount: 64,
                   firstEngineParam: 53, trackCount: 4, protocolVersion: p)
    }

    @Test func detectsSloopOnlyByVersionAndProtocol() {
        #expect(FirmwareDialect.detect(info("FELUCCA SLOOP 2.8.4")) == .sloop)
        #expect(FirmwareDialect.detect(info("FELUCCA SLOOP 2.8.4", protocol: 11)) == nil)
        #expect(FirmwareDialect.detect(info("FELUCCA SLOOP 2.9.0")) == nil)
        #expect(FirmwareDialect.detect(info("FELUCCA v1.1.5")) == nil)
    }

    @Test func detectorHandsBackTheSloopDriver() async throws {
        let outcome = try await FirmwareDetector.connect(FakeSloop(autoEdits: false))
        guard case .driver(let d) = outcome else { Issue.record("no driver"); return }
        #expect(d.dialect == .sloop)
        #expect(d.shape == .sloop && d.shape.trackColours.count >= d.shape.trackCount)
        #expect(d.capabilities.contains(.livePlayhead) && d.capabilities.contains(.sloopSong))
        let list = try await d.tracks()
        #expect(list.tracks.count == 4)
        await d.close()
    }

    @Test func detectorReportsUnknownFirmware() async throws {
        let f = FakeSloop(autoEdits: false); f.version = "FELUCCA v2.2"
        guard case .unknown(let i) = try await FirmwareDetector.connect(f) else { Issue.record("connected"); return }
        #expect(i.version == "FELUCCA v2.2")
    }

    @Test func sessionTakesItsShapeFromTheDriver() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        #expect(session.trackCount == 4 && session.stepCount == 64 && session.drumTrack == 3)   // before connecting
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        #expect(session.dialect == .sloop)
        #expect(session.tracks.count == 4 && session.tracks.allSatisfy { $0.steps.count == 64 })
        #expect(session.tracks.map(\.isDrums) == [false, false, false, true])
        #expect(session.capabilities.contains(.screenLink))      // the fake answers UI
        run.cancel()
    }

    @Test func shapeKnowsLightTracks() {
        let s = DeviceShape(trackCount: 6, stepCount: 64, drumTrack: nil, lightTracks: 0b110000, lightEngines: 1 << 8 | 1 << 9)
        #expect(s.canPlay(track: 0, engine: 9))
        #expect(!s.canPlay(track: 4, engine: 9) && !s.canPlay(track: 5, engine: 8))
        #expect(s.canPlay(track: 5, engine: 0))
        #expect(!s.isDrums(3))
    }
}

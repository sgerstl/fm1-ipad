import Foundation
import Testing
@testable import SloopKit

/// The firmware seam: INFO picks the driver, the driver gives the session its shape and capabilities.
@Suite(.serialized) @MainActor struct DriverTests {
    @Test func beforeConnectingTheSessionHasSkiffsShape() {
        let session = DeviceSession(transport: { nil })
        #expect(session.trackCount == 6 && session.stepCount == 64 && session.drumTrack == nil)
        #expect(session.shape.trackColours == DeviceShape.skiffColours)
    }

    @Test func shapeKnowsLightTracks() {
        let s = DeviceShape(trackCount: 6, stepCount: 64, drumTrack: nil, lightTracks: 0b110000, lightEngines: 1 << 8 | 1 << 9)
        #expect(s.canPlay(track: 0, engine: 9))
        #expect(!s.canPlay(track: 4, engine: 9) && !s.canPlay(track: 5, engine: 8))
        #expect(s.canPlay(track: 5, engine: 0))
        #expect(!s.isDrums(3))
    }
}

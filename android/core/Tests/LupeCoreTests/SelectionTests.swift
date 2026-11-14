import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The selected track is one thing everywhere (Scott's Pixel, 2026-11-14: pads and the editor stayed on a picked pad's
/// track while the FM-1, homeKnobs and diag had moved on). After a pad pick, a track head tapped on the phone and a
/// track pressed on the FM-1 both move pads.selected, the editor, homeKnobs and diag together.
@MainActor extension FixtureRecordingTests {
    /// The track (1-based) each area says is selected.
    func selections(_ core: PhoneCore) -> [String: Int] {
        ["pads": core.padsArea().selected.track, "editor": core.editorArea().track,
         "homeKnobs": core.homeKnobsArea()?.track ?? -1, "diag": core.diagArea().selectedTrack + 1]
    }
    func allOn(_ core: PhoneCore, _ track: Int) -> Bool { selections(core).values.allSatisfy { $0 == track } }

    @Test func theSelectedTrackIsTheSameEverywhere() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        #expect(allOn(core, 1), "\(selections(core))")
        // a pad picked on track 6: everything on track 6, the pad the picked one
        let e = 0
        core.handle(json: #"{"intent":"padSelect","track":6,"entry":\#(e)}"#)
        try await waitFor(3, "the pad's track") { self.allOn(core, 6) && fake.selected == 5 }
        #expect(core.padsArea().selected == PadsArea.Ref(track: 6, entry: e))
        // a track head tapped on the phone: the pick goes with it
        core.handle(json: #"{"intent":"trackSelect","track":3}"#)
        try await waitFor(3, "track 3 from the phone") { self.allOn(core, 3) && fake.selected == 2 }
        // picked again, then a track pressed on the FM-1: everything follows the FM-1
        core.handle(json: #"{"intent":"padSelect","track":6,"entry":\#(e)}"#)
        try await waitFor(3, "the pad's track again") { self.allOn(core, 6) && fake.selected == 5 }
        try await Task.sleep(for: .milliseconds(1200))                 // (past the session's guard after its own select)
        fake.pressOnDevice(page: nil, track: 4)                        // HOME, track 5
        try await waitFor(4, "track 5 from the FM-1") { self.allOn(core, 5) }
        #expect(core.padsArea().selected.track == 5, "\(selections(core))")
        // and back on the pad's own track from the FM-1: the track's current entry, not the old pick
        fake.pressOnDevice(page: nil, track: 1)
        try await waitFor(4, "track 2 from the FM-1") { self.allOn(core, 2) }
    }

    /// Read-only: the pad pick is the screen's own (nothing is sent), and it still gives way to the FM-1's track.
    @Test func aReadOnlyPickGivesWayToTheFM1sTrack() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r, writes: false)
        defer { core.stop(); plug.unplug() }
        core.handle(json: #"{"intent":"padSelect","track":6,"entry":0}"#)
        #expect(core.padsArea().selected.track == 6 && core.editorArea().track == 6 && fake.selected == 0)
        fake.pressOnDevice(page: nil, track: 3)
        try await waitFor(4, "track 4 from the FM-1") { self.allOn(core, 4) }
    }
}

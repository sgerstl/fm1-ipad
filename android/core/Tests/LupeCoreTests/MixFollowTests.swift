import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The Mix section follows the FM-1's GLO page by itself (Scott pressed GLO five times: fm1Screen stepped 30…34, the
/// section stayed). No write is sent for it, read-only included; and mixSection sends no SCREEN_GOTO for a page the
/// FM-1 is already on.
@MainActor extension FixtureRecordingTests {
    @Test func theMixSectionFollowsTheFM1sGloPage() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r, writes: false)          // read-only: following is no write
        defer { core.stop(); plug.unplug() }
        fake.gotoWire.removeAll()
        for (page, key) in [(30, "mixer"), (31, "delay"), (32, "reverb"), (33, "chorus"), (34, "global")] {
            fake.pressOnDevice(page: page)                                        // GLO pressed on the FM-1
            try await waitFor(3, "\(key)") { core.mixArea().section == key }
        }
        // off GLO and back on its first page
        fake.pressOnDevice(page: nil)
        try await waitFor(3, "HOME") { core.session.deviceScreen?.home == true }
        #expect(core.mixArea().section == "global")                              // (kept while the FM-1 is elsewhere)
        fake.pressOnDevice(page: 30)
        try await waitFor(3, "mixer again") { core.mixArea().section == "mixer" }
        #expect(fake.gotoWire.isEmpty, "\(fake.gotoWire)")
    }

    @Test func mixSectionSendsNothingForThePageTheFM1IsOn() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        fake.pressOnDevice(page: 32)
        try await waitFor(3, "reverb") { core.mixArea().section == "reverb" }
        fake.gotoWire.removeAll()
        core.handle(json: #"{"intent":"mixSection","section":"reverb"}"#)        // where the FM-1 is already
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.gotoWire.isEmpty, "\(fake.gotoWire)")
        // another section is still sent, and the FM-1 follows the phone
        core.handle(json: #"{"intent":"mixSection","section":"chorus"}"#)
        try await waitFor(3, "chorus on the FM-1") { fake.screen.page == 33 && !fake.screen.home }
        #expect(core.mixArea().section == "chorus")
    }
}

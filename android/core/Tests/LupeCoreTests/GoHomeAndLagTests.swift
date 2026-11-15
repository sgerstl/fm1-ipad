import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// goHome (decision 19) and the page lag's trace, on FakeSkiff 2.5.1 with the screen link on.
@MainActor extension FixtureRecordingTests {
    func shells(_ r: Recorder) -> [String] { r.frames.filter { $0.area == "shell" }.map(\.json) }

    @Test func goHomeSendsHomeAndTheEditorComesBack() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await pick(core, family: "ENV")
        #expect(shells(r).last?.contains("\"page\"") == true)
        fake.gotoWire.removeAll()
        core.handle(json: #"{"intent":"goHome"}"#)
        try await waitFor(3, "HOME on the FM-1") { fake.screen.home }
        #expect(fake.gotoWire == [127], "\(fake.gotoWire)")
        try await waitFor(3, "the shell back to the editor") { self.shells(r).last?.contains("\"editor\"") == true }
        #expect(core.pageArea() == nil)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func goHomeIsRefusedWhileReadOnly() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r, writes: false)
        defer { core.stop(); plug.unplug() }
        fake.gotoWire.removeAll()
        core.handle(json: #"{"intent":"goHome"}"#)
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.gotoWire.isEmpty)
    }

    /// The phone's own steps after a family key, timed (printed; the numbers go in android/notes/page-lag.md). The
    /// page must be published in the intent's own call (under a frame), from Session's optimistic screen.
    @Test func aFamilyKeyPublishesThePageWithinFrames() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await pick(core, family: "ENV")
        for playing in [false, true] {
            if playing { core.handle(json: #"{"intent":"play"}"#); try await waitFor(3, "playing") { core.session.playing } }
            for fam in ["FX", "LFO", "ENV"] {
                let n = r.frames.count
                let t0 = LagClock.now()
                core.handle(json: #"{"intent":"pickPage","family":"\#(fam)"}"#)
                try await waitFor(2, "\(fam) published") {
                    r.frames.dropFirst(n).contains { $0.area == "page" && $0.json.contains("\"family\":\"\(fam)\"") }
                }
                let dt = LagClock.now() - t0
                try await Task.sleep(for: .milliseconds(300))
                print("LAG \(playing ? "playing" : "stopped") \(fam): page published after \(String(format: "%.1f", dt)) ms")
                for l in core.lag.last { print(String(format: "LAG   +%6.1f  %@", l.at, l.line)) }
                #expect(dt < 16, "\(fam): \(dt) ms: the page goes out in the intent's own call, not a frame later")
            }
        }
    }
}

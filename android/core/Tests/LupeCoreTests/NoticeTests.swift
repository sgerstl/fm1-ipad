import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The `notice` area: what the core didn't carry out reaches the screen, with its track and entry, each time.
// every test ends within 3 minutes, so a stuck test fails instead of stalling the run (2026-11-18)
@Suite(.serialized, .timeLimit(.minutes(3))) @MainActor struct NoticeTests {
    final class Box { var writes = true; var notices: [NoticeArea] = []; var log: [String] = [] }

    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { area, json in
                                 if area == "notice", let n = try? JSONDecoder().decode(NoticeArea.self, from: Data(json.utf8)) { box.notices.append(n) }
                             }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil && core.session.skiffSong?.pool != nil) {
            try await Task.sleep(for: .milliseconds(20))
        }
        if fake.playing {
            core.handle(json: #"{"intent":"stop"}"#)
            let stop = Date().addingTimeInterval(3)
            while Date() < stop, fake.playing || core.session.playing { try await Task.sleep(for: .milliseconds(20)) }
        }
        box.notices.removeAll(); box.log.removeAll()
        return (core, fake)
    }
    func wait(_ what: String, _ ok: () -> Bool) async throws {
        let end = Date().addingTimeInterval(4)
        while Date() < end, !ok() { try await Task.sleep(for: .milliseconds(20)) }
        #expect(ok(), "\(what)")
    }

    /// Scott's case on the Pixel: every pattern number taken, New pattern refused by the FM-1 (LIST NEW, rc 4).
    @Test func patternsFullReachesTheScreen() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        for i in 0..<64 where fake.poolLen[i] == 0 { fake.poolLen[i] = 16 }
        core.handle(json: #"{"intent":"blockNew","track":2}"#)
        try await wait("PATTERNS FULL said") { box.notices.contains { $0.text.hasPrefix("All 64 patterns are taken") } }
        let n = try #require(box.notices.last)
        #expect(n.track == 2, "\(n)")
        // the same refusal again is published again
        let count = box.notices.count
        core.handle(json: #"{"intent":"blockNew","track":2}"#)
        try await wait("said again") { box.notices.count == count + 1 }
        #expect(box.log.contains { $0.hasPrefix("FM-1 refused: ") })
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func theCoresOwnRefusalsSayWhere() async throws {
        let box = Box()
        let (core, _) = try await connected(box)
        defer { core.stop() }
        // an empty pattern number can't be inserted
        let empty = try #require((1...64).first { (core.session.skiffSong?.pool?.patterns[$0 - 1].length ?? 0) == 0 })
        core.handle(json: #"{"intent":"blockInsert","track":1,"at":0,"pattern":\#(empty)}"#)
        #expect(box.notices.last?.text.contains("holds nothing") == true && box.notices.last?.track == 1)
        // a block that isn't there
        core.handle(json: #"{"intent":"blockChain","track":1,"block":15}"#)
        #expect(box.notices.last?.track == 1 && box.notices.last?.entry == 15, "\(box.notices)")
        // an intent the screen got wrong is the log's, not the person's
        let count = box.notices.count
        core.handle(json: #"{"intent":"setHomeKnob","slot":9,"value":1}"#)
        #expect(box.notices.count == count)
    }

    @Test func readOnlyIsSaidOnceForADrag() async throws {
        let box = Box()
        let (core, _) = try await connected(box)
        defer { core.stop() }
        box.writes = false
        for v in 0..<20 { core.handle(json: #"{"intent":"setHomeKnob","slot":0,"value":\#(v)}"#) }
        #expect(box.notices.count == 1 && box.notices[0].text == PhoneCore.readOnlyNotice && box.notices[0].track == nil)
        #expect(box.log.filter { $0.hasPrefix("read-only:") }.count == 20)
        // absent, not null, where the core doesn't know; a refusal says so (Scott, 2026-11-17, messages rule)
        #expect(AreaJSON.encode(box.notices[0]) == #"{"kind":"refusal","text":"\#(PhoneCore.readOnlyNotice)"}"#)
    }

    /// Clear unused patterns: read-only and unconfirmed send nothing, playing is refused with a notice, and stopped
    /// it clears what nothing uses and says how many.
    @Test func clearUnusedPatternsClearsWhatNothingUses() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let named = Set(core.padsArea().rows.flatMap { $0.entries.compactMap(\.pattern) })
        // three kept patterns no entry names
        let spare = Array((1...64).filter { !named.contains($0) && fake.poolLen[$0 - 1] == 0 }.prefix(3))
        for p in spare { fake.poolLen[p - 1] = 16 }
        try await wait("the unused read") { Set(core.padsArea().unused).isSuperset(of: spare) }
        let unused = core.padsArea().unused
        let lens = fake.poolLen
        // read-only: nothing sent
        box.writes = false
        core.handle(json: #"{"intent":"clearUnusedPatterns","confirmed":true}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.poolLen == lens && box.notices.last?.text == PhoneCore.readOnlyNotice)
        box.writes = true
        // not confirmed: nothing sent, the log says so
        core.handle(json: #"{"intent":"clearUnusedPatterns"}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.poolLen == lens && box.log.contains { $0.contains("must confirm") })
        // playing: refused on the screen
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: #"{"intent":"clearUnusedPatterns","confirmed":true}"#)
        #expect(box.notices.last?.text.hasPrefix("Stop playback") == true && fake.poolLen == lens)
        core.handle(json: #"{"intent":"stop"}"#)
        try await wait("stopped") { !core.session.playing && !fake.playing }
        // stopped and confirmed: cleared, said, and the areas follow
        core.handle(json: #"{"intent":"clearUnusedPatterns","confirmed":true}"#)
        try await wait("cleared") { unused.allSatisfy { fake.poolLen[$0 - 1] == 0 } }
        try await wait("said") { box.notices.last?.text.hasPrefix("Cleared \(unused.count) unused patterns.") == true }
        #expect(box.notices.last?.kind == .confirmation, "a result, timed at 4 s on the screen (Scott, 2026-11-17, messages rule)")
        #expect(core.padsArea().unused.isEmpty && named.allSatisfy { fake.poolLen[$0 - 1] > 0 })
        #expect(core.padsArea().patternsFree == fake.poolLen.filter { $0 == 0 }.count)
        // nothing left: said, not sent
        core.handle(json: #"{"intent":"clearUnusedPatterns","confirmed":true}"#)
        #expect(box.notices.last?.text.hasPrefix("No pattern is unused") == true && box.notices.last?.kind == .refusal)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

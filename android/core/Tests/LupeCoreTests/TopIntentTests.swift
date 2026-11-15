import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The readout's writes through PhoneCore into FakeSkiff: setTempo (the BPM global, clamped), rec (REC's arming) and
/// setLaunch (PERFORM's launch), each read back and republished in `top`; read-only sends none.
@Suite(.serialized) @MainActor struct TopIntentTests {
    final class Box { var writes = true; var log: [String] = []; var top: [String] = [] }

    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { area, json in if area == "top" { box.top.append(json) } },
                             log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil && core.session.skiffSong?.perform != nil) {
            try await Task.sleep(for: .milliseconds(20))
        }
        if fake.playing {
            let w = box.writes; box.writes = true
            core.handle(json: #"{"intent":"stop"}"#); box.writes = w
            let stop = Date().addingTimeInterval(3)
            while Date() < stop, fake.playing || core.session.playing { try await Task.sleep(for: .milliseconds(20)) }
        }
        box.log.removeAll()
        return (core, fake)
    }
    func settle(_ cond: () -> Bool, _ what: String) async throws {
        let end = Date().addingTimeInterval(4)
        while !cond() { if Date() > end { Issue.record("timed out: \(what)"); return }; try await Task.sleep(for: .milliseconds(10)) }
    }
    func lastTop(_ box: Box) -> TopArea? { box.top.last.flatMap { try? JSONDecoder().decode(TopArea.self, from: Data($0.utf8)) } }

    @Test func tempoReachesTheFM1AndTopShowsIt() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let target = fake.globals[0] == 128 ? 131 : 128
        core.handle(json: #"{"intent":"setTempo","bpm":\#(Double(target) + 0.3)}"#)       // rounded to a whole BPM
        try await settle({ fake.globals[0] == target }, "tempo on the FM-1")
        try await settle({ lastTop(box)?.tempo == Double(target) }, "top republished")
        // out of range: clamped to the FM-1's range, as the iPad's tempo control does
        let hi = core.session.bpmRange.upperBound
        core.handle(json: #"{"intent":"setTempo","bpm":9999}"#)
        try await settle({ fake.globals[0] == hi }, "clamped")
        try await settle({ lastTop(box)?.tempo == Double(hi) }, "top clamped")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func recArmsAndDisarms() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let bit = 1 << core.session.selectedTrack
        core.handle(json: #"{"intent":"rec"}"#)
        try await settle({ fake.armed & bit != 0 }, "armed")
        try await settle({ lastTop(box)?.rec == true }, "top rec on")
        core.handle(json: #"{"intent":"rec"}"#)
        try await settle({ fake.armed == 0 }, "disarmed")
        try await settle({ lastTop(box)?.rec == false }, "top rec off")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func launchQuantiseReachesTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        for (q, n) in [("beat", 2), ("now", 3), ("loop", 0), ("bar", 1)] {
            core.handle(json: #"{"intent":"setLaunch","quantize":"\#(q)"}"#)
            try await settle({ fake.launch == n }, "launch \(q) on the FM-1")
            try await settle({ lastTop(box)?.launch.rawValue == q }, "top launch \(q)")
        }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func readOnlySendsNoneOfThem() async throws {
        let box = Box(); box.writes = false
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let bpm = fake.globals[0], armed = fake.armed, launch = fake.launch
        for j in [#"{"intent":"setTempo","bpm":140}"#, #"{"intent":"rec"}"#, #"{"intent":"setLaunch","quantize":"now"}"#] { core.handle(json: j) }
        try await Task.sleep(for: .milliseconds(500))
        #expect(fake.globals[0] == bpm && fake.armed == armed && fake.launch == launch)
        #expect(box.log.filter { $0.hasPrefix("read-only:") }.count == 3, "\(box.log)")
        #expect(!box.log.contains { $0.contains("not handled yet") })
    }
}

import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// P6's intents through PhoneCore into FakeSkiff: block edits as the iPad's ArrangeEdits (the song store's rewrite),
/// automation as its motion lanes (MotionPaint, paintMotion), the confirms (decision 16; erasing a pattern; clearing a
/// lane), and read-only sending none.
// every test ends within 3 minutes, so a stuck test fails instead of stalling the run (2026-11-18)
@Suite(.serialized, .timeLimit(.minutes(3))) @MainActor struct P6IntentTests {
    final class Box { var writes = true; var log: [String] = [] }

    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { _, _ in }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil && core.session.skiffSong?.pool != nil) {
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
    func idle(_ core: PhoneCore) async throws {
        try await Task.sleep(for: .milliseconds(30))
        try await settle({ !(core.session.skiffSong?.busy ?? false) }, "idle")
    }
    func send(_ core: PhoneCore, _ json: String) { core.handle(json: json) }

    @Test func theTimelineIsTheFM1sSong() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let a = core.timelineArea()
        #expect(a.tracks.count == 6 && a.bars > 0)
        let t0 = a.tracks[0]
        let used = fake.lists[0].filter { $0.p != 0 }.count
        #expect(t0.blocks.map { $0.last - $0.first + 1 }.reduce(0, +) == used)
        #expect(zip(t0.blocks, t0.blocks.dropFirst()).allSatisfy { abs($0.startBar + $0.lengthBars - $1.startBar) < 0.01 })   // end to end
        #expect(t0.blocks.first.map { fake.lists[0][$0.first].p == $0.pattern } ?? false)
    }

    @Test func blockEditsReachTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let t = 0
        func blocks() -> [TimelineArea.Block] { core.timelineArea().tracks[t].blocks }
        let b0 = try #require(blocks().first)
        // stretch: REPS (the fake keeps REPS − 1)
        send(core, #"{"intent":"blockStretch","track":1,"block":\#(b0.id),"reps":5}"#)
        try await settle({ fake.lists[t][b0.last].r == 4 }, "stretch"); try await idle(core)
        // move one place later: the first block's pattern lands after the second block
        let before = blocks()
        let p0 = before[0].pattern, p1 = before[1].pattern
        send(core, #"{"intent":"blockMove","track":1,"block":\#(before[0].id),"by":1}"#)
        try await settle({ core.timelineArea().tracks[t].blocks.prefix(2).map(\.pattern) == [p1, p0] }, "move"); try await idle(core)
        // duplicate, then insert a kept pattern at the start
        let n = fake.lists[t].filter { $0.p != 0 }.count
        send(core, #"{"intent":"blockDuplicate","track":1,"block":\#(blocks()[0].id)}"#)
        try await settle({ fake.lists[t].filter { $0.p != 0 }.count == n + 1 }, "duplicate"); try await idle(core)
        let kept = try #require(core.timelineArea().kept.last)
        send(core, #"{"intent":"blockInsert","track":1,"at":0,"pattern":\#(kept)}"#)
        try await settle({ fake.lists[t][0].p == kept }, "insert"); try await idle(core)
        // chain the first into the next, then split it again
        send(core, #"{"intent":"blockChain","track":1,"block":0}"#)
        try await settle({ core.timelineArea().tracks[t].blocks[0].patterns.count == 2 }, "chain"); try await idle(core)
        send(core, #"{"intent":"blockSplit","track":1,"block":0}"#)
        try await settle({ core.timelineArea().tracks[t].blocks[0].patterns.count == 1 }, "split"); try await idle(core)
        // a new empty pattern after the last entry (LIST NEW)
        let end = fake.lists[t].lastIndex { $0.p != 0 }!
        send(core, #"{"intent":"blockNew","track":1}"#)
        try await settle({ fake.lists[t][end + 1].p != 0 }, "new"); try await idle(core)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func anEditThatErasesAPatternWaitsForTheConfirm() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        send(core, #"{"intent":"blockNew","track":2}"#)                                   // a pattern only this entry names
        let end = fake.lists[1].lastIndex { $0.p != 0 }!
        try await settle({ (fake.lists[1].lastIndex { $0.p != 0 } ?? 0) == end + 0 && core.timelineArea().tracks[1].blocks.last?.first == end }, "read")
        try await idle(core)
        let last = try #require(core.timelineArea().tracks[1].blocks.last)
        let p = try #require(last.pattern)
        #expect(fake.poolLen[p - 1] >= 0)
        // no confirm any more (batch item 13): the block goes, and its pattern is kept for the undo
        send(core, #"{"intent":"blockDelete","track":2,"block":\#(last.id)}"#)
        try await settle({ fake.lists[1][last.id].p == 0 }, "deleted")
        try await settle({ core.timelineArea().clearUndo.contains { $0.block && $0.track == 2 && $0.entry == last.id } }, "undo offered")
        #expect(fake.poolLen[p - 1] > 0)
        // set pattern: an empty number refused
        let empty = try #require((1...64).first { !core.timelineArea().kept.contains($0) })
        send(core, #"{"intent":"blockSetPattern","track":2,"block":0,"pattern":\#(empty)}"#)
        try await Task.sleep(for: .milliseconds(150))
        #expect(box.log.contains { $0.contains("holds nothing") })
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func playbackModeReachesTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        send(core, #"{"intent":"setPlaybackMode","mode":"once"}"#)
        try await settle({ fake.songMode == 2 }, "once"); try await idle(core)
        send(core, #"{"intent":"setPlaybackMode","mode":"loop"}"#)
        try await settle({ fake.songMode == 0 }, "loop")
        try await settle({ core.timelineArea().mode == "off" }, "shown")
    }

    @Test func automationDrawsAndClears() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let s = core.session, t = core.editorTrack()
        // a lane with nothing recorded on it: drawn at once (MOTION op 3), a stroke over steps 4…7
        let fresh = try #require(s.trackDescs.values.first { d in d.label == "RESONANCE" || d.label == "RESO" }?.label
                                 ?? s.trackDescs.values.map(\.label).first { l in !(s.motion[t]?.events.contains { s.trackDescs[$0.id]?.label == l } ?? false) && core.paramID(l) != nil && ["LEVEL", "PAN", "GLIDE"].contains(l) })
        let fid = try #require(core.paramID(fresh))
        send(core, #"{"intent":"automationLane","lane":"\#(fresh)"}"#)
        #expect(core.automationArea().lane == fresh)
        send(core, #"{"intent":"drawLane","param":"\#(fresh)","from":4,"values":[20,40,60,80]}"#)
        // the whole stroke: steps 4…7 and the put-back after it (MotionPaint's restore), written one after another
        try await settle({ Set(fake.motion[t].filter { $0.id == fid }.map(\.step)).isSuperset(of: [4, 5, 6, 7]) }, "drawn")
        try await Task.sleep(for: .milliseconds(400))
        await s.readMotion(track: t)
        try await settle({ core.automationArea().points.dropFirst(5).first?.source == "recorded" }, "shown recorded")
        // decision 16: over those recorded changes only confirmed
        let count = fake.motion[t].count
        send(core, #"{"intent":"drawLane","param":"\#(fresh)","from":5,"values":[100]}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(box.log.contains { $0.contains("decision 16") } && fake.motion[t].count == count)
        let hi = core.automationArea().max                                                   // values within the lane's range
        send(core, #"{"intent":"drawLane","param":"\#(fresh)","from":5,"values":[\#(hi)],"confirmed":true}"#)
        try await settle({ fake.motion[t].contains { $0.id == fid && $0.step == 5 && $0.value == hi } }, "drawn over")
        // a lock (op 5) on a step; step 12 holds step 8's recorded change, so it is confirmed too (decision 16)
        send(core, #"{"intent":"drawLane","param":"\#(fresh)","from":12,"values":[\#(hi / 2)],"lock":true,"confirmed":true}"#)
        try await settle({ fake.motion[t].contains { $0.id == fid && $0.step == 12 && $0.lock } }, "lock drawn")
        // clear the lane: only confirmed
        send(core, #"{"intent":"clearLane","param":"\#(fresh)"}"#)
        try await Task.sleep(for: .milliseconds(150))
        #expect(fake.motion[t].contains { $0.id == fid })
        send(core, #"{"intent":"clearLane","param":"\#(fresh)","confirmed":true}"#)
        try await settle({ !fake.motion[t].contains { $0.id == fid } }, "cleared")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func readOnlySendsNoneOfThem() async throws {
        let box = Box(); box.writes = false
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let lists = fake.lists, motion = fake.motion.map(\.count), mode = fake.songMode
        for j in [#"{"intent":"blockStretch","track":1,"block":0,"reps":3}"#, #"{"intent":"blockNew","track":1}"#,
                  #"{"intent":"blockDelete","track":1,"block":0,"confirmed":true}"#, #"{"intent":"setPlaybackMode","mode":"once"}"#,
                  #"{"intent":"drawLane","param":"LEVEL","from":0,"values":[10],"confirmed":true}"#,
                  #"{"intent":"clearLane","param":"CHORUS","confirmed":true}"#] { send(core, j) }
        send(core, #"{"intent":"automationLane","lane":"CHORUS"}"#)                        // the screen's own
        try await Task.sleep(for: .milliseconds(400))
        #expect(fake.lists == lists && fake.motion.map(\.count) == motion && fake.songMode == mode)
        #expect(box.log.filter { $0.hasPrefix("read-only:") }.count == 6, "\(box.log)")
        #expect(core.automationArea().lane == "CHORUS")
    }

    /// The pool's free numbers and the unused patterns in the pads and Timeline areas: what New pattern needs, and
    /// what the FM-1's CLEAR UNUSED would take (POOL's own LEN and uses).
    @Test func thePadsSayHowManyPatternNumbersAreFree() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let pool = try #require(core.session.skiffSong?.pool)
        var a = core.padsArea()
        #expect(a.patternsFree == pool.free && a.patternsFree == pool.patterns.filter { $0.length == 0 && $0.uses == 0 }.count)
        #expect(a.unused == (0..<64).filter { pool.patterns[$0].length > 0 && pool.patterns[$0].uses == 0 }.map { $0 + 1 })
        #expect(core.timelineArea().patternsFree == a.patternsFree)
        // every number taken on the FM-1: none free, and the ones no entry names are the unused
        let named = Set(a.rows.flatMap { $0.entries.compactMap(\.pattern) })
        for i in 0..<64 where fake.poolLen[i] == 0 { fake.poolLen[i] = 16 }
        let end = Date().addingTimeInterval(8)
        while Date() < end, core.padsArea().patternsFree != 0 { try await Task.sleep(for: .milliseconds(50)) }
        a = core.padsArea()
        #expect(a.patternsFree == 0 && core.timelineArea().patternsFree == 0)
        #expect(Set(a.unused).isDisjoint(with: named) && a.unused.count == 64 - core.session.skiffSong!.pool!.patterns.filter { $0.uses > 0 }.count)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

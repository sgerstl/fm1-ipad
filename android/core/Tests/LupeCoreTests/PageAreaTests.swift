import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The `page` area (P4's schema) built from FakeSkiff 2.5.1 with the screen link on, and recorded into
/// android/fixtures/state/page-*.json (RECORD_FIXTURES=1, as FixtureRecordingTests). Pages are reached through the
/// phone's own intent (pickPage), then FakeSkiff answers SCREEN_GOTO as the FM-1 does. Each scenario visits its
/// family's pages and ends on the one shown, so FakeLupeCore (which learns every page frame it replays) can switch.
@MainActor extension FixtureRecordingTests {
    /// FakeSkiff 2.5.1 (the FM-1 P1 found), screen link on, `track` (1…6) selected.
    func linkedFake(track: Int, engine: Int? = nil) throws -> FakeSkiff {
        let fake = try #require(FakeSkiff(SkiffFixture.load(.v2_5_1)))
        fake.seedDemo()
        fake.screenLink = true
        fake.selected = track - 1
        if let engine { fake.engines[track - 1].engine = engine }
        return fake
    }

    /// `writes`: the gate lets SCREEN_GOTO and SET through (LinkGate is read-only until told otherwise).
    func readyCore(_ fake: FakeSkiff, _ r: Recorder, writes: Bool = true) async throws -> (PhoneCore, Plug) {
        let plug = Plug(fake)
        plug.gate.readOnly = !writes
        let core = PhoneCore(session: DeviceSession(transport: { plug.gate.makeTransport() }), publish: r.publish, canWrite: { writes })
        core.start()
        try await Task.sleep(for: .milliseconds(200))
        plug.plugIn()
        try await waitFor(10, "ready") { core.linkArea().phase == .ready }
        try await waitFor(5, "the screen link") { core.session.screenLinked }
        return (core, plug)
    }

    func pick(_ core: PhoneCore, family: String, page: Int? = nil) async throws {
        let p = page.map { ", \"page\": \($0)" } ?? ""
        core.handle(json: "{\"intent\": \"pickPage\", \"family\": \"\(family)\"\(p)}")
        let want = page
        try await waitFor(3, "page \(page.map(String.init) ?? family)") {
            guard let a = core.pageArea() else { return false }
            return want.map { a.page == $0 } ?? (a.family == family)
        }
        try await Task.sleep(for: .milliseconds(60))
    }

    func pages(_ r: Recorder) -> [PageArea] {
        r.frames.filter { $0.area == "page" }.compactMap { try? JSONDecoder().decode(PageArea.self, from: Data($0.json.utf8)) }
    }

    /// Visits `visit` (page numbers of `family`, the shown one last), then records: every page frame stamped at the time
    /// (see below).
    func recordPages(_ scenario: String, track: Int, engine: Int? = nil, family: String, visit: [Int], cursor: Int? = nil, cursor2: Int? = nil,
                     until: ((PageArea) -> Bool)? = nil, note: String) async throws {
        let r = Recorder()
        let fake = try linkedFake(track: track, engine: engine)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        for p in visit { try await pick(core, family: family, page: p) }
        if let cursor {
            fake.turnCursorOnDevice(to: cursor)
            try await waitFor(3, "the cursor") { core.session.deviceScreen?.cursor == cursor }
            try await Task.sleep(for: .milliseconds(100))
        }
        if let until { try await waitFor(5, "the page's data") { core.pageArea().map(until) ?? false } }
        try await Task.sleep(for: .milliseconds(300))
        let got = pages(r)
        #expect(got.last?.page == visit.last, "\(scenario): ended on \(String(describing: got.last?.page))")
        #expect(got.last?.track == track)
        #expect(got.last?.controls.count == 4)
        if let cursor, let first = got.last?.controls.first, let c = first { #expect(c.raw == cursor, "\(scenario): the cursor") }
        // The scenario opens ready: the last frame of each area at the start (the link's searching and reading steps
        // are `ready.json`'s). Every page frame follows 1 ms apart, the shown one last: the replay lands on it, and the
        // earlier frames only teach the fake the row.
        var lastOf: [String: (ms: Int, area: String, json: String)] = [:]
        for f in r.frames where f.area != "page" { lastOf[f.area] = f }
        var n = 0
        r.frames = lastOf.values.sorted { $0.area < $1.area }.map { (0, $0.area, $0.json) }
            + r.frames.filter { $0.area == "page" }.map { f in defer { n += 1 }; return (n, f.area, f.json) }
        try save(r, scenario, note: note)
    }

    @Test func recordsEnv() async throws {
        try await recordPages("page-env", track: 5, family: "ENV", visit: [1, 0], note: "ENV on a Piano track, Skiff 2.5.1 (board 55).")
    }
    @Test func recordsLfo() async throws {
        try await recordPages("page-lfo", track: 5, family: "LFO", visit: [3, 4, 2], note: "LFO, Skiff 2.5.1.")
    }
    @Test func recordsMod() async throws {
        try await recordPages("page-mod", track: 5, family: "LFO", visit: [2, 3, 4], cursor: 1, note: "MOD with route 2 (LFO → CUTOFF) picked, Skiff 2.5.1 (board 60).")
    }
    @Test func recordsDrive() async throws {
        try await recordPages("page-drive", track: 1, family: "FX", visit: [5, 46, 47, 7, 9, 10, 6], note: "FX › DRIVE on the 2.5.1 row of eight (board 59 right).")
    }
    @Test func recordsEdit1() async throws {
        try await recordPages("page-edit1", track: 1, family: "EDIT", visit: [15, 28, 29, 14], note: "EDIT 1 on an ANALOG track (board 59 left).")
    }
    @Test func recordsScale() async throws {
        try await recordPages("page-scale", track: 5, family: "SEL", visit: [12, 13, 11], note: "SEL › SCALE, with CHORD's STRUM and DIR beside it (board 61 left).")
    }
    @Test func recordsOperator() async throws {
        try await recordPages("page-operator", track: 2, engine: 12, family: "EDIT", visit: [17, 16], cursor: 1,
                              until: { $0.graph.kind == .fm6op }, note: "EDIT › OPERATOR on an FM6 track, operator 2 picked: the algorithm, ratios and envelopes (FakeSkiff's init patch).")
    }
    @Test func recordsAllOps() async throws {
        try await recordPages("page-allops", track: 2, engine: 12, family: "EDIT", visit: [16, 17],
                              until: { $0.graph.kind == .fm6all }, note: "EDIT › ALL OPS on an FM6 track: the algorithm chart (FakeSkiff's init patch).")
    }
    @Test func recordsDrumXSound() async throws {
        try await recordPages("page-sound", track: 4, engine: 14, family: "EDIT", visit: [20, 19], cursor: 2,
                              until: { $0.graph.kind == .sound }, note: "EDIT › SOUND on a DRUM-X track, lane 3: the kit's windows (FakeSkiff's DEEP kit).")
    }
    @Test func recordsArp() async throws {
        try await recordPages("page-arp", track: 5, family: "ARP", visit: [40, 39], note: "ARP (board 63 left).")
    }

    // MARK: what the area says, beyond what a screen draws

    @Test func envControlsAreTheFM1sKnobs() async throws {
        let r = Recorder()
        let (core, plug) = try await readyCore(try linkedFake(track: 5), r)
        defer { core.stop(); plug.unplug() }
        #expect(core.pageArea() == nil, "no sound page while the FM-1 is on HOME")
        try await pick(core, family: "ENV")
        let a = try #require(core.pageArea())
        #expect(a.family == "ENV" && a.page == 0)
        #expect(a.pages.map(\.title) == ["ENV", "ENV 2"])
        #expect(a.controls.compactMap { $0?.label } == ["ATTACK", "DECAY", "SUSTAIN", "RELEASE"], "\(a.controls)")
        #expect(a.graph.kind == .env && a.graph.values.count == 4)
        #expect(a.graph.values == a.controls.compactMap { $0?.raw })
    }

    @Test func the25FXRowAndItsNumbers() async throws {
        let r = Recorder()
        let (core, plug) = try await readyCore(try linkedFake(track: 1), r)
        defer { core.stop(); plug.unplug() }
        try await pick(core, family: "FX", page: SkiffPageMap.fxDelay)
        #expect(core.session.deviceScreen?.page == 46)
        let a = try #require(core.pageArea())
        #expect(a.page == 46 && a.pages.contains { $0.title == "REVERB" && $0.index == 47 }, "\(a.pages)")
        #expect(a.controls.first??.label == "SEND", "knob 1 is the track's send: \(a.controls)")
        #expect(a.pages.allSatisfy { !(41...45).contains($0.index) })
        #expect(a.pages.map(\.title) == ["FX", "DELAY", "REVERB", "DRIVE", "INSERT", "SLICER", "DUCK"], "decision 17: the FM-1's own seven on 2.5.1, no INSERT 2: \(a.pages.map(\.title))")
    }

    @Test func aKnobTurnedOnTheFM1LightsItsControl() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 5)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await pick(core, family: "ENV")
        let a = try #require(core.pageArea())
        #expect(a.turned == -1)
        let decayID = try #require(core.session.pageLayout?.first { $0.title == "ENV" }?.ids[1])
        fake.push(Cmd.changed, [0, UInt8(decayID)] + fake.v14(77))
        try await waitFor(3, "the turn to light DECAY") { core.pageArea()?.turned == 1 }
        let b = try #require(core.pageArea())
        #expect(b.controls[1]?.raw == 77 && b.turnSeq != 0)
    }

    @Test func setParamWritesThroughTheSession() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 5)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await pick(core, family: "ENV")
        core.handle(json: "{\"intent\": \"setParam\", \"slot\": 1, \"value\": 90}")
        try await waitFor(3, "DECAY 90") { core.pageArea()?.controls[1]?.raw == 90 }
        // a lane page: slot 0 is the pick (no setParam), slots 1…3 the lane's knobs
        core.handle(json: "{\"intent\": \"setParam\", \"slot\": 9, \"value\": 1}")      // out of range: ignored, not a crash
    }

    @Test func aReadOnlyLinkDropsTheWrites() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 5)
        let (core, plug) = try await readyCore(fake, r, writes: false)
        defer { core.stop(); plug.unplug() }
        core.handle(json: "{\"intent\": \"pickPage\", \"family\": \"ENV\"}")
        core.handle(json: "{\"intent\": \"pickPage\", \"family\": \"ENV\", \"page\": 1}")
        try await Task.sleep(for: .milliseconds(500))
        #expect(fake.gotoWire.isEmpty, "refused before Session (and the guard behind it): never reached the FM-1: \(fake.gotoWire)")
        #expect(core.session.deviceScreen?.home == true, "the screen is where the FM-1 left it")
    }

    @Test func readOnlyRefusesPageWritesUpFront() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 5)
        let plug = Plug(fake)
        plug.gate.readOnly = false
        let logged = LogBox()
        let core = PhoneCore(session: DeviceSession(transport: { plug.gate.makeTransport() }), publish: r.publish,
                             log: { logged.add($0) }, canWrite: { false })
        core.start()
        defer { core.stop(); plug.unplug() }
        plug.plugIn()
        try await waitFor(10, "ready") { core.linkArea().phase == .ready }
        try await waitFor(5, "the screen link") { core.session.screenLinked }
        core.handle(json: "{\"intent\": \"pickPage\", \"family\": \"ENV\"}")
        core.handle(json: "{\"intent\": \"setParam\", \"slot\": 1, \"value\": 90}")
        try await Task.sleep(for: .milliseconds(300))
        #expect(core.session.deviceScreen?.home == true && core.pageArea() == nil, "no optimistic page change")
        #expect(logged.lines.filter { $0.hasPrefix("read-only:") }.count == 2, "\(logged.lines)")
    }

    final class LogBox: @unchecked Sendable {
        private let l = NSLock(); private var v: [String] = []
        func add(_ s: String) { l.withLock { v.append(s) } }
        var lines: [String] { l.withLock { v } }
    }

    // MARK: shell.bottom follows the FM-1's screen (decision 3)

    func bottoms(_ r: Recorder) -> [ShellArea.Bottom] {
        r.frames.filter { $0.area == "shell" }.compactMap { try? JSONDecoder().decode(ShellArea.self, from: Data($0.json.utf8)).bottom }
    }

    @Test func aSoundPageOnTheFM1ShowsOnThePhoneAndHomeBringsTheEditorBack() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 5)
        let (core, plug) = try await readyCore(fake, r, writes: false)      // the FM-1's own buttons: nothing is written
        defer { core.stop(); plug.unplug() }
        try await waitFor(3, "the editor first") { self.bottoms(r).last?.kind == "editor" }
        fake.pressOnDevice(page: 2)                                          // LFO
        try await waitFor(3, "LFO") { self.bottoms(r).last == ShellArea.Bottom(kind: "page", family: "LFO", page: "LFO") }
        fake.pressOnDevice(page: 1)
        try await waitFor(3, "ENV 2") { self.bottoms(r).last == ShellArea.Bottom(kind: "page", family: "ENV", page: "ENV 2") }
        fake.pressOnDevice(page: SkiffPageMap.fxDelay)                       // 2.5.1's FX › DELAY
        try await waitFor(3, "DELAY") { self.bottoms(r).last == ShellArea.Bottom(kind: "page", family: "FX", page: "DELAY") }
        fake.pressOnDevice(page: 41)                                         // SEQ › NOTES (device page 42 on 2.5.1)
        try await waitFor(3, "NOTES: the editor") { self.bottoms(r).last?.kind == "editor" }
        #expect(core.pageArea() == nil, "no sound page on NOTES")
        fake.pressOnDevice(page: 0)
        try await waitFor(3, "ENV") { self.bottoms(r).last?.page == "ENV" }
        fake.pressOnDevice(page: nil)                                        // HOME
        try await waitFor(3, "HOME: the editor") { self.bottoms(r).last?.kind == "editor" }
        // only `bottom` is sent: the tab and divider are the screens' own
        let json = try #require(r.frames.last { $0.area == "shell" }?.json)
        #expect(!json.contains("tab") && !json.contains("divider"), Comment(rawValue: json))
    }

    @Test func theDensePagesCarryWhatTheirPicturesDraw() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 2, engine: 12)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await pick(core, family: "EDIT", page: 16)
        try await waitFor(5, "the FM6 patch") { core.pageArea()?.graph.kind == .fm6op }
        let g = try #require(core.pageArea()?.graph)
        let p = try #require(g.fm6)
        #expect(p.ops.count == 6 && p.picked == 1 && p.algorithm == 0, "\(p)")
        #expect(p.ops.allSatisfy { $0.r.count == 4 && $0.l.count == 4 && !$0.ratio.isEmpty })
        #expect(core.pageArea()?.controls.allSatisfy { $0 == nil } == true, "the picture takes the controls' place")
        fake.turnCursorOnDevice(to: 3)
        try await waitFor(3, "operator 4 picked") { core.pageArea()?.graph.fm6?.picked == 4 }
        // pickTile on OPERATOR moves the FM-1's cursor, as the lane tiles do (a write: allowed in this gate)
        core.handle(json: "{\"intent\": \"pickTile\", \"tile\": 5}")
        try await waitFor(3, "operator 6 picked") { core.pageArea()?.graph.fm6?.picked == 6 }
        // SLICES has no picture to draw: the card stays (its markers can't be read)
        try await pick(core, family: "EDIT", page: 17)
        try await waitFor(10, "ALL OPS") { core.pageArea()?.graph.kind == .fm6all }   // several page reads; 5 s ran out with four suites in parallel
    }
}

import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The `freetake` area over FakeSkiff 2.5.1 with the screen link's v7 (FREE TAKE: TAKE 94, UNDO 95), taught from the
/// firmware as SloopKit's FreeTakeLinkTests are. Records android/fixtures/state/take-*.json with RECORD_FIXTURES=1.
/// Like the suite's Plug, and the FM-1's MIDI notes too (they reach the phone as bytes, as the real link brings them).
final class NotePlug: @unchecked Sendable {
    let gate: LinkGate
    let fake: FakeSkiff
    private var pumps: [Task<Void, Never>] = []
    init(_ fake: FakeSkiff) { self.fake = fake; gate = LinkGate(send: { [fake] in fake.send($0) }) }
    func plugIn() {
        gate.opened()
        let gate = gate, frames = fake.frames, notes = fake.notes
        pumps.append(Task.detached { for await f in frames { f.withUnsafeBytes { gate.bytes($0) } } })
        pumps.append(Task.detached {
            for await n in notes { let b: [UInt8] = [(n.on ? 0x90 : 0x80) | (n.channel & 0x0F), n.note, n.on ? max(1, n.velocity) : 0]; b.withUnsafeBytes { gate.bytes($0) } }
        })
    }
    func unplug() { pumps.forEach { $0.cancel() }; gate.lost() }
}

@MainActor extension FixtureRecordingTests {
    func takeCore(_ fake: FakeSkiff, _ r: Recorder, writes: Bool = true, take: Bool = true, log: @escaping (String) -> Void = { _ in }) async throws -> (PhoneCore, NotePlug) {
        let plug = NotePlug(fake)
        plug.gate.readOnly = !writes
        let core = PhoneCore(session: DeviceSession(transport: { plug.gate.makeTransport() }), publish: r.publish, log: log, canWrite: { writes })
        core.start()
        try await Task.sleep(for: .milliseconds(200))
        plug.plugIn()
        try await waitFor(10, "ready") { core.linkArea().phase == .ready }
        try await waitFor(5, "the screen link") { core.session.screenLinked }
        if take { try await waitFor(5, "the take link") { core.session.takeLinked } }
        return (core, plug)
    }

    func takeFake(version: Int = 7) throws -> FakeSkiff {
        // not the demo seed: it starts the transport, and a take is played with the transport stopped
        let fake = try #require(FakeSkiff(SkiffFixture.load(.v2_5_1)))
        fake.screenLink = true
        fake.screenLinkVersion = version
        fake.selected = 4
        fake.takeGuesses = [96, 48, 192]
        return fake
    }

    func freeTakes(_ r: Recorder) -> [FreeTakeArea] {
        r.frames.filter { $0.area == "freetake" }.compactMap { try? JSONDecoder().decode(FreeTakeArea.self, from: Data($0.json.utf8)) }
    }
    func lastBottom(_ r: Recorder) -> String? {
        r.frames.last { $0.area == "shell" }.flatMap { try? JSONDecoder().decode(ShellArea.self, from: Data($0.json.utf8)).bottom.kind }
    }

    func send(_ core: PhoneCore, _ json: String) { core.handle(json: json) }

    /// A phrase played on the FM-1 while stopped, offered after the 2.5 s pause.
    func playAndOffer(_ fake: FakeSkiff, _ core: PhoneCore) async throws {
        fake.playOnDevice(track: core.session.selectedTrack, notes: [60, 63, 67, 70, 72, 70, 67, 63])
        try await waitFor(8, "the offer") { core.freeTakeArea()?.offer != nil }
    }

    @Test func aPhraseIsOfferedStartedChosenAndKept() async throws {
        let r = Recorder()
        let fake = try takeFake()
        let (core, plug) = try await takeCore(fake, r)
        defer { core.stop(); plug.unplug() }
        #expect(core.freeTakeArea()?.offer == nil && core.freeTakeArea()?.picker == nil)
        try await playAndOffer(fake, core)
        let offer = try #require(core.freeTakeArea()?.offer)
        #expect(offer.track == 5 && offer.notes == 8 && offer.canStart && !offer.refused, "\(offer)")
        #expect(lastBottom(r) != "freetake", "only the picker takes the editor's place")

        send(core, #"{"intent": "takeStart"}"#)
        try await waitFor(5, "the picker") { core.freeTakeArea()?.picker != nil }
        let p = try #require(core.freeTakeArea()?.picker)
        #expect(p.track == 5 && p.guesses.map(\.bpm) == [96, 48, 192] && p.guesses.map(\.caption) == ["guess", "half", "double"], "\(p.guesses)")
        #expect(p.bars == [1, 2, 4, 8] && p.length >= 16)
        try await waitFor(5, "the take's notes (the live sync brings them)") { !(core.freeTakeArea()?.picker?.notes.isEmpty ?? true) }
        try await waitFor(3, "the shell to follow") { self.lastBottom(r) == "freetake" }

        send(core, #"{"intent": "takeGuess", "index": 2}"#)
        try await waitFor(3, "the 192 guess") { core.freeTakeArea()?.picker?.guess == 2 && core.freeTakeArea()?.picker?.bpm == 192 }
        send(core, #"{"intent": "takeBars", "index": 2}"#)
        try await waitFor(3, "4 bars") { core.freeTakeArea()?.picker?.barsIndex == 2 && core.freeTakeArea()?.picker?.length == 64 }
        send(core, #"{"intent": "takeSetTempo", "on": false}"#)
        try await waitFor(3, "KEEP tempo") { core.freeTakeArea()?.picker?.setsTempo == false }

        send(core, #"{"intent": "takeKeep"}"#)
        try await waitFor(5, "the take landed") { core.freeTakeArea()?.landed != nil && core.freeTakeArea()?.picker == nil }
        #expect(core.freeTakeArea()?.landed?.undoFromHere == true && core.freeTakeArea()?.landed?.undone == false)
        try await waitFor(3, "the editor back") { self.lastBottom(r) == "editor" }
        send(core, #"{"intent": "takeUndo"}"#)
        try await waitFor(3, "undone") { core.freeTakeArea()?.landed?.undone == true }
        send(core, #"{"intent": "takeDismissLanded"}"#)
        try await waitFor(3, "dismissed") { core.freeTakeArea()?.landed == nil }
    }

    @Test func putBackLeavesNothingLandedAndTheOfferCanBeLetGo() async throws {
        let r = Recorder()
        let fake = try takeFake()
        let (core, plug) = try await takeCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await playAndOffer(fake, core)
        send(core, #"{"intent": "takeDismissOffer"}"#)
        try await waitFor(3, "the offer gone") { core.freeTakeArea()?.offer == nil }
        fake.shiftSaveOnDevice()                                              // SHIFT + SAVE on the FM-1 itself
        try await waitFor(5, "the picker") { core.freeTakeArea()?.picker != nil }
        send(core, #"{"intent": "takePutBack"}"#)
        try await waitFor(5, "the picker closed") { core.freeTakeArea()?.picker == nil }
        #expect(core.freeTakeArea()?.landed == nil, "a put-back lands nothing")
    }

    @Test func readOnlyRefusesTheTakeChoicesButNotLettingGo() async throws {
        let r = Recorder()
        let fake = try takeFake()
        let logged = LogBox()
        let (core, plug) = try await takeCore(fake, r, writes: false, log: { logged.add($0) })
        defer { core.stop(); plug.unplug() }
        try await playAndOffer(fake, core)
        send(core, #"{"intent": "takeStart"}"#)
        try await Task.sleep(for: .milliseconds(400))
        #expect(core.freeTakeArea()?.picker == nil && logged.lines.contains { $0.hasPrefix("read-only: takeStart") }, "\(logged.lines)")
        send(core, #"{"intent": "takeDismissOffer"}"#)
        try await waitFor(3, "let go, read-only") { core.freeTakeArea()?.offer == nil }
    }

    @Test func withoutTheV7LinkTheChoicesAreSaidToBeUnavailable() async throws {
        let r = Recorder()
        let fake = try takeFake(version: 6)
        let logged = LogBox()
        let (core, plug) = try await takeCore(fake, r, take: false, log: { logged.add($0) })
        defer { core.stop(); plug.unplug() }
        send(core, #"{"intent": "takeStart"}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(logged.lines.contains { $0.contains("no FREE TAKE link") }, "\(logged.lines)")
    }

    // MARK: fixtures

    /// The scenario opens ready (the last frame of each area), then the freetake and shell frames as they came.
    func recordTake(_ scenario: String, note: String, drive: (FakeSkiff, PhoneCore, Recorder) async throws -> Void) async throws {
        let r = Recorder()
        let fake = try takeFake()
        let (core, plug) = try await takeCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await drive(fake, core, r)
        try await Task.sleep(for: .milliseconds(300))
        var lastOf: [String: (ms: Int, area: String, json: String)] = [:]
        for f in r.frames where !["freetake", "diag"].contains(f.area) { lastOf[f.area] = f }
        let last = r.frames.last { $0.area == "freetake" }
        r.frames = lastOf.values.sorted { $0.area < $1.area }.map { (0, $0.area, $0.json) } + (last.map { [(1, $0.area, $0.json)] } ?? [])
        try save(r, scenario, note: note)
    }

    @Test func recordsTheOffer() async throws {
        try await recordTake("take-offer", note: "A phrase played on the FM-1 while stopped, offered (FakeSkiff, Skiff 2.5.1, screen link v7).") { fake, core, _ in
            try await self.playAndOffer(fake, core)
        }
    }
    @Test func recordsThePicker() async throws {
        try await recordTake("take-picker", note: "The FM-1's FREE TAKE picker open, 192 BPM guess and 4 bars chosen (FakeSkiff, screen link v7).") { fake, core, _ in
            try await self.playAndOffer(fake, core)
            self.send(core, #"{"intent": "takeStart"}"#)
            try await waitFor(5, "the picker") { core.freeTakeArea()?.picker != nil }
            self.send(core, #"{"intent": "takeBars", "index": 2}"#)
            try await waitFor(3, "4 bars") { core.freeTakeArea()?.picker?.barsIndex == 2 }
            try await waitFor(5, "the notes") { !(core.freeTakeArea()?.picker?.notes.isEmpty ?? true) }
        }
    }
    @Test func recordsTheLanding() async throws {
        try await recordTake("take-landed", note: "A take kept: the landing strip with the FM-1's undo (FakeSkiff, screen link v7).") { fake, core, _ in
            try await self.playAndOffer(fake, core)
            self.send(core, #"{"intent": "takeStart"}"#)
            try await waitFor(5, "the picker") { core.freeTakeArea()?.picker != nil }
            self.send(core, #"{"intent": "takeKeep"}"#)
            try await waitFor(5, "landed") { core.freeTakeArea()?.landed != nil }
        }
    }
}


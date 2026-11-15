import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Records what PhoneCore publishes into android/fixtures/state/<scenario>.json, the files P2's FakeLupeCore
/// replays (android/BRIDGE.md §2, "P2's fake"). The FM-1 side is SloopKit's tested fakes, never invented:
/// FakeSkiff(demo: true) for a Skiff 2.2 FM-1, FakeSloop with another version for wrong firmware (as
/// SessionTests.refusesOtherFirmware). Unplugging goes through LinkGate.lost(), FM1Link's own path.
///
/// Always checks each scenario's phases. Writes the files only when RECORD_FIXTURES=1:
///   RECORD_FIXTURES=1 swift test --filter FixtureRecording     (in android/core)
@Suite(.serialized) @MainActor struct FixtureRecordingTests {
    final class Recorder {
        let start = Date()
        var frames: [(ms: Int, area: String, json: String)] = []
        func publish(_ area: String, _ json: String) {
            guard area != "diag" else { return }       // the debug screen's area, not a screen's: kept out of fixtures
            frames.append((Int(Date().timeIntervalSince(start) * 1000), area, json))
        }
        func phases() -> [String] {
            frames.filter { $0.area == "link" }.compactMap {
                (try? JSONDecoder().decode(LinkArea.self, from: Data($0.json.utf8)))?.phase.rawValue
            }
        }
        /// Frames of areas PhoneCore doesn't publish yet, carried over from the file already there (P2/P3's
        /// hand-written ones), so recording link and top doesn't wipe the pads a screen is being built against.
        var carried: [(ms: Int, area: String, json: String)] = []
        func carryOver(from url: URL) {
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let old = root["frames"] as? [[String: Any]] else { return }
            let mine = Set(frames.map(\.area))
            for f in old {
                guard let area = f["area"] as? String, !mine.contains(area), let ms = f["atMs"] as? Int, let st = f["state"],
                      let j = try? JSONSerialization.data(withJSONObject: st, options: [.sortedKeys]) else { continue }
                carried.append((ms, area, String(decoding: j, as: UTF8.self)))
            }
        }
        func file(scenario: String, note: String) -> String {
            let all = (frames + carried).sorted { $0.ms < $1.ms }
            let rows = all.map { #"    {"atMs": \#($0.ms), "area": "\#($0.area)", "state": \#($0.json)}"# }
            let carriedAreas = Array(Set(carried.map(\.area))).sorted()
            let provenance = carriedAreas.isEmpty ? "" :
                " The \(carriedAreas.joined(separator: ", ")) frames are hand-written (carried over) until PhoneCore publishes them."
            return """
            {
              "provisional": \(carriedAreas.isEmpty ? "false" : "true"),
              "note": "\(note) Recorded by android/core/Tests/LupeCoreTests/FixtureRecordingTests.swift (scenario \(scenario)); don't edit by hand.\(provenance)",
              "frames": [
            \(rows.joined(separator: ",\n"))
              ]
            }

            """
        }
    }

    static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()   // android/core
        .deletingLastPathComponent().appendingPathComponent("fixtures/state")                  // android/fixtures/state
    static let writing = ProcessInfo.processInfo.environment["RECORD_FIXTURES"] == "1"

    func save(_ r: Recorder, _ scenario: String, note: String) throws {
        guard Self.writing else { return }
        r.carryOver(from: Self.fixtures.appendingPathComponent("\(scenario).json"))
        try r.file(scenario: scenario, note: note).write(to: Self.fixtures.appendingPathComponent("\(scenario).json"), atomically: true, encoding: .utf8)
    }

    func waitFor(_ seconds: Double, _ what: String, _ cond: () -> Bool) async throws {
        let end = Date().addingTimeInterval(seconds)
        while !cond() {
            if Date() > end { Issue.record("timed out waiting for \(what)"); return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// FakeSkiff behind LinkGate, the way FM1Link feeds the app: the gate's sends reach the fake, the fake's
    /// frames come back as bytes.
    final class Plug: @unchecked Sendable {
        let gate: LinkGate
        let fake: FakeSkiff
        private var pump: Task<Void, Never>?
        init(_ fake: FakeSkiff) {
            self.fake = fake
            gate = LinkGate(send: { [fake] in fake.send($0) })
        }
        func plugIn() {
            gate.opened()
            let gate = gate, frames = fake.frames
            pump = Task.detached { for await f in frames { f.withUnsafeBytes { gate.bytes($0) } } }
        }
        func unplug() { pump?.cancel(); gate.lost() }
    }

    @Test func ready() async throws {
        let r = Recorder()
        let fake = try #require(FakeSkiff(demo: true))
        let plug = Plug(fake)
        let core = PhoneCore(session: DeviceSession(transport: { plug.gate.makeTransport() }), publish: r.publish)
        core.start()
        defer { core.stop() }
        try await Task.sleep(for: .milliseconds(300))      // a moment of searching first, as on the phone
        plug.plugIn()
        try await waitFor(10, "ready") { core.linkArea().phase == .ready }
        try await Task.sleep(for: .seconds(3))
        #expect(r.phases() == ["searching", "connecting", "reading", "ready"], "\(r.phases())")
        #expect(r.frames.contains { $0.area == "top" })
        try save(r, "ready", note: "An FM-1 on Skiff 2.2 (FakeSkiff demo) found, read and ready.")
    }

    @Test func searching() async throws {
        let r = Recorder()
        let core = PhoneCore(session: DeviceSession(transport: { nil }), publish: r.publish)
        core.start()
        defer { core.stop() }
        try await Task.sleep(for: .seconds(2))
        #expect(r.phases() == ["searching"])
        try save(r, "searching", note: "No FM-1 plugged in.")
    }

    @Test func lost() async throws {
        let r = Recorder()
        var plug = Plug(try #require(FakeSkiff(demo: true)))
        let core = PhoneCore(session: DeviceSession(transport: { plug.gate.makeTransport() }), publish: r.publish)
        core.start()
        defer { core.stop() }
        plug.plugIn()
        try await waitFor(10, "ready") { core.linkArea().phase == .ready }
        try await Task.sleep(for: .seconds(1))
        plug.unplug()                                      // FM1Link.onDeviceRemoved → LupeNative.onLost
        try await waitFor(3, "lost") { core.linkArea().phase == .lost }
        try await Task.sleep(for: .seconds(2))
        plug = Plug(try #require(FakeSkiff(demo: true)))   // plugged back in: a fresh device and connection
        plug.plugIn()
        try await waitFor(10, "ready again") { r.phases().filter { $0 == "ready" }.count == 2 }
        try await Task.sleep(for: .seconds(1))
        let p = r.phases()
        #expect(p.prefix(4) == ["searching", "connecting", "reading", "ready"] && p.contains("lost"), "\(p)")
        let lost = r.frames.first { $0.area == "link" && $0.json.contains("lost") }
        #expect(lost?.json.contains(#""reason":"unplugged""#) == true)
        try save(r, "lost", note: "Ready, then the FM-1 unplugged (lost, reason unplugged), then plugged back in (reading, ready).")
    }

    @Test func wrongFirmware() async throws {
        let r = Recorder()
        let core = PhoneCore(session: DeviceSession(transport: {
            let f = FakeSloop(autoEdits: false); f.version = "FELUCCA SLOOP 2.9.0"; return f
        }), publish: r.publish)
        core.start()
        defer { core.stop() }
        try await waitFor(5, "wrong firmware") { core.linkArea().phase == .wrongFirmware }
        try await Task.sleep(for: .seconds(1))
        #expect(r.frames.last { $0.area == "link" }?.json.contains(#""firmware":"FELUCCA SLOOP 2.9.0""#) == true)
        try save(r, "wrongFirmware", note: "An FM-1 on firmware Lupe doesn't speak (FakeSloop reporting SLOOP 2.9.0, as SloopKit's refusesOtherFirmware test).")
    }

    @Test func intentsDecodeAsP2SendsThem() throws {
        // The strings kotlinx.serialization writes for P2's Intent (classDiscriminator "intent").
        #expect(try PhoneIntent.decode(#"{"intent":"play"}"#) == .play)
        #expect(try PhoneIntent.decode(#"{"intent":"retry"}"#) == .retry)
        #expect(try PhoneIntent.decode(#"{"intent":"setTempo","bpm":128.0}"#) == .setTempo(128))
        #expect(try PhoneIntent.decode(#"{"intent":"setLaunch","quantize":"beat"}"#) == .setLaunch(.beat))
        #expect(try PhoneIntent.decode(#"{"intent":"setPlaybackMode","mode":"once"}"#) == .setPlaybackMode(.once))
        #expect(throws: (any Error).self) { try PhoneIntent.decode(#"{"intent":"explode"}"#) }
    }
}

import Foundation
import Testing
@testable import SloopKit

/// The MIDI export against Skiff's own sequencer (skiff-sim, SKIFF_SIM=1; FELUCCA_PORT names a sim run with --name): a
/// small song is built on the firmware, read the way Lupe saves a project, exported, then played with SONG ONCE from the
/// top while the firmware's NOTES OUT and MIDI clock are heard. Each note in the file must be one the firmware played,
/// on the same channel, at the same clock pulse (±1: the sim's sequencer runs one audio block ahead of its MIDI OUT).
/// Writes only the sim's flash. T1 and T2's lists are cleared before and after.
///   SKIFF_SIM=1 FELUCCA_PORT="Felucca (export sim)" swift test --filter SkiffMIDIExportSimTests
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct SkiffMIDIExportSimTests {
    final class Heard: @unchecked Sendable {
        let lock = NSLock()
        var pulses: [ContinuousClock.Instant] = []
        var start: ContinuousClock.Instant?
        var notes: [(at: ContinuousClock.Instant, on: Bool, ch: Int, note: Int, vel: Int)] = []
    }

    private func connect() async throws -> (SkiffDriver, MIDITransport) {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return (s, t)
    }

    private func clear(_ d: SkiffDriver, _ tracks: [Int]) async throws {
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        let s = try await d.songLists()
        for t in tracks {
            for i in stride(from: 15, through: 0, by: -1) where !s.tracks[t].entries[i].isEmpty {
                _ = try await d.list(.clear(track: t, entry: i))
            }
        }
    }

    private func step(_ notes: [Int], velocity: Int = 100, accent: Bool = false, tie: Bool = false) -> SynthStep {
        var s = SynthStep.empty
        s.notes = notes; s.time = tie ? .tie : .note; s.velocity = velocity; s.accent = accent
        s.levels = notes.map { _ in 0 }; s.ratchets = notes.map { _ in 0 }
        return s
    }

    /// A new pattern on track t's entry e, played there, these steps and this timing written into it.
    private func pattern(_ d: SkiffDriver, track t: Int, entry e: Int, length: Int, gate: Int, swing: Int,
                         _ steps: [Int: SynthStep]) async throws {
        _ = try await d.list(.new(track: t, entry: e))
        _ = try await d.list(.play(track: t, entry: e))
        try await Task.sleep(for: .milliseconds(100))
        _ = try await d.setTrackParam(track: t, id: Param.length, value: length)
        _ = try await d.setTrackParam(track: t, id: Param.division, value: 2)        // 1/16
        _ = try await d.setTrackParam(track: t, id: Param.division + 1, value: swing) // P_SSWING
        _ = try await d.setTrackParam(track: t, id: Param.division + 2, value: gate)  // P_SGATE
        for (i, s) in steps { _ = try await d.setSynthStep(track: t, index: i, s) }
    }

    @Test func theFileIsWhatTheFirmwarePlays() async throws {
        let (d, transport) = try await connect()
        defer { Task { await d.close() } }
        try await clear(d, [0, 1])

        // T1: A (8 steps, swing 40, a tie, an accent) × 2, then B (4 steps); T2: a REST, then C (8 steps)
        try await pattern(d, track: 0, entry: 0, length: 8, gate: 64, swing: 40,
                          [0: step([60]), 1: step([60], tie: true), 3: step([63], accent: true), 5: step([67], velocity: 70)])
        _ = try await d.list(.reps(track: 0, entry: 0, reps: 2))
        try await pattern(d, track: 0, entry: 1, length: 4, gate: 100, swing: 0, [0: step([72]), 2: step([74, 77])])
        _ = try await d.list(.set(track: 1, entry: 0, pattern: SongEntry.rest))
        try await pattern(d, track: 1, entry: 1, length: 8, gate: 32, swing: 0, [0: step([48]), 4: step([55])])
        _ = try await d.list(.song(.once))
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(300))

        // saved as Lupe saves a project, then exported
        let saved = try await SkiffProjectTransfer.read(firmware: d.info.version, request: SkiffProjectTransfer.request(d))
        let (file, report) = try SkiffMIDIExport.midiFile(saved, name: "sim")
        let expected = file.tracks.flatMap(\.events).compactMap { e -> (pulse: Double, ch: Int, note: Int, vel: Int)? in
            if case .note(let n, let v, _) = e.kind { return (Double(e.tick) / 40, e.channel, n, v) }
            return nil
        }.sorted { ($0.pulse, $0.ch, $0.note) < ($1.pulse, $1.ch, $1.note) }
        print("export:", report, expected.map { "\($0.ch + 1):\($0.note)@\($0.pulse)" })
        #expect(!expected.isEmpty)

        // play it from the top and listen
        let heard = Heard()
        let clockTask = Task.detached {
            for await c in transport.clock {
                let now = ContinuousClock.now
                heard.lock.withLock {
                    if c == .start { heard.start = now; heard.pulses = [] }
                    if c == .tick, heard.start != nil { heard.pulses.append(now) }
                }
            }
        }
        let noteTask = Task.detached {
            for await n in transport.notes {
                let now = ContinuousClock.now
                heard.lock.withLock { heard.notes.append((now, n.on && n.velocity > 0, Int(n.channel), Int(n.note), Int(n.velocity))) }
            }
        }
        try await d.playFromStart()
        try await Task.sleep(for: .seconds(report.seconds + 1.5))
        let state = try await d.transportState()
        _ = try await d.transport(play: false)
        clockTask.cancel(); noteTask.cancel()
        #expect(state?.playing == false, "SONG ONCE stopped at the end by itself")

        let (pulses, start, ons) = heard.lock.withLock { (heard.pulses, heard.start, heard.notes.filter { $0.on && $0.ch < 6 }) }
        try #require(start != nil, "no MIDI Start heard: is the sim's CLOCK OUT on?")
        // a note's pulse: the pulses heard before it (the first pulse is tick 0)
        let played = ons.map { n in (pulse: Double(max(0, pulses.filter { $0 <= n.at }.count - 1)), ch: n.ch, note: n.note, vel: n.vel) }
        print("firmware:", played.map { "\($0.ch + 1):\($0.note)@\($0.pulse)" })
        #expect(played.count == expected.count, "the firmware played \(played.count) notes, the file has \(expected.count)")
        var left = played
        for e in expected {
            if let i = left.firstIndex(where: { $0.ch == e.ch && $0.note == e.note && abs($0.pulse - e.pulse.rounded(.down)) <= 1 }) {
                #expect(left[i].vel == e.vel, "velocity of \(e.ch + 1):\(e.note)@\(e.pulse)")
                left.remove(at: i)
            } else {
                Issue.record("the file has T\(e.ch + 1) note \(e.note) at pulse \(e.pulse); the firmware didn't play it there")
            }
        }
        #expect(left.isEmpty, "the firmware played notes the file hasn't: \(left)")
        try await clear(d, [0, 1])
    }
}

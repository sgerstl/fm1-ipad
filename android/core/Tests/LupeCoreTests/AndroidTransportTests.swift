import Foundation
import SloopKit
import Testing
@testable import AndroidLink

/// AndroidTransport and LinkGate against bytes shaped the way Android delivers them: arbitrary chunks,
/// clock bytes inside frames. The FM-1 side comes from SloopKit's own frames (Frame.encode), not invented.
// every test ends within 3 minutes, so a stuck test fails instead of stalling the run (2026-11-18)
@Suite(.timeLimit(.minutes(3))) struct AndroidTransportTests {
    final class Sent: @unchecked Sendable {
        let lock = NSLock(); var frames: [[UInt8]] = []
        func add(_ f: [UInt8]) { lock.withLock { frames.append(f) } }
    }

    @Test func chunkedBytesBecomeWholeFrames() async {
        let t = AndroidTransport(send: { _ in })
        let a = Frame.encode(Cmd.info, [1, 2, 3])
        let b = Frame.encode(Cmd.get, [4, 5])
        // Split mid-frame, with a clock tick (F8) inside the first frame, as Android's USB reads can.
        var all = a + b
        all.insert(0xF8, at: 3)
        t.receive(Array(all[0..<2]))
        t.receive(Array(all[2..<7]))
        t.receive(Array(all[7...]))
        t.finish()
        var got: [[UInt8]] = []
        for await f in t.frames { got.append(f) }
        #expect(got == [a, b])
        var ticks: [ClockEvent] = []
        for await c in t.clock { ticks.append(c) }
        #expect(ticks == [.tick])
    }

    @Test func notesComeThrough() async {
        let t = AndroidTransport(send: { _ in })
        t.receive([0x90, 60, 100, 0x80, 60, 0])
        t.finish()
        var got: [NoteEvent] = []
        for await n in t.notes { got.append(n) }
        #expect(got == [NoteEvent(on: true, channel: 0, note: 60, velocity: 100), NoteEvent(on: false, channel: 0, note: 60, velocity: 0)])
    }

    @Test func sendGoesOutUntilFinished() {
        let sent = Sent()
        let t = AndroidTransport(send: { sent.add($0) })
        t.send(Frame.encode(Cmd.info))
        t.finish()
        t.send(Frame.encode(Cmd.info))
        #expect(sent.frames == [Frame.encode(Cmd.info)])
    }

    @Test func gateHandsOutEachConnectionOnce() async {
        let gate = LinkGate(send: { _ in })
        #expect(gate.makeTransport() == nil)          // nothing open yet
        gate.opening()
        #expect(gate.state == .opening && gate.makeTransport() == nil)
        gate.readOnly = false
        let first = gate.opened()
        #expect(gate.state == .open)
        #expect(gate.makeTransport() === first)
        #expect(gate.makeTransport() == nil)          // not twice

        gate.lost()                                   // unplugged
        #expect(first.isFinished && gate.state == .none)
        var drained = 0
        for await _ in first.frames { drained += 1 }  // the stream Session reads ends: "lost"
        #expect(drained == 0)

        let second = gate.opened()                    // plugged back in
        #expect(gate.makeTransport() === second)

        gate.readOnly = true                          // the default: the connection comes wrapped in the guard
        gate.opened()
        #expect(gate.makeTransport() is GuardedTransport)
    }

    /// The sleep bug (Scott on the Pixel, 2026-11-18): the Session started over (Retry) while the FM-1 stayed plugged in. The gate's one
    /// connection was already handed out, so the new Session got nothing, for ever. renew() gives it a fresh one over the open ports.
    @Test func renewGivesARestartedSessionAFreshConnection() async {
        let gate = LinkGate(send: { _ in })
        gate.readOnly = false
        gate.renew()                                  // nothing open: nothing to renew
        #expect(gate.makeTransport() == nil)
        let first = gate.opened()
        #expect(gate.makeTransport() === first)
        #expect(gate.makeTransport() == nil)          // the restarted Session's ask, before the fix
        gate.renew()
        #expect(first.isFinished)                     // the old Session's stream ends
        let second = gate.makeTransport()
        #expect(second != nil && second !== first && gate.state == .open)
        gate.hold(true)                               // the installer has it: renew leaves it alone
        gate.renew()
        #expect(gate.makeTransport() == nil)
    }

    /// The same, end to end: a Session restarted over the gate (what Retry does) reaches INFO again with the ports never closed.
    @MainActor @Test func aRestartedSessionReconnectsOverOpenPorts() async throws {
        let sent = Sent()
        let gate = LinkGate(send: { sent.add($0) })
        let session = DeviceSession(transport: { gate.makeTransport() })
        var run = Task { await session.run() }
        gate.opened()
        for _ in 0..<60 where sent.frames.isEmpty { try await Task.sleep(for: .milliseconds(50)) }
        #expect(!sent.frames.isEmpty)
        run.cancel()                                  // Retry: the run starts over
        gate.renew()
        let before = sent.frames.count
        run = Task { await session.run() }
        defer { run.cancel() }
        for _ in 0..<60 where sent.frames.count == before { try await Task.sleep(for: .milliseconds(50)) }
        #expect(sent.frames.dropFirst(before).first.flatMap(Frame.decode)?.cmd == Cmd.info)
    }

    @Test func bytesReachTheOpenConnectionOnly() async {
        let gate = LinkGate(send: { _ in })
        let frame = Frame.encode(Cmd.info, [7])
        frame.withUnsafeBytes { gate.bytes($0) }      // nothing open: dropped
        let t = gate.opened()
        frame.withUnsafeBytes { gate.bytes($0) }
        gate.lost()
        var got: [[UInt8]] = []
        for await f in t.frames { got.append(f) }
        #expect(got == [frame])
    }

    /// The whole path Session uses: a Session over the gate reaches the INFO exchange through AndroidTransport.
    @MainActor @Test func sessionSendsInfoThroughTheGate() async throws {
        let sent = Sent()
        let gate = LinkGate(send: { sent.add($0) })
        let session = DeviceSession(transport: { gate.makeTransport() })
        let run = Task { await session.run() }
        defer { run.cancel() }
        gate.opened()
        for _ in 0..<60 where sent.frames.isEmpty { try await Task.sleep(for: .milliseconds(50)) }
        #expect(sent.frames.first.flatMap(Frame.decode)?.cmd == Cmd.info)
    }
}

import Foundation
import Testing
@testable import SloopKit

/// What skiff-sim answered, recorded by SkiffSimTests (SKIFF_RECORD=1): reply bodies by request.
struct SkiffFixture: Codable {
    var info: [UInt8] = []
    var desc: [String: [UInt8]] = [:]        // "scope.id" (track ids whole, as asked for)
    var names: [String: [UInt8]] = [:]       // engine
    var track: [UInt8] = []
    var trackDump: [String: [UInt8]] = [:]   // track
    var steps: [String: [UInt8]] = [:]       // "track.index": TRACK_STEP's reply
    var dump: [UInt8] = []
    var userList: [UInt8] = []
    var transport: [UInt8] = []

    static func load() throws -> SkiffFixture {
        let url = try #require(Bundle.module.url(forResource: "skiff-2.2", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(SkiffFixture.self, from: Data(contentsOf: url))
    }
}

/// A pretend Skiff 2.2, built on what the sim answered: the recorded INFO, DESC and NAMES as they are, and
/// steps, parameters, the selection and the transport kept as state from the recorded starting point. Like
/// the device, it holds one request at a time: a frame that arrives before the last is answered is dropped.
final class FakeSkiff: SysExTransport, @unchecked Sendable {
    let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    let notes: AsyncStream<NoteEvent>
    let clock: AsyncStream<ClockEvent>
    let clockSink: AsyncStream<ClockEvent>.Continuation
    private let lock = NSLock()
    private let fx: SkiffFixture
    private let pCount: Int, gCount: Int

    var selected = 0
    var playing = false
    var steps: [[[UInt8]]] = []              // [track][index]: the step bytes after track, index
    var params: [[Int]] = []                 // [track][id]
    var globals: [Int] = []
    var engines: [(engine: Int, preset: Int)] = []
    var watching = false
    var busy = false
    var dropped = 0
    var requests: [UInt8] = []               // commands received, in order
    var replyDelay: TimeInterval = 0.002

    init(_ fx: SkiffFixture) {
        self.fx = fx
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self)
        (notes, _) = AsyncStream.makeStream(of: NoteEvent.self)
        (clock, clockSink) = AsyncStream.makeStream(of: ClockEvent.self)
        let info = SkiffInfo(fx.info)!
        pCount = info.paramCount; gCount = info.globalCount
        let tl = try! TrackList(fx.track)
        selected = tl.selected
        for t in 0..<info.trackCount {
            steps.append((0..<info.stepCount).map { Array(fx.steps["\(t).\($0)"]!.dropFirst(2)) })
            var r = ByteReader(fx.trackDump["\(t)"]!)
            _ = try! r.u8(); let e = try! r.u8(), p = try! r.u8()
            engines.append((e, p))
            params.append(try! (0..<pCount).map { _ in try r.v14() })
        }
        var r = ByteReader(fx.dump)
        _ = try! r.u8(); _ = try! r.u8()
        for _ in 0..<pCount { _ = try! r.v14() }
        globals = try! (0..<gCount).map { _ in try r.v14() }
    }

    /// Pushes (CHANGED, STEP_CHANGED, ...) as the device sends them while watched.
    func push(_ cmd: UInt8, _ body: [UInt8]) { if watching { sink.yield(Frame.encode(cmd, body)) } }

    func send(_ frame: [UInt8]) {
        guard let (cmd, a) = Frame.decode(frame) else { return }     // plain MIDI: no reply
        lock.lock()
        if busy { dropped += 1; lock.unlock(); return }               // one incoming frame at a time
        busy = true
        requests.append(cmd)
        let reply = answer(cmd, a)
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + replyDelay) { [self] in
            lock.lock(); busy = false; lock.unlock()
            if let reply { sink.yield(Frame.encode(cmd, reply)) }
        }
    }

    private func v14(_ v: Int) -> [UInt8] { Frame.v14(v) }
    private func id(_ scope: UInt8, _ i: UInt8) -> Int { scope == 2 ? Int(i) + 128 : Int(i) }

    private func trackList() -> [UInt8] {
        var b: [UInt8] = [UInt8(selected), UInt8(steps.count)]
        for t in steps.indices { b += [UInt8(engines[t].engine), UInt8(engines[t].preset)] + v14(params[t][0]) + [UInt8(params[t][40]), 0] }
        return b
    }

    // Called with the lock held.
    private func answer(_ cmd: UInt8, _ a: [UInt8]) -> [UInt8]? {
        switch (cmd, a.count) {
        case (1, 0): return fx.info
        case (5, 2): return fx.desc["\(a[0] == 1 ? 1 : 0).\(a[0] == 1 ? Int(a[1]) : id(a[0], a[1]))"]
        case (10, 1): return fx.names["\(a[0])"]
        case (27, 0): return trackList()
        case (27, 1):
            guard Int(a[0]) < steps.count else { return nil }
            selected = Int(a[0]); return trackList()
        case (30, 2):
            let t = Int(a[0]), i = Int(a[1])
            guard t < steps.count, i < steps[t].count else { return nil }
            return [a[0], a[1]] + steps[t][i]
        case (30, let n) where n >= 10:
            let t = Int(a[0]), i = Int(a[1])
            guard t < steps.count, i < steps[t].count, [10, 13, 14, 15, 18, 19].contains(n) else { return nil }
            var s = steps[t][i], w = Array(a[2...])
            if w.count == 8, s.count > 8 { w += s[8...] }               // the device keeps its own hits, chance, …
            s = w
            steps[t][i] = s
            return [a[0], a[1]] + s
        case (31, 2), (31, 4):
            let t = Int(a[0] & 0x3F), i = Int(a[1]) | Int(a[0] >> 6 & 1) << 7
            guard t < params.count, i < pCount else { return nil }
            if a.count == 4 { params[t][i] = (Int(a[2]) | Int(a[3]) << 7) - 8192 }
            return [a[0], a[1]] + v14(params[t][i])
        case (2, 2) where a[0] == 1: return Int(a[1]) < gCount ? [1, a[1]] + v14(globals[Int(a[1])]) : nil
        case (3, 4) where a[0] == 1:
            guard Int(a[1]) < gCount else { return nil }
            globals[Int(a[1])] = (Int(a[2]) | Int(a[3]) << 7) - 8192
            return [1, a[1]] + v14(globals[Int(a[1])])
        case (4, 0):
            return [UInt8(engines[selected].engine), UInt8(engines[selected].preset)] + params[selected].flatMap(v14) + globals.flatMap(v14)
        case (22, 1): watching = a[0] != 0; return [a[0] & 3]
        case (25, 0): return [0]
        case (16, 2): return a[0] == 0 ? fx.userList : [a[0], 0, fx.userList.count > 2 ? fx.userList[2] : 32]
        case (20, 1): return [a[0], 1]
        case (8, 2):
            engines[selected] = (Int(a[0]), Int(a[1])); return [a[0], a[1]]
        case (76, 0), (76, 1):
            if a.first == 1 { playing = true } else if a.first == 2 { playing = false }
            return [0, playing ? 1 : 0, 0, 0, 0, UInt8(selected)]
        default: return nil                                  // as the device: no reply
        }
    }
}

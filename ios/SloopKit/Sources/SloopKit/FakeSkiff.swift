import Foundation

/// What skiff-sim answered, recorded by SkiffSimTests (SKIFF_RECORD=1): reply bodies by request.
public struct SkiffFixture: Codable, Sendable {
    var info: [UInt8] = []
    var desc: [String: [UInt8]] = [:]        // "scope.id" (track ids whole, as asked for)
    var names: [String: [UInt8]] = [:]       // engine
    var track: [UInt8] = []
    var trackDump: [String: [UInt8]] = [:]   // track
    var steps: [String: [UInt8]] = [:]       // "track.index": TRACK_STEP's reply
    var dump: [UInt8] = []
    var userList: [UInt8] = []
    var transport: [UInt8] = []

    public static func load() throws -> SkiffFixture {
        guard let url = Bundle.module.url(forResource: "skiff-2.2", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(SkiffFixture.self, from: Data(contentsOf: url))
    }
}

/// A pretend Skiff 2.2, built on what the sim answered: the recorded INFO, DESC and NAMES as they are, and
/// steps, parameters, the selection and the transport kept as state from the recorded starting point. Like
/// the device, it holds one request at a time: a frame that arrives before the last is answered is dropped.
/// While playing it sends MIDI clock at its BPM, as Skiff's CLOCK OUT does (`-demo-skiff` in the app).
public final class FakeSkiff: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    public let notes: AsyncStream<NoteEvent>
    public let clock: AsyncStream<ClockEvent>
    let clockSink: AsyncStream<ClockEvent>.Continuation
    private var clockTimer: DispatchSourceTimer?
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
    /// The song: each track's 16 entries (pattern 0 empty, 1...64, 65 REST; REPS byte REPS − 1, 16 on CHAIN;
    /// the entry's sound), the entry each track is on, SONG, and the pool's LENs.
    var lists: [[FakeEntry]] = []
    var entryOn: [Int] = []
    var songMode = 0
    var poolLen = Array(repeating: 0, count: 64)

    /// The sim's answers as recorded; nil if the fixture is missing from the bundle.
    public convenience init?(demo: Bool) {
        guard let fx = try? SkiffFixture.load() else { return nil }
        self.init(fx)
        if demo {
            seedDemo()
            // -demo-song empty | full: the Arrange states (no song; T5's 16 entries and the pool full)
            let a = ProcessInfo.processInfo.arguments
            let which = a.firstIndex(of: "-demo-song").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
            if which != "empty" { seedSong() }
            if which == "full" {
                for i in 0..<16 { lists[4][i] = FakeEntry(p: [65, 12, 13][i % 3], r: 0) }
                poolLen = Array(repeating: 16, count: 64)
            }
        }
    }

    public init(_ fx: SkiffFixture) {
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
        lists = Array(repeating: Array(repeating: FakeEntry(), count: 16), count: info.trackCount)
        entryOn = Array(repeating: 127, count: info.trackCount)
    }

    /// The song on the canvas's board A (vault skiff-arrange-spec.md): six lanes, linked copies, rests,
    /// a chain, an entry with a sound, T3 on 64 steps and T4 on 12.
    func seedSong() {
        func e(_ p: Int, _ reps: Int, chain: Bool = false, sound: (Int, Int) = (0, 0)) -> FakeEntry {
            FakeEntry(p: p, r: chain ? 16 : reps - 1, s0: sound.0, s1: sound.1)
        }
        let R = 65
        let song: [[FakeEntry]] = [
            [e(1, 4), e(2, 8), e(3, 1), e(2, 7), e(3, 1), e(4, 4)],
            [e(R, 4), e(5, 8), e(6, 1, chain: true), e(7, 2), e(5, 8)],
            [e(8, 2), e(9, 1), e(8, 2), e(R, 1)],
            [e(R, 4), e(10, 16), e(11, 8)],
            [e(R, 8), e(12, 4, sound: (3, 2)), e(13, 4), e(12, 4), e(12, 4)],
            [e(14, 16), e(14, 8)],
        ]
        for (t, l) in song.enumerated() where t < lists.count {
            for (i, x) in l.enumerated() { lists[t][i] = x }
            entryOn[t] = 0
        }
        poolLen = (0..<64).map { $0 < 14 ? 16 : 0 }
        poolLen[7] = 64; poolLen[8] = 64; poolLen[9] = 12            // 08, 09 on 64 steps; 10 on 12
        if params.count > 3 { params[2][29] = 64; params[3][29] = 12 }  // LENGTH (id 29): T3's and T4's
        songMode = 1
    }

    private func uses(_ p: Int) -> Int { lists.reduce(0) { $0 + $1.filter { $0.p == p + 1 }.count } }

    private func poolReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        [op, rc] + (0..<64).flatMap { [UInt8(poolLen[$0]), UInt8(min(127, uses($0)))] }
    }

    private func listReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        var b: [UInt8] = [op, rc, UInt8(songMode)]
        for t in lists.indices {
            let on = entryOn[t]
            let pat = on < 16 && lists[t][on].p >= 1 && lists[t][on].p <= 64 ? lists[t][on].p - 1 : 127
            b += [UInt8(on), on < 16 && playing ? UInt8((on + 1) % 16) : 127, UInt8(pat)]
            for x in lists[t] { b += [UInt8(x.p), UInt8(x.r), UInt8(x.s0), UInt8(x.s1)] }
        }
        return b
    }

    private func freePattern(after p: Int = -1) -> Int? {
        let order = Array((p + 1)..<64) + Array(0..<max(0, p + 1))
        return order.first { poolLen[$0] == 0 && uses($0) == 0 }
    }

    /// LIST2's ops, as EDITOR_PROTOCOL.md says the device does them (not every refusal it has).
    private func listOp(_ a: [UInt8]) -> [UInt8]? {
        let op = a[0]
        if op == 6 { guard a.count == 2, a[1] <= 2 else { return nil }; songMode = Int(a[1]); return listReply(6, 0) }
        guard a.count >= 3, Int(a[1]) < lists.count, a[2] < 16 else { return nil }
        let t = Int(a[1]), i = Int(a[2])
        var x = lists[t][i]
        switch op {
        case 1:
            guard a.count == 4, (1...65).contains(a[3]) else { return nil }
            if a[3] != 65 && poolLen[Int(a[3]) - 1] == 0 && uses(Int(a[3]) - 1) == 0 { return listReply(1, 1) }
            x.p = Int(a[3])
        case 2:
            guard (1...64).contains(x.p) else { return listReply(2, 1) }
            guard let n = freePattern(after: x.p - 1) else { return listReply(2, 4) }
            poolLen[n] = poolLen[x.p - 1]; x.p = n + 1
        case 3: entryOn[t] = i; return listReply(3, 0)
        case 4:
            if playing && x.p != 65 { return listReply(4, 3) }
            let old = x.p
            x = FakeEntry()
            lists[t][i] = x
            if (1...64).contains(old) && uses(old - 1) == 0 { poolLen[old - 1] = 0 }
            return listReply(4, 0)
        case 5:
            guard a.count == 4, a[3] <= 16 else { return nil }
            if a[3] == 0 {
                guard x.p != 0, i < 15, lists[t][i + 1].p != 0 else { return listReply(5, 1) }
                x.r = 16
            } else { x.r = Int(a[3]) - 1 }
        case 7:
            guard let n = freePattern() else { return listReply(7, 4) }
            poolLen[n] = max(1, params[t][29]); x.p = n + 1
        case 8:
            guard (1...64).contains(x.p), let to = ((i + 1)..<16).first(where: { lists[t][$0].p == 0 }) else { return listReply(8, 1) }
            guard let n = freePattern(after: x.p - 1) else { return listReply(8, 4) }
            poolLen[n] = poolLen[x.p - 1]
            lists[t][to] = FakeEntry(p: n + 1, r: x.r == 16 ? 0 : x.r, s0: x.s0, s1: x.s1)
            return listReply(8, 0)
        case 9:
            guard a.count == 5, x.p != 0 else { return a.count == 5 ? listReply(9, 1) : nil }
            x.s0 = Int(a[3]); x.s1 = Int(a[4])
        default: return nil
        }
        lists[t][i] = x
        return listReply(op, 0)
    }

    /// Pushes (CHANGED, STEP_CHANGED, ...) as the device sends them while watched.
    func push(_ cmd: UInt8, _ body: [UInt8]) { if watching { sink.yield(Frame.encode(cmd, body)) } }

    deinit { clockTimer?.cancel() }

    /// A few notes on each track and PLAY, so the demo has something to show (the recorded unit is blank).
    private func seedDemo() {
        let roots = [48, 60, 55, 36, 64, 38]
        for t in steps.indices {
            for i in stride(from: 0, to: 16, by: t % 2 == 0 ? 2 : 4) {
                var s = steps[t][i]
                let n = UInt8(roots[t] + (i / 2) % 5 * 2)
                s.replaceSubrange(0..<8, with: [1, n, 0, 0, 0, 0, 0, 100])
                steps[t][i] = s
            }
        }
        setPlaying(true)
    }

    /// PLAY / STOP: Start and 24 pulses a beat at the BPM while playing, Stop after.
    private func setPlaying(_ on: Bool) {
        guard on != playing || (on && clockTimer == nil) else { return }
        playing = on
        clockTimer?.cancel(); clockTimer = nil
        if on {
            clockSink.yield(.start)
            let t = DispatchSource.makeTimerSource(queue: .global())
            let interval = 60.0 / Double(max(40, globals.first ?? 120)) / 24
            t.schedule(deadline: .now() + interval, repeating: interval)
            t.setEventHandler { [weak self] in self?.clockSink.yield(.tick) }
            t.resume()
            clockTimer = t
        } else {
            clockSink.yield(.stop)
        }
    }

    public func send(_ frame: [UInt8]) {
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
        case (82, 0): return listReply(0, 0)
        case (82, _): return listOp(a)
        case (78, 0): return poolReply(0, 0)
        case (78, 1) where a[0] == 3:
            if playing { return poolReply(3, 3) }
            var any = false
            for p in 0..<64 where poolLen[p] > 0 && uses(p) == 0 { poolLen[p] = 0; any = true }
            return poolReply(3, any ? 0 : 1)
        case (76, 0), (76, 1):
            if a.first == 1 { setPlaying(true) } else if a.first == 2 { setPlaying(false) }
            return [0, playing ? 1 : 0, 0, 0, 0, UInt8(selected)]
        default: return nil                                  // as the device: no reply
        }
    }
}

/// One entry of FakeSkiff's lists, as LIST2 sends it.
struct FakeEntry: Equatable {
    var p = 0, r = 0, s0 = 0, s1 = 0
}

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
    /// MENU > USB LEVEL (0 MASTER, 1 FIXED): the one MENU setting the fake offers (MENU_DESC index 0, id 10).
    var usbLevel = 0
    /// Armed tracks, a bit each (song.rec), as TRANSPORT op 4 toggles them: ui_input.c rec_tap.
    var armed = 0
    /// Each track's motion: (step, id, value, lock). An edit is recorded while its track is armed, playing and
    /// selected, as Skiff does (at step 0 here: the fake has no playhead).
    var motion: [[(step: Int, id: Int, value: Int, lock: Bool)]] = Array(repeating: [], count: 8)
    /// Lupe's screen link patch (skiff/README.md): INFO's `56 01 02`, SCREEN, SCREEN_GOTO, WATCH bit 2.
    var screenLink = false
    /// The EDIT engine pages' data (SkiffEdit.swift): each track's FM6 patch, the DRUM-X kit (Skiff's DEEP), the user
    /// sets' mixes (USR1 with four sounds).
    var fm6 = Array(repeating: FakeSkiff.initPatch, count: 8)
    var dxKit: [[Int]] = [[0, 0, 1, 1, 0, 6, 60, 84, 2, 10, 10, 80, 92, 4, 30], [0, 1, 0, 0, 0, 36, 20, 60, 90, 60, 40, 28, 70, 100, 70],
                          [0, 1, 0, 0, 0, 56, 0, 52, 127, 70, 52, 0, 64, 127, 64], [2, 2, 0, 0, 0, 92, 0, 18, 100, 104, 96, 0, 24, 110, 110],
                          [2, 2, 0, 0, 0, 92, 0, 70, 100, 100, 96, 0, 84, 110, 106], [0, 0, 1, 1, 0, 22, 50, 80, 6, 20, 28, 70, 92, 10, 40],
                          [3, 2, 1, 0, 0, 58, 8, 16, 10, 40, 62, 16, 22, 20, 50], [2, 1, 0, 0, 0, 64, 0, 80, 0, 36, 70, 0, 92, 10, 48]]
    var mixZones: [[(Int, Int)]] = [[(36, 47), (48, 59), (60, 71), (72, 96)], [], []]
    var mixValues: [[Int]] = Array(repeating: Array(repeating: 127, count: 16) + Array(repeating: 0, count: 32), count: 3)
    /// FM6's init voice: algorithm 1, operator 1 alone at full output, every envelope at its fullest.
    static let initPatch: FM6Patch = {
        var p = FM6Patch(bytes: Array(repeating: 0, count: 128))
        for n in 1...6 {
            for f: FM6Patch.Op in [.r1, .r2, .r3, .r4, .l1, .l2, .l3] { p.setOp(n, f, 99) }
            p.setOp(n, .coarse, 1); p.setOp(n, .detune, 7); p.setOp(n, .breakPoint, 39)
            p.setOp(n, .output, n == 1 ? 99 : n == 2 ? 70 : 0)
        }
        for f: FM6Patch.Voice in [.pr1, .pr2, .pr3, .pr4] { p[f] = 99 }
        for f: FM6Patch.Voice in [.pl1, .pl2, .pl3, .pl4] { p[f] = 50 }
        p[.transpose] = 24; p[.lfoSpeed] = 35
        for (k, c) in "INIT VOICE".utf8.enumerated() { p.bytes[118 + k] = c }
        return p
    }()
    /// Which build: 2 carries the page's cursor (8-byte SCREEN, SCREEN_GOTO's cursor), 1 the first (6 bytes).
    var screenLinkVersion = 2
    /// The page's cursor, where the page has one (`cursorRange`); reset as a page opens.
    var cursor = 0
    /// The pages with a cursor and its top (skiff/README.md): MOD's routes, the lanes, the samples, USER's slots.
    static let cursorRange: [Int: Int] = [4: 10, 16: 5, 18: 7, 19: 7, 20: 7, 22: 15, 36: 31, 37: 63]
    var screenWatched = false
    /// METER (the screen link's third build, `screenLinkVersion` 3): asked with WATCH bit 3, pushed while playing.
    var meterWatched = false
    private var meterLevels = [Double](repeating: 0, count: 8)
    private var meterTick = 0
    /// home, page, layer, menu, flags (the track is `selected`).
    var screen = (home: true, page: 0, layer: 0, menu: 0, flags: 0)
    /// Pages SCREEN_GOTO refuses as Skiff does for one the track's engine doesn't show (LANES on ANALOG).
    var refusedPages: Set<Int> = [18]
    var poolLen = Array(repeating: 0, count: 64)
    /// USER's 32 slots (engine, name; nil empty) and PROJECT's 4 (nil empty), for the SAVE pages.
    var userSlots: [(engine: Int, name: String)?] = Array(repeating: nil, count: 32)
    var projectSlots: [String?] = ["SONG ONE", nil, nil, nil]
    var musicSlot: Int? = 0
    var projectLoads = 0

    /// The sim's answers as recorded; nil if the fixture is missing from the bundle.
    public convenience init?(demo: Bool) {
        guard let fx = try? SkiffFixture.load() else { return nil }
        self.init(fx)
        if demo {
            seedDemo()
            // -demo-song empty | full: the Arrange states (no song; T5's 16 entries and the pool full)
            let a = ProcessInfo.processInfo.arguments
            screenLink = a.contains("-demo-link")       // the screen link patch, so the button map can be seen
            if a.contains("-demo-link-v1") { screenLinkVersion = 1 }   // the first build: no cursor
            if a.contains("-demo-meter") { screenLinkVersion = 3 }     // the third: METER
            // -demo-track N: track N selected (1…6), -demo-engine E: on engine E (DRUM-X 14, SLICE 13: none in the fixture)
            if let i = a.firstIndex(of: "-demo-track"), a.indices.contains(i + 1), let n = Int(a[i + 1]), (1...steps.count).contains(n) { selected = n - 1 }
            if let i = a.firstIndex(of: "-demo-engine"), a.indices.contains(i + 1), let e = Int(a[i + 1]) { engines[selected].engine = e }
            if a.contains("-demo-usr") { params[selected][138] = 3 }      // SAMPLE on USR1
            // -demo-user-sounds: three of USER's slots hold sounds, and P1 and P2 hold projects (the SAVE pages' screenshots)
            if a.contains("-demo-user-sounds") {
                userSlots[0] = (0, "WARM PAD"); userSlots[1] = (2, "ACID LINE"); userSlots[4] = (0, "GLASS KEYS")
                projectSlots[1] = "LIVE SET"
            }
            // -demo-chord N: the selected track's CHORD (81: 1 DIA3 … 9 POW), for the SEL pages' screenshots
            if let i = a.firstIndex(of: "-demo-chord"), a.indices.contains(i + 1), let c = Int(a[i + 1]) { params[selected][81] = c }
            // -demo-mod-walk: MOD opened on the FM-1, then KNOB 1 walks its routes, a route every 1.5 s
            if a.contains("-demo-mod-walk") {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.pressOnDevice(page: 4)
                    for k in 1...10 {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5 * Double(k)) { self?.turnCursorOnDevice(to: k) }
                    }
                }
            }
            // -demo-turn ID: an encoder turned on the FM-1, one CHANGED every 40 ms for track parameter ID (profiling)
            if let i = a.firstIndex(of: "-demo-turn"), a.indices.contains(i + 1), let id = Int(a[i + 1]) { startTurning(id) }
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

    private func projectReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        [op, rc, UInt8(musicSlot ?? 127), 0] + Array((musicSlot.flatMap { projectSlots[$0] } ?? "").utf8) + [0]
            + projectSlots.flatMap { n -> [UInt8] in [n == nil ? 0 : 1] + Array((n ?? "").utf8) + [0] }
    }

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

    private var turnTimer: DispatchSourceTimer?
    /// A knob turned slowly back and forth on the FM-1: CHANGED for `id` every 40 ms, a step each, 0…127 and back.
    func startTurning(_ id: Int) {
        var v = 0, d = 1
        let t = DispatchSource.makeTimerSource(queue: .global())
        t.schedule(deadline: .now() + 3, repeating: .milliseconds(40))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            v += d; if v >= 127 || v <= 0 { d = -d }
            self.lock.lock(); let sel = self.selected; if id < self.params[sel].count { self.params[sel][id] = v }; self.lock.unlock()
            self.push(Cmd.changed, [0, UInt8(id)] + self.v14(v))
        }
        t.resume()
        turnTimer = t
    }

    /// MOTION's reply (editor.c ed_motion_reply): track, rc, on, count, 64, the records, then their kinds when asked.
    private func motionReply(_ t: Int, rc: UInt8, kinds: Bool) -> [UInt8] {
        let m = motion[t]
        var b: [UInt8] = [UInt8(t), rc, m.isEmpty ? 0 : 1, UInt8(m.count), 64]
        for e in m { b += [UInt8(e.step | (e.id >> 7 & 1) << 6), UInt8(e.id & 127)] + v14(e.value) }
        if kinds { for e in m { b.append(e.lock ? 1 : 0) } }
        return b
    }

    private func mixReply(_ s: Int) -> [UInt8] {
        let z = mixZones[s]
        return [UInt8(s), z.isEmpty ? 1 : 0, UInt8(z.count)] + z.flatMap { [UInt8($0.0), UInt8($0.1)] } + mixValues[s].map { UInt8($0) }
    }

    private func screenBytes() -> [UInt8] {
        let b: [UInt8] = [screen.home ? 1 : 0, UInt8(screen.page), UInt8(screen.layer), UInt8(screen.menu), UInt8(selected), UInt8(screen.flags)]
        guard screenLinkVersion >= 2 else { return b }
        let c: UInt8 = !screen.home && Self.cursorRange[screen.page] != nil ? UInt8(cursor) : 127
        return b + [c, 127]
    }

    /// A button pressed on the FM-1: its screen changes and, watched with bit 2, it says so (cmd 90).
    func pressOnDevice(page: Int?, track: Int? = nil) {
        lock.lock()
        if let page { if page != screen.page || screen.home { cursor = 0 }; screen = (false, page, 0, 0, 0) } else { screen.home = true }
        if let track { selected = track }
        let b = screenBytes(), on = screenWatched
        lock.unlock()
        if on { push(90, b) }
    }

    /// KNOB 1 turned on the FM-1 on a page with a cursor: it moves (clamped) and, watched, it says so.
    func turnCursorOnDevice(to c: Int) {
        lock.lock()
        guard !screen.home, let top = Self.cursorRange[screen.page] else { lock.unlock(); return }
        cursor = max(0, min(top, c))
        let b = screenBytes(), on = screenWatched
        lock.unlock()
        if on { push(90, b) }
    }

    /// A clock tick while playing: each track's level jumps on a step with a note and falls as the FM-1's meter does
    /// (127 / 30 a 16 ms frame); pushed every other tick (about 25 a second at 120 BPM), as editor.c ed_met_tick.
    private func meterStep(_ dt: Double) {
        lock.lock()
        meterTick += 1
        let step = (meterTick / 6) % 16, onStep = meterTick % 6 == 1
        for t in steps.indices where t < meterLevels.count {
            let fall = dt / 0.016 / 30
            meterLevels[t] = max(0, meterLevels[t] - fall)
            if onStep, steps[t][step].first ?? 0 != 0, params[t][40] == 0 { meterLevels[t] = 0.85 }
        }
        let b = meterLevels.prefix(steps.count).map { UInt8(min(127, max(0, Int($0 * 127)))) }
        let on = meterWatched && meterTick % 2 == 0
        lock.unlock()
        if on { push(92, b) }
    }

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
        // T1 with recorded motion (CHORUS turned up across its first bar, as skiff-sim recorded it), so Jib's
        // motion marks show in the demo
        motion[0] = [(2, 34, 40, false), (5, 34, 96, false), (9, 34, 20, false), (12, 34, 70, false), (14, 34, 120, true),
                     (4, 36, 60, false), (10, 36, 10, false)]
        if !ProcessInfo.processInfo.arguments.contains("-demo-stopped") { setPlaying(true) }   // -demo-stopped: idle (CPU)
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
            t.setEventHandler { [weak self] in self?.clockSink.yield(.tick); self?.meterStep(interval) }
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
        case (1, 0): return screenLink ? fx.info + [0x56, 1, UInt8(screenLinkVersion)] : fx.info
        case (90, 0) where screenLink: return screenBytes()
        case (91, 1) where screenLink, (91, 2) where screenLink && screenLinkVersion >= 2:
            // always answered: a refused page (or a cursor for a page or HOME with none) answers the screen unchanged
            let p = Int(a[0])
            if a.count == 2 {
                guard p != 127, let top = Self.cursorRange[p], p < 46, !refusedPages.contains(p) else { return screenBytes() }
                screen = (false, p, 0, 0, 0); cursor = min(top, Int(a[1]))
            } else if p == 127 { screen.home = true; screen.layer = 0; screen.menu = 0 }
            else if p < 46, !refusedPages.contains(p) { if p != screen.page || screen.home { cursor = 0 }; screen = (false, p, 0, 0, 0) }
            return screenBytes()
        case (72, 1):
            // MENU_DESC: index → index, id, kind, value, min, max, … (the rest isn't read); past the list: id 127
            return a[0] == 0 ? [0, UInt8(SkiffMenu.usbLevel), 0] + v14(usbLevel) + v14(0) + v14(1) : [a[0], 127]
        case (73, 3):
            let v = (Int(a[1]) | Int(a[2]) << 7) - 8192
            guard Int(a[0]) == SkiffMenu.usbLevel else { return [1, a[0]] + v14(v) }
            usbLevel = max(0, min(1, v))
            return [0, a[0]] + v14(usbLevel)
        case (5, 2) where a == [2, 10] && engines[selected].engine == 4:
            // SAMPLE's SET: the built-in sets, then the user's (eng_sample.c SMP_ALL_NAMES)
            return [2, 10, 8] + v14(0) + v14(5) + v14(0) + Array("SET".utf8) + [0, 0]
                + ["PIANO", "STRINGS", "CHOIR", "USR1", "USR2", "USR3"].flatMap { Array($0.utf8) + [0] }
        case (68, 2) where a[0] == 0 && Int(a[1]) < fm6.count: return [0, a[1], 0] + fm6[Int(a[1])].bytes
        case (69, 130) where a[0] == 0 && Int(a[1]) < fm6.count:
            fm6[Int(a[1])] = FM6Patch(bytes: Array(a[2...]))
            return [0, a[1], 0]
        case (74, 1) where a[0] < 8: return [a[0]] + dxKit[Int(a[0])].map { UInt8($0) }
        case (75, 16):
            // out of range: no reply, as Skiff
            let hi = [7, 3, 2, 1, 3, 1] + Array(repeating: 127, count: 10)
            guard zip(a, hi).allSatisfy({ Int($0) <= $1 }) else { return nil }
            dxKit[Int(a[0])] = a[1...].map(Int.init)
            return a
        case (81, 1) where a[0] < 3: return mixReply(Int(a[0]))
        case (81, 49) where a[0] < 3:
            let s = Int(a[0])
            if !mixZones[s].isEmpty { mixValues[s] = a[1...].map(Int.init) }
            return mixReply(s)
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
            if a.count == 4 {
                params[t][i] = (Int(a[2]) | Int(a[3]) << 7) - 8192
                if playing, t == selected, armed & (1 << t) != 0 {
                    motion[t].removeAll { $0.step == 0 && $0.id == i && !$0.lock }
                    motion[t].append((0, i, params[t][i], false))
                }
            }
            return [a[0], a[1]] + v14(params[t][i])
        case (2, 2) where a[0] == 1: return Int(a[1]) < gCount ? [1, a[1]] + v14(globals[Int(a[1])]) : nil
        case (3, 4) where a[0] == 1:
            guard Int(a[1]) < gCount else { return nil }
            globals[Int(a[1])] = (Int(a[2]) | Int(a[3]) << 7) - 8192
            return [1, a[1]] + v14(globals[Int(a[1])])
        case (4, 0):
            return [UInt8(engines[selected].engine), UInt8(engines[selected].preset)] + params[selected].flatMap(v14) + globals.flatMap(v14)
        case (22, 1):
            watching = a[0] != 0
            screenWatched = screenLink && a[0] & 4 != 0
            meterWatched = screenLink && screenLinkVersion >= 3 && a[0] & 8 != 0
            return [a[0] & (screenLink ? (screenLinkVersion >= 3 ? 15 : 7) : 3)]
        case (25, 0): return [0]
        case (16, 2):
            // UP_LIST: start, count, total, then per slot used, engine, name
            let st = Int(a[0]), n = min(Int(a[1]), 32 - st)
            return [a[0], UInt8(n), 32] + (st..<(st + n)).flatMap { k -> [UInt8] in
                guard let u = userSlots[k] else { return [0, 0, 0] }
                return [1, UInt8(u.engine)] + Array(u.name.utf8) + [0]
            }
        case (19, _) where a.count >= 2 && Int(a[0]) < 32:
            // UP_STORE: the selected track's sound, under the name (as Skiff, upper case)
            let name = String(decoding: a[1...].prefix { $0 != 0 }, as: UTF8.self).uppercased()
            userSlots[Int(a[0])] = (engines[selected].engine, name)
            return [a[0], 0]
        case (21, 1) where Int(a[0]) < 32:
            userSlots[Int(a[0])] = nil
            return [a[0], 0]
        case (9, 2) where a[0] == 0 && a[1] < 4:
            // PROJECT load: a used slot replaces the music, the transport stopped
            let k = Int(a[1]), used = projectSlots[k] != nil
            if used { setPlaying(false); musicSlot = k; projectLoads += 1 }
            return [0, a[1], used ? 1 : 0]
        case (77, 0): return projectReply(0, 0)
        case (77, _) where a.count >= 2 && a[0] == 1 && a[1] < 4:
            setPlaying(false)
            projectSlots[Int(a[1])] = String(decoding: a[2...].prefix { $0 != 0 }, as: UTF8.self).uppercased()
            musicSlot = Int(a[1])
            return projectReply(1, 0)
        case (78, 2) where a[0] == 1 || a[0] == 2:
            // CLEAR one nothing uses, or EMPTY one (its steps; it stays): stopped only
            let p = Int(a[1])
            // as skiff-sim: nothing there answers 1 before playing is refused
            guard p < 64, poolLen[p] > 0 else { return poolReply(a[0], 1) }
            if playing { return poolReply(a[0], 3) }
            if a[0] == 1 {
                guard uses(p) == 0 else { return poolReply(1, 2) }
                poolLen[p] = 0
            }
            return poolReply(a[0], 0)
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
        case (64, 2) where a[1] == 7:
            return motionReply(Int(a[0]), rc: 0, kinds: true)
        case (64, 6) where a[1] == 3 || a[1] == 5:
            // a recorded change (3) or a lock (5): a new record, or the one on that step and id becomes this
            let t = Int(a[0]), step = Int(a[2] & 63), id = Int(a[3]) | Int(a[2] >> 6 & 1) << 7
            let v = (Int(a[4]) | Int(a[5]) << 7) - 8192
            guard SkiffMotion.recordable(id) else { return motionReply(t, rc: 1, kinds: a[1] == 5) }   // as motion_param
            let total = motion.reduce(0) { $0 + $1.count }
            if let k = motion[t].firstIndex(where: { $0.step == step && $0.id == id }) {
                motion[t][k] = (step, id, v, a[1] == 5)
            } else if total >= 64 {
                return motionReply(t, rc: 2, kinds: a[1] == 5)
            } else {
                motion[t].append((step, id, v, a[1] == 5))
            }
            return motionReply(t, rc: 0, kinds: a[1] == 5)
        case (64, 4) where a[1] == 4:
            let t = Int(a[0]), step = Int(a[2] & 63), id = Int(a[3]) | Int(a[2] >> 6 & 1) << 7
            motion[t].removeAll { $0.step == step && $0.id == id }
            return motionReply(t, rc: 0, kinds: false)
        case (64, 3) where a[1] == 6:
            let t = Int(a[0]), step = Int(a[2])
            motion[t].removeAll { $0.lock && (step >= 64 || $0.step == step) }
            return motionReply(t, rc: 0, kinds: true)
        case (64, 2) where a[1] == 2:
            motion[Int(a[0])] = []
            return [a[0], 0, 0, 0, 64]
        case (76, 0), (76, 1):
            if a.first == 1 { setPlaying(true) } else if a.first == 2 { setPlaying(false) }
            if a.first == 3 { setPlaying(false); setPlaying(true) }      // RESTART: from the top, playing on
            if a.first == 4 {
                // rec_tap: the selected track armed disarms them all; otherwise it's armed too (and a stopped
                // transport starts)
                let bit = 1 << selected
                armed = armed & bit != 0 ? 0 : armed | bit
                if armed & bit != 0, !playing { setPlaying(true) }
            }
            return [0, playing ? 1 : 0, 0, 0, UInt8(armed & 127), UInt8(selected)]
        default: return nil                                  // as the device: no reply
        }
    }
}

/// One entry of FakeSkiff's lists, as LIST2 sends it.
struct FakeEntry: Equatable {
    var p = 0, r = 0, s0 = 0, s1 = 0
}

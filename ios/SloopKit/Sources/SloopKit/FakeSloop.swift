import Foundation

/// A pretend FM-1 on SLOOP 2.8.4, so the app runs without the device. It answers the requests pass 1
/// sends, plays at 108 BPM, and, while watched, now and then edits a step on the selected track or
/// switches tracks and pushes about it, as the real one does.
public final class FakeSloop: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    private let queue = DispatchQueue(label: "FakeSloop")
    private let started = Date()

    public var version = DeviceInfo.expectedVersion
    public var protocolVersion = DeviceInfo.expectedProtocol
    public var autoEdits: Bool
    public var replyDelay: TimeInterval = 0.002

    static let engines = ["ANALOG", "DIGITAL", "PHASE", "LOFI", "SAMPLE", "VOICE", "TRIO", "WHEEL", "GRAIN", "FM6", "PHYS", "NOISE"]
    static let presetNames = ["ANALOG": ["808 BOOM", "SUB BASS", "ACID 303", "REESE", "WARM PAD"],
                              "DIGITAL": ["RHODES", "DX RHODES", "WURLI", "CLAV", "M1 PIANO", "GLASS PAD"],
                              "SAMPLE": ["LOFI KEYS", "TAPE STR", "CHOIR"]]

    var selected = 0
    var engine = [1, 4, 1, 12]
    var preset = [1, 0, 5, 0]
    var params: [[Int]] = Array(repeating: [Int](repeating: 0, count: 71), count: 4)
    var steps: [[SynthStep]] = Array(repeating: Array(repeating: .empty, count: 64), count: 3)
    var drums = Array(repeating: DrumStep.empty, count: 64)
    var bpm = 108, swing = 16, drumLevel = 92
    var playing = true
    var watching = false
    private var editTimer: DispatchSourceTimer?

    public init(autoEdits: Bool = true) {
        self.autoEdits = autoEdits
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self, bufferingPolicy: .unbounded)
        seedPattern()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 3, repeating: 2.5)
        t.setEventHandler { [weak self] in self?.randomEdit() }
        t.resume()
        editTimer = t
    }

    deinit { editTimer?.cancel(); sink.finish() }

    private func seedPattern() {
        for t in 0..<4 {
            params[t][Param.level] = [100, 90, 84, 0][t]
            params[t][Param.root] = 0; params[t][Param.scale] = 2
            params[t][Param.length] = 32; params[t][Param.division] = 2
        }
        let chords: [(Int, [Int], Int)] = [(0, [63, 67, 70], 4), (6, [63, 67, 70], 1), (8, [70, 72, 75, 79], 1),
                                           (12, [70, 72, 75, 79], 1), (15, [63, 67, 70], 1), (18, [67, 70, 74, 77], 1),
                                           (19, [67, 74, 77], 1), (20, [67, 70, 74, 77], 1), (26, [70, 72, 75, 79], 1),
                                           (27, [72, 75, 79], 1), (28, [70, 72, 75, 79], 1), (30, [72, 75, 79], 1)]
        for (i, notes, len) in chords {
            steps[0][i] = SynthStep(notes: notes, time: .note, accent: i == 8, slide: false, velocity: i % 4 == 0 ? 112 : 92)
            for k in 1..<len { steps[0][i + k] = SynthStep(notes: [], time: .tie, accent: false, slide: false, velocity: 100) }
        }
        for i in 0..<32 { steps[1][i] = SynthStep(notes: [36 + [0, 0, 7, 3][i % 4]], time: .note, accent: false, slide: i % 8 == 7, velocity: 100) }
        for i in stride(from: 1, to: 32, by: 2) { steps[2][i] = SynthStep(notes: [72 + [0, 3, 7, 10, 7, 3][i % 6]], time: .note, accent: false, slide: false, velocity: 80) }
        for i in stride(from: 0, to: 32, by: 4) { drums[i].on |= 1 }
        for i in [4, 12, 20, 28] { drums[i].on |= 1 << 3 }
        for i in stride(from: 2, to: 32, by: 4) { drums[i].on |= 1 << 4 }
        drums[30].on |= 1 << 5; drums[30].ratchets |= 1 << 10
    }

    private func now() -> TimeInterval { Date().timeIntervalSince(started) }
    private func stepAt(_ t: Int) -> Int {
        guard playing else { return 0 }
        let beats = Music.divisionBeats[params[t][Param.division]]
        let len = max(1, params[t][Param.length])
        return Int(now() / (60.0 / Double(bpm) * beats)) % len
    }

    private func emit(_ cmd: UInt8, _ body: [UInt8]) {
        let f = Frame.encode(cmd, body)
        queue.asyncAfter(deadline: .now() + replyDelay) { [sink] in sink.yield(f) }
    }

    public func send(_ frame: [UInt8]) {
        queue.async { [self] in handle(frame) }
    }

    private func synthBody(_ s: SynthStep) -> [UInt8] {
        let notes = (0..<4).map { $0 < s.notes.count ? UInt8(s.notes[$0]) : 0 }
        var lvl = 0, rat = 0
        for (k, l) in s.levels.enumerated() { lvl |= l << (2 * k) }
        for (k, r) in s.ratchets.enumerated() { rat |= r << (2 * k) }
        return [UInt8(s.notes.count)] + notes + [UInt8(s.time.rawValue), UInt8((s.accent ? 1 : 0) | (s.slide ? 2 : 0)),
                UInt8(s.velocity), UInt8(lvl & 0x7F), UInt8((lvl >> 7 & 1) | (rat >> 7 & 1) << 1), UInt8(rat & 0x7F)]
    }

    private func bits(_ v: UInt64, _ n: Int) -> [UInt8] { (0..<n).map { UInt8((v >> (7 * UInt64($0))) & 0x7F) } }

    private func handle(_ frame: [UInt8]) {
        guard let (cmd, a) = Frame.decode(frame) else { return }
        switch cmd {
        case Cmd.info:
            var b = Array(version.utf8) + [0, UInt8(Self.engines.count), 71, 50, 64, 63]
            for e in Self.engines { b += Array(e.utf8) + [0] }
            emit(cmd, b + [4, UInt8(protocolVersion)])
        case Cmd.track:
            if let t = a.first { selected = Int(t) }
            var b: [UInt8] = [UInt8(selected), 4]
            for t in 0..<4 { b += [UInt8(engine[t]), UInt8(preset[t])] + Frame.v14(t == 3 ? drumLevel : params[t][0]) + [UInt8(params[t][Param.mute]), 0] }
            emit(cmd, b + [0])
        case Cmd.names:
            let e = Int(a[0]), names = Self.presetNames[Self.engines[e]] ?? (1...8).map { "\(Self.engines[e]) \($0)" }
            var b: [UInt8] = [a[0], UInt8(names.count)]
            for n in names { b += Array(n.utf8) + [0] }
            emit(cmd, b + Array("SOUND".utf8) + [0] + Array("SHAPE".utf8) + [0])
        case Cmd.trackStep:
            let t = Int(a[0]), i = Int(a[1])
            emit(cmd, [a[0], a[1]] + synthBody(t < 3 ? steps[t][i] : .empty))
        case Cmd.drumStep:
            let d = drums[Int(a[0])]
            emit(cmd, [a[0]] + bits(UInt64(d.on), 3) + bits(UInt64(d.levels), 5) + bits(UInt64(d.ratchets), 5))
        case Cmd.trackParam:
            emit(cmd, [a[0], a[1]] + Frame.v14(params[Int(a[0])][Int(a[1])]))
        case Cmd.get:
            let id = Int(a[1])
            emit(cmd, [a[0], a[1]] + Frame.v14(id == Global.bpm ? bpm : id == Global.swing ? swing : id == Global.drumLevel ? drumLevel : 0))
        case Cmd.watch:
            watching = a.first ?? 0 != 0
            emit(cmd, [a.first ?? 0])
        case Cmd.ping:
            emit(cmd, [0])
        case Cmd.live:
            if a.first == 1, a.count > 1 { playing = a[1] != 0 }
            var b: [UInt8] = [a.first ?? 0, playing ? 1 : 0, 0] + Frame.v14(bpm) + [1, 0, 0, 0, 0, 0, 0, UInt8(selected), 0, playing ? 24 : 8, 0, 0, 0, 0, 1]
            for t in 0..<4 { b += [UInt8(stepAt(t)), UInt8(params[t][Param.length]), playing ? 72 : 0] }
            emit(cmd, b + [0, 0] + Array(repeating: 0x48, count: 16))
        default:
            break     // the real device ignores what it doesn't know
        }
    }

    /// An edit "on the device": changes the step, then pushes STEP_CHANGED while watched.
    public func edit(track: Int, index: Int, step: SynthStep) {
        queue.async { [self] in
            if track < 3 { steps[track][index] = step }
            if watching { emit(Cmd.stepChanged, [UInt8(index), UInt8(track)]) }
        }
    }

    private func randomEdit() {
        guard autoEdits, watching else { return }
        if Int.random(in: 0..<6) == 0 {
            selected = (selected + 1) % 4
            emit(Cmd.reload, [UInt8(engine[selected] % 13), UInt8(preset[selected]), UInt8(selected)])
            return
        }
        let i = Int.random(in: 0..<params[selected][Param.length])
        if selected == 3 {
            drums[i].on ^= 1 << UInt16([0, 2, 3, 4].randomElement()!)
        } else if steps[selected][i].isOn {
            steps[selected][i] = .empty
        } else {
            let root = 60 + selected * 12
            steps[selected][i] = SynthStep(notes: [root + [0, 3, 7, 10].randomElement()!], time: .note, accent: false, slide: false, velocity: 100)
        }
        emit(Cmd.stepChanged, [UInt8(i), UInt8(selected)])
    }
}

import Foundation

/// A pretend FM-1 on SLOOP 2.8.4, so the app runs without the device. It answers the requests pass 1
/// sends, plays at 108 BPM, and, while watched, edits a step on the selected track every few
/// seconds and pushes about it, as the real one does. It never switches tracks by itself (that
/// read as the app misbehaving); `switchesTracks` turns that on for tests.
public final class FakeSloop: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    public let notes = AsyncStream<NoteEvent> { _ in }
    private let queue = DispatchQueue(label: "FakeSloop")
    private let started = Date()

    public var version = DeviceInfo.expectedVersion
    public var protocolVersion = DeviceInfo.expectedProtocol
    public var autoEdits: Bool
    public var switchesTracks = false
    public var replyDelay: TimeInterval = 0.002

    static let engines = ["ANALOG", "DIGITAL", "PHASE", "LOFI", "SAMPLE", "VOICE", "TRIO", "WHEEL", "GRAIN", "FM6", "PHYS", "NOISE"]
    static let presetNames = ["ANALOG": ["808 BOOM", "SUB BASS", "ACID 303", "REESE", "WARM PAD"],
                              "DIGITAL": ["RHODES", "DX RHODES", "WURLI", "CLAV", "M1 PIANO", "GLASS PAD"],
                              "SAMPLE": ["LOFI KEYS", "TAPE STR", "CHOIR"]]

    var globals = Array(repeating: 0, count: 50)

    /// A rough stand-in for SLOOP's parameter table (firmware params.c), enough to draw the Sound tab.
    static func trackDesc(_ id: Int) -> (label: String, fmt: Int, min: Int, max: Int, unit: String, names: [String]) {
        let labels = ["LVL", "ATK", "DEC", "SUS", "REL", "FLT", "PIT", "SHP", "TRIM", "RATE", "WAVE", "PHS", "FADE", "PIT", "FLT", "SHP",
                      "AMP", "MODE", "RATE", "OCT", "GATE", "SWG", "PROB", "HOLD", "ORD", "ROOT", "SCL", "QNT", "TRN", "LEN", "DIV",
                      "SWG", "GATE", "DST", "CHO", "DLY", "REV", "VCE", "GLD", "PAN", "MUTE", "GLMOD", "PRIO", "ALLOC", "DTUNE",
                      "SLCR", "PAT", "RATE", "DEPTH", "CHORD", "FILT", "STRUM", "VLEAD", "INSRT", "INS A", "INS B", "INS C", "MIX",
                      "TYPE", "ESYNC", "SYNC", "TRIG", "POL"]
        let enums: [Int: [String]] = [10: ["SINE", "TRI", "SAW", "SQR", "S&H"], 17: ["OFF", "UP", "DOWN", "UPDN", "RAND"],
                                      23: ["OFF", "ON"], 26: Music.scales.map(\.name), 27: ["OFF", "SNAP", "WHITE"],
                                      30: Music.divisionNames, 37: ["POLY", "MONO", "LEGATO", "UNISON"], 40: ["OFF", "ON"],
                                      49: ["OFF", "TRIAD", "7TH", "9TH", "SUS4", "POWER"], 52: ["OFF", "ON"], 59: ["OFF", "ON"]]
        if id >= 63 { return ("E\(id - 62)", 1, 0, 127, "", []) }
        let label = id < labels.count ? labels[id] : "P\(id)"
        if let n = enums[id] { return (label, 8, 0, n.count - 1, "", n) }
        switch id {
        case 5, 6, 7, 13, 14, 15, 39: return (label, 2, -64, 63, "", [])
        case 8: return (label, 0, -64, 63, "", [])
        case 25: return (label, 10, 0, 11, "", [])
        case 28: return (label, 7, -24, 24, "", [])
        case 29: return (label, 13, 1, 64, "", [])
        case 19: return (label, 0, 1, 4, "", [])
        case 21, 31: return (label, 14, 0, 100, "", [])
        case 50: return (label, 15, -64, 63, "", [])
        default: return (label, 1, 0, 127, "", [])
        }
    }

    static func globalDesc(_ id: Int) -> (label: String, fmt: Int, min: Int, max: Int, unit: String, names: [String]) {
        switch id {
        case 0: return ("BPM", 9, 40, 240, "", [])
        case 1: return ("SWING", 14, 0, 100, "", [])
        case 3: return ("TUNE", 0, -50, 50, "", [])
        case 29: return ("FILT", 15, -64, 63, "", [])
        default:
            let labels = [4: "TIME", 5: "FDBK", 6: "COLR", 7: "MIX", 8: "SIZE", 9: "DAMP", 10: "CRT", 11: "CDP", 25: "LVL", 26: "REV",
                          27: "DUST", 28: "DUCK", 32: "DLY", 38: "LEVEL", 39: "TONE", 40: "MOVE"]
            return (labels[id] ?? "G\(id)", 1, 0, 127, "", [])
        }
    }

    static let kits = ["ORIGINAL", "TIGHT", "BOOM", "LOFI", "DUST", "GM KIT", "808", "909", "TAPE", "SYN1"]
    var userPresets: [Int: (engine: Int, name: String)] = [0: (1, "MY RHODES"), 1: (0, "WIDE BASS"), 4: (4, "TAPE CHOIR")]
    var selected = 0
    var engine = [1, 4, 1, 12]
    var preset = [1, 0, 5, 0]
    var params: [[Int]] = Array(repeating: [Int](repeating: 0, count: 71), count: 4)
    var steps: [[SynthStep]] = Array(repeating: Array(repeating: .empty, count: 64), count: 3)
    var drums = Array(repeating: DrumStep.empty, count: 64)
    var bpm = 108, swing = 16, drumLevel = 92
    var playing = true
    var watching = false
    /// The demo behaves like the fm1-ipad firmware: it reports its page (90 UI) and opens pages (91).
    public var hasUIPush = true
    var watchingUI = false
    var uiPage = 5, uiHome = false        // FX, page 1
    var recOn = false

    // The song (as SLOOP: four sections, an order of up to 16 steps, chains, loop / song mode, SONG REC)
    var stored = 0b0111                        // A, B, C hold loops; D is empty
    var sectionPlaying: Int? = 0, sectionQueued: Int?
    var songMode = false, songRec = false
    var chain: [Int] = [], chainAt = 0
    var settings: [UInt8] = {
        var s = [UInt8](repeating: 0, count: 96)
        s[0] = 0x33; s[1] = 0x52; s[2] = 0x45; s[3] = 0x50          // "PER3", little-endian
        return SongOrder(steps: [.init(section: 0, bars: 4), .init(section: 1, bars: 4), .init(section: 0, bars: 4), .init(section: 2, bars: 8)],
                         loop: false).written(into: s)
    }()
    var lastBar = -1, songStep = 0, songBarInStep = 0, recSteps: [SongOrder.Step] = []
    private var bkStaged: [UInt8] = [], bkLen = 0, bkCRC: UInt32 = 0

    var order: SongOrder { SongOrder(settings: settings) ?? .standard }

    /// The song's clock: on every new bar, a queued section starts, a chain moves on, the song steps.
    private func tickSong() {
        guard playing else { lastBar = -1; return }
        let bar = Int(now() / (60.0 / Double(bpm) * 4))
        guard bar != lastBar else { return }
        let first = lastBar < 0
        lastBar = bar
        if first { return }
        if songMode {
            let o = order
            songBarInStep += 1
            if songBarInStep >= o.steps[songStep].bars {
                songBarInStep = 0
                songStep += 1
                if songStep >= o.steps.count { songStep = 0; if !o.loop { playing = false; return } }
            }
            sectionPlaying = o.steps[songStep].section
            return
        }
        if !chain.isEmpty {
            if bar % 2 == 0 { chainAt = (chainAt + 1) % chain.count; sectionPlaying = chain[chainAt] }
        } else if let q = sectionQueued {
            sectionPlaying = q; sectionQueued = nil
        }
        if songRec, let s = sectionPlaying {
            if let last = recSteps.last, last.section == s, recSteps.count > 0 { recSteps[recSteps.count - 1].bars += 1 }
            else if recSteps.count < 16 { recSteps.append(.init(section: s, bars: 1)) }
        }
    }
    private var editTimer: DispatchSourceTimer?

    public init(autoEdits: Bool = true) {
        self.autoEdits = autoEdits
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self, bufferingPolicy: .unbounded)
        seedPattern()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 6, repeating: 6)
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
            for (id, v) in [(1, 10), (2, 70), (3, 90), (4, 60), (9, 60), (20, 64), (22, 127), (32, 64), (34, 24), (35, 40), (36, 52)] {
                params[t][id] = v
            }
            for id in 63..<71 { params[t][id] = 64 }
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
            if a.count >= 10, t < 3 {                     // a write: n, notes, time, flags, vel [, lvl, hi, rat]
                var r = ByteReader(Array(a[2...]))
                if var st = try? SynthStep(reader: &r) {
                    if st.time != .note { st.notes = []; st.levels = []; st.ratchets = [] }
                    steps[t][i] = st
                }
            }
            emit(cmd, [a[0], a[1]] + synthBody(t < 3 ? steps[t][i] : .empty))
        case Cmd.drumStep:
            if a.count >= 14 {
                var r = ByteReader(Array(a[1...]))
                if let on = try? r.bits(3), let lv = try? r.bits(5), let rt = try? r.bits(5) {
                    let d = DrumStep(on: UInt16(truncatingIfNeeded: on), levels: UInt32(truncatingIfNeeded: lv), ratchets: UInt32(truncatingIfNeeded: rt))
                    var clean = DrumStep(on: d.on, levels: 0, ratchets: 0)
                    for l in d.lanes { clean = clean.setting(l, on: true, level: d.level(l), ratchet: d.ratchet(l)) }
                    drums[Int(a[0])] = clean
                }
            }
            let d = drums[Int(a[0])]
            emit(cmd, [a[0]] + bits(UInt64(d.on), 3) + bits(UInt64(d.levels), 5) + bits(UInt64(d.ratchets), 5))
        case Cmd.trackParam:
            let t = Int(a[0]), id = Int(a[1])
            if a.count >= 4 {
                var r = ByteReader(Array(a[2...]))
                if let v = try? r.v14() {
                    let range = id == Param.length ? 1...64 : id == Param.pan ? -64...63 : 0...127
                    params[t][id] = min(max(v, range.lowerBound), range.upperBound)
                }
            }
            emit(cmd, [a[0], a[1]] + Frame.v14(params[t][id]))
        case Cmd.set:
            let id = Int(a[1])
            var r = ByteReader(Array(a[2...]))
            if a[0] == 1, let v = try? r.v14() {
                if id == Global.swing { swing = min(max(v, 0), 100) }
                if id == Global.drumLevel { drumLevel = min(max(v, 0), 127) }
                if id == Global.bpm { bpm = min(max(v, 40), 240) }
            }
            emit(cmd, [a[0], a[1]] + Frame.v14(id == Global.bpm ? bpm : id == Global.swing ? swing : id == Global.drumLevel ? drumLevel : 0))
        case Cmd.get:
            let id = Int(a[1])
            emit(cmd, [a[0], a[1]] + Frame.v14(id == Global.bpm ? bpm : id == Global.swing ? swing : id == Global.drumLevel ? drumLevel : 0))
        case Cmd.preset:
            let e = Int(a[0]), i = Int(a[1])
            if selected < 3, e < Self.engines.count { engine[selected] = e; preset[selected] = i }
            emit(cmd, [UInt8(engine[selected] % 13), UInt8(preset[selected])])
            if watching { emit(Cmd.reload, [UInt8(engine[selected] % 13), UInt8(preset[selected]), UInt8(selected)]) }
        case Cmd.userList:
            let start = Int(a[0]), n = max(0, min(Int(a[1]), 32 - start))
            var b: [UInt8] = [a[0], UInt8(n), 32]
            for slot in start..<(start + n) {
                if let u = userPresets[slot] { b += [1, UInt8(u.engine)] + Array(u.name.utf8) + [0] } else { b += [0, 0, 0] }
            }
            emit(cmd, b)
        case Cmd.userLoad:
            let slot = Int(a[0])
            if selected < 3, let u = userPresets[slot] {
                engine[selected] = u.engine
                emit(cmd, [a[0], 0])
                if watching { emit(Cmd.reload, [UInt8(u.engine), UInt8(preset[selected]), UInt8(selected)]) }
            } else { emit(cmd, [a[0], 1]) }
        case Cmd.desc:
            let scope = a[0], id = Int(a[1])
            if scope == 0, id == 63, selected == 3 {
                var b: [UInt8] = [0, 63, 8] + Frame.v14(0) + Frame.v14(Self.kits.count - 1) + Frame.v14(0) + Array("KIT".utf8) + [0, 0]
                for k in Self.kits { b += Array(k.utf8) + [0] }
                emit(cmd, b)
            } else {
                let d = scope == 0 ? Self.trackDesc(id) : Self.globalDesc(id)
                var b: [UInt8] = [scope, UInt8(id), UInt8(d.fmt)] + Frame.v14(d.min) + Frame.v14(d.max) + Frame.v14(d.min)
                b += Array(d.label.utf8) + [0] + Array(d.unit.utf8) + [0]
                for n in d.names { b += Array(n.utf8) + [0] }
                emit(cmd, b)
            }
        case Cmd.dump:
            var b: [UInt8] = [UInt8(engine[selected] % 13), UInt8(preset[selected])]
            for id in 0..<71 { b += Frame.v14(params[selected][id]) }
            for id in 0..<50 { b += Frame.v14(id == Global.bpm ? bpm : id == Global.swing ? swing : id == Global.drumLevel ? drumLevel : globals[id]) }
            emit(cmd, b)
        case Cmd.ui where hasUIPush:
            emit(cmd, uiBody())
        case Cmd.uiGoto where hasUIPush:
            if let p = a.first { uiPage = Int(p); uiHome = false }
            emit(Cmd.ui, uiBody())
        case Cmd.bkList:
            // rc, count, then per object: id, length (5), CRC-32 (5). Only the settings object here.
            emit(cmd, [0, 1, 1] + Pack7.u35(UInt32(settings.count)) + Pack7.u35(CRC32.of(settings)))
        case Cmd.bkGet:
            let off = Int(Pack7.readU35(a[1...])), n = Int(a[6]) | Int(a[7]) << 7
            let chunk = Array(settings[min(off, settings.count)..<min(off + n, settings.count)])
            emit(cmd, [a[0], 0] + Pack7.u35(UInt32(off)) + [UInt8(n & 127), UInt8(n >> 7)] + Pack7.encode(chunk))
        case Cmd.bkPut:
            let op = Int(a[0]), id = a[1]
            var rc: UInt8 = 1
            if op == 0, a.count == 12 { bkLen = Int(Pack7.readU35(a[2...])); bkCRC = Pack7.readU35(a[7...]); bkStaged = []; rc = 0 }
            else if op == 1 { bkStaged += Pack7.decode(Array(a[7...])); rc = 0 }
            else if op == 2 {
                if songMode && playing { rc = 3 }
                else if bkStaged.count == bkLen, CRC32.of(bkStaged) == bkCRC, SongOrder(settings: bkStaged) != nil { settings = bkStaged; rc = 0 }
                else { rc = 2 }
            }
            emit(cmd, [UInt8(op), id, rc])
        case Cmd.watch:
            watching = a.first ?? 0 != 0
            watchingUI = hasUIPush && (a.first ?? 0) & 4 != 0
            emit(cmd, [a.first ?? 0])
        case Cmd.ping:
            emit(cmd, [0])
        case Cmd.live:
            if a.first == 1, a.count > 1 { playing = a[1] != 0 }
            if a.first == 4 { recOn.toggle() }
            if a.first == 2, a.count >= 4, a[1] == 7, a[3] == 1 { saveLayerKey(Int(a[2])) }
            if a.first == 9, a.count >= 2 {
                let n = Int(a[1])
                chain = n == 0 ? [] : a.dropFirst(2).prefix(n).map { Int($0) }
                chainAt = 0
            }
            tickSong()
            let mutes = UInt8((0..<4).reduce(0) { $0 | (params[$1][Param.mute] != 0 ? 1 << $1 : 0) })   // as editor_live.c
            let songPlays = songMode && playing
            let flags: UInt8 = (playing ? 1 : 0) | (songMode ? 4 : 0) | (songPlays ? 8 : 0) | (songRec ? 64 : 0)
            var b: [UInt8] = [a.first ?? 0, flags, 0] + Frame.v14(bpm)
            b += [UInt8((sectionPlaying ?? -1) + 1), UInt8((sectionQueued ?? -1) + 1), UInt8(chain.count), UInt8(chainAt)]
            b += [mutes, 0, recOn ? UInt8(1 << selected) : 0, UInt8(selected), 0, playing ? 24 : 8]
            b += [UInt8(songStep), UInt8(order.steps.count), UInt8(songBarInStep), UInt8(order.steps[min(songStep, order.steps.count - 1)].bars), UInt8(stored)]
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

    /// SAVE held + a white key (ui_layers.c LY_SONG): 0–3 play / load a section, 4–7 store the loop
    /// (a used section on the second press), 12 loop / song, 13 SONG REC.
    private var armed: (section: Int, at: Date)?
    private func saveLayerKey(_ w: Int) {
        switch w {
        case 0..<4:
            guard stored >> w & 1 == 1, !(songMode && playing) else { return }
            chain = []
            if playing { sectionQueued = w } else { sectionPlaying = w }
        case 4..<8:
            let s = w - 4
            if stored >> s & 1 == 1, !(armed?.section == s && Date().timeIntervalSince(armed!.at) < 3) { armed = (s, Date()); return }
            armed = nil
            stored |= 1 << s
        case 12:
            if !songRec { songMode.toggle(); songStep = 0; songBarInStep = 0 }
        case 13:
            if songRec {
                songRec = false
                if !recSteps.isEmpty { settings = SongOrder(steps: recSteps, loop: false).written(into: settings) }
            } else if !(songMode && playing) {
                songMode = false; songRec = true; recSteps = []
            }
        default: break
        }
    }

    private func uiBody() -> [UInt8] { [uiHome ? 1 : 0, UInt8(uiPage), 0, 0] }

    /// A button pressed "on the device": the page changes, then UI is pushed while watched.
    public func showPage(_ p: Int) {
        queue.async { [self] in
            uiPage = p; uiHome = false
            if watchingUI { emit(Cmd.ui, uiBody()) }
        }
    }

    /// A knob turned "on the device": the value changes, then CHANGED is pushed while watched.
    public func turnKnob(scope: Int, id: Int, to v: Int) {
        queue.async { [self] in
            if scope == 0 { params[selected][id] = v } else if id == Global.swing { swing = v } else { globals[id] = v }
            if watching { emit(Cmd.changed, [UInt8(scope), UInt8(id)] + Frame.v14(v)) }
        }
    }

    private func randomEdit() {
        guard autoEdits, watching else { return }
        if Int.random(in: 0..<3) == 0 {              // now and then a knob turned "on the device" (CHANGED)
            let id = [1, 4, 9, 33, 34, 35, 36, 39].randomElement()!
            let v = id == 39 ? Int.random(in: -40...40) : Int.random(in: 10...120)
            params[selected][id] = v
            emit(Cmd.changed, [0, UInt8(id)] + Frame.v14(v))
            return
        }
        if switchesTracks, Int.random(in: 0..<6) == 0 {
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

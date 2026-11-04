// skiffprobe: talk to Skiff's editor protocol (Felucca's numbering, F0 7D 46 4C cmd ... F7), on an FM-1 or skiff-sim.
// usage: skiffprobe info | desc | clock <secs> | seed | playhead [secs] [scenario...]
// Finds the port by name (skiff-sim's first, then "Felucca"), so other MIDI devices can stay plugged in.
import CoreMIDI
import Foundation

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "info"
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }

var client = MIDIClientRef(); MIDIClientCreate("skiffprobe" as CFString, nil, nil, &client)
var inp = MIDIPortRef(), out = MIDIPortRef()
let lock = NSLock()
var partial: [UInt8] = []
var replies: [UInt8: [UInt8]] = [:]
let got = DispatchSemaphore(value: 0)
var waitingFor: UInt8 = 0xFF
let pushes: Set<UInt8> = [23, 24, 26, 32]
var onPush: (([UInt8]) -> Void)? = nil
var onOther: ((UInt8, UInt8, UInt8) -> Void)? = nil    // status, d1, d2 (realtime: status only)
var onTruth: (([UInt8]) -> Void)? = nil                 // skiff-sim --truth (test-only): each track's playing step
var pktTime: UInt64 = 0                                 // the packet being read: its mach time (the sender's stamp)

func frame(_ bytes: [UInt8]) {
    if bytes.count >= 5, bytes[1] == 0x7D, bytes[2] == 0x53, bytes[3] == 0x4D {
        onTruth?(Array(bytes[4..<(bytes.count - 1)])); return
    }
    guard bytes.count >= 5, bytes[1] == 0x7D, bytes[2] == 0x46, bytes[3] == 0x4C else {
        print("RX other sysex", hex(bytes)); return
    }
    let cmd = bytes[4], body = Array(bytes[5..<(bytes.count - 1)])
    if pushes.contains(cmd) { onPush?([cmd] + body); return }
    lock.lock(); replies[cmd] = body; let w = waitingFor; lock.unlock()
    if cmd == w { got.signal() }
}

var running: [UInt8] = []
MIDIInputPortCreateWithBlock(client, "in" as CFString, &inp) { list, _ in
    for packet in list.unsafeSequence() {
        let len = Int(packet.pointee.length)
        pktTime = packet.pointee.timeStamp != 0 ? packet.pointee.timeStamp : mach_absolute_time()
        let raw = UnsafeRawPointer(packet) + MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
        for b in UnsafeRawBufferPointer(start: raw, count: len) {
            if b >= 0xF8 { onOther?(b, 0, 0); continue }
            if b == 0xF0 { partial = [b]; continue }
            if b == 0xF7, !partial.isEmpty { partial.append(b); frame(partial); partial = []; continue }
            if !partial.isEmpty { partial.append(b); continue }
            if b & 0x80 != 0 { running = [b]; continue }
            guard !running.isEmpty else { continue }
            running.append(b)
            let need = (running[0] & 0xF0 == 0xC0 || running[0] & 0xF0 == 0xD0) ? 2 : 3
            if running.count == need {
                onOther?(running[0], running[1], need == 3 ? running[2] : 0)
                running = [running[0]]
            }
        }
    }
}
MIDIOutputPortCreate(client, "out" as CFString, &out)

func endpointName(_ e: MIDIEndpointRef) -> String {
    var s: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &s)
    return (s?.takeRetainedValue() as String?) ?? ""
}
let srcs = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource)
let dsts = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination)
// skiff-sim's port first: an FM-1 on SLOOP is called Felucca too
func pick(_ es: [MIDIEndpointRef]) -> MIDIEndpointRef? {
    es.first(where: { endpointName($0).localizedCaseInsensitiveContains("skiff") })
        ?? es.first(where: { endpointName($0).localizedCaseInsensitiveContains("felucca") })
}
guard let src = pick(srcs), let dst = pick(dsts) else {
    print("no Felucca port. Sources: \(srcs.map(endpointName)); destinations: \(dsts.map(endpointName))")
    exit(1)
}
MIDIPortConnectSource(inp, src, nil)
print("port: \(endpointName(src))")

func send(_ msg: [UInt8]) {
    let size = 1024
    let buf = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
    defer { buf.deallocate() }
    let pl = buf.bindMemory(to: MIDIPacketList.self, capacity: 1)
    let pk = MIDIPacketListInit(pl)
    _ = MIDIPacketListAdd(pl, size, pk, 0, msg.count, msg)
    MIDISend(out, dst, pl)
}

func request(_ cmd: UInt8, _ a: [UInt8] = [], timeout: Double = 1.0) -> [UInt8]? {
    lock.lock(); replies[cmd] = nil; waitingFor = cmd; lock.unlock()
    send([0xF0, 0x7D, 0x46, 0x4C, cmd] + a + [0xF7])
    if got.wait(timeout: .now() + timeout) == .timedOut { return nil }
    lock.lock(); let r = replies[cmd]; lock.unlock(); return r
}

struct Reader {
    var b: [UInt8]; var i = 0
    mutating func u8() -> Int { defer { i += 1 }; return i < b.count ? Int(b[i]) : -1 }
    mutating func v14() -> Int { let lo = u8(), hi = u8(); return (lo | hi << 7) - 8192 }
    mutating func str() -> String {
        var s: [UInt8] = []; while i < b.count, b[i] != 0 { s.append(b[i]); i += 1 }; i += 1
        return String(decoding: s, as: UTF8.self)
    }
    var left: Int { b.count - i }
}
func v14(_ v: Int) -> [UInt8] { let x = v + 8192; return [UInt8(x & 127), UInt8(x >> 7 & 127)] }

// INFO (1): the counts, the engines, then the tagged capability blocks, each "tag 01 payload"
struct Info {
    var version = "", nEngines = 0, pCount = 0, gCount = 0, nStep = 0, pE0 = 0, nTrk = 0, chainRows = 0
    var engines: [String] = []
    var tags: [(UInt8, [UInt8])] = []
}
// payload bytes after "tag 01", per EDITOR_PROTOCOL.md's INFO row
let tagLen: [UInt8: Int] = [0x55: 1, 0x4D: 2, 0x42: 1, 0x46: 2, 0x53: 1, 0x50: 1, 0x4E: 1, 0x52: 1, 0x4C: 1,
                            0x54: 4, 0x43: 1, 0x4B: 1, 0x57: 1, 0x49: 4, 0x58: 1]
func readInfo() -> Info? {
    guard let b = request(1) else { return nil }
    var r = Reader(b: b), info = Info()
    info.version = r.str()
    info.nEngines = r.u8(); info.pCount = r.u8(); info.gCount = r.u8(); info.nStep = r.u8(); info.pE0 = r.u8()
    info.engines = (0..<info.nEngines).map { _ in r.str() }
    if r.left > 0 { info.nTrk = r.u8() }
    if r.left > 0 { info.chainRows = r.u8() }
    while r.left >= 2 {
        let tag = UInt8(r.u8()); _ = r.u8()
        guard let n = tagLen[tag] else { info.tags.append((tag, Array(b[r.i...]))); break }
        info.tags.append((tag, (0..<n).map { _ in UInt8(max(0, r.u8())) }))
    }
    if let w = info.tags.first(where: { $0.0 == 0x49 })?.1, w.count == 4 {     // wide ids: the whole counts
        info.pCount = Int(w[0]) | Int(w[1]) << 7; info.pE0 = Int(w[2]) | Int(w[3]) << 7
    }
    return info
}

// a track parameter's address on the wire: ids from 128 are scope 2, id - 128 (Skiff 1.3's wide ids)
func addr(_ id: Int) -> [UInt8] { id < 128 ? [0, UInt8(id)] : [2, UInt8(id - 128)] }

struct Desc { var fmt = 0, min = 0, max = 0, def = 0; var label = "", unit = ""; var names: [String] = [] }
func desc(scope: Int, id: Int) -> Desc? {
    let a: [UInt8] = scope == 0 ? addr(id) : [UInt8(scope), UInt8(id)]
    guard let b = request(5, a) else { return nil }
    var r = Reader(b: b); _ = r.u8(); _ = r.u8()
    var d = Desc(); d.fmt = r.u8(); d.min = r.v14(); d.max = r.v14(); d.def = r.v14(); d.label = r.str(); d.unit = r.str()
    if d.fmt == 8 { while r.left > 0 { d.names.append(r.str()) } }
    return d
}
func describe(_ d: Desc) -> String {
    let range = d.fmt == 8 ? d.names.joined(separator: " ") : "\(d.min)..\(d.max)\(d.unit.isEmpty ? "" : " " + d.unit)"
    return "\(d.label) [fmt \(d.fmt)] \(range), default \(d.def)"
}

func transport(_ op: UInt8? = nil) -> (playing: Int, counting: Int, pending: Int, armed: Int, selected: Int)? {
    guard let b = request(76, op.map { [$0] } ?? []) else { return nil }
    var r = Reader(b: b); _ = r.u8()
    return (r.u8(), r.u8(), r.u8(), r.u8(), r.u8())
}

let tagNames: [UInt8: String] = [0x55: "UI caps", 0x4D: "motion", 0x42: "backup", 0x46: "FM6 bank", 0x53: "live sync",
    0x50: "user FM6", 0x4E: "MENU settings", 0x52: "ratchet", 0x4C: "locks", 0x54: "light tracks", 0x43: "FLAM/COND/NUDGE",
    0x4B: "DRUM-X kit", 0x57: "transport/name/pool/list/perform", 0x49: "wide ids", 0x58: "lists 2.0"]

switch mode {
case "info":
    let t0 = Date()
    guard let info = readInfo() else { print("no INFO reply"); exit(1) }
    print(String(format: "INFO in %.0f ms", Date().timeIntervalSince(t0) * 1000))
    print("version: \(info.version)")
    print("engines (\(info.nEngines)): \(info.engines.joined(separator: " "))")
    print("P_COUNT \(info.pCount), P_E0 \(info.pE0), G_COUNT \(info.gCount), NSTEP \(info.nStep), NTRK \(info.nTrk), CHAIN_ROWS \(info.chainRows)")
    for (tag, p) in info.tags { print(String(format: "  tag %02X %@: %@", tag, tagNames[tag] ?? "?", hex(p))) }
    if let b = request(27) {
        var r = Reader(b: b); let sel = r.u8(), n = r.u8()
        print("TRACK: selected T\(sel + 1) of \(n)")
        for k in 0..<n {
            let eng = r.u8(), pre = r.u8(), lvl = r.v14(), mute = r.u8(), armed = r.u8()
            let name = eng >= 0 && eng < info.engines.count ? info.engines[eng] : "#\(eng)"
            print("  T\(k + 1): \(name) preset \(pre), level \(lvl)\(mute == 1 ? ", muted" : "")\(armed == 1 ? ", armed" : "")")
        }
    } else { print("no TRACK reply") }
    for id in [0, 1, info.pE0, info.pE0 + 1] {
        if let d = desc(scope: 0, id: id) { print("DESC \(id): \(describe(d))") } else { print("DESC \(id): no reply") }
    }
    if let t = transport() { print("TRANSPORT: playing \(t.playing), counting in \(t.counting), pending \(t.pending), armed \(t.armed), selected T\(t.selected + 1)") }
    var times: [Double] = []
    for _ in 0..<50 { let s = Date(); if transport() != nil { times.append(Date().timeIntervalSince(s) * 1000) } }
    if !times.isEmpty {
        times.sort()
        print(String(format: "TRANSPORT round trip: median %.1f ms, max %.1f ms (%d of 50)", times[times.count / 2], times.last!, times.count))
    }

case "desc":
    guard let info = readInfo() else { print("no INFO reply"); exit(1) }
    print("\(info.version): \(info.pCount) track parameters (engine block from \(info.pE0)), \(info.gCount) globals")
    for id in 0..<info.pCount {
        if let d = desc(scope: 0, id: id) { print("P \(id): \(describe(d))") } else { print("P \(id): no reply") }
    }
    for id in 0..<info.gCount {
        if let d = desc(scope: 1, id: id) { print("G \(id): \(describe(d))") } else { print("G \(id): no reply") }
    }

case "clock":
    // PLAY, then count what arrives for <secs>: clock ticks, Start / Stop, notes per channel; then STOP
    let secs = args.count > 2 ? Double(args[2]) ?? 4 : 4
    var ticks = 0, starts = 0, stops = 0, firstTick: Date? = nil, lastTick: Date? = nil
    var notesByCh: [Int: Int] = [:]
    let cl = NSLock()
    onOther = { st, _, d2 in
        cl.lock(); defer { cl.unlock() }
        switch st {
        case 0xF8: ticks += 1; if firstTick == nil { firstTick = Date() }; lastTick = Date()
        case 0xFA: starts += 1
        case 0xFC: stops += 1
        default: if st & 0xF0 == 0x90 && d2 > 0 { notesByCh[Int(st & 15) + 1, default: 0] += 1 }
        }
    }
    _ = transport(1)
    Thread.sleep(forTimeInterval: secs)
    _ = transport(2)
    Thread.sleep(forTimeInterval: 0.3)
    cl.lock()
    var bpm = 0.0
    if let a = firstTick, let b = lastTick, ticks > 1 { bpm = Double(ticks - 1) / 24 / b.timeIntervalSince(a) * 60 }
    print("Start \(starts), Stop \(stops), clock ticks \(ticks) (\(String(format: "%.1f", bpm)) BPM from the ticks)")
    print("note-ons by channel: \(notesByCh.sorted { $0.key < $1.key }.map { "ch\($0.key) \($0.value)" }.joined(separator: ", "))")
    cl.unlock()

case "seed":
    // a test pattern on T1: C4 on every 4th of its 16 steps (TRACK_STEP 30: track, index, n, note0..3, time, flags, vel)
    var ok = 0
    for i in 0..<16 {
        let step: [UInt8] = i % 4 == 0 ? [1, 60, 0, 0, 0, 0, 0, 100] : [0, 0, 0, 0, 0, 2, 0, 100]
        if request(30, [0, UInt8(i)] + step) != nil { ok += 1 }
    }
    print("T1: \(ok) of 16 steps written (C4 on 1, 5, 9, 13)")

case "playhead":
    // Can a playhead counted from MIDI clock follow Skiff's sequencer? Each scenario sets BPM and each track's LENGTH,
    // DIV, DIR and SWING (TRACK_PARAM 31), reads them back, writes a distinct note on every step (36 + step, TRACK_STEP
    // 30, so each note-on names its step), PLAYs, counts clock ticks from Start and predicts each track's step. Every
    // note-on is checked against the prediction, and so is skiff-sim --truth's report of the sequencer's own step
    // (a test-only SysEx F0 7D 53 4D s0..s5 F7; an FM-1 sends none). Two predictions:
    //   naive: step n = floor(ticks / T), T = DIV's ticks (1/16: 6), position n mod LEN (RVRS, PING folded)
    //   model: the steps walked as seq.c walks them, each lasting T, swung T * (1 +- SWING / 250) by its position's
    //          parity, LEN / DIV changes taken at the step they land in
    let secs = args.count > 2 ? Double(args[2]) ?? 8 : 8
    let only = Set(args.dropFirst(3))
    var tb = mach_timebase_info_data_t(); mach_timebase_info(&tb)
    func secsOf(_ t: UInt64) -> Double { Double(t) * Double(tb.numer) / Double(tb.denom) / 1e9 }
    let divTicks = [24.0, 12, 6, 3, 8, 4, 48, 96, 192, 384]     // DIV in clock ticks (voice.c DIV_48 / 2)
    let divNames = ["1/4", "1/8", "1/16", "1/32", "8T", "16T", "1/2", "1/1", "2BAR", "4BAR"]
    let dirNames = ["FWD", "RVRS", "PING", "RAND"]
    func tp(_ t: Int, _ id: Int, _ v: Int? = nil) -> Int? {     // TRACK_PARAM: bit 6 of the track byte is id's bit 7
        let a: [UInt8] = [UInt8(t | (id >= 128 ? 0x40 : 0)), UInt8(id & 127)] + (v.map(v14) ?? [])
        guard let b = request(31, a) else { return nil }
        var r = Reader(b: b); _ = r.u8(); _ = r.u8(); return r.v14()
    }
    func getG(_ id: Int) -> Int? {
        guard let b = request(2, [1, UInt8(id)]) else { return nil }
        var r = Reader(b: b); _ = r.u8(); _ = r.u8(); return r.v14()
    }
    func setG(_ id: Int, _ v: Int) { _ = request(3, [1, UInt8(id)] + v14(v)) }
    func naivePos(_ n: Int, _ len: Int, _ dir: Int) -> Int {
        switch dir {
        case 1: return len - 1 - n % len
        case 2: if len < 2 { return 0 }; let c = n % (2 * len - 2); return c < len ? c : 2 * len - 2 - c
        case 3: return -1
        default: return n % len
        }
    }
    struct Trk { var len = 16, div = 2, dir = 0, swing = 0 }
    // halfway through the run: a TRACK_PARAM write (id 29 LENGTH, 30 DIV), or (id -1) LIST PLAY of entry `value`, the
    // second of two patterns set up before PLAY (LIST2 NEW, COPY+, that copy's LENGTH 10 and DIR RVRS), LAUNCH BAR,
    // or (id -2) global BPM to `value`. On its own clock Skiff keeps a track's samples into its step (seq_pos) as they
    // are when BPM changes (midi_clock_pulse rescales them for an external clock only), so the step playing ends
    // early on a faster tempo, late on a slower one: e ticks into a step of T, it lasts e + T - e * new / old ticks,
    // (from the step's start: less than e when that has passed), and every track's grid stays shifted from the
    // clock's by e * (1 - new / old) after it
    struct Change { var track: Int, id: Int, value: Int }
    // the sequencer runs ahead of its MIDI OUT by the audio block being rendered (skiff-sim: ~6 ms, measured from
    // --truth); a write lands in the sequencer's time, so the model moves it on by that much
    let seqLead = 0.006
    struct Scenario { var name: String, bpm: Int, gswing = 0, tracks: [Trk], nudge: [Int: Int] = [:], change: Change? = nil }
    let mixA: [Trk] = [Trk(len: 16, div: 2, dir: 0), Trk(len: 12, div: 1, dir: 1), Trk(len: 7, div: 4, dir: 2),
                       Trk(len: 5, div: 5, dir: 0), Trk(len: 16, div: 2, dir: 2), Trk(len: 3, div: 3, dir: 1)]
    let mixB: [Trk] = [Trk(len: 12, div: 4, dir: 1), Trk(len: 7, div: 2, dir: 2), Trk(len: 16, div: 1, dir: 0),
                       Trk(len: 1, div: 2, dir: 2), Trk(len: 2, div: 2, dir: 2), Trk(len: 64, div: 3, dir: 0)]
    var swung = mixA; swung[0].swing = 50; swung[1].swing = 25; swung[2].swing = 30
    var rand = mixA; rand[0].dir = 3
    var scenarios: [Scenario] = [
        Scenario(name: "a90", bpm: 90, tracks: mixA), Scenario(name: "a150", bpm: 150, tracks: mixA),
        Scenario(name: "b90", bpm: 90, tracks: mixB), Scenario(name: "b137", bpm: 137, tracks: mixB),
        Scenario(name: "swing", bpm: 120, gswing: 20, tracks: swung),
        Scenario(name: "nudge", bpm: 120, tracks: mixA, nudge: [1: 16, 2: -16, 3: 31, 5: -32, 9: -1]),
        Scenario(name: "rand", bpm: 120, tracks: rand),
        Scenario(name: "len", bpm: 120, tracks: mixA, change: Change(track: 0, id: 29, value: 12)),
        Scenario(name: "div", bpm: 120, tracks: mixA, change: Change(track: 0, id: 30, value: 1)),
        Scenario(name: "launch", bpm: 120, tracks: mixA, change: Change(track: 0, id: -1, value: 1)),
        Scenario(name: "tempo", bpm: 90, tracks: mixA, change: Change(track: 0, id: -2, value: 150)),
        Scenario(name: "slower", bpm: 150, tracks: mixA, change: Change(track: 0, id: -2, value: 90)),
    ]
    if !only.isEmpty { scenarios = scenarios.filter { only.contains($0.name) } }

    // the tracks play their steps as notes: DRUM / DRUM-X tracks (hits, lane notes) become ANALOG (G 20 ENGINE)
    if let b = request(27) {
        var r = Reader(b: b); let sel = r.u8(), n = r.u8()
        var drums: [Int] = []
        for k in 0..<n { let eng = r.u8(); _ = r.u8(); _ = r.v14(); _ = r.u8(); _ = r.u8(); if eng == 10 || eng == 14 { drums.append(k) } }
        for k in drums { _ = request(27, [UInt8(k)]); setG(20, 0) }
        if !drums.isEmpty { _ = request(27, [UInt8(max(0, sel))]); print("T\(drums.map { String($0 + 1) }.joined(separator: ", T")): DRUM -> ANALOG") }
    }

    struct Ev { var k: Int; var f: Double; var ch: Int; var note: Int }
    let el = NSLock()
    var notes: [Ev] = [], truths: [(f: Double, s: [UInt8])] = [], count = -1, lastTick: UInt64 = 0, tickDur = 0.02
    var starts = 0, firstTick: UInt64 = 0
    onOther = { st, d1, d2 in
        el.lock(); defer { el.unlock() }
        switch st {
        case 0xFA: count = 0; starts += 1
        case 0xF8: if count >= 0 { count += 1; lastTick = pktTime; if count == 1 { firstTick = pktTime } }
        default:
            guard st & 0xF0 == 0x90, d2 > 0, count >= 0 else { return }
            let frac = count == 0 ? -0.01 : pktTime > lastTick ? min(0.999, secsOf(pktTime - lastTick) / tickDur) : 0
            notes.append(Ev(k: count - 1, f: Double(max(0, count - 1)) + frac, ch: Int(st & 15), note: Int(d1)))
        }
    }
    onTruth = { s in
        el.lock(); defer { el.unlock() }
        guard count > 0 else { return }
        let frac = pktTime > lastTick ? min(0.999, secsOf(pktTime - lastTick) / tickDur) : 0
        truths.append((Double(count - 1) + frac, s))
    }

    for sc in scenarios {
        _ = transport(2); Thread.sleep(forTimeInterval: 0.2)
        setG(0, sc.bpm); setG(1, sc.gswing)
        let bpm = getG(0) ?? sc.bpm, gsw = getG(1) ?? sc.gswing
        var cfg: [Trk] = []
        for (t, c) in sc.tracks.enumerated() {
            _ = tp(t, 29, c.len); _ = tp(t, 30, c.div); _ = tp(t, 91, c.dir); _ = tp(t, 31, c.swing)
            cfg.append(Trk(len: tp(t, 29) ?? -1, div: tp(t, 30) ?? -1, dir: tp(t, 91) ?? -1, swing: tp(t, 31) ?? -1))
        }
        // every step a note of its own (36 + step), full length so the old bytes go: hits 0, chance 100, ratchet 1,
        // FLAM 0, COND 0, NUDGE + 32
        var written = 0
        for t in 0..<cfg.count {
            for i in 0..<64 {
                let nudge = t == 0 ? sc.nudge[i] ?? 0 : 0
                if request(30, [UInt8(t), UInt8(i), 1, UInt8(36 + i), 0, 0, 0, 0, 0, 100, 0, 0, 0, 100, 1, 0, 0, UInt8(32 + nudge)]) != nil { written += 1 }
            }
        }
        var launchTo: (len: Int, dir: Int)? = nil
        if let ch = sc.change, ch.id == -1 {
            // T1 on a new pattern (entry 0) holding the steps; COPY+ to entry 1; entry 1 at once (stopped) to give it
            // LENGTH 10 and DIR RVRS; back to entry 0, whose LENGTH and DIR should be as before
            func list(_ a: [UInt8]) -> Int { request(82, a).map { $0.count > 1 ? Int($0[1]) : -1 } ?? -2 }
            var rcs = [list([7, 0, 0])]
            for i in 0..<64 { _ = request(30, [0, UInt8(i), 1, UInt8(36 + i), 0, 0, 0, 0, 0, 100, 0, 0, 0, 100, 1, 0, 0, 32]) }
            _ = tp(0, 29, cfg[0].len); _ = tp(0, 91, cfg[0].dir)
            rcs.append(list([8, 0, 0])); rcs.append(list([3, 0, 1]))
            _ = tp(0, 29, 10); _ = tp(0, 91, 1)
            rcs.append(list([3, 0, 0]))
            launchTo = (10, 1)
            _ = request(80, [5, 1])                                 // PERFORM LAUNCH BAR
            print("\n   launch setup: LIST2 rc \(rcs) (NEW, COPY+, PLAY 1, PLAY 0); T1 back on entry 0: LENGTH \(tp(0, 29) ?? -1), DIR \(tp(0, 91) ?? -1)")
        }
        el.lock(); notes = []; truths = []; count = -1; starts = 0; tickDur = 60.0 / (Double(bpm) * 24); el.unlock()
        _ = transport(1)
        var changeTick: Double? = nil
        if let ch = sc.change {
            Thread.sleep(forTimeInterval: secs / 2 + 0.07)         // (off the bar line)
            el.lock(); let k = Double(count - 1) + min(0.999, secsOf(mach_absolute_time() - lastTick) / tickDur); el.unlock()
            if ch.id == -1 { _ = request(82, [3, UInt8(ch.track), UInt8(ch.value)]) }
            else if ch.id == -2 { setG(0, ch.value); el.lock(); tickDur = 60.0 / (Double(ch.value) * 24); el.unlock() }
            else { _ = tp(ch.track, ch.id, ch.value) }
            changeTick = k
            Thread.sleep(forTimeInterval: secs / 2)
        } else {
            Thread.sleep(forTimeInterval: secs)
        }
        _ = transport(2); Thread.sleep(forTimeInterval: 0.3)
        el.lock(); let ns = notes, ts = truths, total = count, st = starts, t0 = firstTick, t1 = lastTick; el.unlock()
        let measured = total > 1 ? Double(total - 1) / 24 / secsOf(t1 - t0) * 60 : 0
        print("\n== \(sc.name): BPM \(bpm), SWING+ \(gsw)\(sc.nudge.isEmpty ? "" : ", T1 NUDGE \(sc.nudge.sorted { $0.key < $1.key }.map { "s\($0.key + 1) \($0.value)" }.joined(separator: " "))")\(sc.change.map { ($0.id == -2 ? ", BPM -> \($0.value)" : ", T\($0.track + 1) \($0.id < 0 ? "LIST PLAY entry" : "P\($0.id) ->") \($0.value + ($0.id < 0 ? 1 : 0))") + " at tick \(String(format: "%.1f", changeTick ?? -1))" } ?? "")")
        print("   Start \(st), \(total) ticks (\(String(format: "%.2f", measured)) BPM), \(ns.count) note-ons, \(ts.count) truth reports, \(written) steps written")

        for (t, c) in cfg.enumerated() {
            // model: walk the steps as seq.c does (seq_tick / seq_next), in ticks
            var len = c.len, T = divTicks[max(0, c.div) % 10], idx = len - 1, cnt = 0, down = false, dir = c.dir
            var startsAt: [Double] = [], idxs: [Int] = [], at = 0.0
            var pendingChange = sc.change?.track == t || sc.change?.id == -2 ? sc.change : nil   // (BPM: every track)
            while at <= Double(total) + 400 {
                if let ch = pendingChange, let kc0 = changeTick {
                    let kc = kc0 + seqLead / tickDur                    // (in the sequencer's time)
                    if ch.id == -1, let to = launchTo, at >= ceil(kc / 96) * 96 {   // BAR: the first step on the next
                        len = to.len; dir = to.dir; cnt = 0; idx = len - 1           // bar from Start, a new pass
                        pendingChange = nil
                    } else if ch.id == -2, at > kc, let s = startsAt.last {
                        // (past already: the next step plays now, its time kept from there: seq_tick carries seq_pos over)
                        at = max(s, kc + T - (kc - s) * Double(ch.value) / Double(bpm))
                        pendingChange = nil
                    } else if ch.id >= 0, at > kc {                    // a change lands at the next boundary..
                        if ch.id == 29 { len = ch.value } else if ch.id == 30 { T = divTicks[ch.value] }
                        if ch.id == 30, let s = startsAt.last { at = max(kc, s + T) }   // .. DIV stretches or cuts the step
                        pendingChange = nil
                    }
                }
                let ln = max(1, len)
                if dir == 3 { idx = -1 }
                else if cnt == 0 && dir != 0 { down = false; idx = dir == 1 ? ln - 1 : 0 }
                else {
                    let i = idx < ln ? idx : ln - 1
                    var n: Int
                    switch dir {
                    case 1: n = i > 0 ? i - 1 : ln - 1
                    case 2: n = ln < 2 ? 0 : down ? (i > 0 ? i - 1 : 1) : (i + 1 < ln ? i + 1 : ln - 2)
                            down = n < i
                    default: n = (idx + 1) % ln
                    }
                    idx = n
                }
                if dir == 0 ? idx == 0 : (cnt == 0 || cnt >= ln) { cnt = 0 }
                cnt += 1
                startsAt.append(at); idxs.append(idx)
                let sw = Double(min(100, max(0, c.swing + gsw)))
                at += T * (1 + (idx >= 0 && idx & 1 == 1 ? -sw : sw) / 250)
            }
            func model(_ f: Double) -> (n: Int, idx: Int, start: Double) {
                var lo = 0, hi = startsAt.count - 1
                while lo < hi { let m = (lo + hi + 1) / 2; if startsAt[m] <= f { lo = m } else { hi = m - 1 } }
                return (lo, idxs[lo], startsAt[lo])
            }
            let T0 = divTicks[max(0, c.div) % 10]
            func naive(_ f: Double) -> Int {
                let n = Int(floor(f / T0))
                if let ch = sc.change, ch.track == t, ch.id == 29, let kc = changeTick, f > kc { return naivePos(n, ch.value, c.dir) }
                if let ch = sc.change, ch.track == t, ch.id == -1, let to = launchTo, let kc = changeTick, f > kc { return naivePos(n, to.len, to.dir) }
                return naivePos(n, c.len, c.dir)
            }
            // the notes: 0.5 tick of tolerance (a note can arrive just before its tick)
            var nn = 0, okM = 0, okN = 0, worst = 0.0, worstN = 0.0, misses: [String] = []
            for e in ns where e.ch == t {
                nn += 1
                let m = model(e.f + 0.5), got = e.note - 36
                if got == m.idx { okM += 1; worst = max(worst, abs(e.f - m.start)) }
                else if misses.count < 3 { misses.append("tick \(e.k): step \(got + 1), model \(m.idx + 1)") }
                if got == naive(e.f + 0.5) { okN += 1; worstN = max(worstN, abs(e.f - floor((e.f + 0.5) / T0) * T0)) }
            }
            // the sequencer's own step at each report, at the clock position it came with; where it differs, how far
            // ahead (in ticks) the model has the step it reports: the sequencer runs ahead of its MIDI OUT by the audio
            // block it renders before that block plays (mo.tick)
            var tn = 0, tM = 0, tM1 = 0, tN = 0, lead = 0.0, over = 0, tX = 0
            for (f, s) in ts where t < s.count {
                tn += 1
                let got = Int(s[t])
                if got == model(f).idx { tM += 1 }
                else if let d = stride(from: 0.01, through: 1.0, by: 0.01).first(where: { model(f + $0).idx == got }) { tM1 += 1; lead = max(lead, d); if d > 0.5 { over += 1 } }
                else { tX += 1 }
                if got == naive(f) { tN += 1 }
            }
            if t == 0, ProcessInfo.processInfo.environment["PLAYHEAD_DEBUG"] != nil, let kc = changeTick {   // around the change
                for e in ns where e.ch == 0 && abs(e.f - kc) < 40 { print(String(format: "      note  f %7.2f step %d", e.f, e.note - 35)) }
                for (f, s) in ts where abs(f - kc) < 40 { print(String(format: "      truth f %7.2f step %d", f, Int(s[0]) + 1)) }
            }
            func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "  -  " : String(format: "%5.1f%%", 100.0 * Double(a) / Double(b)) }
            let swing = min(100, c.swing + gsw)
            print(String(format: "   T%d L%-2d %-4@ %-4@ sw%-3d notes %4d: model %@ naive %@, drift %.2f / %.2f tick; truth %4d: model %@ (+%d <= %.2f tick / %.1f ms ahead, %d over 0.5; %d off) naive %@",
                         t + 1, c.len, divNames[max(0, c.div) % 10] as NSString, dirNames[max(0, c.dir) % 4] as NSString, swing,
                         nn, pct(okM, nn), pct(okN, nn), worst, worstN, tn, pct(tM, tn), tM1, lead, lead * 60000 / (Double(bpm) * 24), over, tX, pct(tN, tn)))
            if !misses.isEmpty && okM < nn { print("        misses: \(misses.joined(separator: "; "))") }
        }
    }
    _ = transport(2)
    setG(1, 0)

default:
    print("usage: skiffprobe info | desc | clock <secs> | seed | playhead [secs] [scenario...]")
}

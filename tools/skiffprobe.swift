// skiffprobe: talk to Skiff's editor protocol (Felucca's numbering, F0 7D 46 4C cmd ... F7), on an FM-1 or skiff-sim.
// usage: skiffprobe info | desc | clock <secs> | seed
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

func frame(_ bytes: [UInt8]) {
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

default:
    print("usage: skiffprobe info | desc | clock <secs> | seed")
}

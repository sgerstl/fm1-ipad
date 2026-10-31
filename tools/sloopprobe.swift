// sloopprobe: talk to SLOOP's editor protocol (F0 7D 46 4C cmd ... F7).
// usage: sloopprobe info | sloopprobe watch <secs>
import CoreMIDI
import Foundation

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "info"
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }

var client = MIDIClientRef(); MIDIClientCreate("sloopprobe" as CFString, nil, nil, &client)
var inp = MIDIPortRef(), out = MIDIPortRef()
let lock = NSLock()
var partial: [UInt8] = []
var replies: [UInt8: [UInt8]] = [:]
let got = DispatchSemaphore(value: 0)
var waitingFor: UInt8 = 0xFF
let pushes: Set<UInt8> = [23, 24, 26, 32]
var onPush: (([UInt8]) -> Void)? = nil
var notes = 0

func frame(_ bytes: [UInt8]) {
    guard bytes.count >= 5, bytes[1] == 0x7D, bytes[2] == 0x46, bytes[3] == 0x4C else {
        print("RX other sysex", hex(bytes)); return
    }
    let cmd = bytes[4], body = Array(bytes[5..<(bytes.count - 1)])
    if pushes.contains(cmd) { onPush?([cmd] + body); return }
    lock.lock(); replies[cmd] = body; let w = waitingFor; lock.unlock()
    if cmd == w { got.signal() }
}

MIDIInputPortCreateWithBlock(client, "in" as CFString, &inp) { list, _ in
    for packet in list.unsafeSequence() {
        let len = Int(packet.pointee.length)
        let raw = UnsafeRawPointer(packet) + MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
        for b in UnsafeRawBufferPointer(start: raw, count: len) {
            if b == 0xF0 { partial = [b] }
            else if b == 0xF7, !partial.isEmpty { partial.append(b); frame(partial); partial = [] }
            else if b >= 0xF8 { continue }
            else if !partial.isEmpty { partial.append(b) }
            else if b & 0xF0 == 0x90 { notes += 1 }
        }
    }
}
MIDIOutputPortCreate(client, "out" as CFString, &out)
let src = MIDIGetSource(0), dst = MIDIGetDestination(0)
MIDIPortConnectSource(inp, src, nil)

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
func bits(_ b: [UInt8]) -> Int { b.enumerated().reduce(0) { $0 | Int($1.element) << (7 * $1.offset) } }
let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
func nn(_ n: Int) -> String { "\(noteNames[n % 12])\(n / 12 - 1)" }

print("source: \(src != 0 ? "ok" : "none")  dest: \(dst != 0 ? "ok" : "none")")

func liveLine(_ r: [UInt8]) -> String {
    var s = Reader(b: r); _ = s.u8()
    let f = s.u8(); _ = s.u8(); let bpm = s.v14()
    let sec = s.u8(); _ = s.u8(); _ = s.u8(); _ = s.u8()
    let mutes = s.u8(); _ = s.u8(); _ = s.u8(); let sel = s.u8(); _ = s.u8(); let cpu = s.u8()
    for _ in 0..<5 { _ = s.u8() }
    var tr: [String] = []
    for _ in 0..<4 { let st = s.u8(), ln = s.u8(), m = s.u8(); tr.append("\(st)/\(ln)" + (m > 0 ? "*" : "")) }
    return "playing=\(f & 1) bpm=\(bpm) section=\(sec) mutes=\(mutes) selected=T\(sel + 1) cpu=\(cpu)% steps " + tr.joined(separator: " ") + "  (\(r.count) bytes)"
}

if mode == "info" {
    guard let info = request(1) else { print("INFO: no reply"); exit(1) }
    var r = Reader(b: info)
    let ver = r.str(), ne = r.u8(), pc = r.u8(), gc = r.u8(), ns = r.u8(), pe0 = r.u8()
    var engines: [String] = []; for _ in 0..<ne { engines.append(r.str()) }
    let ntrk = r.u8(), proto = r.u8()
    print("INFO  version=\(ver) engines=\(ne) P_COUNT=\(pc) G_COUNT=\(gc) NSTEP=\(ns) P_E0=\(pe0) tracks=\(ntrk) protocol=v\(proto)")
    print("      engines: \(engines.joined(separator: ", "))")

    guard let t = request(27) else { print("TRACK: no reply"); exit(1) }
    var tr = Reader(b: t)
    let sel = tr.u8(), n = tr.u8()
    var trackEngines: [Int] = []
    print("TRACK selected=T\(sel + 1)")
    for k in 0..<n {
        let e = tr.u8(), p = tr.u8(), lvl = tr.v14(), mute = tr.u8(), armed = tr.u8()
        trackEngines.append(e)
        print("      T\(k + 1): engine=\(e < engines.count ? engines[e] : "DRUMS") preset=\(p) level=\(lvl) mute=\(mute) armed=\(armed)")
    }

    for e in Set(trackEngines.filter { $0 < ne }).sorted() {
        guard let nm = request(10, [UInt8(e)]) else { print("NAMES \(engines[e]): no reply"); continue }
        var r2 = Reader(b: nm); _ = r2.u8(); let c = r2.u8()
        var names: [String] = []; for _ in 0..<c { names.append(r2.str()) }
        print("NAMES \(engines[e]) (\(c)): \(names.prefix(12).joined(separator: ", "))\(c > 12 ? ", ..." : "")")
    }

    for k in 0..<3 {
        var cells: [String] = []
        for i in 0..<16 {
            guard let st = request(30, [UInt8(k), UInt8(i)]) else { cells.append("??"); continue }
            var s = Reader(b: st); _ = s.u8(); _ = s.u8()
            let cnt = s.u8(); let ns4 = (0..<4).map { _ in s.u8() }; let time = s.u8()
            cells.append(cnt == 0 ? (time == 1 ? "~" : ".") : ns4.prefix(cnt).map(nn).joined(separator: "+"))
        }
        print("T\(k + 1) steps 1-16: \(cells.joined(separator: " "))")
    }
    var rows = Array(repeating: "", count: 16)
    for i in 0..<16 {
        guard let d = request(33, [UInt8(i)]) else { for l in 0..<16 { rows[l] += "?" }; continue }
        let on = bits(Array(d[1..<4]))
        for l in 0..<16 { rows[l] += (on >> l) & 1 == 1 ? "x" : "." }
    }
    print("DRUMS steps 1-16 (lane: hits)")
    for l in 0..<16 where rows[l].contains("x") { print(String(format: "      lane %2d: ", l + 1) + rows[l]) }
    if !rows.contains(where: { $0.contains("x") }) { print("      (no hits in steps 1-16)") }

    if let live = request(77, [0]) { print("LIVE  " + liveLine(live)) } else { print("LIVE: no reply") }
} else if mode == "watch" {
    let secs = args.count > 2 ? Double(args[2]) ?? 30 : 30
    onPush = { p in
        var r = Reader(b: Array(p.dropFirst()))
        let t = String(format: "%.2f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
        switch p[0] {
        case 23: let sc = r.u8(), id = r.u8(), v = r.v14(); print("\(t) CHANGED \(sc == 0 ? "track" : "global") param \(id) = \(v)")
        case 24: let e = r.u8(), pr = r.u8(), tk = r.u8(); print("\(t) RELOAD engine=\(e) preset=\(pr) track=T\(tk + 1)")
        case 26: let i = r.u8(), tk = r.u8(); print("\(t) STEP_CHANGED step \(i + 1) on T\(tk + 1)")
        case 32: let tk = r.u8(), id = r.u8(), v = r.v14(); print("\(t) TRACK_CHANGED T\(tk + 1) param \(id) = \(v)")
        default: print("\(t) push", hex(p))
        }
    }
    print("WATCH reply:", request(22, [3]).map(hex) ?? "none")
    let end = Date().addingTimeInterval(secs)
    var lastLive = "", lastPing = Date()
    while Date() < end {
        if Date().timeIntervalSince(lastPing) > 1 { _ = request(25); lastPing = Date() }
        if let live = request(77, [0]) {
            let line = liveLine(live)
            let key = line.components(separatedBy: " steps ").first ?? line
            if key != lastLive { print("LIVE  " + line); lastLive = key }
        }
        Thread.sleep(forTimeInterval: 0.25)
    }
    _ = request(22, [0])
    if let live = request(77, [0]) { print("LIVE end  " + liveLine(live)) }
    print("note-ons seen: \(notes)")
}

if mode == "misc" {
    for (sc, id) in [(0, 0), (1, 1)] {
        if let d = request(5, [UInt8(sc), UInt8(id)]) {
            var r = Reader(b: d); _ = r.u8(); _ = r.u8(); let fmt = r.u8(); let mn = r.v14(), mx = r.v14(), df = r.v14()
            print("DESC \(sc == 0 ? "track" : "global") \(id): label=\(r.str()) unit=\(r.str()) fmt=\(fmt) range=\(mn)..\(mx) default=\(df)")
        } else { print("DESC \(sc) \(id): no reply") }
    }
    var times: [Double] = []
    for _ in 0..<50 { let t0 = Date(); _ = request(77, [0]); times.append(Date().timeIntervalSince(t0) * 1000) }
    times.sort()
    print(String(format: "LIVE round trip over 50: min %.1f ms, median %.1f ms, max %.1f ms", times[0], times[25], times[49]))
}

func snapshot() -> [String: String] {
    var snap: [String: String] = [:]
    for k in 0..<3 { for i in 0..<64 {
        if let st = request(30, [UInt8(k), UInt8(i)]) { snap["T\(k + 1) step \(i + 1)"] = hex(Array(st.dropFirst(2))) }
    } }
    for i in 0..<64 { if let d = request(33, [UInt8(i)]) { snap["DRUMS step \(i + 1)"] = hex(Array(d.dropFirst(1))) } }
    return snap
}
if mode == "steps" {
    let secs = args.count > 2 ? Double(args[2]) ?? 45 : 45
    let before = snapshot()
    print("snapshot before: \(before.count) steps read")
    onPush = { p in
        var r = Reader(b: Array(p.dropFirst()))
        let t = String(format: "%.2f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
        switch p[0] {
        case 26: let i = r.u8(), tk = r.u8(); print("\(t) STEP_CHANGED step \(i + 1) on T\(tk + 1)")
        case 24: let e = r.u8(), pr = r.u8(), tk = r.u8(); print("\(t) RELOAD engine=\(e) preset=\(pr) track=T\(tk + 1)")
        case 23: let sc = r.u8(), id = r.u8(), v = r.v14(); print("\(t) CHANGED \(sc == 0 ? "track" : "global") param \(id) = \(v)")
        default: print("\(t) push", hex(p))
        }
    }
    print("WATCH reply:", request(22, [3]).map(hex) ?? "none", "- edit steps now")
    let end = Date().addingTimeInterval(secs)
    let pollHz = args.count > 3 ? Double(args[3]) ?? 0 : 0
    var polls = 0, missedSteps = 0, lastStep = -1, lastPing = Date()
    while Date() < end {
        if pollHz <= 0 { _ = request(25); Thread.sleep(forTimeInterval: 1.0); continue }
        if Date().timeIntervalSince(lastPing) > 1 { _ = request(25); lastPing = Date() }
        if let live = request(77, [0]), live.count > 20 {
            polls += 1
            let st = Int(live[20]), ln = max(Int(live[21]), 1), playing = live[1] & 1 == 1
            if playing && lastStep >= 0 { let d = (st - lastStep + ln) % ln; if d > 1 { missedSteps += d - 1 } }
            lastStep = playing ? st : -1
        }
        Thread.sleep(forTimeInterval: 1.0 / pollHz)
    }
    if pollHz > 0 { print(String(format: "playhead polls: %d (%.1f per second), T1 steps skipped between polls: %d", polls, Double(polls) / secs, missedSteps)) }
    _ = request(22, [0])
    let after = snapshot()
    let changed = after.keys.filter { before[$0] != after[$0] }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    print("steps that differ after: \(changed.count)")
    for k in changed { print("  \(k): \(before[k] ?? "-")  ->  \(after[k] ?? "-")") }
}

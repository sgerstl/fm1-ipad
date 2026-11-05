// meterprobe: METER (92), WATCH bit 3, against skiff-sim.
// usage: screenprobe PORTNAME CONSOLE_FIFO SHOTDIR
// The sim's console is driven through the fifo ("press X", "hold X MS", "screen FILE").
import CoreMIDI
import Foundation

let args = CommandLine.arguments
guard args.count == 4 else { print("usage: screenprobe PORTNAME FIFO SHOTDIR"); exit(2) }
let portName = args[1], shots = args[3]
let console = FileHandle(forWritingAtPath: args[2])!
func say(_ c: String) { console.write((c + "\n").data(using: .utf8)!) }
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
func nap(_ ms: Int) { usleep(useconds_t(ms * 1000)) }

var client = MIDIClientRef(); MIDIClientCreate("screenprobe" as CFString, nil, nil, &client)
var inp = MIDIPortRef(), out = MIDIPortRef()
let lock = NSLock()
var partial: [UInt8] = []
var frames: [(cmd: UInt8, body: [UInt8])] = []

MIDIInputPortCreateWithBlock(client, "in" as CFString, &inp) { list, _ in
    for packet in list.unsafeSequence() {
        let len = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(len)) }
        for b in bytes {
            if b == 0xF0 { partial = [b]; continue }
            if b >= 0xF8 { continue }
            if partial.isEmpty { continue }
            partial.append(b)
            if b == 0xF7 {
                let f = partial; partial = []
                if f.count >= 6, f[1] == 0x7D, f[2] == 0x46, f[3] == 0x4C {
                    lock.lock(); frames.append((f[4], Array(f[5..<(f.count - 1)]))); lock.unlock()
                }
            }
        }
    }
}
MIDIOutputPortCreate(client, "out" as CFString, &out)
func named(_ e: MIDIEndpointRef) -> String {
    var s: Unmanaged<CFString>?; MIDIObjectGetStringProperty(e, kMIDIPropertyName, &s)
    return (s?.takeRetainedValue() as String?) ?? ""
}
var src: MIDIEndpointRef = 0, dst: MIDIEndpointRef = 0
for i in 0..<MIDIGetNumberOfSources() where named(MIDIGetSource(i)) == portName { src = MIDIGetSource(i) }
for i in 0..<MIDIGetNumberOfDestinations() where named(MIDIGetDestination(i)) == portName { dst = MIDIGetDestination(i) }
guard src != 0, dst != 0 else { print("no port \(portName)"); exit(1) }
MIDIPortConnectSource(inp, src, nil)

func send(_ cmd: UInt8, _ a: [UInt8] = []) {
    let msg: [UInt8] = [0xF0, 0x7D, 0x46, 0x4C, cmd] + a + [0xF7]
    var pl = MIDIPacketList(); let p = MIDIPacketListInit(&pl)
    _ = MIDIPacketListAdd(&pl, MemoryLayout<MIDIPacketList>.size, p, 0, msg.count, msg)
    MIDISend(out, dst, &pl)
}
func take() -> [(cmd: UInt8, body: [UInt8])] { lock.lock(); let f = frames; frames = []; lock.unlock(); return f }
func ask(_ cmd: UInt8, _ a: [UInt8] = [], wait: Int = 300) -> [UInt8]? {
    _ = take(); send(cmd, a); nap(wait)
    return take().last(where: { $0.cmd == cmd })?.body
}
let PAGES = ["ENV", "ENV 2", "LFO", "LFO 2", "MOD", "FX", "DRIVE", "INSERT", "INSERT 2", "SLICER", "DUCK", "SCALE",
             "CHORD", "FOLLOW", "EDIT 1", "EDIT 2", "OPERATOR", "ALL OPS", "LANES", "SOUND", "LANE MIX", "SLICES",
             "SAMPLES", "OP1 ENV", "OP2 ENV", "OP3 ENV", "OP4 ENV", "OP LEVEL", "VOICE", "VOICE 2", "MIXER", "DELAY",
             "REVERB", "CHORUS", "GLOBAL", "PRESETS", "USER", "PATTERNS", "PROJECT", "ARP", "ARP 2", "NOTES", "FEEL",
             "PATTERN", "AUTOMATION", "SONG"]
let LAYERS = ["-", "FX", "GLO", "SCL", "EDIT", "SEQ", "REC", "PERF"]
func show(_ s: [UInt8]) -> String {
    guard s.count == 8 else { return "bad \(hex(s))" }
    let pg = Int(s[1]) < PAGES.count ? PAGES[Int(s[1])] : "?"
    return "home \(s[0]) page \(s[1]) \(pg) layer \(LAYERS[min(Int(s[2]), 7)]) menu \(s[3]) track \(s[4]) flags \(s[5]) cursor \(s[6] == 127 ? "-" : String(s[6]))/\(s[7] == 127 ? "-" : String(s[7]))"
}
var fails = 0
func check(_ what: String, _ ok: Bool) { print(String(format: "%-66@ %@", what as NSString, ok ? "ok" : "FAIL")); if !ok { fails += 1 } }
func counts(_ f: [(cmd: UInt8, body: [UInt8])]) -> String {
    Dictionary(grouping: f, by: { $0.cmd }).sorted { $0.key < $1.key }.map { "\($0.key)x\($0.value.count)" }.joined(separator: " ")
}

func rtt() -> Double {                                   // a PING's round trip, ms
    _ = take(); let t0 = Date(); send(25)
    while Date().timeIntervalSince(t0) < 0.5 { nap(1); lock.lock(); let got = frames.contains { $0.cmd == 25 }; lock.unlock(); if got { break } }
    return Date().timeIntervalSince(t0) * 1000
}
// run for ms, PINGing each second-ish; collect all frames
func run(_ ms: Int, every: (() -> Void)? = nil, stepMs: Int = 250) -> [(cmd: UInt8, body: [UInt8])] {
    var all: [(cmd: UInt8, body: [UInt8])] = []; var t = 0
    while t < ms { every?(); nap(stepMs); t += stepMs; if t % 750 < stepMs { send(25); nap(30) }; all += take() }
    nap(40); all += take()
    return all
}
func raw(_ b: [UInt8]) {
    var pl = MIDIPacketList(); let p = MIDIPacketListInit(&pl)
    _ = MIDIPacketListAdd(&pl, MemoryLayout<MIDIPacketList>.size, p, 0, b.count, b); MIDISend(out, dst, &pl)
}
var nt = 0
func notes() { let n = UInt8(48 + (nt * 7) % 24); raw([0x90, n, 110]); nap(5); raw([0x80, UInt8(48 + ((nt + 23) * 7) % 24), 0]); nt += 1 }
func meters(_ f: [(cmd: UInt8, body: [UInt8])]) -> [[UInt8]] { f.filter { $0.cmd == 92 }.map { $0.body } }

if let info = ask(1) { let t = Array(info.suffix(3)); check("INFO ends with 56 01 03 (got \(hex(t)))", t == [0x56, 1, 3]) }
check("WATCH 15 replies 15", ask(22, [15]) == [15])
var m = meters(run(2100))
check("stopped 2 s: \(m.count) METER (keep-alive ~1/s), all zero", (1...3).contains(m.count) && m.allSatisfy { $0 == [0, 0, 0, 0, 0, 0] })
check("METER (92) asked: 6 bytes", ask(92)?.count == 6)
_ = ask(91, [30])                                        // MIXER, so the screen's meters run too
_ = ask(76, [1])
let t0 = Date()
var f = run(4000, every: notes, stepMs: 125)
let secs = Date().timeIntervalSince(t0)
m = meters(f)
var peak = [UInt8](repeating: 0, count: 6)
for x in m where x.count == 6 { for i in 0..<6 { peak[i] = max(peak[i], x[i]) } }
let rate = Double(m.count) / secs
print(String(format: "   playing: %d METER in %.1f s = %.1f/s, %.0f bytes/s of METER on the wire; peaks %@", m.count, secs, rate, rate * 12, peak.map(String.init).joined(separator: " ")))
for x in m.prefix(6) { print("    ", x.map { String(format: "%3d", $0) }.joined(separator: " ")) }
check("playing: at most 25 a second (only when a level changed), a track moving", rate > 2 && rate <= 26 && peak.contains { $0 > 30 })
check("every METER 6 bytes", m.allSatisfy { $0.count == 6 })
say("screen \(shots)/mixer-playing.ppm"); nap(200)
var quiet: [Double] = []; for _ in 0..<10 { quiet.append(rtt()); nap(40) }
// knobs turned fast while playing: CHANGED goes first, METER yields; requests still answered
var turns = 0
let t1 = Date()
f = run(3000, every: { notes(); for _ in 0..<4 { say("turn 3 \(turns % 20 < 10 ? 1 : -1)"); turns += 1; nap(10) } }, stepMs: 60)
let ch = f.filter { $0.cmd == 23 || $0.cmd == 26 || $0.cmd == 32 }.count
m = meters(f)
let ksecs = Date().timeIntervalSince(t1)
var busy: [Double] = []
for _ in 0..<10 { say("turn 4 1"); busy.append(rtt()); nap(40) }
print(String(format: "   knobs (%.1f s): %d turns, %d CHANGED pushes (%.1f/s), %d METER (%.1f/s); frames by cmd: %@", ksecs, turns, ch, Double(ch) / ksecs, m.count, Double(m.count) / ksecs, counts(f)))
check("knobs: METER at most 25 a second", Double(m.count) / ksecs <= 26)
print(String(format: "   PING round trip: quiet %.1f ms max %.1f, turning knobs with METER %.1f ms max %.1f", quiet.reduce(0, +) / 10, quiet.max()!, busy.reduce(0, +) / 10, busy.max()!))
check("knobs: pushes still flow, PING still answered fast (< 50 ms)", busy.max()! < 50 && f.count > m.count)
for n in 0..<128 { raw([0x80, UInt8(n), 0]) }
_ = ask(76, [2])
f = run(3000)
m = meters(f)
let firstZero = m.firstIndex { $0 == [0, 0, 0, 0, 0, 0] }
check("stopped: falls to zero (\(firstZero.map { "after \($0 + 1) pushes" } ?? "never")), then ~1/s (\(m.count) in 3 s)", firstZero != nil && m.count - firstZero! <= 4)
check("WATCH 7 replies 7", ask(22, [7]) == [7])
_ = ask(76, [1])
m = meters(run(1500, every: notes, stepMs: 125))
check("WATCH 7 while playing: no METER", m.isEmpty)
_ = ask(76, [2])
print(fails == 0 ? "meterprobe: all ok" : "meterprobe: \(fails) FAILED")
exit(fails == 0 ? 0 : 1)

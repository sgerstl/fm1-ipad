// screenprobe: checks Skiff's screen link (cmds 90 SCREEN, 91 SCREEN_GOTO, WATCH bit 2) against skiff-sim.
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
    guard s.count == 6 else { return "bad \(hex(s))" }
    let pg = Int(s[1]) < PAGES.count ? PAGES[Int(s[1])] : "?"
    return "home \(s[0]) page \(s[1]) \(pg) layer \(LAYERS[min(Int(s[2]), 7)]) menu \(s[3]) track \(s[4]) flags \(s[5])"
}
var fails = 0
func check(_ what: String, _ ok: Bool) { print(String(format: "%-66@ %@", what as NSString, ok ? "ok" : "FAIL")); if !ok { fails += 1 } }
func counts(_ f: [(cmd: UInt8, body: [UInt8])]) -> String {
    Dictionary(grouping: f, by: { $0.cmd }).sorted { $0.key < $1.key }.map { "\($0.key)x\($0.value.count)" }.joined(separator: " ")
}

// INFO: the tag last
if let info = ask(1) {
    let t = Array(info.suffix(3))
    check("INFO ends with 56 01 01 (got \(hex(t)))", t == [0x56, 1, 1])
    print("INFO version:", String(bytes: info.prefix(while: { $0 != 0 }), encoding: .ascii) ?? "?")
}
let buttons = ["FX", "SCL", "ENV", "LFO", "EDIT", "GLO", "SAVE", "ARP", "SEQ", "HOME"]

// A: an editor that never asks (WATCH 3): no SCREEN traffic while every button is pressed
check("WATCH 3 replies 3", ask(22, [3]) == [3])
var seen: [(cmd: UInt8, body: [UInt8])] = []
for b in buttons + ["FX", "FX"] { say("press \(b)"); nap(350); seen += take(); send(25) }
say("hold FX 900"); nap(1300); seen += take()
check("WATCH 3: no cmd 90/91 while pressing buttons (frames: \(counts(seen)))", !seen.contains { $0.cmd == 90 || $0.cmd == 91 })

// B: WATCH 7: the state at once, then a push per change
_ = take(); send(22, [7]); nap(300)
var f = take()
check("WATCH 7 replies 7", f.first(where: { $0.cmd == 22 })?.body == [7])
check("WATCH 7 pushes the state at once", f.contains { $0.cmd == 90 })
if let s = f.last(where: { $0.cmd == 90 }) { print("   now:", show(s.body)) }
for b in buttons + ["FX", "FX", "SEQ", "SEQ"] {
    say("press \(b)"); nap(350); send(25); nap(30); f = take()
    let p = f.filter { $0.cmd == 90 }
    check("press \(b): \(p.count) push(es)", !p.isEmpty)
    for x in p { print("   ", show(x.body)) }
}
say("press FX"); nap(350); send(25); _ = take()
say("hold FX 900"); nap(650); send(25); nap(650); send(25); nap(30); f = take().filter { $0.cmd == 90 }
check("hold FX: the layer pushed open and closed (\(f.count) pushes)", f.contains { $0.body.count == 6 && $0.body[2] == 1 } && f.last?.body[2] == 0)
for x in f { print("   ", show(x.body)) }
say("hold HOME 900"); nap(650); send(25); nap(650); send(25); nap(30); f = take().filter { $0.cmd == 90 }
check("hold HOME: pushes (\(f.count))", !f.isEmpty)
for x in f { print("   ", show(x.body)) }
say("press HOME"); nap(350); send(25); nap(30); _ = take()
send(22, [7]); nap(300)
check("WATCH 7 again while watching: no push again", !take().contains { $0.cmd == 90 })

// C: SCREEN_GOTO, with the screen dumped after each
func shot(_ name: String) { say("screen \(shots)/\(name).ppm"); nap(300); send(25); nap(50) }
shot("0-before")
for (i, pg) in [(31, "DELAY"), (43, "PATTERN"), (5, "FX"), (37, "PATTERNS"), (127, "HOME")] {
    let r = ask(91, [UInt8(pg == "HOME" ? 127 : i)])
    let ok = r?.count == 6 && (pg == "HOME" ? r![0] == 1 : r![0] == 0 && r![1] == UInt8(i))
    check("SCREEN_GOTO \(pg): \(r.map(show) ?? "no reply")", ok)
    nap(150); send(25); nap(30)
    check("   no push echoing it", !take().contains { $0.cmd == 90 })
    shot("\(i)-\(pg.replacingOccurrences(of: " ", with: "_"))")
}
let before = ask(90)
let lanes = ask(91, [18])
check("SCREEN_GOTO LANES on the track's own engine: \(lanes.map(show) ?? "no reply") (refused unless DRUM)", lanes == before)
check("SCREEN (90) answers", before?.count == 6)
say("press GLO"); nap(350); send(25); nap(30)
check("still watching after the GOTOs: a button still pushes", take().contains { $0.cmd == 90 })

// D: WATCH 1: pushes stop
check("WATCH 1 replies 1", ask(22, [1]) == [1])
seen = []
for b in ["FX", "GLO", "HOME"] { say("press \(b)"); nap(350); seen += take(); send(25) }
check("WATCH 1: no SCREEN pushes (frames: \(counts(seen)))", !seen.contains { $0.cmd == 90 })
print(fails == 0 ? "screenprobe: all ok" : "screenprobe: \(fails) FAILED")
exit(fails == 0 ? 0 : 1)

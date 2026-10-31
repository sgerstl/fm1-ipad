// sloopcapture: record SLOOP editor-protocol traffic as test fixtures.
// usage: sloopcapture <out.jsonl> [watchSecs]
// Sends INFO, TRACK, NAMES (every engine), TRACK_STEP (3 x 64), DRUM_STEP (64), the knob parameters,
// DESC of the scale, a few LIVE polls, then WATCH 3 and records every frame for watchSecs while you
// play and edit on the FM-1 (PING once a second, LIVE 20 times a second). One JSON object per line:
// {"t": seconds since start, "dir": "tx" | "rx", "hex": "F0 7D ..."}
import CoreMIDI
import Foundation

let args = CommandLine.arguments
guard args.count > 1 else { print("usage: sloopcapture <out.jsonl> [watchSecs]"); exit(2) }
let outURL = URL(fileURLWithPath: args[1])
let watchSecs = args.count > 2 ? Double(args[2]) ?? 30 : 30
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }

let t0 = Date()
var lines: [String] = []
let logLock = NSLock()
func log(_ dir: String, _ bytes: [UInt8]) {
    let t = String(format: "%.4f", Date().timeIntervalSince(t0))
    logLock.lock(); lines.append("{\"t\": \(t), \"dir\": \"\(dir)\", \"hex\": \"\(hex(bytes))\"}"); logLock.unlock()
}

var client = MIDIClientRef(); MIDIClientCreate("sloopcapture" as CFString, nil, nil, &client)
var inp = MIDIPortRef(), out = MIDIPortRef()
let lock = NSLock()
var partial: [UInt8] = []
var replies: [UInt8: [UInt8]] = [:]
let got = DispatchSemaphore(value: 0)
var waitingFor: UInt8 = 0xFF
let pushes: Set<UInt8> = [23, 24, 26, 32]
var pushCount = 0

func frame(_ bytes: [UInt8]) {
    log("rx", bytes)
    guard bytes.count >= 6, bytes[1] == 0x7D, bytes[2] == 0x46, bytes[3] == 0x4C else { return }
    let cmd = bytes[4]
    if pushes.contains(cmd) { pushCount += 1; return }
    lock.lock(); replies[cmd] = Array(bytes[5..<(bytes.count - 1)]); let w = waitingFor; lock.unlock()
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
        }
    }
}
MIDIOutputPortCreate(client, "out" as CFString, &out)
let src = MIDIGetSource(0), dst = MIDIGetDestination(0)
guard src != 0, dst != 0 else { print("no MIDI source/destination: is the FM-1 plugged in?"); exit(1) }
MIDIPortConnectSource(inp, src, nil)

func send(_ msg: [UInt8]) {
    log("tx", msg)
    let size = 1024
    let buf = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
    defer { buf.deallocate() }
    let pl = buf.bindMemory(to: MIDIPacketList.self, capacity: 1)
    let pk = MIDIPacketListInit(pl)
    _ = MIDIPacketListAdd(pl, size, pk, 0, msg.count, msg)
    MIDISend(out, dst, pl)
}

@discardableResult
func request(_ cmd: UInt8, _ a: [UInt8] = [], timeout: Double = 1.0) -> [UInt8]? {
    lock.lock(); replies[cmd] = nil; waitingFor = cmd; lock.unlock()
    send([0xF0, 0x7D, 0x46, 0x4C, cmd] + a + [0xF7])
    if got.wait(timeout: .now() + timeout) == .timedOut { print("cmd \(cmd) \(a): no reply"); return nil }
    lock.lock(); let r = replies[cmd]; lock.unlock(); return r
}

Thread.sleep(forTimeInterval: 0.3)   // let anything queued in the USB buffer arrive first
guard let info = request(1) else { print("INFO: no reply"); exit(1) }
let nEngines = Int(info[info.firstIndex(of: 0)! + 1])
request(27)
for e in 0..<nEngines { request(10, [UInt8(e)]) }
for k in 0..<3 { for i in 0..<64 { request(30, [UInt8(k), UInt8(i)]) } }
for i in 0..<64 { request(33, [UInt8(i)]) }
// knob and key parameters: P_LEVEL 0, P_ROOT 25, P_SCALE 26, P_SLEN 29, P_SDIV 30, P_PAN 39, P_MUTE 40
for k in 0..<4 { for id: UInt8 in [0, 25, 26, 29, 30, 39, 40] { request(31, [UInt8(k), id]) } }
for id: UInt8 in [0, 1, 25] { request(2, [1, id]) }    // G_BPM, G_SWING, G_DRLVL
request(5, [0, 26])                                      // DESC P_SCALE
request(5, [1, 1])                                       // DESC G_SWING
for _ in 0..<5 { request(77, [0]); Thread.sleep(forTimeInterval: 0.05) }
request(25)
print("snapshot done (\(lines.count) frames). WATCH 3 for \(Int(watchSecs)) s: play, switch tracks, edit steps, turn knobs now")

request(22, [3])
let end = Date().addingTimeInterval(watchSecs)
var lastPing = Date()
while Date() < end {
    if Date().timeIntervalSince(lastPing) > 1 { request(25); lastPing = Date() }
    request(77, [0])
    Thread.sleep(forTimeInterval: 0.05)
}
request(22, [0])
logLock.lock()
try! (lines.joined(separator: "\n") + "\n").write(to: outURL, atomically: true, encoding: .utf8)
print("wrote \(lines.count) frames (\(pushCount) pushes) to \(outURL.path)")
logLock.unlock()

import CoreMIDI
import Foundation
func name(_ e: MIDIEndpointRef) -> String { var s: Unmanaged<CFString>?; MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &s); return (s?.takeRetainedValue() as String?) ?? "?" }
print("Sources:"); for i in 0..<MIDIGetNumberOfSources() { print("  [\(i)] \(name(MIDIGetSource(i)))") }
print("Destinations:"); for i in 0..<MIDIGetNumberOfDestinations() { print("  [\(i)] \(name(MIDIGetDestination(i)))") }
let secs = Double(CommandLine.arguments.dropFirst().first ?? "15") ?? 15
var client = MIDIClientRef(); MIDIClientCreate("probe" as CFString, nil, nil, &client)
var port = MIDIPortRef()
var clock = 0
MIDIInputPortCreateWithProtocol(client, "in" as CFString, ._1_0, &port) { list, _ in
  for packet in list.unsafeSequence() {
    let words = packet.words().map { String(format: "%08X", $0) }
    // filter clock (F8) spam
    let w = packet.words().first ?? 0
    if (w >> 28) == 1 && ((w >> 16) & 0xFF) == 0xF8 { clock += 1; continue }
    print(String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)), words.joined(separator: " "))
  }
}
for i in 0..<MIDIGetNumberOfSources() { let s = MIDIGetSource(i); if true { MIDIPortConnectSource(port, s, nil); print("listening to \(name(s)) for \(Int(secs))s...") } }
RunLoop.main.run(until: Date().addingTimeInterval(secs))
print("clock ticks seen: \(clock)")

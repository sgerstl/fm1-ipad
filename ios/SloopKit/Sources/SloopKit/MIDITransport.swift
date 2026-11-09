import CoreMIDI
import Foundation

/// The FM-1 over USB MIDI, or over Bluetooth LE MIDI with the bluetooth-poc firmware. SLOOP keeps Felucca's port name, so
/// the USB endpoints are found by "Felucca". Over Bluetooth iOS shows the FM-1 as a CoreMIDI device once it's connected
/// through Apple's Bluetooth MIDI view (CABTMIDICentralViewController): its endpoints carry the advertised name,
/// "FM1-XXXX" (optimist's stack, ble_cfg.h BLE_DEVICE_NAME), and Apple's Bluetooth MIDI driver owns them. USB wins when both
/// are there.
public final class MIDITransport: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    public let notes: AsyncStream<NoteEvent>
    private let noteSink: AsyncStream<NoteEvent>.Continuation
    public let clock: AsyncStream<ClockEvent>
    private let clockSink: AsyncStream<ClockEvent>.Continuation
    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var source: MIDIEndpointRef = 0
    private var destination: MIDIEndpointRef = 0
    private var assembler = SysExAssembler()
    private let lock = NSLock()
    private var finished = false
    public let name: String
    public let link: TransportLink

    /// The FM-1's Bluetooth name as the bluetooth-poc firmware advertises it: "FM1-" and four hex digits.
    public static func isBluetoothName(_ name: String) -> Bool {
        name.range(of: #"^FM1-[0-9A-Fa-f]{4}\b"#, options: .regularExpression) != nil
    }

    /// The device's endpoints and link, or nil when no Felucca port (USB) or FM1-XXXX port (Bluetooth) is there.
    /// FELUCCA_PORT names another USB port to look for (one skiff-sim among several on the Mac, each run with its own --name).
    public static func findDevice() -> (source: MIDIEndpointRef, destination: MIDIEndpointRef, name: String, link: TransportLink)? {
        let want = ProcessInfo.processInfo.environment["FELUCCA_PORT"] ?? "felucca"
        func string(_ e: MIDIEndpointRef, _ key: CFString) -> String {
            var s: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(e, key, &s)
            return (s?.takeRetainedValue() as String?) ?? ""
        }
        func name(_ e: MIDIEndpointRef) -> String { string(e, kMIDIPropertyDisplayName) }
        func offline(_ e: MIDIEndpointRef) -> Bool {     // (a Bluetooth device iOS keeps after it went: not there)
            var v: Int32 = 0
            return MIDIObjectGetIntegerProperty(e, kMIDIPropertyOffline, &v) == noErr && v != 0
        }
        func bluetooth(_ e: MIDIEndpointRef) -> Bool {
            guard !offline(e) else { return false }
            return isBluetoothName(name(e)) || (string(e, kMIDIPropertyDriverOwner).localizedCaseInsensitiveContains("bluetooth")
                                                && name(e).uppercased().hasPrefix("FM1"))
        }
        let sources = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource)
        let dests = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination)
        if let s = sources.first(where: { name($0).localizedCaseInsensitiveContains(want) }),
           let d = dests.first(where: { name($0).localizedCaseInsensitiveContains(want) }) {
            return (s, d, name(s), .usb)
        }
        if let s = sources.first(where: bluetooth), let d = dests.first(where: bluetooth) {
            return (s, d, name(s), .bluetooth)
        }
        return nil
    }

    public init?() {
        guard let dev = Self.findDevice() else { return nil }
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self, bufferingPolicy: .unbounded)
        (notes, noteSink) = AsyncStream.makeStream(of: NoteEvent.self, bufferingPolicy: .bufferingNewest(128))
        (clock, clockSink) = AsyncStream.makeStream(of: ClockEvent.self, bufferingPolicy: .bufferingNewest(512))
        source = dev.source; destination = dev.destination; name = dev.name; link = dev.link

        let status = MIDIClientCreateWithBlock("FM1 iPad" as CFString, &client) { [weak self] note in
            if note.pointee.messageID == .msgObjectRemoved || note.pointee.messageID == .msgSetupChanged {
                self?.checkStillThere()
            }
        }
        guard status == noErr else { return nil }
        MIDIInputPortCreateWithBlock(client, "in" as CFString, &inPort) { [weak self] list, _ in
            self?.receive(list)
        }
        MIDIOutputPortCreate(client, "out" as CFString, &outPort)
        MIDIPortConnectSource(inPort, source, nil)
    }

    deinit { finish(); MIDIClientDispose(client) }

    private func receive(_ list: UnsafePointer<MIDIPacketList>) {
        lock.lock()
        var out: [[UInt8]] = []
        for packet in list.unsafeSequence() {
            let len = Int(packet.pointee.length)
            let raw = UnsafeRawPointer(packet) + MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
            out += assembler.feed(UnsafeRawBufferPointer(start: raw, count: len))
        }
        let notes = assembler.drainNotes()
        let ticks = assembler.drainClock()
        lock.unlock()
        for f in out { sink.yield(f) }
        for n in notes { noteSink.yield(n) }
        for c in ticks { clockSink.yield(c) }
    }

    public func send(_ frame: [UInt8]) {
        let size = 1024
        let buf = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { buf.deallocate() }
        let pl = buf.bindMemory(to: MIDIPacketList.self, capacity: 1)
        let pk = MIDIPacketListInit(pl)
        _ = MIDIPacketListAdd(pl, size, pk, 0, frame.count, frame)
        MIDISend(outPort, destination, pl)
    }

    private func checkStillThere() {
        if Self.findDevice()?.source != source { finish() }
    }

    private func finish() {
        lock.lock(); defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        sink.finish()
        noteSink.finish()
        clockSink.finish()
    }
}

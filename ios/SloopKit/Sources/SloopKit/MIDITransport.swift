import CoreMIDI
import Foundation

/// The FM-1 over USB MIDI. SLOOP keeps Felucca's port name, so the endpoints are found by "Felucca".
public final class MIDITransport: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    public let notes: AsyncStream<NoteEvent>
    private let noteSink: AsyncStream<NoteEvent>.Continuation
    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var source: MIDIEndpointRef = 0
    private var destination: MIDIEndpointRef = 0
    private var assembler = SysExAssembler()
    private let lock = NSLock()
    private var finished = false
    public let name: String

    /// The device's endpoints, or nil when no Felucca port is there.
    public static func findDevice() -> (source: MIDIEndpointRef, destination: MIDIEndpointRef, name: String)? {
        func name(_ e: MIDIEndpointRef) -> String {
            var s: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &s)
            return (s?.takeRetainedValue() as String?) ?? ""
        }
        let sources = (0..<MIDIGetNumberOfSources()).map(MIDIGetSource)
        let dests = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination)
        guard let s = sources.first(where: { name($0).localizedCaseInsensitiveContains("felucca") }),
              let d = dests.first(where: { name($0).localizedCaseInsensitiveContains("felucca") }) else { return nil }
        return (s, d, name(s))
    }

    public init?() {
        guard let dev = Self.findDevice() else { return nil }
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self, bufferingPolicy: .unbounded)
        (notes, noteSink) = AsyncStream.makeStream(of: NoteEvent.self, bufferingPolicy: .bufferingNewest(128))
        source = dev.source; destination = dev.destination; name = dev.name

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
        lock.unlock()
        for f in out { sink.yield(f) }
        for n in notes { noteSink.yield(n) }
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
    }
}

// The installer's MIDI ports on CoreMIDI, and the frame queue its links share with the fake FM-1.
import CoreMIDI
import Foundation

/// SysEx frames waiting to be read, with one reader at a time that may wait for the next.
final class FrameQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [[UInt8]] = []
    private var waiter: (id: Int, cont: CheckedContinuation<[UInt8]?, Never>)?
    private var nextID = 0

    func put(_ f: [UInt8]) {
        lock.lock()
        if let w = waiter { waiter = nil; lock.unlock(); w.cont.resume(returning: f); return }
        frames.append(f)
        lock.unlock()
    }

    func drain() { lock.lock(); frames.removeAll(); lock.unlock() }

    func read(timeout: Duration) async -> [UInt8]? {
        if let f = lock.withLock({ frames.isEmpty ? nil : frames.removeFirst() }) { return f }
        let id = lock.withLock { nextID += 1; return nextID }
        return await withCheckedContinuation { (c: CheckedContinuation<[UInt8]?, Never>) in
            let ready: [UInt8]? = lock.withLock {
                if !frames.isEmpty { return frames.removeFirst() }
                waiter = (id, c)
                return nil
            }
            if let ready { c.resume(returning: ready); return }
            Task {
                try? await Task.sleep(for: max(timeout, .zero))
                self.expire(id)
            }
        }
    }

    private func expire(_ id: Int) {
        lock.lock()
        guard let w = waiter, w.id == id else { lock.unlock(); return }
        waiter = nil
        lock.unlock()
        w.cont.resume(returning: nil)
    }
}

/// CoreMIDI: every source and destination by display name. Only names `FirmwareInstaller.mayBeFM1` accepts are
/// ever opened (the installer checks).
public final class CoreMIDIUpdatePorts: UpdatePorts, @unchecked Sendable {
    private var client = MIDIClientRef()

    public init() {
        MIDIClientCreateWithBlock("Jib firmware" as CFString, &client, nil)
    }

    deinit { MIDIClientDispose(client) }

    static func name(_ e: MIDIEndpointRef) -> String {
        var s: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &s)
        return (s?.takeRetainedValue() as String?) ?? ""
    }

    static func sources() -> [(MIDIEndpointRef, String)] {
        (0..<MIDIGetNumberOfSources()).map { let e = MIDIGetSource($0); return (e, name(e)) }
    }

    static func destinations() -> [(MIDIEndpointRef, String)] {
        (0..<MIDIGetNumberOfDestinations()).map { let e = MIDIGetDestination($0); return (e, name(e)) }
    }

    public func inputNames() -> [String] {
        var seen = Set<String>()
        return Self.sources().map(\.1).filter { seen.insert($0).inserted }
    }

    public func open(_ name: String) throws -> UpdateLink {
        guard let src = Self.sources().first(where: { $0.1 == name })?.0 else { throw CocoaError(.fileNoSuchFile) }
        let dests = Self.destinations()
        // the same name; else one whose name is the same without a trailing number (Windows-style numbering)
        func base(_ s: String) -> String { s.replacingOccurrences(of: #"\s+\d+$"#, with: "", options: .regularExpression) }
        guard let dst = dests.first(where: { $0.1 == name })?.0 ?? dests.first(where: { base($0.1) == base(name) })?.0 else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try CoreMIDIUpdateLink(client: client, source: src, destination: dst, name: name)
    }
}

final class CoreMIDIUpdateLink: UpdateLink, @unchecked Sendable {
    private var inPort = MIDIPortRef(), outPort = MIDIPortRef()
    private let source: MIDIEndpointRef, destination: MIDIEndpointRef
    private let name: String
    private let queue = FrameQueue()
    private var assembler = SysExAssembler()
    private let lock = NSLock()
    private var closed = false

    init(client: MIDIClientRef, source: MIDIEndpointRef, destination: MIDIEndpointRef, name: String) throws {
        self.source = source; self.destination = destination; self.name = name
        var st = MIDIInputPortCreateWithBlock(client, "fw in" as CFString, &inPort) { [weak self] list, _ in self?.receive(list) }
        if st == noErr { st = MIDIOutputPortCreate(client, "fw out" as CFString, &outPort) }
        if st == noErr { st = MIDIPortConnectSource(inPort, source, nil) }
        guard st == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(st)) }
        Thread.sleep(forTimeInterval: 0.3)     // CoreMIDI may drop a message sent just after opening (fm1_install.py)
    }

    deinit { close() }

    private func receive(_ list: UnsafePointer<MIDIPacketList>) {
        lock.lock()
        var out: [[UInt8]] = []
        for packet in list.unsafeSequence() {
            let raw = UnsafeRawPointer(packet) + MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
            out += assembler.feed(UnsafeRawBufferPointer(start: raw, count: Int(packet.pointee.length)))
        }
        _ = assembler.drainNotes(); _ = assembler.drainClock()
        lock.unlock()
        for f in out { queue.put(f) }
    }

    var lost: Bool { !CoreMIDIUpdatePorts.sources().contains { $0.0 == source && $0.1 == name } }

    func send(_ frame: [UInt8]) -> Bool {
        lock.lock(); let c = closed; lock.unlock()
        guard !c, !lost else { return false }
        let size = frame.count + 256
        let buf = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { buf.deallocate() }
        let pl = buf.bindMemory(to: MIDIPacketList.self, capacity: 1)
        let pk = MIDIPacketListInit(pl)
        _ = MIDIPacketListAdd(pl, size, pk, 0, frame.count, frame)
        return MIDISend(outPort, destination, pl) == noErr
    }

    func read(timeout: Duration) async -> [UInt8]? { await queue.read(timeout: timeout) }
    func drain() { queue.drain() }

    func close() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        MIDIPortDisconnectSource(inPort, source)
        MIDIPortDispose(inPort)
        MIDIPortDispose(outPort)
    }
}

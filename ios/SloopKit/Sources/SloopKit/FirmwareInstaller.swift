// Installs a Felucca-family package (Skiff, SLOOP), or M-VAVE's own V15, on an FM-1 over USB-MIDI: a port of Skiff's
// tools/fm1_install.py and web/fm1ota.js (GPL-3.0, Leo Kuroshita), with SLOOP's narrower port filter and loader rule.
//
// Step 1: the running firmware (Skiff, SLOOP, Felucca or M-VAVE's) gets UPGRADE, reads parts of the package
// with cmd 0x30 requests, stages the package's update loader, asks 0xE0000000 ("success") and restarts into it.
// Nothing is written to the app before that "success". Step 2: the loader ("ota-FM-1_7xx" / "_9xx", USB name
// "Felucca Update") gets UPGRADE, reads the whole flash.bin twice (a check pass, then the write), asks 0xF0000000,
// and restarts into the new firmware, whose identity is checked. The device asks and the host only answers.
//
// Stock V15 goes the same two steps with M-VAVE's loader in step 2: Skiff's and SLOOP's step 1 stage it only when
// the package's 16 KiB head equals the unit's (the official loader rewrites the head), and the record it leaves names
// "ota-FM-1_015". That loader reads flash.bin once, downward (Skiff's tests; not seen on a device here).
//
// A write cut off (cable, power, a stall) leaves the update record in place: the FM-1 comes back as the loader at
// every power-on until a write finishes, and the loader writes the app's header last, so writing again is safe.
import Foundation

/// The device's identity from the update handshake (cmd 0x11): "FM-1_722", or "ota-FM-1_722" for the loader.
public struct DeviceIdentity: Equatable, Sendable {
    public let text: String
    public let model: String
    public let version: Int
    public var isLoader: Bool { model.lowercased().hasPrefix("ota-") }
    /// The model without "ota-".
    public var baseModel: String { isLoader ? String(model.dropFirst(4)) : model }

    public init?(_ text: String) {
        guard let us = text.lastIndex(of: "_"), let v = Int(text[text.index(after: us)...]),
              text[text.index(after: us)...].allSatisfy(\.isNumber), us != text.startIndex else { return nil }
        self.text = text; model = String(text[..<us]); version = v
    }
}

/// One in/out pair, opened by name. Frames are whole SysEx messages, F0 … F7.
public protocol UpdateLink: AnyObject, Sendable {
    /// false when the port is gone.
    func send(_ frame: [UInt8]) -> Bool
    /// The next SysEx frame, or nil after `timeout`.
    func read(timeout: Duration) async -> [UInt8]?
    func drain()
    /// The port has disappeared (unplugged, or the device restarted as something else).
    var lost: Bool { get }
    func close()
}

/// The MIDI ports the installer may look at (CoreMIDI in the app, a fake FM-1 in the tests).
public protocol UpdatePorts: AnyObject, Sendable {
    func inputNames() -> [String]
    func open(_ name: String) throws -> UpdateLink
}

public struct InstallError: Error, Equatable, CustomStringConvertible, Sendable {
    public enum Code: String, Sendable {
        case notFound, model, foreignLoader, otherStock, lost, stopped, badRequest, noLoader, noReturn, mismatch, cancelled
    }
    public let code: Code
    public let message: String
    /// Requests answered before it stopped.
    public var served = 0
    /// Whether the FM-1 may now be in update mode: running the install again finishes it.
    public var inUpdateMode = false
    public var description: String { message }
}

public enum InstallStep: Equatable, Sendable {
    case start(String)          // the identity of the running firmware
    case check(Int)             // step 1, reads answered
    case loader                 // waiting for the update loader
    case write(Int)             // step 2, percent (forward only)
    case dropped                // the loader went away mid-write: waiting for it to come back
    case resume(Int)            // it came back: try n
    case reboot                 // written, waiting for the new firmware
    case done(String)           // the identity it reports
}

public final class FirmwareInstaller: @unchecked Sendable {
    static let hsQuery: [UInt8] = [0xF0, 0x00, 0x32, 0x45, 0x00, 0x00, 0x00, 0x40, 0x7F, 0xF7]
    static let upgrade: [UInt8] = [0xF0, 0x22, 0x24, 0x35, 0x7F, 0xF7]
    static let finishCheck = 0xE000_0000, finishWrite = 0xF000_0000
    static let maxData = 512
    /// The ports that may be an FM-1 (SLOOP's PORT_RE: Felucca and its forks, CLIPPER, the update loaders, the stock
    /// firmware's names). Nothing else is ever opened, and a port is only written to after it answers the
    /// handshake with an FM-1 identity.
    static let portPattern = #"fm-1|felucca|sloop|clipper|ota|composite|sinco|usb-midi"#
    static let model = "FM-1"

    /// Seconds, as fm1_install.py's DELAY; the tests shorten them.
    public struct Delays: Sendable {
        public var start: Duration = .seconds(2), reply: Duration = .milliseconds(10)
        public var loader: Duration = .seconds(3), reboot: Duration = .seconds(3), retry: Duration = .seconds(1)
        public var poll: Duration = .seconds(1), handshake: Duration = .seconds(1)
        public var idleCheck: Duration = .seconds(8), idleWrite: Duration = .seconds(180)
        public var waitLoader: Duration = .seconds(30), waitReboot: Duration = .seconds(40), waitResume: Duration = .seconds(120)
        public init() {}
    }

    public let ports: UpdatePorts
    public var delays: Delays
    /// Write attempts: the first and the resumes after a drop.
    public var resumeMax = 5
    private let cancelLock = NSLock()
    private var cancelled = false

    public init(ports: UpdatePorts, delays: Delays = Delays()) {
        self.ports = ports; self.delays = delays
    }

    // MARK: Wire format

    public static func pack7(_ data: some Sequence<UInt8>) -> [UInt8] {
        var out: [UInt8] = [], acc: UInt32 = 0, nb: UInt32 = 0
        for b in data {
            acc |= UInt32(b) << nb; nb += 8
            while nb >= 7 { out.append(UInt8(acc & 0x7F)); acc >>= 7; nb -= 7 }
        }
        if nb > 0 { out.append(UInt8(acc & 0x7F)) }
        return out
    }

    public static func unpack7(_ s: some Sequence<UInt8>) -> [UInt8] {
        var out: [UInt8] = [], acc: UInt32 = 0, nb: UInt32 = 0
        for b in s {
            acc |= UInt32(b & 0x7F) << nb; nb += 7
            while nb >= 8 { out.append(UInt8(acc & 0xFF)); acc >>= 8; nb -= 8 }
        }
        return out
    }

    static func checksum(_ d: some Sequence<UInt8>) -> UInt8 { ~d.reduce(UInt8(0), &+) }

    /// The answer to a read request: 00 59 30 len16 0 fl addr32 len24 data ~sum, packed.
    static func response(addr: Int, data: some Collection<UInt8>, flags: UInt8 = 0) -> [UInt8] {
        let n = data.count
        var body: [UInt8] = [0x00, 0x59, 0x30, UInt8((n + 8) & 0xFF), UInt8(((n + 8) >> 8) & 0xFF), 0, flags,
                             UInt8(addr & 0xFF), UInt8((addr >> 8) & 0xFF), UInt8((addr >> 16) & 0xFF), UInt8((addr >> 24) & 0xFF),
                             UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF), 0]
        body += data
        body.append(checksum(body[6...]))
        return [0xF0] + pack7(body) + [0xF7]
    }

    /// A read request from the device: (flags, address, length), or nil.
    static func parseRequest(_ pkt: [UInt8]) -> (flags: UInt8, addr: Int, len: Int)? {
        guard pkt.count >= 2, pkt.first == 0xF0, pkt.last == 0xF7 else { return nil }
        let u = unpack7(pkt[1..<(pkt.count - 1)])
        guard u.count == 15, u[0] == 0, u[1] == 0x59, u[2] == 0x30, checksum(u[6..<14]) == u[14] else { return nil }
        let addr = Int(u[7]) | Int(u[8]) << 8 | Int(u[9]) << 16 | Int(u[10]) << 24
        return (u[6], addr, Int(u[11]) | Int(u[12]) << 8 | Int(u[13]) << 16)
    }

    static func parseIdentity(_ pkt: [UInt8]) -> DeviceIdentity? {
        guard pkt.count >= 2, pkt.first == 0xF0, pkt.last == 0xF7 else { return nil }
        let d = unpack7(pkt[1..<(pkt.count - 1)])
        guard d.count == 34, d[0] == 0, d[1] == 0x59, d[2] == 0x11 else { return nil }
        var raw = Array(d[6..<33])
        while raw.last == 0 { raw.removeLast() }
        // printable ASCII only: bytes from the device are never shown as anything else
        return DeviceIdentity(String(raw.map { (32..<127).contains($0) ? Character(Unicode.Scalar($0)) : "?" }))
    }

    /// Two identities name the same model, "ota-" aside.
    public static func sameModel(_ a: String, _ b: String) -> Bool {
        func m(_ s: String) -> String { let x = s.split(separator: "_").first.map(String.init) ?? s; return x.hasPrefix("ota-") ? String(x.dropFirst(4)) : x }
        return m(a) == m(b)
    }

    /// A loader Jib finishes a write with: Skiff's (7xx) or Felucca's and SLOOP's (9xx). M-VAVE's update mode and any
    /// other firmware's are left to their own updater: their image layout may differ (SLOOP's rule, widened to Skiff).
    public static func isResumable(loader: DeviceIdentity) -> Bool {
        loader.text.range(of: #"^ota-FM-1_[79]\d\d$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The identity M-VAVE's update loader answers with, from the record Skiff's, SLOOP's and the stock step 1 write.
    public static let officialLoader = "ota-FM-1_015"

    /// The loader that writes `pkg`: M-VAVE's for the stock V15 (and only that file), a Felucca-family loader for the
    /// others. A write is only ever finished by the loader that belongs to the package.
    public static func writes(_ pkg: FirmwarePackage, loader id: DeviceIdentity) -> Bool {
        guard id.isLoader else { return false }
        return pkg.isOfficial ? id.text == officialLoader : isResumable(loader: id) && sameModel(id.text, pkg.product)
    }

    public static func mayBeFM1(portName: String) -> Bool {
        portName.range(of: portPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: Finding the device

    public struct Device: @unchecked Sendable {
        public let link: UpdateLink
        public let id: DeviceIdentity
        public let name: String
    }

    func handshake(_ link: UpdateLink, tries: Int = 2) async -> DeviceIdentity? {
        link.drain()
        for _ in 0..<tries {
            guard link.send(Self.hsQuery) else { return nil }
            let end = ContinuousClock.now + delays.handshake
            while ContinuousClock.now < end {
                guard let p = await link.read(timeout: end - ContinuousClock.now) else { break }
                if let id = Self.parseIdentity(p) { return id }
            }
        }
        return nil
    }

    /// The first FM-1 port that answers the handshake with an FM-1 identity (and `want`). Ports whose names aren't
    /// an FM-1's are never opened.
    public func find(_ want: ((DeviceIdentity) -> Bool)? = nil) async -> Device? {
        for name in ports.inputNames() where Self.mayBeFM1(portName: name) {
            guard let link = try? ports.open(name) else { continue }
            if let id = await handshake(link), Self.sameModel(id.text, Self.model), want?(id) ?? true {
                return Device(link: link, id: id, name: name)
            }
            link.close()
        }
        return nil
    }

    /// What's plugged in, for the app's offer: the identity, the link closed again.
    public func probe() async -> DeviceIdentity? {
        guard let d = await find() else { return nil }
        d.link.close()
        return d.id
    }

    func waitFor(_ want: @escaping (DeviceIdentity) -> Bool, _ limit: Duration) async throws -> Device? {
        let end = ContinuousClock.now + limit
        while ContinuousClock.now < end {
            try checkCancelled()
            if let d = await find(want) { return d }
            try await Task.sleep(for: delays.retry)
        }
        return nil
    }

    /// Stops between requests; the device stays where it was (update mode, if the write had begun).
    public func cancel() { cancelLock.lock(); cancelled = true; cancelLock.unlock() }
    private func checkCancelled() throws {
        cancelLock.lock(); defer { cancelLock.unlock() }
        if cancelled || Task.isCancelled { throw InstallError(code: .cancelled, message: "Stopped.") }
    }

    // MARK: Serving

    struct Served { var served = 0, finished = false, lost = false }

    /// Answers read requests until the device asks for `finish`.
    func serve(_ link: UpdateLink, image: [UInt8], finish: Int, idle: Duration,
               progress: (Int, Int, Int) -> Void) async throws -> Served {
        var s = Served(), last = ContinuousClock.now
        while true {
            try checkCancelled()
            guard let pkt = await link.read(timeout: delays.poll) else {
                if link.lost { s.lost = true; return s }
                if ContinuousClock.now - last > idle { return s }
                continue
            }
            guard let r = Self.parseRequest(pkt) else { continue }
            last = ContinuousClock.now
            if r.addr == Self.finishCheck || r.addr == Self.finishWrite {
                _ = link.send(Self.response(addr: r.addr, data: Array("success".utf8) + [0]))
                if r.addr == finish { s.finished = true; return s }
                continue
            }
            guard r.len <= Self.maxData, r.addr >= 0, r.addr + r.len <= image.count else {
                throw InstallError(code: .badRequest, message: "The FM-1 asked for bytes outside the package (\(String(r.addr, radix: 16))+\(r.len)).",
                                   served: s.served)
            }
            try await Task.sleep(for: delays.reply)
            guard link.send(Self.response(addr: r.addr, data: image[r.addr..<(r.addr + r.len)], flags: r.flags)) else {
                s.lost = true; return s
            }
            s.served += 1
            progress(s.served, r.addr, r.len)
        }
    }

    // MARK: The install

    /// Step 1: the running firmware checks the package and starts the loader.
    func check(_ dev: Device, _ pkg: FirmwarePackage, _ step: (InstallStep) -> Void) async throws -> Device {
        step(.start(dev.id.text))
        _ = dev.link.send(Self.upgrade)
        try await Task.sleep(for: delays.start)
        let s = try await serve(dev.link, image: pkg.image, finish: Self.finishCheck, idle: delays.idleCheck) { k, _, _ in step(.check(k)) }
        dev.link.close()
        guard s.finished else {
            // (ota.c: the header's 2 reads and the loader's head, then the 32 reads of the 16 KiB head; a head unlike
            // the unit's stops it there, as Skiff's web/fm1ota.js stockRefusal reads it)
            if pkg.isOfficial, !s.lost, (4...35).contains(s.served) {
                throw InstallError(code: .otherStock, message: Self.otherStockMessage, served: s.served)
            }
            throw InstallError(code: s.lost ? .lost : .stopped,
                               message: s.lost ? "The FM-1 dropped off USB while it checked the firmware file." : "The FM-1 stopped asking for the firmware file partway through the check.",
                               served: s.served)
        }
        step(.loader)
        try await Task.sleep(for: delays.loader)
        guard let ota = try await waitFor({ Self.writes(pkg, loader: $0) }, delays.waitLoader) else {
            throw InstallError(code: .noLoader, message: "The update loader didn't appear.", inUpdateMode: true)
        }
        return ota
    }

    /// Step 2: the loader reads and writes the whole package, then restarts.
    func write(_ ota: Device, _ pkg: FirmwarePackage, _ step: (InstallStep) -> Void) async throws {
        step(.write(0))
        _ = ota.link.send(Self.upgrade)
        try await Task.sleep(for: delays.start)
        var meter = WriteMeter(span: pkg.flashSpan, size: pkg.image.count)
        let s = try await serve(ota.link, image: pkg.image, finish: Self.finishWrite, idle: delays.idleWrite) { _, addr, n in
            step(.write(meter.add(addr, n)))
        }
        ota.link.close()
        guard s.finished else {
            throw InstallError(code: s.lost ? .lost : .stopped,
                               message: s.lost ? "The FM-1 dropped off USB during the write." : "The FM-1 stopped asking for data during the write.",
                               served: s.served, inUpdateMode: true)
        }
        step(.write(100))
    }

    func verify(_ pkg: FirmwarePackage, _ step: (InstallStep) -> Void) async throws -> String {
        step(.reboot)
        try await Task.sleep(for: delays.reboot)
        guard let back = try await waitFor({ !$0.isLoader && Self.sameModel($0.text, pkg.product) }, delays.waitReboot) else {
            throw InstallError(code: .noReturn, message: "The FM-1 didn't come back after the write.")
        }
        back.link.close()
        guard back.id.text == pkg.product else {
            throw InstallError(code: .mismatch, message: "Written, but the FM-1 reports \(back.id.text) (expected \(pkg.product)).")
        }
        step(.done(back.id.text))
        return back.id.text
    }

    static let otherStockMessage = "Nothing was written. This FM-1 started out on a different official version (V16, probably), so V15 can't go on it. Its way back is that version, with M-VAVE's own updater."

    /// Running firmware → loader → new firmware; or, when the FM-1 is already in the package's update loader, the
    /// write alone. A write cut off is resumed when the loader answers again within `waitResume`.
    @discardableResult
    public func install(_ pkg: FirmwarePackage, step: @escaping (InstallStep) -> Void = { _ in }) async throws -> String {
        cancelLock.withLock { cancelled = false }
        let dev = await find { Self.sameModel($0.text, pkg.product) }
        guard let dev else {
            throw InstallError(code: .notFound, message: "No FM-1 found. Plug it straight into this device with a USB data cable, and close other music apps.")
        }
        if dev.id.isLoader, !Self.writes(pkg, loader: dev.id) {
            dev.link.close()
            let which = BundledFirmware.matching(identity: dev.id.text).map { "\($0.title)'s" } ?? "another firmware's"
            let finish = Self.isResumable(loader: dev.id) || dev.id.text == Self.officialLoader
                ? "Finish that install first, then choose this one." : "Finish that update with its own updater first."
            throw InstallError(code: .foreignLoader,
                               message: "The FM-1 is in \(which) update mode (\(dev.id.text)). \(finish)", inUpdateMode: true)
        }
        // a unit already on a newer stock version has that version's head: V15's loader would write V15's over it
        if pkg.isOfficial, !dev.id.isLoader, dev.id.text.range(of: #"^FM-1_0\d\d$"#, options: .regularExpression) != nil,
           dev.id.version > 15 {
            dev.link.close()
            throw InstallError(code: .otherStock, message: Self.otherStockMessage)
        }
        var ota = dev.id.isLoader ? dev : try await check(dev, pkg, step)
        for attempt in 1...resumeMax {
            do {
                try await write(ota, pkg, step)
                break
            } catch let e as InstallError where (e.code == .lost || e.code == .stopped) && attempt < resumeMax {
                step(.dropped)
                guard let back = try await waitFor({ Self.writes(pkg, loader: $0) }, delays.waitResume) else { throw e }
                step(.resume(attempt + 1))
                ota = back
            }
        }
        return try await verify(pkg, step)
    }
}

/// Step 2's percentage, forward only, from the flash.bin bytes served. Felucca's and Skiff's loaders read flash.bin
/// twice, upward: a check pass, then the write without the 16 KiB head. M-VAVE's reads it once, downward. The first
/// reads past the head tell which; until then it shows 0.
struct WriteMeter {
    let span: (off: Int, size: Int)?
    let size: Int
    var done = 0, total: Int? = nil, pct = 0, seen: [Int] = []

    init(span: (off: Int, size: Int)?, size: Int) { self.span = span; self.size = size }

    mutating func add(_ addr: Int, _ n: Int) -> Int {
        let p: Int
        if let span {
            guard addr >= span.off, addr < span.off + span.size else { return pct }
            done += n
            let o = addr - span.off
            if total == nil, o >= 0x4000, seen.last != o {
                seen.append(o)
                if seen.count > 8 {
                    let up = zip(seen, seen.dropFirst()).filter { $1 > $0 }.count
                    total = up * 2 > 8 ? 2 * span.size - 0x4000 : span.size
                }
            }
            p = total.map { done * 100 / $0 } ?? 0
        } else {
            p = (addr + n) * 100 / max(size, 1)
        }
        pct = max(pct, min(99, p))
        return pct
    }
}

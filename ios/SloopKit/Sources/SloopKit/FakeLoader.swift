// A pretend FM-1 for the installer: the device side of both update steps, as the firmware plays them.
// Step 1 follows Skiff's firmware/src/ota.c (ota_stage, an own Felucca loader): the UFW header in two 512-byte
// reads, flash.bin's size checked (0x93000), the loader's head read and checked for FELUCCA-LOADER-1, read again,
// its body in 512-byte reads checked against its CRC, then 0xE0000000 asked up to 4 times; on "success" it
// restarts into the loader. Step 2 follows firmware/loader/ldr_core.c (ldr_session): the header, the app head
// (32 bytes), the whole flash.bin once (its CRC checked before anything is erased), then the app area sector by
// sector from 0x5000 up and 0x4000 last (sectors already equal are skipped, the app's header erased before the first
// changed one), then 0xF0000000; it restarts into the new firmware. Each device read is tried 3 times, 5 s each.
// M-VAVE's package (stock V15) takes ota.c's other branch in step 1: the official loader is recognised by its CRCs and
// length, flash.bin's 16 KiB head is read in 32 reads and compared with the unit's (stopping at the first difference),
// and the record names "ota-FM-1_015". Its step 2 plays M-VAVE's loader as Skiff's tests do: the header, then flash.bin
// once, downward, each 4 KiB sector written as it completes, the head's sector last, then 0xF0000000.
// What it doesn't do: the chip-key check (it reads the 32 bytes, no key), and anything M-VAVE's loader does beyond
// flash.bin (V15's package has a resource entry for 0xEA000; whether that loader writes it isn't public).
import Foundation

public final class FakeFM1: UpdatePorts, @unchecked Sendable {
    /// Something to go wrong, once, counted in reads answered within a step.
    public enum Fault: Equatable, Sendable {
        /// The cable comes out after `reads` answers in step `stage` (1 or 2); with `replugAfter`, it goes back in.
        case unplug(stage: Int, after: Int, replugAfter: Duration?)
        /// The device stops asking after `reads` answers (still on USB, still answering the handshake).
        case stall(stage: Int, after: Int)
        /// After step 1 the loader never shows up on USB.
        case noLoader
        /// The new firmware reports another identity.
        case reports(String)
    }

    static let flashLen = 0x93000, appLo = 0x4000, sectors = (0x93000 - 0x4000) >> 12
    /// M-VAVE's V16 flash.bin: ota.c lets its size through for the official loader only.
    static let flashLenV16 = 0xA9000
    /// The USB name M-VAVE's loader gets here. Not seen on a device: the real one may be named otherwise (the port
    /// filter's "composite" / "usb-midi" / "sinco" are the stock names SLOOP's installer knows).
    public static let officialLoaderPort = "FM-1"

    /// V15's 16 KiB head, as an FM-1 that shipped with V15 has it (no firmware but M-VAVE's ever writes it).
    static let v15Head: [UInt8] = {
        guard let p = try? BundledFirmware.stock.load(), let s = p.flashSpan else { return [UInt8](repeating: 0x5A, count: 0x4000) }
        return Array(p.image[s.off..<(s.off + 0x4000)])
    }()

    private let lock = NSLock()
    private var gen = 0
    private var links: [FakeUpdateLink] = []
    public private(set) var connected = true
    /// The identity it answers the handshake with, and its USB name.
    public private(set) var identity: String
    public private(set) var portName: String
    /// The update record: the loader staged in step 1 waits for a write (the identity it answers with).
    public private(set) var record: String?
    /// The app area the device holds (flash.bin [0x4000, 0x93000)), and the identity it reports when it runs.
    private var app: [UInt8]
    private var appIdentity: String?
    /// flash [0, 0x4000): the boot head, from the stock version the unit started on (V16's differs from V15's).
    private var head: [UInt8]
    /// Packages it recognises: the first 1 KiB of the image (the header it reads first) and the app area.
    private var known: [(header: ArraySlice<UInt8>, app: ArraySlice<UInt8>, product: String)] = []
    public var faults: [Fault] = []
    /// Other gear on the same MIDI setup: names only. Opening one is recorded in `opened`.
    public var otherPorts: [String] = []
    public private(set) var opened: [String] = []
    /// What was sent to the other gear's ports that were opened (names that might be an FM-1's).
    private(set) var otherLinks: [String: SilentLink] = [:]
    /// Every frame the host sent, with the identity the device had then.
    public private(set) var received: [(identity: String, frame: [UInt8])] = []
    /// Answers that didn't match the package (wrong bytes, checksum, length).
    public private(set) var badAnswers = 0
    /// Answers to another address than the one it waits on (a late answer to a request it asked again).
    public private(set) var strayAnswers = 0
    public private(set) var stats = (check: 0, write: 0, sectorsWritten: 0)
    /// Device timing (its 5 s read timeout, the restart) is multiplied by this.
    public var timeScale = 1.0
    private var session: Task<Void, Never>?
    private var pending: (addr: Int, len: Int, cont: CheckedContinuation<[UInt8]?, Never>)?
    private var stageReads = 0
    private var stage = 0

    /// An FM-1 running `running` (a package it was installed from), or the stock firmware when nil. `startedOn`: the
    /// stock version it shipped with or was first updated to, whose head it keeps (15, or 16).
    public init(running: FirmwarePackage?, stockIdentity: String = "FM-1_015", startedOn: Int = 15) {
        if let p = running, let span = p.flashSpan {
            app = Array(p.image[(span.off + Self.appLo)..<(span.off + span.size)])
            identity = p.product
            known.append((p.image[0..<1024], app[...], p.product))
        } else {
            app = (0..<(Self.flashLen - Self.appLo)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }
            identity = stockIdentity
            known.append(([], app[...], stockIdentity))
        }
        portName = Self.port(running: identity)
        head = Self.v15Head
        if startedOn != 15 { for i in stride(from: 0x200, to: 0x4000, by: 0x400) { head[i] ^= 0xA5 } }   // another head
        appIdentity = identity
    }

    /// An FM-1 left in `loader`'s update mode by a write that was cut off (its app header gone). For the stock V15,
    /// M-VAVE's loader.
    public convenience init(inLoaderOf pkg: FirmwarePackage, was running: FirmwarePackage?) {
        self.init(running: running)
        record = pkg.isOfficial ? FirmwareInstaller.officialLoader : "ota-" + pkg.product
        appIdentity = nil
        boot()
    }

    static func port(running identity: String) -> String { identity.hasPrefix("FM-1_0") ? "FM-1" : "Felucca" }

    /// Packages whose app area it should recognise once written (the ones the test installs).
    public func knows(_ pkgs: FirmwarePackage...) {
        lock.lock(); defer { lock.unlock() }
        for p in pkgs { if let s = p.flashSpan { known.append((p.image[0..<1024], p.image[(s.off + Self.appLo)..<(s.off + s.size)], p.product)) } }
    }

    // MARK: UpdatePorts

    public func inputNames() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return otherPorts + (connected ? [portName] : [])
    }

    public func open(_ name: String) throws -> UpdateLink {
        lock.lock(); defer { lock.unlock() }
        opened.append(name)
        if otherPorts.contains(name) { let l = SilentLink(); otherLinks[name] = l; return l }
        guard connected, name == portName else { throw CocoaError(.fileNoSuchFile) }
        let l = FakeUpdateLink(device: self, gen: gen)
        links.append(l)
        return l
    }

    func isLost(gen g: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return g != gen || !connected }

    // MARK: Power

    /// Unplugs it: every link is lost, the session stops where it was.
    public func unplug() {
        lock.lock()
        connected = false
        gen += 1
        links = []
        session?.cancel(); session = nil
        let p = pending; pending = nil
        lock.unlock()
        p?.cont.resume(returning: nil)
    }

    /// Plugs it back in (power on): the loader when an update record waits, else the app.
    public func replug() {
        lock.lock(); defer { lock.unlock() }
        guard !connected else { return }
        bootLocked()
    }

    private func boot() { lock.lock(); bootLocked(); lock.unlock() }

    private func bootLocked() {
        gen += 1
        links = []
        connected = true
        stage = 0
        if let r = record {
            identity = r; portName = r == FirmwareInstaller.officialLoader ? Self.officialLoaderPort : "Felucca Update"
        } else if let a = appIdentity {
            identity = a; portName = Self.port(running: a)
        } else {
            identity = ""; portName = "WL82 UBOOT1.00"         // no app, no record: the chip's boot mode (never expected)
        }
    }

    /// The device restarts: off USB for a moment, then back as whatever it boots into.
    private func restart(hidden: Bool = false) {
        let delay = 0.05 * timeScale
        unplug()
        guard !hidden else { return }
        Task { try? await Task.sleep(for: .seconds(delay)); self.replug() }
    }

    // MARK: Wire

    func tx(_ frame: [UInt8], gen g: Int) {
        lock.lock()
        let to = links.filter { $0.gen == g && !$0.closed }
        lock.unlock()
        for l in to { l.queue.put(frame) }
    }

    private func identityFrame() -> [UInt8] {
        let t = Array(identity.utf8.prefix(27))
        return [0xF0] + FirmwareInstaller.pack7([0, 0x59, 0x11, 0, 0, 0] + t + [UInt8](repeating: 0, count: 28 - t.count)) + [0xF7]
    }

    func rx(_ frame: [UInt8], gen g: Int) {
        lock.lock()
        guard g == gen, connected else { lock.unlock(); return }
        received.append((identity, frame))
        if frame == FirmwareInstaller.hsQuery {
            let f = identityFrame()
            lock.unlock()
            tx(f, gen: g)
            return
        }
        if frame == FirmwareInstaller.upgrade {
            guard session == nil, !identity.isEmpty else { lock.unlock(); return }
            let loader = identity.hasPrefix("ota-")
            stage = loader ? 2 : 1
            stageReads = 0
            session = Task { [weak self] in
                guard let self else { return }
                if !loader { await self.checkSession(gen: g) }
                else if self.identity == FirmwareInstaller.officialLoader { await self.officialWriteSession(gen: g) }
                else { await self.writeSession(gen: g) }
            }
            lock.unlock()
            return
        }
        // an answer to the read the device is waiting on
        guard let p = pending else { lock.unlock(); return }
        let u = FirmwareInstaller.unpack7(frame.dropFirst().dropLast())
        // (ota_read takes only the answer to its own request: a late answer to one it asked again is ignored)
        guard u.count >= 15, u[0] == 0, u[1] == 0x59, u[2] == 0x30,
              Int(u[7]) | Int(u[8]) << 8 | Int(u[9]) << 16 | Int(u[10]) << 24 == p.addr else {
            strayAnswers += 1; lock.unlock(); return
        }
        guard u.count == p.len + 15, Int(u[11]) | Int(u[12]) << 8 == p.len else { badAnswers += 1; lock.unlock(); return }
        if FirmwareInstaller.checksum(u[6..<(14 + p.len)]) != u[14 + p.len] { badAnswers += 1; lock.unlock(); return }
        pending = nil
        stageReads += 1
        let fault = faultNow()
        lock.unlock()
        p.cont.resume(returning: Array(u[14..<(14 + p.len)]))
        switch fault {
        case .unplug(_, _, let back)?:
            unplug()
            if let back { Task { try? await Task.sleep(for: back); self.replug() } }
        default: break
        }
    }

    /// The fault due now (lock held), taken off the list.
    private func faultNow() -> Fault? {
        guard let i = faults.firstIndex(where: {
            switch $0 {
            case .unplug(let s, let n, _): s == stage && stageReads >= n
            default: false
            }
        }) else { return nil }
        return faults.remove(at: i)
    }

    private var stalled = false

    /// One read request: 3 tries, 5 s each (scaled); nil when nothing came.
    private func read(_ addr: Int, _ len: Int, gen g: Int) async -> [UInt8]? {
        for _ in 0..<3 {
            if lock.withLock({ stalled || g != gen }) || Task.isCancelled { return nil }
            var q: [UInt8] = [0, 0x59, 0x30, 8, 0, 0, 0]
            q += [UInt8(addr & 0xFF), UInt8((addr >> 8) & 0xFF), UInt8((addr >> 16) & 0xFF), UInt8((addr >> 24) & 0xFF),
                  UInt8(len & 0xFF), UInt8(len >> 8), 0]
            q.append(FirmwareInstaller.checksum(q[6...]))
            let got: [UInt8]? = await withCheckedContinuation { c in
                lock.lock()
                pending = (addr, len, c)
                lock.unlock()
                tx([0xF0] + FirmwareInstaller.pack7(q) + [0xF7], gen: g)
                let wait = 5.0 * timeScale
                Task {
                    try? await Task.sleep(for: .seconds(wait))
                    let p: (addr: Int, len: Int, cont: CheckedContinuation<[UInt8]?, Never>)? = self.lock.withLock {
                        guard let p = self.pending, p.addr == addr, p.len == len else { return nil }
                        self.pending = nil
                        return p
                    }
                    p?.cont.resume(returning: nil)
                }
            }
            if let got {
                lock.withLock {
                    // a stall due now: the device asks nothing more this session
                    let due = { (f: Fault) -> Bool in if case .stall(let s, let n) = f { s == self.stage && self.stageReads >= n } else { false } }
                    if faults.contains(where: due) { faults.removeAll(where: due); stalled = true }
                }
                return got
            }
        }
        return nil
    }

    private func endSession() { lock.lock(); session = nil; stalled = false; lock.unlock() }

    /// The UFW header: flash.bin and ota.bin (offset, length), or nil (refused).
    private func header(gen g: Int) async -> (flOff: Int, flLen: Int, flCRC: Int, otaOff: Int, otaLen: Int, raw: [UInt8])? {
        guard let a = await read(0, 512, gen: g), let b = await read(512, 512, gen: g) else { return nil }
        let raw = a + b
        let hdr = FirmwarePackage.jlEnc(raw[0..<0x40])
        let nent = FirmwarePackage.u16(hdr, 8)
        guard FirmwarePackage.crc16(hdr[2..<0x40]) == UInt16(FirmwarePackage.u16(hdr, 0)), (1...11).contains(nent),
              FirmwarePackage.crc16(raw[0x40..<(0x40 + nent * 0x50)]) == UInt16(FirmwarePackage.u16(hdr, 2)) else { return nil }
        var r = (flOff: 0, flLen: 0, flCRC: 0, otaOff: 0, otaLen: 0, raw: raw)
        for i in 0..<nent {
            let e = FirmwarePackage.jlEnc(raw[(0x40 + i * 0x50)..<(0x90 + i * 0x50)])
            switch FirmwarePackage.u16(e, 0) {
            case 0: r.flOff = FirmwarePackage.u32(e, 8); r.flLen = FirmwarePackage.u32(e, 12); r.flCRC = FirmwarePackage.u16(e, 4)
            case 100: r.otaOff = FirmwarePackage.u32(e, 8); r.otaLen = FirmwarePackage.u32(e, 12)
            default: break
            }
        }
        return r
    }

    /// Step 1 (ota.c ota_stage, Felucca's own loader or the official one). Returns quietly on any refusal: the
    /// firmware carries on.
    private func checkSession(gen g: Int) async {
        defer { endSession() }
        guard let h = await header(gen: g), h.flOff > 0, h.otaOff > 0, [Self.flashLen, Self.flashLenV16].contains(h.flLen) else { return }
        guard let head = await read(h.otaOff, 512, gen: g) else { return }
        let len = FirmwarePackage.u32(head, 8)
        let own = (0x48..<(0x48 + 48)).contains { FirmwarePackage.contains(Array(head[$0..<($0 + 16)]), FirmwarePackage.loaderMark) }
        let ol = FirmwarePackage.officialLoader
        let official = FirmwarePackage.u16(head, 0) == ol.hcrc && FirmwarePackage.u16(head, 2) == ol.dcrc && len == ol.len
        guard FirmwarePackage.crc16(head[2..<32]) == UInt16(FirmwarePackage.u16(head, 0)), FirmwarePackage.u32(head, 4) == 0x20,
              head[12] == 0x41, h.otaLen == len + 0x20, len <= 0x5000 - 0x200, own || official else { return }
        guard official || h.flLen == Self.flashLen else { return }
        if official {               // the official loader writes the head: it must equal the unit's
            for i in stride(from: 0, to: 0x4000, by: 512) {
                guard let b = await read(h.flOff + i, 512, gen: g) else { return }
                guard lock.withLock({ b.elementsEqual(self.head[i..<(i + 512)]) }) else { return }
            }
        }
        guard let again = await read(h.otaOff, 512, gen: g) else { return }
        let want = UInt16(FirmwarePackage.u16(again, 2))
        var crc: UInt16 = 0, i = 0
        while i < len {
            let n = min(512, len - i)
            guard let b = await read(h.otaOff + 0x20 + i, n, gen: g) else { return }
            crc = FirmwarePackage.crc16(b, crc)
            i += n
        }
        guard crc == want else { return }
        lock.withLock { stats.check += stageReads }
        for _ in 0..<4 {
            if let s = await read(FirmwareInstaller.finishCheck, 8, gen: g), s == Array("success".utf8) + [0] {
                // the update record, then the restart into the loader (its identity: "ota-" + the package's)
                let hide = lock.withLock {
                    // (a real loader carries its identity compiled in, FELUCCA_ID: here, that of the package it came from)
                    record = official ? FirmwareInstaller.officialLoader
                        : "ota-" + (known.first { !$0.header.isEmpty && $0.header.elementsEqual(h.raw) }?.product ?? "FM-1_700")
                    return faults.contains(.noLoader)
                }
                endSession()
                restart(hidden: hide)
                return
            }
        }
    }

    /// Step 2 by M-VAVE's loader (as Skiff's tests play it): the header, flash.bin once from the top down, each 4 KiB
    /// sector written when its lowest read arrives (the head's last; the app no longer starts once the first changed
    /// sector is written), then 0xF0000000. (Whether it checks flash.bin's CRC, and when, isn't public: not played.)
    private func officialWriteSession(gen g: Int) async {
        defer { endSession() }
        guard let h = await header(gen: g), h.flOff > 0, h.flLen > Self.appLo, h.flLen <= Self.flashLenV16,
              h.flLen % 0x1000 == 0 else { return }
        var flash = [UInt8](repeating: 0xFF, count: h.flLen), i = h.flLen
        while i > 0 {
            let n = min(512, i)
            i -= n
            guard let b = await read(h.flOff + i, n, gen: g) else { return }
            flash.replaceSubrange(i..<(i + n), with: b)
            guard i & 0xFFF == 0 else { continue }
            let sec = flash[i..<(i + 0x1000)]
            lock.withLock {
                if i < Self.appLo {
                    head.replaceSubrange(i..<(i + 0x1000), with: sec)
                } else if i < Self.flashLen, !app[(i - Self.appLo)..<(i - Self.appLo + 0x1000)].elementsEqual(sec) {
                    app.replaceSubrange((i - Self.appLo)..<(i - Self.appLo + 0x1000), with: sec)
                    appIdentity = nil
                    stats.sectorsWritten += 1
                }
            }
        }
        for _ in 0..<4 { if await read(FirmwareInstaller.finishWrite, 8, gen: g) != nil { break } }
        guard !isLost(gen: g) else { return }      // the power went: the record stays, the loader runs again
        lock.withLock {
            stats.write += stageReads
            record = nil
            let reported = faults.compactMap { if case .reports(let s) = $0 { s } else { nil } }.first
            appIdentity = reported ?? known.first { $0.app.elementsEqual(app) }?.product ?? "FM-1_999"
        }
        endSession()
        restart()
    }

    /// Step 2 (ldr_core.c ldr_session).
    private func writeSession(gen g: Int) async {
        defer { endSession() }
        guard let h = await header(gen: g), h.flOff > 0, h.flLen == Self.flashLen else { return }
        guard await read(h.flOff + Self.appLo, 32, gen: g) != nil else { return }      // the app head (chip-key check)
        // 2b. the whole flash.bin, its CRC checked before anything is erased; each app sector's CRC kept
        var crc: UInt16 = 0, sc = [UInt16](repeating: 0, count: Self.sectors), i = 0
        while i < h.flLen {
            let n = min(512, h.flLen - i)
            guard let b = await read(h.flOff + i, n, gen: g) else { return }
            crc = FirmwarePackage.crc16(b, crc)
            if i >= Self.appLo { let k = (i - Self.appLo) >> 12; sc[k] = FirmwarePackage.crc16(b, i & 0xFFF != 0 ? sc[k] : 0) }
            i += n
        }
        guard Int(crc) == h.flCRC else { return }
        // 3. the app area, 0x5000 up and 0x4000 last; the header goes first
        var headGone = false
        for n in 1...Self.sectors {
            let s = Self.appLo + (n % Self.sectors) * 0x1000
            var sec: [UInt8] = []
            for k in stride(from: 0, to: 0x1000, by: 512) {
                guard let b = await read(h.flOff + s + k, 512, gen: g) else { return }
                sec += b
            }
            guard FirmwarePackage.crc16(sec) == sc[(s - Self.appLo) >> 12] else { return }
            let at = s - Self.appLo
            lock.withLock {
            if !app[at..<(at + 0x1000)].elementsEqual(sec) {
                if !headGone, s != Self.appLo {
                    for j in 0..<0x1000 { app[j] = 0xFF }
                    appIdentity = nil
                    headGone = true
                }
                app.replaceSubrange(at..<(at + 0x1000), with: sec)
                stats.sectorsWritten += 1
            }
            }
        }
        // 4. the host confirms, the record goes, the new app starts
        for _ in 0..<4 { if await read(FirmwareInstaller.finishWrite, 8, gen: g) != nil { break } }
        guard !isLost(gen: g) else { return }      // the power went: the record stays, the loader runs again
        lock.withLock {
            stats.write += stageReads
            record = nil
            let reported = faults.compactMap { if case .reports(let s) = $0 { s } else { nil } }.first
            appIdentity = reported ?? known.first { $0.app.elementsEqual(app) }?.product ?? "FM-1_999"
        }
        endSession()
        restart()
    }
}

final class FakeUpdateLink: UpdateLink, @unchecked Sendable {
    weak var device: FakeFM1?
    let gen: Int
    let queue = FrameQueue()
    private(set) var closed = false

    init(device: FakeFM1, gen: Int) { self.device = device; self.gen = gen }

    var lost: Bool { device?.isLost(gen: gen) ?? true }

    func send(_ frame: [UInt8]) -> Bool {
        guard let d = device, !closed, !lost else { return false }
        d.rx(frame, gen: gen)
        return true
    }

    func read(timeout: Duration) async -> [UInt8]? { await queue.read(timeout: timeout) }
    func drain() { queue.drain() }
    func close() { closed = true }
}

/// Another device's port: answers nothing (the tests check it is never even opened).
final class SilentLink: UpdateLink, @unchecked Sendable {
    private(set) var sent: [[UInt8]] = []
    func send(_ frame: [UInt8]) -> Bool { sent.append(frame); return true }
    func read(timeout: Duration) async -> [UInt8]? { try? await Task.sleep(for: timeout); return nil }
    func drain() {}
    var lost: Bool { false }
    func close() {}
}

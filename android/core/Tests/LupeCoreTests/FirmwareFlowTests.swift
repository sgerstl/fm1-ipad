import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The phone's firmware install (decision 42; Firmware.swift) against SloopKit's fake FM-1 (FakeLoader.swift, which
/// plays both update steps as Skiff's ota.c and ldr_core.c do): the offer for a stock unit and for a cut-off install,
/// the download handed in and checked against its pin, the two steps, and the refusals. And the link gate's part:
/// who gets the device by its USB name, and the installer taking it from the Session. Offline; no real FM-1.
@Suite(.serialized) @MainActor struct FirmwareFlowTests {
    final class Box { var areas: [FirmwareArea] = []; var notices: [NoticeArea] = []; var log: [String] = []; var holds: [Bool] = [] }
    static let skiff251 = try! LupeFirmware.skiff251.load()
    static let releases = LupeFirmware.skiff251.localCopy!.deletingLastPathComponent()

    func core(_ dev: FakeFM1, _ box: Box, storage: URL, hasRelease: Bool = false) -> PhoneCore {
        // (patient delays, as FirmwareInstallTests' own: a busy Mac must not read as the loader gone)
        var d = FirmwareInstaller.Delays()
        d.start = .milliseconds(5); d.reply = .zero; d.loader = .milliseconds(10); d.reboot = .milliseconds(10)
        d.retry = .milliseconds(20); d.poll = .milliseconds(20); d.handshake = .milliseconds(300)
        d.idleCheck = .seconds(5); d.idleWrite = .seconds(5); d.waitLoader = .seconds(5); d.waitReboot = .seconds(5); d.waitResume = .seconds(3)
        dev.timeScale = 0.2
        dev.knows(Self.skiff251)
        let c = PhoneCore(session: DeviceSession(transport: { nil }),            // nothing an editor could talk to
                          publish: { area, json in
                              if area == "firmware", let a = try? JSONDecoder().decode(FirmwareArea.self, from: Data(json.utf8)) { box.areas.append(a) }
                              if area == "notice", let n = try? JSONDecoder().decode(NoticeArea.self, from: Data(json.utf8)) { box.notices.append(n) }
                          }, log: { box.log.append($0) }, canWrite: { false })
        c.firmwareLink = FirmwareLink(ports: dev, hold: { box.holds.append($0) }, delays: d)
        c.firmwareWatchEvery = .milliseconds(100)
        c.appStorage = storage
        if hasRelease { c.firmwareLocalReleases = Self.releases }
        c.start()
        return c
    }
    func storage() throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("lupe-fw-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    func wait(_ what: String, _ seconds: Double = 30, _ ok: () -> Bool) async throws {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end, !ok() { try await Task.sleep(for: .milliseconds(20)) }
        #expect(ok(), "\(what)")
    }

    @Test func aStockFM1IsOfferedSkiffLupeAndGetsIt() async throws {
        let box = Box(), dir = try storage()
        let dev = FakeFM1(running: nil, stockIdentity: "FM-1_016", startedOn: 16)
        dev.newFlashChip = true
        let c = core(dev, box, storage: dir)
        defer { c.stop() }
        // the offer: it runs stock V16, Lupe can install Skiff-Lupe 2.5.1
        try await wait("offered") { c.firmwareArea().offer?.kind == "install" }
        var a = c.firmwareArea()
        #expect(a.offer?.firmware == "Skiff-Lupe-2.5.1" && a.identity == "FM-1_016" && a.running == "M-VAVE's own firmware, V16" && a.state == "idle")
        #expect(a.offer?.from == "mvave" && a.offer?.key == "mvave|FM-1_016")
        // not confirmed: nothing starts. A low battery off the charger: refused with the reason
        c.handle(json: #"{"intent":"firmwareInstall","which":"Skiff-Lupe-2.5.1"}"#)
        #expect(c.firmwareArea().state == "idle" && box.log.contains { $0.contains("must confirm") })
        c.handle(json: #"{"intent":"firmwareInstall","which":"Skiff-Lupe-2.5.1","confirmed":true,"battery":20,"charging":false}"#)
        #expect(c.firmwareArea().state == "idle" && box.notices.last?.text.hasPrefix("Charge the phone first") == true)
        c.handle(json: #"{"intent":"firmwareInstall","which":"FM-1_015","confirmed":true}"#)
        #expect(c.firmwareArea().state == "idle" && box.notices.last?.text.hasPrefix("Stock V15 can't be installed from the phone") == true)
        // confirmed: the file isn't here yet, so the app is asked to fetch it
        c.handle(json: #"{"intent":"firmwareInstall","which":"Skiff-Lupe-2.5.1","confirmed":true,"battery":80,"charging":false}"#)
        a = c.firmwareArea()
        #expect(a.state == "downloading" && a.download?.sha256 == LupeFirmware.skiff251.sha256 && a.download?.size == 610_429)
        #expect(a.download?.url.hasPrefix("https://github.com/") == true && a.download?.fileName == "Skiff-Lupe-2.5.1.fwsc" && a.offer == nil)
        #expect(dev.received.allSatisfy { $0.frame.count < 16 }, "only the identity question has gone to the FM-1 so far")
        // the wrong file handed in: thrown away, nothing sent
        let wrong = dir.appendingPathComponent("wrong.fwsc")
        try Data(contentsOf: LupeFirmware.skiff.localCopy!).write(to: wrong)
        c.handle(json: #"{"intent":"firmwareFile","which":"Skiff-Lupe-2.5.1","path":"\#(wrong.path)"}"#)
        #expect(c.firmwareArea().state == "failed" && c.firmwareArea().message.contains("isn't the one Lupe was tested with"))
        #expect(box.holds.isEmpty && dev.stats.check == 0 && dev.stats.write == 0)
        c.handle(json: #"{"intent":"firmwareClose"}"#)
        #expect(c.firmwareArea().state == "idle")
        // again, with the right file: both steps, and the FM-1 comes back as Skiff-Lupe 2.5.1
        c.handle(json: #"{"intent":"firmwareInstall","which":"Skiff-Lupe-2.5.1","confirmed":true}"#)
        c.handle(json: #"{"intent":"firmwareDownloadProgress","progress":0.5}"#)
        #expect(c.firmwareArea().state == "downloading" && c.firmwareArea().progress > 0)
        let right = dir.appendingPathComponent("right.fwsc")
        try Data(contentsOf: LupeFirmware.skiff251.localCopy!).write(to: right)
        box.areas.removeAll()
        c.handle(json: #"{"intent":"firmwareFile","which":"Skiff-Lupe-2.5.1","path":"\#(right.path)"}"#)
        try await wait("installed", 90) { ["done", "failed"].contains(c.firmwareArea().state) }
        a = c.firmwareArea()
        #expect(a.state == "done" && a.progress == 1 && a.message.contains("FM-1_725"), "\(a.message)")
        #expect(dev.identity == "FM-1_725" && dev.stats.write > 0)
        // the screens saw each stage, the progress never went back, and the Session was told to let go and take back
        let states = box.areas.map(\.state)
        #expect(states.contains("staging") && states.contains("writing") && states.contains("restarting") && states.last == "done", "\(Set(states))")
        let p = box.areas.map(\.progress)
        #expect(zip(p, p.dropFirst()).allSatisfy { $0 <= $1 }, "progress went back")
        #expect(box.holds == [true, false])
        // the file is kept: the next install needs no download
        #expect(c.firmwareStore().isReady(.skiff251) && !FileManager.default.fileExists(atPath: right.path))
    }

    @Test func anInstallCutOffIsOfferedToFinish() async throws {
        let box = Box(), dir = try storage()
        let dev = FakeFM1(inLoaderOf: Self.skiff251, was: nil)
        let c = core(dev, box, storage: dir, hasRelease: true)
        defer { c.stop() }
        try await wait("offered") { c.firmwareArea().offer?.kind == "finish" }
        let a = c.firmwareArea()
        #expect(a.offer?.firmware == "Skiff-Lupe-2.5.1" && a.running == "update mode" && a.identity == "ota-FM-1_725")
        // "not now" hides it; it isn't offered again while the same FM-1 waits
        c.handle(json: #"{"intent":"firmwareCancelOffer"}"#)
        #expect(c.firmwareArea().offer == nil)
        try await Task.sleep(for: .milliseconds(400))
        #expect(c.firmwareArea().offer == nil)
        // the file is with the build here: no download, straight to the write
        c.handle(json: #"{"intent":"firmwareInstall","which":"Skiff-Lupe-2.5.1","confirmed":true}"#)
        #expect(c.firmwareArea().state != "downloading")
        try await wait("finished", 90) { ["done", "failed"].contains(c.firmwareArea().state) }
        #expect(c.firmwareArea().state == "done" && dev.identity == "FM-1_725", "\(c.firmwareArea().message)")
        #expect(box.holds == [true, false])
    }

    @Test func aCableCutMidWriteIsResumed() async throws {
        let box = Box(), dir = try storage()
        let dev = FakeFM1(running: nil)
        dev.faults = [.unplug(stage: 2, after: 300, replugAfter: .milliseconds(200))]
        let c = core(dev, box, storage: dir, hasRelease: true)
        defer { c.stop() }
        try await wait("offered") { c.firmwareArea().offer != nil }
        c.handle(json: #"{"intent":"firmwareInstall","confirmed":true}"#)
        try await wait("finished", 120) { ["done", "failed"].contains(c.firmwareArea().state) }
        #expect(c.firmwareArea().state == "done" && dev.identity == "FM-1_725", "\(c.firmwareArea().message)")
        #expect(box.areas.contains { $0.state == "resuming" }, "the cut was shown")
    }

    @Test func anotherFirmwaresUpdateModeIsLeftAlone() async throws {
        let box = Box(), dir = try storage()
        let dev = FakeFM1(running: nil, stockIdentity: "ota-FM-1_301")
        let c = core(dev, box, storage: dir, hasRelease: true)
        defer { c.stop() }
        try await wait("said") { c.firmwareArea().offer?.kind == "foreign" }
        #expect(c.firmwareArea().offer?.firmware == nil)
    }

    /// A connected FM-1 (the editor's Session on FakeSkiff) is backed up into the app's storage first, in the
    /// firmware's own backup format, and not while it plays.
    @Test func aConnectedFM1IsBackedUpFirst() async throws {
        let box = Box(), dir = try storage()
        let dev = FakeFM1(running: Self.skiff251)
        var d = FirmwareInstaller.Delays()
        d.start = .milliseconds(5); d.reply = .zero; d.loader = .milliseconds(10); d.reboot = .milliseconds(10)
        d.retry = .milliseconds(20); d.poll = .milliseconds(20); d.handshake = .milliseconds(300)
        d.idleCheck = .seconds(5); d.idleWrite = .seconds(5); d.waitLoader = .seconds(5); d.waitReboot = .seconds(5); d.waitResume = .seconds(3)
        dev.timeScale = 0.2
        dev.knows(Self.skiff251)
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let c = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                          publish: { area, json in
                              if area == "firmware", let a = try? JSONDecoder().decode(FirmwareArea.self, from: Data(json.utf8)) { box.areas.append(a) }
                              if area == "notice", let n = try? JSONDecoder().decode(NoticeArea.self, from: Data(json.utf8)) { box.notices.append(n) }
                          }, log: { box.log.append($0) }, canWrite: { true })
        c.firmwareLink = FirmwareLink(ports: dev, hold: { box.holds.append($0) }, delays: d)
        c.firmwareWatchEvery = .milliseconds(100)
        c.appStorage = dir
        c.firmwareLocalReleases = Self.releases
        c.start()
        defer { c.stop() }
        try await wait("connected") { c.session.isConnected && c.session.skiffSong?.song != nil }
        // the demo FM-1 runs Skiff 2.2 without Lupe's screen link: Skiff-Lupe 2.5.1 is offered (the iPhone's "stockSkiff")
        try await wait("Skiff-Lupe offered") { c.firmwareArea().offer?.kind == "install" }
        #expect(c.firmwareArea().offer?.from == "stockSkiff")
        #expect(c.firmwareArea().offer?.firmware == "Skiff-Lupe-2.5.1" && c.firmwareArea().running?.contains("2.2") == true)
        // playing: refused
        if !fake.playing { c.handle(json: #"{"intent":"play"}"#) }
        try await wait("playing") { c.session.playing }
        c.handle(json: #"{"intent":"firmwareInstall","confirmed":true}"#)
        #expect(c.firmwareArea().state == "idle" && box.notices.last?.text.hasPrefix("Stop playback before installing") == true)
        c.handle(json: #"{"intent":"stop"}"#)
        try await wait("stopped") { !c.session.playing && !fake.playing }
        try await Task.sleep(for: .milliseconds(400))
        // stopped: a backup, then the install
        box.areas.removeAll()
        c.handle(json: #"{"intent":"firmwareInstall","confirmed":true}"#)
        try await wait("finished", 120) { ["done", "failed"].contains(c.firmwareArea().state) }
        let a = c.firmwareArea()
        #expect(a.state == "done", "\(a.message)")
        #expect(box.areas.contains { $0.state == "backingUp" })
        let path = try #require(a.backup)
        #expect(path.hasPrefix(dir.path) && path.hasSuffix(".json"))
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any])
        #expect(json["format"] as? String == "felucca-backup", "\(json.keys)")
        #expect(box.holds == [true, false])
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    /// Stock Skiff 2.6 (2.5.1 plus CAST): it connects as 2.5.1, and Skiff-Lupe is offered as a step back, saying so.
    @Test func aStock26UnitIsOfferedSkiffLupeAsAStepBack() async throws {
        let box = Box(), dir = try storage()
        var fx = try SkiffFixture.load(.v2_5_1)
        let old = Array("FELUCCA v2.5.1".utf8), new = Array("FELUCCA v2.6".utf8)   // (null-terminated)
        let at = try #require(fx.info.indices.first { fx.info[$0...].starts(with: old) })
        fx.info.replaceSubrange(at..<(at + old.count), with: new)
        let fake = FakeSkiff(fx)
        fake.screenLink = false
        var once = false
        let c = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                          publish: { area, json in
                              if area == "firmware", let a = try? JSONDecoder().decode(FirmwareArea.self, from: Data(json.utf8)) { box.areas.append(a) }
                          }, log: { box.log.append($0) }, canWrite: { true })
        let dev = FakeFM1(running: Self.skiff251)
        var d = FirmwareInstaller.Delays()
        d.start = .milliseconds(5); d.reply = .zero; d.handshake = .milliseconds(300); d.poll = .milliseconds(20)
        dev.timeScale = 0.2
        c.firmwareLink = FirmwareLink(ports: dev, hold: { _ in }, delays: d)
        c.firmwareWatchEvery = .milliseconds(100)
        c.appStorage = dir
        c.firmwareLocalReleases = Self.releases
        c.start()
        defer { c.stop() }
        try await wait("connected") { c.session.isConnected }
        #expect(c.session.skiffFirmware == .v2_6)
        try await wait("Skiff-Lupe offered") { c.firmwareArea().offer?.kind == "install" }
        let o = try #require(c.firmwareArea().offer)
        #expect(o.from == "newerSkiff")
        #expect(o.text.contains("goes back from 2.6") && o.text.contains("screen link"), "\(o.text)")
        #expect(o.title == "Get all of Lupe with Skiff-Lupe")
    }

    // MARK: the link gate

    @Test func theGateGivesTheDeviceToTheEditorOrTheInstallerByItsName() async throws {
        final class Sent: @unchecked Sendable { var frames: [[UInt8]] = [] }
        let sent = Sent()
        let gate = LinkGate(send: { sent.frames.append($0) })
        gate.readOnly = true
        // an editor firmware: the Session's
        gate.opened(name: "Hügelton Instruments Felucca")
        #expect(LinkGate.isEditorDevice(name: "Hügelton Instruments Felucca") && gate.makeTransport() != nil)
        #expect(gate.inputNames() == ["Hügelton Instruments Felucca"] && FirmwareInstaller.mayBeFM1(portName: "Hügelton Instruments Felucca"))
        // the update loader and a stock FM-1: never the Session's
        for name in ["Felucca Update", "FM-1", "USB-MIDI"] {
            gate.lost(); gate.opened(name: name)
            #expect(!LinkGate.isEditorDevice(name: name) && gate.makeTransport() == nil, "\(name)")
            #expect(gate.inputNames() == [name])
        }
        // the installer's link: whole SysEx frames both ways, and not through the read-only guard
        gate.lost(); gate.opened(name: "Felucca Update")
        let link = try gate.open("Felucca Update")
        let upgrade: [UInt8] = [0xF0, 0x22, 0x24, 0x35, 0x7F, 0xF7]
        #expect(link.send(upgrade) && sent.frames.last == upgrade)
        let reply: [UInt8] = [0xF0, 0x00, 0x59, 0x11, 0x01, 0x02, 0xF7]
        reply.withUnsafeBytes { gate.bytes($0) }
        #expect(await link.read(timeout: .seconds(2)) == reply)
        gate.lost()
        #expect(link.lost && !link.send(upgrade) && gate.inputNames().isEmpty)
        #expect(throws: (any Error).self) { _ = try gate.open("Felucca Update") }
        // an install on a connected FM-1: the Session's connection ends, the ports stay, and it gets them back after
        gate.opened(name: "Hügelton Instruments Felucca")
        let session = try #require(gate.makeTransport())
        gate.hold(true)
        var ended = true
        for await _ in session.frames { ended = false }
        #expect(ended && gate.makeTransport() == nil && gate.inputNames() == ["Hügelton Instruments Felucca"])
        let held = try gate.open("Hügelton Instruments Felucca")
        #expect(held.send(upgrade))
        gate.hold(false)
        #expect(gate.makeTransport() != nil)
    }
}

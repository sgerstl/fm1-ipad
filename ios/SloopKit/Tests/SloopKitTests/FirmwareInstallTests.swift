import Foundation
import Testing
@testable import SloopKit

/// The firmware installer against a fake FM-1 (FakeLoader.swift) that plays both update steps as Skiff's ota.c and
/// ldr_core.c do: the bundled packages, full installs, cut-offs at many points and the resume, refusals. Offline.
@Suite(.serialized) struct FirmwareInstallTests {
    static let skiff = try! BundledFirmware.skiff.load()
    static let sloop = try! BundledFirmware.sloop.load()

    /// fm1_install.py's test delays, about.
    static func installer(_ dev: FakeFM1) -> FirmwareInstaller {
        var d = FirmwareInstaller.Delays()
        d.start = .milliseconds(5); d.reply = .zero; d.loader = .milliseconds(10); d.reboot = .milliseconds(10)
        d.retry = .milliseconds(20); d.poll = .milliseconds(20); d.handshake = .milliseconds(100)
        d.idleCheck = .milliseconds(400); d.idleWrite = .milliseconds(400)
        d.waitLoader = .seconds(2); d.waitReboot = .seconds(2); d.waitResume = .seconds(1)
        return FirmwareInstaller(ports: dev, delays: d)
    }

    static func device(running: FirmwarePackage?) -> FakeFM1 {
        let dev = FakeFM1(running: running)
        dev.timeScale = 0.02                  // its 5 s read timeout: 100 ms
        dev.knows(skiff, sloop)
        return dev
    }

    /// Steps seen, in order (thread-safe: the installer calls back from its task).
    final class Steps: @unchecked Sendable {
        private let lock = NSLock()
        private var all: [InstallStep] = []
        func add(_ s: InstallStep) { lock.withLock { all.append(s) } }
        var list: [InstallStep] { lock.withLock { all } }
        var writes: [Int] { list.compactMap { if case .write(let p) = $0 { p } else { nil } } }
        func count(_ f: (InstallStep) -> Bool) -> Int { list.filter(f).count }
    }

    // MARK: The files

    @Test func bundledFilesMatchTheirPins() throws {
        for f in BundledFirmware.allCases {
            let p = try f.load()
            #expect(p.product == f.product)
            #expect(p.sha256 == f.sha256)
            #expect(p.flashSpan?.size == 0x93000)
            #expect(p.image.count == f.size - 20)
            #expect(BundledFirmware.matching(identity: f.product) == f)
            #expect(BundledFirmware.matching(identity: "ota-" + f.product) == f)
        }
        #expect(BundledFirmware.matching(identity: "FM-1_015") == nil)
    }

    @Test func aChangedByteIsRefused() throws {
        var raw = [UInt8](try Data(contentsOf: BundledFirmware.skiff.url!))
        raw[200_000] ^= 0x01
        #expect(throws: PackageError.self) { try FirmwarePackage(data: raw, pinned: .skiff) }
        do { _ = try FirmwarePackage(data: raw, pinned: .skiff) } catch let e as PackageError {
            guard case .hashMismatch = e else { Issue.record("not a hash mismatch: \(e)"); return }
        }
        // unpinned, the files' CRCs catch it as SLOOP's installer does
        #expect(throws: PackageError.damaged("flash.bin: CRC")) { try FirmwarePackage(data: raw) }
    }

    @Test func theWrongFileIsRefused() throws {
        let sloopRaw = [UInt8](try Data(contentsOf: BundledFirmware.sloop.url!))
        // SLOOP's file offered as Skiff's: its hash isn't Skiff's
        #expect(throws: PackageError.self) { try FirmwarePackage(data: sloopRaw, pinned: .skiff) }
        // not a package at all
        #expect(throws: PackageError.self) { try FirmwarePackage(data: [UInt8](repeating: 0x41, count: 4096)) }
        // another model's identity (an SMK-37 package)
        var smk = sloopRaw
        for (i, c) in Array("SMK-37 Pro_700".utf8).enumerated() { smk[i * 0x30 + 0x2F] = c &+ UInt8(i) &+ 1 }
        #expect(throws: PackageError.notFM1("SMK-37 Pro_700")) { try FirmwarePackage(data: smk) }
        // no Felucca update loader in it
        var plain = sloopRaw
        var at = 0
        while let r = plain[at...].firstRange(of: FirmwarePackage.loaderMark) { plain[r.lowerBound] = 0; at = r.upperBound }
        #expect(throws: PackageError.noLoader) { try FirmwarePackage(data: plain) }
        #expect(try FirmwarePackage.productOf(sloopRaw) == "FM-1_900")
    }

    @Test func wireFormatRoundTrips() {
        let data = (0..<300).map { UInt8($0 & 0xFF) }
        #expect(FirmwareInstaller.unpack7(FirmwareInstaller.pack7(data)).prefix(300).elementsEqual(data))
        let r = FirmwareInstaller.response(addr: 0x1234, data: [1, 2, 3])
        let u = FirmwareInstaller.unpack7(r.dropFirst().dropLast())
        #expect(Array(u[0..<3]) == [0, 0x59, 0x30])
        #expect(Array(u[14..<17]) == [1, 2, 3])
        #expect(DeviceIdentity("ota-FM-1_722")?.isLoader == true)
        #expect(DeviceIdentity("FM-1_900")?.baseModel == "FM-1")
        #expect(FirmwareInstaller.isResumable(loader: DeviceIdentity("ota-FM-1_722")!))
        #expect(FirmwareInstaller.isResumable(loader: DeviceIdentity("ota-FM-1_900")!))
        #expect(!FirmwareInstaller.isResumable(loader: DeviceIdentity("ota-FM-1_015")!))
        #expect(FirmwareInstaller.mayBeFM1(portName: "Felucca Update"))
        #expect(!FirmwareInstaller.mayBeFM1(portName: "IAC Driver Bus 1"))
    }

    // MARK: Full installs

    @Test func sloopToSkiff() async throws {
        let dev = Self.device(running: Self.sloop)
        let steps = Steps()
        let got = try await Self.installer(dev).install(Self.skiff, step: steps.add)
        #expect(got == "FM-1_722")
        #expect(dev.identity == "FM-1_722" && dev.portName == "Felucca" && dev.record == nil)
        #expect(dev.badAnswers == 0)
        #expect(steps.list.first == .start("FM-1_900"))
        #expect(steps.list.contains(.loader) && steps.list.last == .done("FM-1_722"))
        #expect(steps.writes == steps.writes.sorted() && steps.writes.last == 100)
        // step 1 read the header and the loader, not the app; step 2 the whole flash.bin twice, about
        #expect(dev.stats.check < 30)
        #expect(dev.stats.write > 2 * (0x93000 / 512) - 40)
        #expect(dev.stats.sectorsWritten > 100)
    }

    @Test func skiffToSloop() async throws {
        let dev = Self.device(running: Self.skiff)
        #expect(try await Self.installer(dev).install(Self.sloop) == "FM-1_900")
        #expect(dev.badAnswers == 0)
    }

    @Test func stockToSkiff() async throws {
        let dev = Self.device(running: nil)
        #expect(dev.portName == "FM-1" && dev.identity == "FM-1_015")
        #expect(try await Self.installer(dev).install(Self.skiff) == "FM-1_722")
    }

    @Test func probeSaysWhatIsPluggedIn() async throws {
        let dev = Self.device(running: Self.skiff)
        #expect(await Self.installer(dev).probe()?.text == "FM-1_722")
        let inLoader = FakeFM1(inLoaderOf: Self.sloop, was: Self.skiff)
        #expect(await Self.installer(inLoader).probe()?.text == "ota-FM-1_900")
        #expect(inLoader.portName == "Felucca Update")
    }

    // MARK: Cut off, then resumed

    /// The cable out every so often through step 2, back in 50 ms later: the install waits for the loader and
    /// writes again, and finishes.
    @Test(arguments: [1, 7, 64, 300, 900, 1175, 1176, 1180, 1500, 2000, 2290, 2316])
    func cutDuringTheWriteResumes(after reads: Int) async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.unplug(stage: 2, after: reads, replugAfter: .milliseconds(50))]
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.skiff, step: steps.add) == "FM-1_722")
        #expect(steps.count { $0 == .dropped } == 1)
        #expect(steps.list.contains(.resume(2)))
        #expect(dev.badAnswers == 0 && dev.record == nil)
    }

    /// Cut every Nth chunk, over and over: each drop resumes, until the write gets through.
    @Test func cutRepeatedly() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [400, 900, 1700, 2200].map { .unplug(stage: 2, after: $0, replugAfter: .milliseconds(30)) }
        let steps = Steps()
        let i = Self.installer(dev)
        i.resumeMax = 6
        #expect(try await i.install(Self.skiff, step: steps.add) == "FM-1_722")
        #expect(steps.count { $0 == .dropped } >= 2)
    }

    /// The cable stays out: the install gives up with the FM-1 in update mode. Plugged back in later, the next
    /// install finds the loader and finishes the write, without step 1.
    @Test(arguments: [10, 1176, 2000])
    func cutAndLeftThenFinishedFromTheLoader(after reads: Int) async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.unplug(stage: 2, after: reads, replugAfter: nil)]
        await #expect(throws: InstallError.self) { try await Self.installer(dev).install(Self.skiff) }
        do { try await Self.installer(dev).install(Self.skiff) } catch let e as InstallError {
            #expect(e.code == .notFound)            // still unplugged
        }
        dev.replug()
        #expect(dev.identity == "ota-FM-1_722" && dev.portName == "Felucca Update")
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.skiff, step: steps.add) == "FM-1_722")
        #expect(!steps.list.contains { if case .start = $0 { true } else { false } })
    }

    @Test func theFirstErrorSaysUpdateMode() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.unplug(stage: 2, after: 500, replugAfter: nil)]
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .lost && e.inUpdateMode)
        }
    }

    /// Cut in step 1: nothing was written, the FM-1 comes back on its own firmware, the next install goes through.
    @Test(arguments: [1, 3, 10, 18])
    func cutDuringTheCheck(after reads: Int) async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.unplug(stage: 1, after: reads, replugAfter: .milliseconds(20))]
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .lost && !e.inUpdateMode)
        }
        try await Task.sleep(for: .milliseconds(60))
        #expect(dev.identity == "FM-1_900" && dev.record == nil)
        #expect(try await Self.installer(dev).install(Self.skiff) == "FM-1_722")
    }

    /// Already in update mode when Jib starts (the cut came from somewhere else).
    @Test func startsInTheLoader() async throws {
        let dev = FakeFM1(inLoaderOf: Self.skiff, was: Self.sloop)
        dev.timeScale = 0.02
        dev.knows(Self.skiff)
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.skiff, step: steps.add) == "FM-1_722")
        #expect(steps.list.first == .write(0))
    }

    // MARK: Timeouts

    /// The loader stops asking mid-write: the host's idle timeout ends the attempt, the loader still answers the
    /// handshake, a new UPGRADE starts it again.
    @Test func aStalledLoaderIsStartedAgain() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.stall(stage: 2, after: 700)]
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.skiff, step: steps.add) == "FM-1_722")
        #expect(steps.list.contains(.dropped) && steps.list.contains(.resume(2)))
    }

    @Test func aStallInTheCheckWritesNothing() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.stall(stage: 1, after: 4)]
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .stopped && !e.inUpdateMode)
        }
        #expect(dev.identity == "FM-1_900" && dev.record == nil)
    }

    @Test func theLoaderNeverAppears() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.noLoader]
        let start = ContinuousClock.now
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .noLoader && e.inUpdateMode)
        }
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func nothingPluggedIn() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.unplug()
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .notFound)
        }
    }

    // MARK: Refusals

    @Test func otherGearIsNeverTouched() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.otherPorts = ["IAC Driver Bus 1", "Launchpad X", "Digitakt", "USB-MIDI"]
        #expect(try await Self.installer(dev).install(Self.skiff) == "FM-1_722")
        #expect(!dev.opened.contains("IAC Driver Bus 1") && !dev.opened.contains("Launchpad X") && !dev.opened.contains("Digitakt"))
        // a generic name the stock FM-1 may use is asked who it is, and nothing else
        let generic = dev.otherLinks["USB-MIDI"]?.sent ?? []
        #expect(!generic.isEmpty && generic.allSatisfy { $0 == FirmwareInstaller.hsQuery })
    }

    @Test func anotherFirmwaresUpdateModeIsLeftAlone() async throws {
        let dev = FakeFM1(running: nil, stockIdentity: "ota-FM-1_015")   // M-VAVE's update mode
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .foreignLoader && e.inUpdateMode)
        }
        #expect(dev.received.allSatisfy { $0.frame == FirmwareInstaller.hsQuery })
    }

    @Test func anotherIdentityAfterTheWriteIsAnError() async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.reports("FM-1_721")]
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .mismatch)
        }
    }

    @Test func cancelStopsBetweenRequests() async throws {
        let dev = Self.device(running: Self.sloop)
        let i = Self.installer(dev)
        let t = Task { try await i.install(Self.skiff) { if case .write(let p) = $0, p >= 20 { i.cancel() } } }
        do { _ = try await t.value; Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .cancelled)
        }
    }
}

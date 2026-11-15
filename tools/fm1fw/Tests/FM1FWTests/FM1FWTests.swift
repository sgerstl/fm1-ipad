// fm1fw against SloopKit's fakes only: FakeSkiff (INFO, the backup) and FakeFM1 (both update steps, cuts, the
// resume). Never a real FM-1.
import Foundation
import Testing
@testable import FM1FWCore
import SloopKit

@Suite(.serialized) struct FM1FWTests {
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// The B1 build: since 2026-11-15 the pinned Skiff-Lupe 2.5.1 (the experimental file it was, renamed).
    static let b1 = repo.appendingPathComponent("firmware/releases/Skiff-Lupe-2.5.1.fwsc")
    /// A package Lupe doesn't pin (SLOOP-Lupe 2.8.4, kept as a test fixture since decision 43): the unpinned path.
    static let unpinned = repo.appendingPathComponent("firmware/releases/SLOOP-Lupe-2.8.4.fwsc")
    static let running = try! LupeFirmware.skiff.load()           // the fake FM-1 starts on Skiff-Lupe 2.2
    static let b1pkg = try! FirmwarePackage(data: [UInt8](Data(contentsOf: b1)))
    static let unpinnedPkg = try! FirmwarePackage(data: [UInt8](Data(contentsOf: unpinned)))

    final class Lines: @unchecked Sendable {
        private let lock = NSLock(); private var all: [String] = []
        func add(_ s: String) { lock.withLock { all.append(s) } }
        var text: String { lock.withLock { all.joined(separator: "\n") } }
    }

    /// An FM-1 on Skiff-Lupe 2.5.1 (FakeFM1) with its editor link (FakeSkiff, the 2.5.1 fixture, a pattern bank
    /// record so the backup has something in it); short delays, as SloopKit's own installer tests.
    static func rig(cut: [FakeFM1.Fault] = []) throws -> (FM1FW, FakeFM1, Lines, URL) {
        let dev = FakeFM1(running: running)
        dev.timeScale = 0.2
        dev.knows(running, b1pkg, unpinnedPkg)
        dev.faults = cut
        let fx = try SkiffFixture.load(.v2_5_1)
        let tool = FM1FW(transport: {
            let f = FakeSkiff(fx)
            f.bankRecords[0] = (0..<888).map { UInt8($0 % 253) }
            return f
        }, ports: dev)
        var d = FirmwareInstaller.Delays()
        d.start = .milliseconds(5); d.reply = .zero; d.loader = .milliseconds(10); d.reboot = .milliseconds(10)
        d.retry = .milliseconds(20); d.poll = .milliseconds(20); d.handshake = .milliseconds(100)
        d.idleCheck = .milliseconds(3000); d.idleWrite = .milliseconds(3000)
        d.waitLoader = .seconds(2); d.waitReboot = .seconds(2); d.waitResume = .seconds(2)
        tool.delays = d
        let lines = Lines()
        tool.out = lines.add
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fm1fw-\(UUID().uuidString)")
        return (tool, dev, lines, dir)
    }

    @Test func theB1FileIsThePinnedSkiffLupe251() {
        #expect(Self.b1pkg.product == "FM-1_725")
        #expect(Self.b1pkg.sha256 == "2cb940c71557049ba3c46f11d35311b1e69e81d1f9348d9e0b906ec82847383b")
        #expect(LupeFirmware.skiff251.sha256 == Self.b1pkg.sha256)
        #expect(!LupeFirmware.allCases.contains { $0.sha256 == Self.unpinnedPkg.sha256 })     // the unpinned path's file
    }

    @Test func info() async throws {
        let (tool, _, lines, _) = try Self.rig()
        let i = await tool.info()
        #expect(i.version == "FELUCCA v2.5.1" && i.identity == "FM-1_722")    // (the editor link's fixture is 2.5.1's)
        try await tool.printInfo()
        #expect(lines.text.contains("firmware (INFO): FELUCCA v2.5.1") && lines.text.contains("identity (update handshake): FM-1_722"))
    }

    @Test func backupIsWrittenAndReadsBack() async throws {
        let (tool, _, lines, dir) = try Self.rig()
        let url = try await tool.backup(into: dir)
        #expect(url.path.contains("/Skiff/Backups/") && url.lastPathComponent.hasSuffix(" v2.5.1.json"))
        let b = try FM1FW.readBackup(url)
        #expect(b.firmware == "FELUCCA v2.5.1" && b.objects.contains { $0.id == 16 && $0.size == 4 * 888 })
        #expect(lines.text.contains("backup saved: \(url.path)") && lines.text.contains("100 %"))
        #expect(FM1FW.newestBackup(in: dir)?.resolvingSymlinksInPath().path == url.resolvingSymlinksInPath().path)
    }

    @Test func noFM1NoBackup() async throws {
        let tool = FM1FW(transport: { nil }, ports: FakeFM1(running: Self.running))
        await #expect(throws: FM1FW.Failure.self) { try await tool.backup(into: FileManager.default.temporaryDirectory) }
    }

    @Test func aDamagedBackupFileIsRefused() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("x.json")
        let good = Data([1, 2, 3]).base64EncodedString()
        try Data(#"{"format":"felucca-backup","version":1,"firmware":"FELUCCA v2.5.1","created":"2026-11-15T20:00:00.000Z","objects":[{"id":16,"size":3,"crc":1,"data":"\#(good)"}]}"#.utf8).write(to: f)
        #expect(throws: FM1FW.Failure.self) { try FM1FW.readBackup(f) }     // CRC 1 is wrong
    }

    // MARK: install: the refusals come before anything touches the FM-1

    @Test func anUnpinnedFileNeedsExperimental() async throws {
        let (tool, dev, _, dir) = try Self.rig()
        try await tool.backup(into: dir)
        do { try await tool.install(Self.unpinned, .init(backupDir: dir)); Issue.record("installed") } catch let f as FM1FW.Failure {
            #expect(f.code == 2 && f.description.contains("--experimental"))
        }
        #expect(dev.stats.check == 0 && dev.stats.write == 0)
    }

    @Test func noBackupNoInstall() async throws {
        let (tool, dev, _, dir) = try Self.rig()
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true; o.yes = true
        do { try await tool.install(Self.unpinned, o); Issue.record("installed") } catch let f as FM1FW.Failure {
            #expect(f.code == 2 && f.description.contains("No backup"))
        }
        #expect(dev.stats.check == 0 && dev.opened.isEmpty)
    }

    @Test func aBackupOlderThanAnHourIsRefused() async throws {
        let (tool, dev, _, dir) = try Self.rig()
        try await tool.backup(into: dir)
        tool.now = { Date().addingTimeInterval(2 * 3600) }
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true; o.yes = true
        do { try await tool.install(Self.unpinned, o); Issue.record("installed") } catch let f as FM1FW.Failure {
            #expect(f.code == 2 && f.description.contains("minutes old"))
        }
        #expect(dev.stats.check == 0)
    }

    @Test func aBackupOfOtherFirmwareIsRefused() async throws {
        let (tool, dev, _, dir) = try Self.rig()
        try await tool.backup(into: dir)
        tool.probeInfo = { .init(version: "FELUCCA v2.2", identity: "FM-1_722") }
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true; o.yes = true
        do { try await tool.install(Self.unpinned, o); Issue.record("installed") } catch let f as FM1FW.Failure {
            #expect(f.code == 2 && f.description.contains("take a backup of this unit"))
        }
        #expect(dev.stats.check == 0)
    }

    @Test func overTheTakeBuildNeedsAcceptOlderLink() async throws {
        let (tool, dev, _, dir) = try Self.rig()
        try await tool.backup(into: dir)
        tool.probeInfo = { .init(version: "FELUCCA v2.5.1", identity: "FM-1_725", screenLink: 7) }
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true; o.yes = true
        do { try await tool.install(Self.unpinned, o); Issue.record("installed") } catch let f as FM1FW.Failure {
            #expect(f.code == 2 && f.description.contains("--accept-older-link"))
        }
        #expect(dev.stats.check == 0)
    }

    @Test func withoutYesItIsADryRun() async throws {
        let (tool, dev, lines, dir) = try Self.rig()
        try await tool.backup(into: dir)
        #expect(try await tool.install(Self.b1, .init(backupDir: dir)) == nil)     // pinned: no --experimental needed
        #expect(dev.stats.check == 0 && dev.stats.write == 0)
        #expect(lines.text.contains("SHA-256 2cb940c7") && lines.text.contains("pinned in Lupe as Skiff-Lupe 2.5.1") && lines.text.contains("a dry run"))
    }

    @Test func anUnpinnedFileWithExperimentalGetsAsFarAsTheDryRun() async throws {
        let (tool, dev, lines, dir) = try Self.rig()
        try await tool.backup(into: dir)
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true
        #expect(try await tool.install(Self.unpinned, o) == nil)
        #expect(dev.stats.check == 0 && lines.text.contains("NOT pinned") && lines.text.contains("a dry run"))
    }

    // MARK: install, for real (on the fake)

    @Test func installsTheB1Build() async throws {
        let (tool, dev, lines, dir) = try Self.rig()
        try await tool.backup(into: dir)
        var o = FM1FW.InstallOptions(backupDir: dir); o.yes = true
        #expect(try await tool.install(Self.b1, o) == "FM-1_725")
        #expect(dev.stats.check > 0 && dev.stats.write > 0 && dev.record == nil && dev.badAnswers == 0)
        #expect(lines.text.contains("step 2: writing 100 %") && lines.text.contains("done: the FM-1 reports FM-1_725"))
    }

    @Test func aCutDuringTheWriteIsResumed() async throws {
        let (tool, dev, lines, dir) = try Self.rig(cut: [.unplug(stage: 2, after: 900, replugAfter: .milliseconds(50))])
        try await tool.backup(into: dir)
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true; o.yes = true
        #expect(try await tool.install(Self.b1, o) == "FM-1_725")
        #expect(lines.text.contains("resuming (try 2)") && dev.record == nil)
    }

    @Test func leftInUpdateModeTheSameCommandFinishes() async throws {
        let (tool, dev, lines, dir) = try Self.rig(cut: [.unplug(stage: 2, after: 600, replugAfter: nil)])
        let backup = try await tool.backup(into: dir)
        var o = FM1FW.InstallOptions(backupDir: dir); o.experimental = true; o.yes = true
        do { try await tool.install(Self.b1, o); Issue.record("installed") } catch let f as FM1FW.Failure {
            #expect(f.code == 1 && f.description.contains("update mode") && f.description.contains("--backup-taken"))
        }
        dev.replug()
        #expect(dev.identity == "ota-FM-1_725")
        // the editor link can't answer in update mode: --backup-taken names the backup, as the message says
        tool.probeInfo = { .init(identity: "ota-FM-1_725") }
        o.backupTaken = backup
        #expect(try await tool.install(Self.b1, o) == "FM-1_725")
        #expect(lines.text.contains("done: the FM-1 reports FM-1_725"))
    }
}

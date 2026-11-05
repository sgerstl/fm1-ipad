import Foundation
import Testing
@testable import SloopKit

/// Back to stock: M-VAVE's V15 (FM-1_015.fwsc, pinned), staged by Skiff's or SLOOP's step 1 through ota.c's official
/// branch (the 16 KiB head compared with the unit's) and written by M-VAVE's loader, which FakeFM1 plays as Skiff's
/// tests do (flash.bin once, downward). Then from V15 back to a custom firmware. Offline.
@Suite(.serialized) struct FirmwareStockTests {
    static let skiff = FirmwareInstallTests.skiff
    static let sloop = FirmwareInstallTests.sloop
    static let stock = try! BundledFirmware.stock.load()
    typealias Steps = FirmwareInstallTests.Steps

    static func device(running: FirmwarePackage?, startedOn: Int = 15) -> FakeFM1 {
        let dev = FakeFM1(running: running, startedOn: startedOn)
        dev.timeScale = 0.02
        dev.knows(skiff, sloop, stock)
        return dev
    }
    static func installer(_ dev: FakeFM1) -> FirmwareInstaller { FirmwareInstallTests.installer(dev) }
    /// Reads M-VAVE's loader makes in one write: the header's two, flash.bin in 512-byte reads, the finish.
    static let writeReads = 2 + 0x93000 / 512 + 1

    // MARK: The file

    @Test func theStockFileIsM_VAVEsV15() throws {
        #expect(Self.stock.product == "FM-1_015" && Self.stock.isOfficial)
        #expect(Self.stock.flashSpan?.size == 0x93000)
        #expect(FirmwarePackage.hasOfficialLoader(Self.stock.image))
        #expect(!FirmwarePackage.hasOfficialLoader(Self.skiff.image))
        // its head is the one an FM-1 that shipped with V15 has
        #expect(FakeFM1.v15Head.elementsEqual(Self.stock.image[0x400..<0x4400]))
    }

    @Test func onlyThePinnedFileTakesTheOfficialPath() throws {
        let raw = [UInt8](try Data(contentsOf: BundledFirmware.stock.url!))
        // unpinned it's refused: no Felucca loader (nothing but the pinned V15 is installed with M-VAVE's loader)
        #expect(throws: PackageError.noLoader) { try FirmwarePackage(data: raw) }
        var bad = raw
        bad[300_000] ^= 0x01
        #expect(throws: PackageError.self) { try FirmwarePackage(data: bad, pinned: .stock) }
        #expect(throws: PackageError.self) { try FirmwarePackage(data: raw, pinned: .skiff) }
    }

    @Test func whichLoaderWritesWhat() {
        let mvave = DeviceIdentity("ota-FM-1_015")!, skiffLoader = DeviceIdentity("ota-FM-1_722")!
        #expect(FirmwareInstaller.writes(Self.stock, loader: mvave))
        #expect(!FirmwareInstaller.writes(Self.stock, loader: skiffLoader))
        #expect(!FirmwareInstaller.writes(Self.skiff, loader: mvave))
        #expect(FirmwareInstaller.writes(Self.skiff, loader: skiffLoader))
        #expect(FirmwareInstaller.writes(Self.skiff, loader: DeviceIdentity("ota-FM-1_900")!))
        #expect(!FirmwareInstaller.writes(Self.stock, loader: DeviceIdentity("FM-1_015")!))
    }

    // MARK: Full installs

    @Test(arguments: ["skiff", "sloop"])
    func customToStock(from: String) async throws {
        let dev = Self.device(running: from == "skiff" ? Self.skiff : Self.sloop)
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.stock, step: steps.add) == "FM-1_015")
        #expect(dev.identity == "FM-1_015" && dev.portName == "FM-1" && dev.record == nil)
        #expect(dev.badAnswers == 0)
        #expect(steps.list.contains(.loader) && steps.list.last == .done("FM-1_015"))
        // forward only, as M-VAVE's loader reads downward
        #expect(steps.writes == steps.writes.sorted() && steps.writes.last == 100)
        #expect(steps.writes.dropLast().max() ?? 0 >= 90)
        // step 1: header, loader head, the 32 reads of the 16 KiB head, the loader body; step 2: flash.bin once
        #expect(dev.stats.check > 35 && dev.stats.check < 80)
        #expect(dev.stats.write == Self.writeReads)
    }

    @Test func stockV15ToSkiffAndBack() async throws {
        let dev = Self.device(running: Self.stock)
        #expect(dev.portName == "FM-1")
        #expect(try await Self.installer(dev).install(Self.skiff) == "FM-1_722")
        #expect(try await Self.installer(dev).install(Self.stock) == "FM-1_015")
        #expect(try await Self.installer(dev).install(Self.sloop) == "FM-1_900")
        #expect(dev.badAnswers == 0)
    }

    // MARK: Cut off, then resumed

    @Test(arguments: [1, 2, 3, 100, 600, 1000, 1150, 1170, 1177, 1178])
    func cutDuringTheStockWriteResumes(after reads: Int) async throws {
        let dev = Self.device(running: Self.skiff)
        dev.faults = [.unplug(stage: 2, after: reads, replugAfter: .milliseconds(50))]
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.stock, step: steps.add) == "FM-1_015")
        #expect(steps.count { $0 == .dropped } == 1 && steps.list.contains(.resume(2)))
        #expect(dev.badAnswers == 0 && dev.record == nil)
    }

    @Test(arguments: [1, 3, 20, 40])
    func cutDuringTheStockCheckWritesNothing(after reads: Int) async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.unplug(stage: 1, after: reads, replugAfter: .milliseconds(20))]
        do { try await Self.installer(dev).install(Self.stock); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .lost && !e.inUpdateMode)
        }
        try await Task.sleep(for: .milliseconds(60))
        #expect(dev.identity == "FM-1_900" && dev.record == nil && dev.stats.sectorsWritten == 0)
        #expect(try await Self.installer(dev).install(Self.stock) == "FM-1_015")
    }

    /// Left unplugged mid-write: on power-on it's M-VAVE's loader, and the next install of V15 finishes it.
    @Test(arguments: [10, 900])
    func cutAndLeftThenFinishedFromM_VAVEsLoader(after reads: Int) async throws {
        let dev = Self.device(running: Self.sloop)
        dev.faults = [.unplug(stage: 2, after: reads, replugAfter: nil)]
        await #expect(throws: InstallError.self) { try await Self.installer(dev).install(Self.stock) }
        dev.replug()
        #expect(dev.identity == "ota-FM-1_015" && dev.portName == FakeFM1.officialLoaderPort)
        // Skiff isn't written by M-VAVE's loader: refused, with nothing but the handshake sent
        let before = dev.received.count
        do { try await Self.installer(dev).install(Self.skiff); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .foreignLoader && e.inUpdateMode && e.message.contains("Stock V15"))
        }
        #expect(dev.received.dropFirst(before).allSatisfy { $0.frame == FirmwareInstaller.hsQuery })
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.stock, step: steps.add) == "FM-1_015")
        #expect(steps.list.first == .write(0))
    }

    @Test func aStalledStockLoaderIsStartedAgain() async throws {
        let dev = Self.device(running: Self.skiff)
        dev.faults = [.stall(stage: 2, after: 500)]
        let steps = Steps()
        #expect(try await Self.installer(dev).install(Self.stock, step: steps.add) == "FM-1_015")
        #expect(steps.list.contains(.dropped) && steps.list.contains(.resume(2)))
    }

    // MARK: Refusals

    /// A Skiff install cut off leaves Skiff's loader: V15 doesn't go through it (it writes the app area only).
    @Test func stockIsNotWrittenByAFeluccaLoader() async throws {
        let dev = FakeFM1(inLoaderOf: Self.skiff, was: Self.sloop)
        dev.timeScale = 0.02
        do { try await Self.installer(dev).install(Self.stock); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .foreignLoader && e.message.contains("Skiff 2.2"))
        }
        #expect(dev.received.allSatisfy { $0.frame == FirmwareInstaller.hsQuery })
    }

    /// A unit that ran V16 has V16's head: the running firmware stops at the first head read that differs, and
    /// nothing is written.
    @Test func aUnitThatStartedOnV16IsRefused() async throws {
        let dev = Self.device(running: Self.skiff, startedOn: 16)
        do { try await Self.installer(dev).install(Self.stock); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .otherStock && !e.inUpdateMode)
            #expect(e.message.hasPrefix("Nothing was written"))
        }
        #expect(dev.identity == "FM-1_722" && dev.record == nil && dev.stats.sectorsWritten == 0)
        // and it still takes a custom firmware
        #expect(try await Self.installer(dev).install(Self.sloop) == "FM-1_900")
    }

    @Test func stockV16RunningIsRefusedBeforeAnythingIsSent() async throws {
        let dev = FakeFM1(running: nil, stockIdentity: "FM-1_016", startedOn: 16)
        dev.timeScale = 0.02
        do { try await Self.installer(dev).install(Self.stock); Issue.record("no error") } catch let e as InstallError {
            #expect(e.code == .otherStock)
        }
        #expect(dev.received.allSatisfy { $0.frame == FirmwareInstaller.hsQuery })
    }
}

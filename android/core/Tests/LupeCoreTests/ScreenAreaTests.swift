import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The FM-1 button block (decision 24) on FakeSkiff 2.5.1: screenGoto sends GLO, SAVE, SEQ to the FM-1 (SCREEN_GOTO,
/// Lupe's numbers translated by the driver), the fm1Screen area names the key whose screen is up, also when the
/// FM-1's own keys move it, and read-only sends nothing.
@MainActor extension FixtureRecordingTests {
    func screens(_ r: Recorder) -> [Fm1ScreenArea] {
        r.frames.filter { $0.area == "fm1Screen" }.compactMap { try? JSONDecoder().decode(Fm1ScreenArea.self, from: Data($0.json.utf8)) }
    }

    @Test func screenGotoSendsTheFM1ToGloSaveAndSeq() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let map = SkiffFirmware.v2_5_1.pageMap
        for (key, first, title) in [("GLO", 30, "MIXER"), ("SAVE", 35, "PRESETS"), ("SEQ", 41, "NOTES")] {
            core.handle(json: #"{"intent":"screenGoto","screen":"\#(key)"}"#)
            try await waitFor(3, "\(key) on the FM-1") { !fake.screen.home && fake.screen.page == first }
            #expect(fake.gotoWire.last == map.device(first), "\(key): \(fake.gotoWire)")
            try await waitFor(3, "\(key) lit") { self.screens(r).last.map { $0.key == key && $0.page == first && $0.title == title } ?? false }
        }
        // a second page of a key: SAVE › PROJECT
        core.handle(json: #"{"intent":"screenGoto","screen":"SAVE","page":38}"#)
        try await waitFor(3, "PROJECT") { self.screens(r).last.map { $0.key == "SAVE" && $0.title == "PROJECT" } ?? false }
        try await waitFor(3, "PROJECT on the FM-1") { fake.screen.page == 38 }       // (the phone shows it before the FM-1 answers)
        // the FM-1's own keys: HOME, then ENV
        fake.pressOnDevice(page: nil)
        try await waitFor(3, "HOME") { self.screens(r).last?.key == "HOME" }
        fake.pressOnDevice(page: 0)
        try await waitFor(3, "ENV") { self.screens(r).last.map { $0.key == "ENV" && $0.title == "ENV" } ?? false }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func screenGotoIsRefusedWhileReadOnly() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r, writes: false)
        defer { core.stop(); plug.unplug() }
        fake.gotoWire.removeAll()
        core.handle(json: #"{"intent":"screenGoto","screen":"GLO"}"#)
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.gotoWire.isEmpty)
    }
}

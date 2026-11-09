import Foundation
import Testing
@testable import SloopKit

/// The FM-1 over Bluetooth (bluetooth-poc, 2026-11-10), against FakeSkiff's Bluetooth link as the firmware's source
/// and optimist's measurements describe it (FakeSkiff.useBluetooth): every twentieth reply lost (optimist's one in three was
/// while whole screens streamed; Skiff-Lupe's firmware drops only when its 2 KB ring is full), no METER or SCOPE, uploads refused.
@MainActor struct BluetoothTests {
    @Test func waitsLongerAndRetriesMoreOverBluetooth() {
        #expect(TransportLink.usb.adjusted(timeout: .milliseconds(300), retries: 1) == (.milliseconds(300), 1))
        #expect(TransportLink.bluetooth.adjusted(timeout: .milliseconds(300), retries: 1) == (.milliseconds(600), 3))
        #expect(TransportLink.bluetooth.adjusted(timeout: .seconds(2), retries: 1) == (.seconds(4), 3))
        // a request sent once only (a commit, a key) is still sent once
        #expect(TransportLink.bluetooth.adjusted(timeout: .milliseconds(150), retries: 0) == (.milliseconds(600), 0))
    }

    @Test func theBluetoothNameIsMatchedAndNeverTakenForAnInstall() {
        #expect(MIDITransport.isBluetoothName("FM1-1A2B"))
        #expect(MIDITransport.isBluetoothName("FM1-00ff Bluetooth"))
        #expect(!MIDITransport.isBluetoothName("Felucca"))
        #expect(!MIDITransport.isBluetoothName("FM-1"))
        #expect(!FirmwareInstaller.mayBeFM1(portName: "FM1-1A2B"))
        #expect(FirmwareInstaller.mayBeFM1(portName: "Felucca"))
    }

    /// A session over a lossy link: it connects through the lost replies, reads the song, follows the screen, and asks
    /// for neither METER nor SCOPE, even with a scope on show.
    @Test func aSessionConnectsOverALossyLinkWithoutMetersOrScope() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        fake.screenLink = true; fake.screenLinkVersion = 4
        fake.useBluetooth(dropEvery: 20)
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(60) { s.isConnected && s.screenLinked }
        if !s.isConnected { print("BT status \(s.status) requests \(fake.requests.suffix(16)) n \(fake.requests.count) dropped \(fake.repliesDropped)") }
        #expect(s.link == .bluetooth && s.onBluetooth)
        #expect(fake.repliesDropped > 0, "the link lost replies and the session still connected")
        #expect(!fake.meterWatched && !fake.scopeWatched)
        s.showScope(UUID(), true)
        try await Task.sleep(for: .milliseconds(400))
        #expect(!fake.scopeWatched)
        await #expect(throws: DeviceSession.SampleError.needsUSB) {
            try await s.uploadSample(slot: 0, name: "TEST", samples: [Int16](repeating: 100, count: 2000)) { _ in }
        }
        #expect(!fake.requests.contains(Cmd.smpBegin))
        #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught")
        run.cancel()
    }
}

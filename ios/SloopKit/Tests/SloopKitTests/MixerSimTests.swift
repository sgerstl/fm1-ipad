import Foundation
import Testing
@testable import SloopKit

/// The Mixer tab against skiff-sim (SKIFF_SIM=1, the sim running): what a strip's faders and MUTE send, and GLO
/// stepping the pages the tab follows (SKIFF_LINK=1 and SKIFF_CONSOLE, the sim's console FIFO, as
/// SkiffScreenLinkSimTests). They change the sim's mix and put it back.
///   SKIFF_SIM=1 swift test --filter MixerSimTests
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct MixerSimTests {
    private func connected() async throws -> (DeviceSession, Task<Void, Never>) {
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return MIDITransport() })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(20) { if case .connected = session.status { true } else { false } }
        return (session, run)
    }

    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else { throw ClientError.timeout("not Skiff") }
        return s
    }

    /// A fader held and dragged on a track that isn't the selected one: every frame's value (120 a second) goes to
    /// the session, the writes coalesce, and the FM-1 ends on the last. PAN, MUTE and the REVERB send the same way.
    @Test func aStripsFadersReachTheFirmware() async throws {
        let (session, run) = try await connected()
        session.select(track: 0)
        let t = 3
        let rev = try #require(session.pageLayout?.first { $0.title == "FX" }?.ids[safe: 3] ?? nil)
        await session.readEveryTrack(id: rev)
        let before = (session.tracks[t].level, session.tracks[t].pan, session.tracks[t].mute, session.everyTrack[rev]?[t] ?? 0)
        for v in stride(from: 112, through: 40, by: -1) {               // a drag down, a value a frame
            session.set(track: t, param: Param.level, to: v)
            try await Task.sleep(for: .milliseconds(8))
        }
        session.set(track: t, param: Param.pan, to: -32)
        session.set(track: t, param: Param.mute, to: 1)
        session.set(track: t, param: rev, to: 90)
        try await Task.sleep(for: .milliseconds(600))
        #expect(session.tracks[t].level == 40 && session.tracks[t].pan == -32 && session.tracks[t].mute)
        run.cancel()
        try await Task.sleep(for: .milliseconds(300))

        let d = try await driver()
        #expect(try await d.trackParam(track: t, id: Param.level) == 40)
        #expect(try await d.trackParam(track: t, id: Param.pan) == -32)
        #expect(try await d.trackParam(track: t, id: Param.mute) == 1)
        #expect(try await d.trackParam(track: t, id: rev) == 90)
        #expect(try await d.trackParam(track: 0, id: Param.level) != 40)   // the selected track untouched
        _ = try await d.setTrackParam(track: t, id: Param.level, value: before.0)
        _ = try await d.setTrackParam(track: t, id: Param.pan, value: before.1)
        _ = try await d.setTrackParam(track: t, id: Param.mute, value: before.2 ? 1 : 0)
        _ = try await d.setTrackParam(track: t, id: rev, value: before.3)
        await d.close()
    }

    /// GLO on the FM-1 steps MIXER DELAY REVERB CHORUS GLOBAL and round again; each arrives as a SCREEN push the
    /// button map places on the Mixer tab's section. Then the tab's own SCREEN_GOTO for each card.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SKIFF_LINK"] == "1" && ProcessInfo.processInfo.environment["SKIFF_CONSOLE"] != nil))
    func gloStepsTheMixersPages() async throws {
        let console = try #require(ProcessInfo.processInfo.environment["SKIFF_CONSOLE"])
        let (session, run) = try await connected()
        #expect(session.screenLinked)
        session.showOnDevice(page: 127)
        try await waitFor(5) { session.deviceScreen?.home == true }
        func press(_ b: String) throws {
            let h = try #require(FileHandle(forWritingAtPath: console))
            h.write(Data("press \(b)\n".utf8)); try h.close()
        }
        for tab in SkiffButtonMap.MixerTab.allCases + [.mixer] {
            try press("GLO")
            try await waitFor(5) { session.deviceScreen.map { !$0.home && $0.page == tab.page } == true }
            #expect(session.deviceScreen.flatMap { SkiffButtonMap.place(for: $0) } == .mixer(tab))
        }
        for tab in SkiffButtonMap.MixerTab.allCases.reversed() {        // a card swiped to, here
            session.showOnDevice(page: tab.page)
            try await waitFor(5) { session.deviceScreen?.page == tab.page }
        }
        session.showOnDevice(page: 127)
        try await waitFor(5) { session.deviceScreen?.home == true }
        run.cancel()
    }
}

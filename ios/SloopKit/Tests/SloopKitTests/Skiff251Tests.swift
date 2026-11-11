import Foundation
import Testing
@testable import SloopKit

/// Skiff-Lupe 2.5.1 beside 2.2 (vault skiff-2.5.1-rebase.md): the page numbers, the new pages and parameters, KEEP
/// SENDS, the project record, the undo depth and FREE TAKE level 1. Each against FakeSkiff on both releases; the 2.5.1
/// fixture was recorded from skiff-sim built on Skiff-Lupe 2.5.1 (737e3fb).
@Suite(.serialized) @MainActor struct Skiff251Tests {
    private func connect(_ fw: SkiffFirmware, link: Bool = true) async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load(fw))
        fake.screenLink = link
        fake.screenLinkVersion = 6
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        if link { try await waitFor(5) { s.screenLinked && fake.screenWatched } }
        return (s, fake, run)
    }

    // MARK: The page map

    @Test func pageNumbersByRelease() {
        let m = SkiffFirmware.v2_5_1.pageMap
        // device → Lupe: 0–5 as they were, the two send pages past 2.2's end, DRIVE and INSERT back two, the rest back one
        #expect((0...5).map(m.lupe) == Array(0...5))
        #expect(m.lupe(6) == SkiffPageMap.fxDelay && m.lupe(7) == SkiffPageMap.fxReverb)
        #expect(m.lupe(8) == 6 && m.lupe(9) == 7 && m.lupe(10) == 9 && m.lupe(46) == 45 && m.lupe(127) == 127)
        // Lupe → device, and INSERT 2 (gone on 2.5) opens INSERT, where its MIX is
        #expect(m.device(6) == 8 && m.device(7) == 9 && m.device(8) == 9 && m.device(41) == 42 && m.device(45) == 46)
        #expect(m.device(46) == 6 && m.device(47) == 7 && m.device(127) == 127)
        // every 2.5.1 page round-trips
        for d in 0..<47 { #expect(m.device(m.lupe(d)) == d, "device page \(d)") }
        // 2.2: as it is, and no send pages
        let o = SkiffFirmware.v2_2.pageMap
        #expect((0..<46).allSatisfy { o.lupe($0) == $0 && o.device($0) == $0 })
        #expect(o.device(SkiffPageMap.fxDelay) == nil && o.device(SkiffPageMap.fxReverb) == nil)
    }

    @Test func undoDepthByRelease() {
        #expect(SkiffFirmware.v2_2.undoLevels == 8 && SkiffFirmware.v2_5_1.undoLevels == 6)
    }

    /// The FM-1 on a page: Lupe hears it in its own numbers. Lupe opening a page: the FM-1 gets its own.
    @Test(arguments: [SkiffFirmware.v2_2, .v2_5_1]) func pagesFollowBothWays(_ fw: SkiffFirmware) async throws {
        let (s, fake, run) = try await connect(fw)
        // DRIVE, INSERT, SLICER, MIXER, NOTES, SONG pressed on the FM-1
        for p in [6, 7, 9, 30, 41, 45] {
            fake.pressOnDevice(page: p)
            try await waitFor(5) { s.deviceScreen?.page == p }
        }
        // Lupe opens them: on the wire as this release numbers them
        for p in [6, 7, 9, 31, 41, 45] {
            s.showOnDevice(page: p)
            try await waitFor(5) { fake.screen.page == p && s.deviceScreen?.page == p }
            #expect(fake.gotoWire.last == fw.pageMap.device(p))
        }
        if fw == .v2_5_1 {
            #expect(fake.gotoWire.suffix(6) == [8, 9, 10, 32, 42, 46])
            // FX › DELAY and FX › REVERB, both ways
            fake.pressOnDevice(page: SkiffPageMap.fxDelay)
            try await waitFor(5) { s.deviceScreen?.page == SkiffPageMap.fxDelay }
            s.showOnDevice(page: SkiffPageMap.fxReverb)
            try await waitFor(5) { fake.screen.page == SkiffPageMap.fxReverb }
            #expect(fake.gotoWire.last == 7)
            // INSERT 2: the FM-1 shows INSERT
            s.showOnDevice(page: 8)
            try await waitFor(5) { fake.gotoWire.last == 9 && s.deviceScreen?.page == 7 }
        } else {
            #expect(fake.gotoWire.suffix(6) == [6, 7, 9, 31, 41, 45])
            // a send page doesn't exist on 2.2: nothing asked for
            let n = fake.gotoWire.count
            s.showOnDevice(page: SkiffPageMap.fxDelay)
            try await Task.sleep(for: .milliseconds(300))
            #expect(fake.gotoWire.count == n)
        }
        // the button map's pages, each landing where Lupe sent it
        for place: SkiffButtonMap.Place in [.shape(page: 0), .shape(page: 7), .shape(page: 11), .shape(page: 39), .mixer(.delay),
                                            .sequence(.notes), .sequence(.automation), .arrange(patterns: false), .projects, .browse] {
            let p = SkiffButtonMap.page(for: place)
            s.showOnDevice(page: p)
            try await waitFor(5) { s.deviceScreen.flatMap(SkiffButtonMap.place) == place }
        }
        #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught")
        run.cancel()
    }

    // MARK: Counts, pages and parameters

    @Test(arguments: [SkiffFirmware.v2_2, .v2_5_1]) func countsAreTheDevices(_ fw: SkiffFirmware) async throws {
        let (s, fake, run) = try await connect(fw)
        #expect(s.skiffFirmware == fw && fake.firmware == fw)
        let info = try #require(s.info)
        #expect(info.paramCount == (fw == .v2_2 ? 146 : 148) && info.firstEngineParam == (fw == .v2_2 ? 138 : 140))
        #expect(info.globalCount == (fw == .v2_2 ? 27 : 28))
        #expect(s.globalDescs[27]?.label == (fw == .v2_2 ? nil : "DLY MODE"))
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    @Test(arguments: [SkiffFirmware.v2_2, .v2_5_1]) func theReleasesPages(_ fw: SkiffFirmware) async throws {
        let (s, fake, run) = try await connect(fw)
        let pages = try #require(s.pageLayout)
        func page(_ f: String, _ t: String) -> PageSpec? { pages.first { $0.family == f && $0.title == t } }
        let chord = try #require(page("SEL", "CHORD")), gloDelay = try #require(page("GLO", "DELAY"))
        let insert = try #require(page("FX", "INSERT")), insert2 = try #require(page("FX", "INSERT 2"))
        #expect(insert.ids == [121, 122, 123, 124] && insert2.ids == [125, nil, nil, nil])
        if fw == .v2_5_1 {
            let fxDelay = try #require(page("FX", "DELAY")), fxReverb = try #require(page("FX", "REVERB"))
            // KNOB 1 the track's send, 2–4 the bus's (G_DTIME G_DFDBK G_DCOLOR; G_RTYPE G_RSIZE G_RDAMP)
            #expect(fxDelay.ids == [35, 4, 5, 6] && fxDelay.scopes == [0, 1, 1, 1] && fxDelay.knobLabels.first == "SEND")
            #expect(fxReverb.ids == [36, 24, 8, 9] && fxReverb.scope(of: 0) == 0 && fxReverb.scope(of: 3) == 1)
            // right after FX, before DRIVE, as on the FM-1
            let fx = pages.filter { $0.family == "FX" }.map(\.title)
            #expect(fx.prefix(4) == ["FX", "DELAY", "REVERB", "DRIVE"])
            #expect(chord.ids == [81, 82, 138, 139])
            #expect(gloDelay.settings == [27])
            #expect(s.trackDesc(138)?.label == "STRUM" && s.trackDesc(138)?.unit.lowercased() == "ms" && s.trackDesc(138)?.max == 100)
            #expect(s.trackDesc(139)?.names == ["DOWN", "UP", "ALT"])
            #expect(s.globalDescs[27]?.names == ["MONO", "STEREO", "PING"])
            #expect(s.trackDesc(121)?.names.last == "FILTR")
        } else {
            #expect(page("FX", "DELAY") == nil && page("FX", "REVERB") == nil)
            #expect(chord.ids == [81, 82, nil, nil] && gloDelay.settings.isEmpty)
            #expect(s.trackDesc(121)?.names.last == "CHOR")
        }
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    /// FILTR (2.5's tenth INSERT TYPE): its A B C are CUTOFF, RES and SHAPE, SHAPE in F_SHAPE.
    @Test func filtrNamesItsKnobs() async throws {
        let (s, fake, run) = try await connect(.v2_5_1)
        s.set(track: s.selectedTrack, param: 121, to: 9)
        try await waitFor(5) { fake.params[fake.selected][121] == 9 }
        #expect(s.trackDesc(122)?.label == "CUTOFF" && s.trackDesc(123)?.label == "RES" && s.trackDesc(124)?.label == "SHAPE")
        #expect(s.trackDesc(124)?.format == SkiffDisplay.shapeFormat)
        s.set(track: s.selectedTrack, param: 121, to: 8)                         // CHOR: the swept ones
        #expect(s.trackDesc(122)?.label == "RATE")
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    @Test func shapeReadsAsTheFM1Does() {
        #expect(SkiffDisplay.shape(0) == ("LP", "") && SkiffDisplay.shape(64) == ("BP", "") && SkiffDisplay.shape(127) == ("HP", ""))
        #expect(SkiffDisplay.shape(19) == ("30", "BP"))                    // (19 × 100 + 32) / 64
        #expect(SkiffDisplay.shape(96) == ("51", "HP"))                    // ((96 − 64) × 100 + 31) / 63
    }

    /// STRUM, DIR set from Lupe go to the FM-1 by their wire ids (138, 139: scope 2, 10 and 11).
    @Test func strumAndDirection() async throws {
        let (s, fake, run) = try await connect(.v2_5_1)
        s.set(track: s.selectedTrack, param: 138, to: 40)
        s.set(track: s.selectedTrack, param: 139, to: 2)
        try await waitFor(5) { fake.params[fake.selected][138] == 40 && fake.params[fake.selected][139] == 2 }
        #expect(SkiffMotion.recordable(138, paramCount: 148) && SkiffMotion.recordable(139, paramCount: 148))
        #expect(SkiffMotion.recordable(147, paramCount: 148) && !SkiffMotion.recordable(148, paramCount: 148))
        #expect(SkiffMotion.recordable(145) && !SkiffMotion.recordable(146))                 // 2.2: E0..E7 at 138–145
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    /// GLO › DELAY's MODE (G_DMODE, GSID 27): a global like the rest.
    @Test func delayMode() async throws {
        let (s, fake, run) = try await connect(.v2_5_1)
        #expect(s.globalCell(27).value == fake.globals[27])
        s.set(global: 27, to: 2)                                           // PING
        try await waitFor(5) { fake.globals[27] == 2 }
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    // MARK: KEEP SENDS

    @Test(arguments: [SkiffFirmware.v2_2, .v2_5_1]) func keepSends(_ fw: SkiffFirmware) async throws {
        let (s, fake, run) = try await connect(fw)
        if fw == .v2_2 {
            try await Task.sleep(for: .milliseconds(300))
            #expect(s.keepSends == nil)                                     // not offered: no switch
        } else {
            try await waitFor(5) { s.keepSends == false }
            s.setKeepSends(true)
            try await waitFor(5) { fake.menuValues[SkiffMenu.keepSends] == 1 && s.keepSends == true }
            s.setKeepSends(false)
            try await waitFor(5) { fake.menuValues[SkiffMenu.keepSends] == 0 && s.keepSends == false }
        }
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    // MARK: The project record (SKF4)

    @Test func projectRecordsOfBothReleases() throws {
        let old = try #require(SkiffProjectData.blank.project), new = try #require(SkiffProjectData.blank251.project)
        // 2.2 wrote 27 globals: 2.5 opens it with the delay MONO, STRUM and DIR absent (OFF, DOWN)
        #expect(old.globals?.count == 27 && old.delayMode == 0 && old.strum(track: 0) == nil)
        #expect(old.trackParams?.count == 6 && old.trackParams?.allSatisfy { $0.sids.count == 146 } == true)
        // 2.5.1 writes 28, a new project's delay STEREO, and 148 SIDs a track
        #expect(new.globals?.count == 28 && new.delayMode == 1)
        #expect(new.trackParams?.allSatisfy { $0.sids.count == 148 } == true)
        #expect(new.strum(track: 0)?.ms == 0 && new.strum(track: 0)?.dir == 0)
        #expect(new.globals?[0] == 120 && old.globals?[0] == 120)          // BPM, GSID 0, in both
        // the record Lupe opens on each
        #expect(SkiffProjectData.blank(for: .v2_5_1) == .blank251 && SkiffProjectData.blank(for: .v2_2) == .blank)
        #expect(SkiffProjectData.blank(for: nil) == .blank)
    }

    /// A record whose STRUM and DIR (SIDs 146, 147) are set reads them back; a damaged SID byte (past 191) is refused.
    @Test func sidsPastTheOldCountAreRead() throws {
        var b = SkiffProjectData.blank251.record.map { $0 }
        let at = SKF4.globalsAt + 1 + 2 * 28 + 4                           // track 1's SIDs
        b[at + SKF4.strumSID] = UInt8(55 + 64); b[at + SKF4.strumDirSID] = UInt8(2 + 64)
        let p = try #require(SKF4(b.withSealed()))
        #expect(p.strum(track: 0)?.ms == 55 && p.strum(track: 0)?.dir == 2)
        b[at] = 200
        #expect(SKF4(b.withSealed())?.trackParams == nil)
    }

    // MARK: FREE TAKE, level 1

    @Test(arguments: [SkiffFirmware.v2_2, .v2_5_1]) func aKeptTakeIsReadAgainAndSaid(_ fw: SkiffFirmware) async throws {
        let (s, fake, run) = try await connect(fw)
        let t = s.selectedTrack
        #expect(!s.playing)
        try await Task.sleep(for: .milliseconds(100))
        fake.freeTakeOnDevice(track: t, notes: [60, 64, 67, 72], length: 32, bpm: 96)
        if fw == .v2_5_1 {
            try await waitFor(5) { s.freeTake != nil }
            let k = try #require(s.freeTake)
            #expect(k.track == t && k.length == 32 && k.bpm == 96 && k.undoLevels == 6)
            #expect(s.tracks[t].length == 32 && s.tracks[t].steps[0].notes == [60] && s.tracks[t].steps[8].notes == [64])
            // a second take on the same track lands again, as a new one
            try await Task.sleep(for: .milliseconds(500))
            fake.freeTakeOnDevice(track: t, notes: [62, 65], length: 16, bpm: 96)
            try await waitFor(5) { (s.freeTake?.id ?? 0) > k.id }
            #expect(s.freeTake?.length == 16)
            s.dismissFreeTake()
            #expect(s.freeTake == nil)
        } else {
            // 2.2 has no FREE TAKE: the steps follow as any edit on the FM-1 does, and nothing lands
            try await waitFor(5) { s.tracks[t].steps[0].notes == [60] }
            try await Task.sleep(for: .milliseconds(800))
            #expect(s.freeTake == nil)
        }
        #expect(fake.unansweredCommands.isEmpty)
        run.cancel()
    }

    /// Step edits on SEQ › NOTES aren't a take, even after playing keys there.
    @Test func editsOnTheNotesPageAreNotATake() async throws {
        let (s, fake, run) = try await connect(.v2_5_1)
        fake.pressOnDevice(page: 41)
        try await waitFor(5) { s.deviceScreen?.page == 41 }
        fake.freeTakeOnDevice(track: s.selectedTrack, notes: [60, 64], length: 16, bpm: nil)
        try await waitFor(5) { s.tracks[s.selectedTrack].steps[0].notes == [60] }
        try await Task.sleep(for: .milliseconds(800))
        #expect(s.freeTake == nil)
        run.cancel()
    }

    /// Playing: not a take (a take is the transport stopped).
    @Test func nothingLandsWhilePlaying() async throws {
        let (s, fake, run) = try await connect(.v2_5_1)
        s.setPlaying(true)
        try await waitFor(5) { fake.playing && s.playing }
        fake.freeTakeOnDevice(track: s.selectedTrack, notes: [60], length: 16, bpm: nil)
        try await Task.sleep(for: .milliseconds(800))
        #expect(s.freeTake == nil)
        s.setPlaying(false)
        run.cancel()
    }
}

/// The staged release: the repository's copy matches its pin, says FM-1_725, and downloads from its own release.
@Suite struct Skiff251ReleaseTests {
    @Test func theStagedPackageMatchesItsPin() throws {
        let f = LupeFirmware.skiff251
        let p = try f.load()
        #expect(p.product == "FM-1_725" && p.sha256 == f.sha256 && f.size == 610_429)
        #expect(f.downloadURL?.absoluteString == "https://github.com/sgerstl/fm1-ipad/releases/download/lupe-firmware-2/Skiff-Lupe-2.5.1.fwsc")
        #expect(LupeFirmware.skiff.release == "lupe-firmware-1")
        #expect(LupeFirmware.matching(identity: "ota-FM-1_725") == .skiff251)
    }
}

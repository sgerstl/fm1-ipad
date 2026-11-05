import Foundation
import Testing
@testable import SloopKit

/// The FM-1's buttons in Jib (vault skiff-arrange-spec.md, "Lupe and the FM-1's buttons"): the table, then the fake's
/// screen link carrying it both ways.
@Suite struct SkiffButtonMapTests {
    typealias M = SkiffButtonMap

    @Test func everyPageLandsWhereTheSpecSays() {
        func at(_ p: Int) -> M.Place? { M.place(for: UIState(home: false, page: p)) }
        for p in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 22, 23, 27, 28, 29, 39, 40] {
            #expect(at(p) == .shape(page: p), "page \(p)")
        }
        #expect(at(30) == .mixer(.mixer) && at(31) == .mixer(.delay) && at(32) == .mixer(.reverb))
        #expect(at(33) == .mixer(.chorus) && at(34) == .mixer(.global))
        #expect(at(35) == .browse && at(36) == .browse)                                // PRESETS, USER
        #expect(at(37) == .arrange(patterns: true) && at(38) == .projects)             // PATTERNS, PROJECT
        #expect(at(41) == .sequence(.notes) && at(42) == .sequence(.feel))
        #expect(at(43) == .sequence(.pattern) && at(44) == .sequence(.automation))
        #expect(at(45) == .arrange(patterns: false))                                   // SONG
        #expect(at(46) == nil)
        #expect(M.place(for: UIState(home: true, page: 12)) == .home)
        #expect(M.place(for: UIState(home: false, page: 5, layer: 3)) == .shape(page: 11))   // SCL held: the keys
        #expect(M.place(for: UIState(home: false, page: 5, layer: 2)) == nil)                 // another layer
        #expect(M.place(for: UIState(home: false, page: 5, menu: 1)) == nil)                  // the MENU
    }

    @Test func jibsPlacesGoBackToTheirPage() {
        for p in Array(0...45) where M.place(for: UIState(home: false, page: p)) != nil {
            let place = M.place(for: UIState(home: false, page: p))!
            // the place's page is the page (PRESETS and USER share Browse, which opens PRESETS)
            #expect(M.page(for: place) == (p == 36 ? 35 : p), "page \(p)")
        }
        #expect(M.page(for: .home) == 127)
        #expect(M.MixerTab.allCases.map(\.page) == [30, 31, 32, 33, 34])
    }
}

extension SkiffScreenLinkTests {
    /// GLO on the FM-1 opens the mixer on its tab and steps through them; another button lands elsewhere; and a tab
    /// picked in Jib (the page it maps to) goes to the FM-1.
    @Test func theButtonMapBothWaysOnTheFake() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        fake.screenLink = true
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        try await waitFor(5) { s.screenLinked && fake.screenWatched }
        for p in 30...34 {                                               // GLO, GLO, GLO …
            fake.pressOnDevice(page: p)
            try await waitFor(5) { s.deviceScreen?.page == p }
            #expect(SkiffButtonMap.place(for: s.deviceScreen!) == .mixer(SkiffButtonMap.MixerTab(rawValue: p - 30)!))
        }
        fake.pressOnDevice(page: 43)                                     // SEQ to PATTERN
        try await waitFor(5) { s.deviceScreen?.page == 43 }
        #expect(SkiffButtonMap.place(for: s.deviceScreen!) == .sequence(.pattern))
        for place: SkiffButtonMap.Place in [.mixer(.chorus), .arrange(patterns: true), .sequence(.automation), .shape(page: 39)] {
            let p = SkiffButtonMap.page(for: place)
            s.showOnDevice(page: p)
            try await waitFor(5) { fake.screen.page == p && s.deviceScreen?.page == p }
            #expect(SkiffButtonMap.place(for: s.deviceScreen!) == place)
        }
        run.cancel()
    }
}

/// Motion as Skiff plays it (motion.c), and its editing ops against the fake.
@Suite struct SkiffMotionTests {
    @Test func whatAStepSounds() {
        let m = TrackMotion(on: true, events: [.init(step: 2, id: 34, value: 40, lock: false), .init(step: 5, id: 34, value: 96, lock: false),
                                               .init(step: 6, id: 34, value: 120, lock: true), .init(step: 3, id: 36, value: 10, lock: true)])
        #expect(m.value(of: 34, at: 0, base: 64) == (64, .sound))           // each pass starts from the sound
        #expect(m.value(of: 34, at: 2, base: 64) == (40, .recorded))
        #expect(m.value(of: 34, at: 4, base: 64) == (40, .recorded))        // holds until the next change
        #expect(m.value(of: 34, at: 6, base: 64) == (120, .lock))           // a lock wins on its step
        #expect(m.value(of: 34, at: 7, base: 64) == (96, .recorded))        // … and only there
        #expect(m.value(of: 36, at: 4, base: 0) == (0, .sound))             // a lock doesn't hold
        #expect(m.ids == [34, 36])
    }
}

extension SkiffScreenLinkTests {
    @Test func motionEditsOnTheFake() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        #expect(await s.setMotion(track: 1, step: 4, id: 34, value: 90, lock: false) == .done)
        #expect(await s.setMotion(track: 1, step: 7, id: 34, value: 20, lock: true) == .done)
        #expect(s.motion[1]?.events.count == 2 && s.motion[1]?.record(34, at: 7)?.lock == true)
        #expect(await s.setMotion(track: 1, step: 7, id: 34, value: 20, lock: false) == .done)   // the lock made to hold
        #expect(s.motion[1]?.record(34, at: 7)?.lock == false && s.motion[1]?.events.count == 2)
        _ = await s.setMotion(track: 1, step: 9, id: 35, value: 5, lock: true)
        await s.clearLocks(track: 1, step: 9)
        #expect(s.motion[1]?.record(35, at: 9) == nil)
        await s.deleteMotion(track: 1, step: 4, id: 34)
        #expect(s.motion[1]?.events.map(\.step) == [7])
        await s.clearMotionLane(track: 1, id: 34)
        #expect(s.motion[1]?.events.isEmpty == true)
        // a knob turned while locking to a step: a lock there, the sound untouched
        let before = s.params.count > 34 ? s.params[34] : 0
        s.lockStep = 3
        s.set(track: s.selectedTrack, param: 34, to: 77)
        try await waitFor(5) { s.motion[s.selectedTrack]?.record(34, at: 3)?.lock == true }
        #expect(s.params.count <= 34 || s.params[34] == before)
        s.lockStep = nil
        run.cancel()
    }
}

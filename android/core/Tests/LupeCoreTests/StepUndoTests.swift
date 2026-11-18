import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Edit's undo and redo (Scott, 2026-11-18): the history in the core.
@Suite(.serialized) @MainActor struct StepUndoTests {
    func connected() async throws -> PhoneCore {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }), publish: { _, _ in })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil) { try await Task.sleep(for: .milliseconds(20)) }
        if core.session.playing { core.handle(json: #"{"intent":"stop"}"#); try await Task.sleep(for: .milliseconds(300)) }
        core.handle(json: #"{"intent":"padSelect","track":1,"entry":0}"#)
        try await Task.sleep(for: .milliseconds(200))
        return core
    }
    func notes(_ c: PhoneCore, _ i: Int) -> [Int] { let st = c.session.tracks[c.editorTrack()].steps[i]; return st.isOn ? st.notes : [] }

    @Test func undoRedoAndANewEditClearsRedo() async throws {
        let c = try await connected(); defer { c.stop() }
        let was = notes(c, 3)
        c.handle(json: #"{"intent":"undoMark","label":"note set · step 4"}"#)
        c.handle(json: #"{"intent":"setStepNotes","step":3,"notes":[70]}"#)
        #expect(notes(c, 3) == [70])
        c.handle(json: #"{"intent":"stepUndo"}"#)
        #expect(notes(c, 3) == was)
        #expect(c.editorArea().redoLabel == "note set · step 4")
        c.handle(json: #"{"intent":"stepRedo"}"#)
        #expect(notes(c, 3) == [70])
        c.handle(json: #"{"intent":"stepUndo"}"#)
        // a new edit after an undo clears the redo
        c.handle(json: #"{"intent":"undoMark","label":"note set · step 6"}"#)
        c.handle(json: #"{"intent":"setStepNotes","step":5,"notes":[72]}"#)
        c.handle(json: #"{"intent":"undoMark","label":"x"}"#)
        #expect(c.editorArea().redoLabel == nil)
        #expect(c.editorArea().undoLabel == "note set · step 6")
    }

    @Test func aGestureIsOneUndoStep() async throws {
        let c = try await connected(); defer { c.stop() }
        let a = notes(c, 8), b = notes(c, 9)
        c.handle(json: #"{"intent":"undoMark","label":"note moved"}"#)
        c.handle(json: #"{"intent":"setStepNotes","step":8,"notes":[61]}"#)
        c.handle(json: #"{"intent":"setStepNotes","step":9,"notes":[62]}"#)
        c.handle(json: #"{"intent":"stepUndo"}"#)
        #expect(notes(c, 8) == a)
        #expect(notes(c, 9) == b)
        #expect(c.editorArea().undoLabel != "note moved")
    }

    @Test func aStepTheFM1ChangedSinceIsSkipped() async throws {
        let c = try await connected(); defer { c.stop() }
        c.handle(json: #"{"intent":"undoMark","label":"note set · step 12"}"#)
        c.handle(json: #"{"intent":"setStepNotes","step":11,"notes":[64]}"#)
        c.closeUndo()
        // the FM-1 records over it (its own write, not an edit of the phone's)
        let t = c.editorTrack(); var st = c.session.tracks[t].steps[11]; st.notes = [67]; c.session.write(track: t, index: 11, st)
        c.handle(json: #"{"intent":"stepUndo"}"#)
        #expect(notes(c, 11) == [67])
    }
}

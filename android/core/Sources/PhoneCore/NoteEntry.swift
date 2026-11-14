// Note entry from the phone's own keyboard strip (decision 28, board 73: the Edit tab in landscape). Each goes through
// the call the iPad's piano roll and drum grid use: Session.write and Session.toggle (TRACK_STEP, the pattern the
// track is on), Session.noteDown / noteUp (a note-on and note-off on the track's channel). All four are refused while
// read-only. Skiff takes TRACK_STEP while it plays (EDITOR_PROTOCOL.md "30 TRACK_STEP" names no refusal), so none is
// refused for playing.
import Foundation
import SloopKit

extension PhoneCore {
    /// Skiff's chord: four notes a step at most (STEP_SET's note0..3).
    static let maxStepNotes = 4
    /// A note sounded with no note-off after it is let go after this long (a key the screen lost track of).
    static let auditionLimit: Duration = .seconds(5)

    private struct NoteWire: Decodable {
        let intent: String
        let step: Int?, notes: [Int]?, note: Int?, lane: Int?, on: Bool?
    }

    /// setStepNotes, toggleStepNote, toggleHit, playNote. True when `json` was one of them.
    func handleNoteJSON(_ json: String) -> Bool {
        guard json.contains("\"setStepNotes\"") || json.contains("\"toggleStepNote\"") || json.contains("\"toggleHit\"") || json.contains("\"playNote\""),
              let w = try? JSONDecoder().decode(NoteWire.self, from: Data(json.utf8)),
              ["setStepNotes", "toggleStepNote", "toggleHit", "playNote"].contains(w.intent) else { return false }
        guard canWrite() else { refuseReadOnly("\(w.intent)"); return true }
        let s = session, t = editorTrack()
        guard s.isConnected, s.tracks.indices.contains(t) else { refuse("The FM-1 hasn't been read yet. Try again in a moment."); return true }
        let kit = s.isKit(t)

        if w.intent == "playNote" {
            guard let on = w.on else { log("playNote: missing on"); return true }
            // a kit's lane plays its lane note (Music.skiffLaneNotes), as the iPad's drum keys do
            guard let note = w.note ?? w.lane.flatMap({ Music.skiffLaneNotes[safe: $0] }), (0...127).contains(note) else { log("playNote: missing note or lane"); return true }
            // the notes go out on the selected track's channel: the editor's track selected first, if it isn't
            if s.selectedTrack != t { s.select(track: t) }
            if on {
                s.noteDown(note)
                auditions[note]?.cancel()
                auditions[note] = Task { [weak self] in
                    try? await Task.sleep(for: Self.auditionLimit)
                    guard !Task.isCancelled, let self else { return }
                    self.session.noteUp(note); self.auditions[note] = nil
                }
            } else {
                auditions.removeValue(forKey: note)?.cancel()
                s.noteUp(note)
            }
            return true
        }

        guard let i = w.step, s.tracks[t].steps.indices.contains(i), i < 16 else { log("\(w.intent): no step \(w.step.map(String.init) ?? "")"); return true }
        var st = s.tracks[t].steps[i]
        switch w.intent {
        case "toggleHit":
            guard kit else { log("toggleHit: T\(t + 1) isn't a kit track (setStepNotes writes its notes)"); return true }
            guard let lane = w.lane, (0..<8).contains(lane) else { log("toggleHit: lane 0…7"); return true }
            // the lane's hit on or off in the step's hit bytes, the step's velocity as it is (100 on an empty step)
            let d = st.kitLanes
            s.write(track: t, index: i, st.withHits(d.setting(lane, on: !d.has(lane), level: 0)))
        case "setStepNotes":
            guard !kit else { log("setStepNotes: T\(t + 1) is a kit track (toggleHit writes its hits)"); return true }
            guard let raw = w.notes else { log("setStepNotes: missing notes"); return true }
            var notes: [Int] = []
            for n in raw where (0...127).contains(n) && !notes.contains(n) { notes.append(n) }
            guard notes.count <= Self.maxStepNotes else {
                refuse("A step holds \(Self.maxStepNotes) notes. Take one off to add another.", track: t + 1); return true
            }
            if notes.isEmpty {
                // cleared: the note gone (its locks stay; stepAction clear takes them too)
                if st.time == .note { s.write(track: t, index: i, .empty) }
                return true
            }
            if !st.isOn {
                // an empty step (or a TIE, which the new note cuts): the defaults, the step's own bytes kept
                st.time = .note; st.velocity = 100
            }
            // length is the TIEs after the step, untouched; velocity, accent, slide and Skiff's other bytes stay
            let old = st
            st.notes = notes
            st.levels = notes.map { n in old.notes.firstIndex(of: n).flatMap { old.levels[safe: $0] } ?? 0 }
            st.ratchets = Array(repeating: old.ratchets.first ?? 0, count: notes.count)
            s.write(track: t, index: i, st)
        default:    // toggleStepNote
            guard !kit else { log("toggleStepNote: T\(t + 1) is a kit track (toggleHit writes its hits)"); return true }
            guard let note = w.note, (0...127).contains(note) else { log("toggleStepNote: missing note"); return true }
            if !s.toggle(track: t, index: i, note: note) {
                refuse("Step \(i + 1) holds \(Self.maxStepNotes) notes already. Take one off to add another.", track: t + 1)
            }
        }
        pokeAreas(["editor"])
        return true
    }
}

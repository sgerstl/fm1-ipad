// Clear unused patterns (Scott, 2026-11-14, after "All 64 patterns are taken" on LUPE TEST): the FM-1's own CLEAR
// UNUSED (POOL op 3, EDITOR_PROTOCOL.md "78 POOL"; SkiffSongStore.clearUnused, as the iPad's pattern drawer sends it).
// It clears every kept pattern nothing uses (`pads.unused` lists them: no entry in any track's list or in a saved
// project names it, and no track is on it). Stopped only, and it can't be undone: the FM-1 asks on its own screen
// for this, so the phone's screen must have asked first (`confirmed`). The answer goes to the `notice` area.
import Foundation
import SloopKit

extension PhoneCore {
    private struct ClearWire: Decodable { let intent: String; let confirmed: Bool? }

    /// `{"intent":"clearUnusedPatterns","confirmed":true}`: true when `json` was it.
    func handleClearUnusedJSON(_ json: String) -> Bool {
        guard json.contains("\"clearUnusedPatterns\""),
              let w = try? JSONDecoder().decode(ClearWire.self, from: Data(json.utf8)), w.intent == "clearUnusedPatterns" else { return false }
        guard canWrite() else { refuseReadOnly("clearUnusedPatterns"); return true }
        guard let store = session.skiffSong, let pool = store.pool else {
            refuse("The FM-1's patterns haven't been read yet. Try again in a moment."); return true
        }
        let unused = (0..<64).filter { pool.patterns[safe: $0].map { $0.length > 0 && $0.uses == 0 } ?? false }.map { $0 + 1 }
        guard !unused.isEmpty else { refuse("No pattern is unused, so there is nothing to clear."); return true }
        guard !session.playing else { refuse("Stop playback to clear unused patterns. The FM-1 only clears them while stopped."); return true }
        guard w.confirmed == true else {
            log("clearUnusedPatterns erases pattern \(unused.map(String.init).joined(separator: ", ")) for good: the screen must confirm"); return true
        }
        Task {
            let rc = await store.clearUnused()      // the store keeps the pool the FM-1 answers with
            switch rc {
            case .done:
                let left = store.pool?.unused ?? 0, n = unused.count - left
                self.publishNotice(NoticeArea(text: "Cleared \(n) unused \(n == 1 ? "pattern" : "patterns"). \(store.pool?.free ?? 0) pattern numbers are free.", kind: .confirmation))
                self.log("cleared \(n) unused patterns: \(unused.map(String.init).joined(separator: ", "))")
            case .empty: self.refuse("No pattern is unused, so there is nothing to clear.")
            case .playing: self.refuse("Stop playback to clear unused patterns. The FM-1 only clears them while stopped.")
            default:
                if let r = store.refusal { self.refuse(r) }
                else { self.refuse("The FM-1 didn't clear the unused patterns. Check its screen, then try again.") }
            }
            self.pokeAreas(["pads", "timeline"])
        }
        return true
    }
}

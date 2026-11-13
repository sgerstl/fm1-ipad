// The `freetake` area: Skiff's FREE TAKE on the phone (screen link v7). A phrase played on the FM-1 with the transport
// stopped is offered once its 2.5 s pause has passed (`offer`); Keep that opens the FM-1's picker (`picker`: the four
// knobs in words and the take's own notes as the live sync brings them); Keep it lands the take (`landed`, with the FM-1's
// undo). Built from what the iPad's picker reads (DeviceSession.takePicker, takeOffer, freeTake; ios/FM1/FreeTakePicker.swift).
// The FM-1's keys never write from the phone: every choice here is a TAKE op (a write behind the read-only gate).
import Foundation
import SloopKit

public struct FreeTakeArea: Codable, Equatable, Sendable {
    public struct Guess: Codable, Equatable, Sendable { public var bpm: Int; public var caption: String }
    public struct Note: Codable, Equatable, Sendable { public var step: Int; public var len: Int; public var pitch: Int }

    /// A phrase heard on the selected track, offered as a take.
    public struct Offer: Codable, Equatable, Sendable {
        public var track: Int           // 1-based
        public var trackName: String
        public var notes: Int
        /// Keep that works from here (screen link v7); otherwise the strip names SHIFT + SAVE on the FM-1.
        public var canStart: Bool
        public var refused: Bool
    }

    /// The FM-1's picker, open.
    public struct Picker: Codable, Equatable, Sendable {
        public var track: Int
        public var trackName: String
        /// "Replaces pattern 12 there, and on its 1 other entry. Undo brings it back."
        public var replaces: String
        /// Keep it asks once more when it replaces a pattern: the words on that key ("Replace pattern 12 on T5 and 1 more"); nil: nothing to replace.
        public var confirm: String?
        public var guesses: [Guess]
        public var guess: Int
        public var bars: [Int]
        public var barsIndex: Int
        public var firstBeat: Int
        public var firstBeats: Int
        public var setsTempo: Bool
        public var tempoBefore: Int
        public var bpm: Int
        public var externalClock: Bool
        /// The transport is playing (Listen is on: the key says Stop).
        public var playing: Bool
        /// Steps shown (16 a bar, at most 64) and the track's notes over them.
        public var length: Int
        public var notes: [Note]
    }

    /// A take that landed: what it became, and the FM-1's own undo.
    public struct Landed: Codable, Equatable, Sendable {
        public var track: Int
        public var trackName: String
        public var length: Int
        public var bpm: Int
        public var undoFromHere: Bool
        public var undone: Bool
    }

    public var offer: Offer?
    public var picker: Picker?
    public var landed: Landed?
}

extension PhoneCore {
    public func freeTakeArea() -> FreeTakeArea? {
        let s = session
        guard s.isConnected, s.dialect == .skiff else { return nil }
        var a = FreeTakeArea()
        if let o = s.takeOffer, s.tracks.indices.contains(o.track) {
            a.offer = .init(track: o.track + 1, trackName: s.tracks[o.track].displayName, notes: o.notes, canStart: o.canStart, refused: o.refused)
        }
        if let p = s.takePicker, p.open, s.tracks.indices.contains(p.track) {
            a.picker = pickerArea(p)
        }
        if let f = s.freeTake, s.tracks.indices.contains(f.track) {
            a.landed = .init(track: f.track + 1, trackName: s.tracks[f.track].displayName, length: f.length, bpm: f.bpm,
                             undoFromHere: f.undoFromHere, undone: f.undone)
        }
        return a
    }

    private func pickerArea(_ p: TakePicker) -> FreeTakeArea.Picker {
        let s = session, t = p.track
        let tr = s.tracks[t]
        // the pattern a keep writes over, and its other entries (they name the same pattern, so they change too)
        var replaces = "The FM-1 writes it into the track. Undo brings back what was there."
        var confirm: String?
        if let pat = p.pattern {
            let n = s.skiffSong?.song.map { song in song.tracks.reduce(0) { $0 + $1.entries.filter { $0.poolIndex == pat }.count } } ?? 0
            let others = max(0, n - 1)
            let more = others > 0 ? ", and on its \(others) other entr\(others == 1 ? "y" : "ies")" : ""
            replaces = "Replaces pattern \(String(format: "%02d", pat + 1)) there\(more). Undo brings it back."
            confirm = "Replace pattern \(String(format: "%02d", pat + 1)) on T\(t + 1)" + (others > 0 ? " and \(others) more" : "")
        }
        // the take's notes as the FM-1 placed them: the track's own steps over the picker's bars (held notes run on through their ties)
        let len = max(1, min(tr.steps.count == 0 ? 64 : tr.steps.count, p.bars >= 8 ? 64 : 16 * p.bars))
        var notes: [FreeTakeArea.Note] = []
        for i in 0..<min(len, tr.steps.count) where tr.steps[i].time == .note {
            for pitch in tr.steps[i].notes {
                var j = i + 1
                while j < len, tr.steps[j].time == .tie { j += 1 }
                notes.append(.init(step: i, len: j - i, pitch: pitch))
            }
        }
        let guesses = p.guesses.enumerated().map { i, g in FreeTakeArea.Guess(bpm: g, caption: i == 0 ? "guess" : p.relation(i) ?? "") }
        return .init(track: t + 1, trackName: tr.displayName, replaces: replaces, confirm: confirm, guesses: guesses, guess: p.guess,
                     bars: TakePicker.barChoices, barsIndex: p.barsIndex, firstBeat: p.firstBeat, firstBeats: max(1, p.firstBeats),
                     setsTempo: p.setsTempo, tempoBefore: p.tempoBefore, bpm: p.bpm, externalClock: p.externalClock,
                     playing: s.playing, length: len, notes: notes)
    }

    // MARK: intents

    private struct TakeWire: Decodable { let intent: String; let index: Int?; let on: Bool? }

    /// The take intents. True when `json` was one of them. Each is a TAKE op, a write: refused up front while read-only
    /// (so Session's optimistic copy never shows a choice the guard then drops). Dismissing the offer or the landing
    /// strip is local, and works read-only.
    func handleFreeTakeJSON(_ json: String) -> Bool {
        guard let w = try? JSONDecoder().decode(TakeWire.self, from: Data(json.utf8)), w.intent.hasPrefix("take") else { return false }
        switch w.intent {
        case "takeDismissOffer": session.dismissTakeOffer(); return true
        case "takeDismissLanded": session.dismissFreeTake(); return true
        case "takeGuess", "takeBars", "takeFirstBeat", "takeSetTempo", "takeListen", "takeKeep", "takePutBack", "takeStart", "takeUndo":
            break
        default: return false
        }
        guard session.isConnected, session.dialect == .skiff else { log("\(w.intent): no Skiff FM-1 connected"); return true }
        guard canWrite() else { log("read-only: \(w.intent) not sent (allow writes to send it)"); return true }
        guard session.takeLinked else { log("\(w.intent): the FM-1's firmware has no FREE TAKE link (screen link v7)"); return true }
        func need(_ v: Int?) -> Int? { if v == nil { log("\(w.intent): missing index") }; return v }
        switch w.intent {
        case "takeGuess": if let i = need(w.index) { session.takeOp(.guess(i)) }
        case "takeBars": if let i = need(w.index) { session.takeOp(.bars(i)) }
        case "takeFirstBeat": if let i = need(w.index) { session.takeOp(.firstBeat(i)) }
        case "takeSetTempo": session.takeOp(.setTempo(w.on ?? true))
        case "takeListen": session.takeOp(.listen)
        case "takeKeep": session.takeOp(.keep)
        case "takePutBack": session.takeOp(.putBack)
        case "takeStart": session.startTake()
        default: session.undoFreeTake()
        }
        return true
    }
}

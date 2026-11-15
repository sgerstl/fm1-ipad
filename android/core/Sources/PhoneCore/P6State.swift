// P6's areas (android/BRIDGE.md §2's phase table): timeline and automation, and their intents. Mirrored field for
// field by android/app/.../core/P6State.kt. Direction-free: the phone draws time down (decision 6), Labs may draw it
// across; the area only says where things are in bars and steps.
import Foundation

// MARK: timeline (the song as the FM-1 holds it: each track's list as blocks in bars)

public struct TimelineArea: Codable, Equatable, Sendable {
    public struct Block: Codable, Equatable, Sendable {
        /// The block's first entry (0-based): what the intents name it by.
        public var id: Int
        public var first: Int
        public var last: Int
        /// "pattern", "rest", or "gap" (an empty entry inside the list: Skiff passes over it)
        public var kind: String
        /// The pattern number (1…64) on a pattern block; a chain's first part.
        public var pattern: Int?
        /// A chain's parts' patterns, in order (one entry: just `pattern`).
        public var patterns: [Int]
        /// REPS: how many passes it plays (STRETCH changes this).
        public var reps: Int
        /// Where it starts and how long it plays, in bars (4/4, from the patterns' lengths and divisions), and one pass.
        public var startBar: Double
        public var lengthBars: Double
        public var passBars: Double
        /// The entry carries a sound of its own (the pad's cut corner).
        public var hasSound: Bool
        /// The block the track is on; the pass playing (1-based) when known; the block a launch or the song brings next.
        public var playing: Bool
        public var pass: Int?
        public var next: Bool
        public var queued: Bool
    }
    public struct Track: Codable, Equatable, Sendable {
        public var track: Int                 // 1-based
        public var name: String
        public var muted: Bool
        public var blocks: [Block]
        /// The bar the track's list ends on.
        public var endBar: Double
        /// Entries in use (16 at most): whether one more fits.
        public var entriesUsed: Int
    }
    /// SONG off (each track loops its block), on, or once.
    public var mode: String
    public var tracks: [Track]
    /// The song's length in bars (the longest track).
    public var bars: Double
    /// Where the clock is, in bars since Start (4/4); nil when stopped or unknown. With SONG on the tracks move through
    /// their lists from there; with SONG off each loops its block (the blocks' `playing` and `pass` say where).
    /// The song's playhead in bars, stepped to the beat (2026-11-15; before, a hundredth of a bar, which resent this
    /// whole area many times a second). For a smooth one: clock ticksNow / `ticksPerBar`. To be dropped once the
    /// screens use that.
    public var playheadBar: Double?
    /// Clock pulses in a bar (96 in 4/4).
    public var ticksPerBar: Double = 96
    public var playing: Bool
    /// The pattern numbers the FM-1 holds (what Set pattern may name).
    public var kept: [Int]
    /// How many pattern numbers are free (as the pads area's): New and Duplicate need one. nil until the pool is read.
    public var patternsFree: Int? = nil
    /// Blocks and pads just removed that undoClear can still put back (the pads area's list, PadClearUndo.swift).
    public var clearUndo: [PadsArea.ClearUndo] = []
}

// MARK: automation (decision 7: one lane at a time under the grid; SEQ › AUTOMATION opens it)

public struct AutomationArea: Codable, Equatable, Sendable {
    public struct Lane: Codable, Equatable, Sendable {
        public var param: String              // the parameter's label ("CUTOFF")
        public var id: Int
        /// Recorded changes and locks on this lane (MOTION records). A change drawn here is a recorded change too:
        /// MOTION keeps no difference between played-in and drawn; locks are the other kind.
        public var recorded: Int
        public var locks: Int
    }
    public struct Point: Codable, Equatable, Sendable {
        public var step: Int
        /// What the parameter sounds at this step (raw), and where that comes from.
        public var value: Int
        /// "lock" (this step only), "recorded" (a change at or before this step, held), or "sound" (the sound's own)
        public var source: String
        public var text: String               // as the FM-1 shows the value
    }
    public var track: Int                     // 1-based: the editor's track
    public var pattern: Int                   // the pattern the track is on
    public var steps: Int                     // the pattern's length (what a lane spans)
    public var lanes: [Lane]
    /// The lane shown (`param`), "" when the track has none yet.
    public var lane: String
    public var min: Int
    public var max: Int
    /// The sound's own value of the lane's parameter (what the lane returns to).
    public var base: Int
    public var points: [Point]
    /// MOTION's shared records: used across all tracks, of 64.
    public var used: Int
    public var capacity: Int
}

// MARK: intents

public enum P6Intent: Equatable, Sendable {
    // timeline (ArrangeEdits, through the song store's rewrite)
    case blockInsert(track: Int, at: Int, pattern: Int)       // pattern 1…64 (a kept one) or 65, a REST
    case blockNew(track: Int)                                  // a new empty pattern after the track's last entry
    case blockMove(track: Int, block: Int, by: Int)            // one place earlier (−1) or later (+1) among its blocks
    case blockStretch(track: Int, block: Int, reps: Int)       // REPS 1…16
    case blockDelete(track: Int, block: Int, confirmed: Bool)  // a pattern used nowhere else would be erased: confirmed
    case blockSetPattern(track: Int, block: Int, pattern: Int, confirmed: Bool)
    case blockDuplicate(track: Int, block: Int)                // a linked copy right after it
    case blockChain(track: Int, block: Int)                    // into the next as one pattern
    case blockSplit(track: Int, block: Int)
    // automation
    case automationLane(String)                                // the lane shown (P3's lanePick does the same)
    case drawLane(param: String, from: Int, values: [Int], lock: Bool, confirmed: Bool)
    case clearLane(param: String, confirmed: Bool)

    private struct Wire: Decodable {
        let intent: String
        let track: Int?, at: Int?, pattern: Int?, block: Int?, by: Int?, reps: Int?, confirmed: Bool?
        let param: String?, from: Int?, values: [Int]?, lock: Bool?, lane: String?
    }

    static func decode(_ json: String) throws -> P6Intent? {
        let w = try JSONDecoder().decode(Wire.self, from: Data(json.utf8))
        func need<T>(_ v: T?, _ f: String) throws -> T { guard let v else { throw PhoneIntent.DecodeError.missing("\(w.intent).\(f)") }; return v }
        let ok = w.confirmed ?? false
        switch w.intent {
        case "blockInsert": return .blockInsert(track: try need(w.track, "track"), at: try need(w.at, "at"), pattern: try need(w.pattern, "pattern"))
        case "blockNew": return .blockNew(track: try need(w.track, "track"))
        case "blockMove": return .blockMove(track: try need(w.track, "track"), block: try need(w.block, "block"), by: try need(w.by, "by"))
        case "blockStretch": return .blockStretch(track: try need(w.track, "track"), block: try need(w.block, "block"), reps: try need(w.reps, "reps"))
        case "blockDelete": return .blockDelete(track: try need(w.track, "track"), block: try need(w.block, "block"), confirmed: ok)
        case "blockSetPattern": return .blockSetPattern(track: try need(w.track, "track"), block: try need(w.block, "block"), pattern: try need(w.pattern, "pattern"), confirmed: ok)
        case "blockDuplicate": return .blockDuplicate(track: try need(w.track, "track"), block: try need(w.block, "block"))
        case "blockChain": return .blockChain(track: try need(w.track, "track"), block: try need(w.block, "block"))
        case "blockSplit": return .blockSplit(track: try need(w.track, "track"), block: try need(w.block, "block"))
        case "automationLane": return .automationLane(try need(w.lane, "lane"))
        case "drawLane": return .drawLane(param: try need(w.param, "param"), from: try need(w.from, "from"), values: try need(w.values, "values"), lock: w.lock ?? false, confirmed: ok)
        case "clearLane": return .clearLane(param: try need(w.param, "param"), confirmed: ok)
        default: return nil
        }
    }

    var writes: Bool { if case .automationLane = self { false } else { true } }
}

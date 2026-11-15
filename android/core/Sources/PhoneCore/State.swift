// The ViewState areas the phone's screens draw, and the intents they send back (android/BRIDGE.md §2).
//
// These mirror P2's Kotlin (android/app/.../core/State.kt and Intent.kt) field for field: same names, same
// enum spellings, nil fields left out. Change both together, through android/fixtures/state/ (the Mac test
// writes them from this file; P2's FixturesTest decodes them), so a renamed field fails a build.
import Foundation

// MARK: link

public struct LinkArea: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case searching, connecting, reading, ready, lost, wrongFirmware }
    public var phase: Phase
    /// Why it was lost: "unplugged" (the FM-1 went away while connected), "readFailed" (it stopped answering
    /// during the read). P2 has words for "unplugged" and a general line for the rest.
    public var reason: String?
    /// What a wrong-firmware FM-1 reported (its INFO version string).
    public var firmware: String?
    public init(phase: Phase, reason: String? = nil, firmware: String? = nil) {
        self.phase = phase; self.reason = reason; self.firmware = firmware
    }
}

// MARK: top

public struct TopArea: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable { case loop, song, once }
    public enum Launch: String, Codable, Sendable { case loop, bar, beat, now }
    /// The FM-1 key's label: the project's name ("" when the music isn't saved in a slot).
    public var project: String
    public var playing: Bool
    /// REC lit: the selected track armed, or a recording running.
    public var rec: Bool
    public var tempo: Double
    public var mode: Mode
    public var launch: Launch
    /// How many tracks have a launch queued for the launch point (SkiffSongStore.marks' `queued`); the song's
    /// own next entries don't count (the pads show those as "next").
    public var waiting: Int
    /// The readout's position, 1-based, counted from MIDI clock in 4/4 (1·1 when stopped or unknown).
    public var bar: Int
    public var beat: Int
    /// The bars `bar` counts within (Loop: the selected track's block; Song and Once: the song); nil when unknown,
    /// and then `bar` counts up from Start.
    public var bars: Int? = nil
    public init(project: String = "", playing: Bool = false, rec: Bool = false, tempo: Double = 120, mode: Mode = .loop,
                launch: Launch = .bar, waiting: Int = 0, bar: Int = 1, beat: Int = 1) {
        self.project = project; self.playing = playing; self.rec = rec; self.tempo = tempo; self.mode = mode
        self.launch = launch; self.waiting = waiting; self.bar = bar; self.beat = beat
    }
}

extension TopArea {
    func with(bars: Int?) -> TopArea { var t = self; t.bars = bars; return t }
}

// MARK: pads (P3's PadsState)

public struct PadsArea: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case empty, pattern, rest }
    public enum Play: String, Codable, Sendable { case idle, playing, waiting, next }
    public struct Entry: Codable, Equatable, Sendable {
        public var kind: Kind = .empty
        public var pattern: Int?
        public var play: Play = .idle
        /// Where a waiting launch lands, 1-based.
        public var bar: Int?
        /// A waiting launch: the clock pulse it lands on (ClockArea.swift), nil with no clock (a dashed outline).
        public var launchTick: Double?
        /// REPS (nil when 1) and the pass playing.
        public var passes: Int?, pass: Int?
        public var progress: Double?
        public var hasSound = false
    }
    public struct Row: Codable, Equatable, Sendable {
        public var track: Int            // 1-based
        public var name: String
        public var muted: Bool
        public var entries: [Entry]
        /// The playing entry's pass in clock pulses, and the pulse this pass began on: the pass bar each frame is
        /// ((ticksNow − passStartTick) / passTicks) mod 1. nil stopped or with no clock.
        public var passTicks: Double? = nil
        public var passStartTick: Double? = nil
        /// A mute waiting for the launch point (PERFORM's staged mute): "none", "mute" or "unmute".
        public var mutePending = "none"
        /// This track's solo has mutes still waiting on other tracks.
        public var soloPending = false
        /// The pulse this track's launch point comes on (its waiting pad, mute or solo lands there); nil with no clock.
        public var launchTick: Double? = nil
    }
    public struct Scene: Codable, Equatable, Sendable {
        public var stored: Bool; public var current: Bool
        /// Recalled while playing, some of its tracks not in yet; the pulse the last of them lands on (nil: no clock).
        public var waiting = false
        public var launchTick: Double? = nil
    }
    public struct Ref: Codable, Equatable, Sendable { public var track: Int; public var entry: Int }   // track 1-based, entry 0-based
    public var rows: [Row]
    public var scenes: [Scene]
    public var selected: Ref
    /// The pattern numbers (1…64) the FM-1 holds: the only ones Set pattern can name (LIST SET takes "a kept
    /// pattern"; an empty number is refused, rc 1). The iPad's picker lists these (Scott's run, 2026-11-14).
    public var kept: [Int] = []
    /// How many pattern numbers are free (0…64): New pattern and Duplicate need one (LIST NEW and COPY answer
    /// PATTERNS FULL at 0). nil until the FM-1's pool has been read. Free is POOL's LEN 0 with nothing using it.
    public var patternsFree: Int? = nil
    /// The kept patterns nothing uses (1…64): what the FM-1's CLEAR UNUSED would clear. "Uses" is the FM-1's own
    /// count (POOL): entries in any track's list, entries in the saved projects, and a track on it.
    public var unused: [Int] = []
    /// Pads just cleared that undoClear can still put back (PadClearUndo.swift), for the Undo strip.
    public var clearUndo: [ClearUndo] = []
}

// MARK: editor (P3's EditorState)

public struct EditorArea: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case roll, drum }
    public enum Lock: String, Codable, Sendable { case off, held, latched }
    public struct Value: Codable, Equatable, Sendable { public var param: String; public var value: Int; public var locked: Bool }
    public struct Hit: Codable, Equatable, Sendable { public var lane: Int; public var accent: Bool }
    public struct Step: Codable, Equatable, Sendable {
        public var on = false
        /// The step's notes as MIDI numbers, in the FM-1's order (a chord: up to `maxNotes`); empty on a kit track.
        public var notes: [Int] = []
        /// A kit track's hits on this step: the lane (0…7) and whether it's accented. Skiff keeps no velocity per
        /// lane: the step's `velocity` is every hit's.
        public var hits: [Hit] = []
        /// The step carries a parameter lock (any of its `values` locked).
        public var locked = false
        public var note = ""
        public var extra = 0
        public var length = 1
        public var velocity = 100
        public var chance = 100
        public var ratchet = 1
        public var cond = "ALWAYS"
        public var nudge = 0
        public var pitchText = ""
        public var values: [Value] = []
        /// How long LENGTH can make it: up to the next step with a note (Session.setLength stops there), at most 16.
        public var maxLength = 16
        /// A TIE step: the step (0-based) whose note it holds, else -1. Pasting into it or clearing it shortens
        /// that note (Skiff's own behaviour; Scott's run, 2026-11-14), which a confirm should say.
        public var heldFrom = -1
    }
    public var track: Int                // 1-based
    public var trackName: String
    public var entry: String             // "A"…
    public var pattern: Int
    public var scale: String
    public var kind: Kind
    public var steps: [Step]             // sixteen
    public var selected: Int
    public var playhead: Int             // -1 stopped
    /// Always false: the phone has no Chord entry (the FM-1's keys never write from the phone; decision 5 revised,
    /// 2026-11-14). Kept so the schema stays as P3 has it until the field is dropped on both sides.
    public var chord: Bool
    public var lock: Lock
    public var lanes: [String]
    public var lane: String
    public var laneValues: [Int]
    /// How many notes a step holds (Skiff's chord: 4). 0 on a kit track.
    public var maxNotes = 4
    /// A kit track's eight lanes, short ("BD") and the MIDI note each plays (playNote's `lane` sounds it); empty on a
    /// note track.
    public var kitLanes: [String] = []
    public var kitNotes: [Int] = []
    /// The pattern's step count (the FM-1's LENGTH, 1…`patternStepsMax`); setPatternSteps sets it. `steps` above
    /// still carries the first sixteen only.
    public var patternSteps = 16
    public var patternStepsMax = 64
}

// MARK: diag

/// Not a screen's area: what the link debug screen shows to check the reads on real hardware (firmware, the screen
/// link, the clock). Kotlin keeps it for the debug screen only; nothing in the product UI reads it.
public struct DiagArea: Codable, Equatable, Sendable {
    public var firmware: String?
    public var tracks: Int
    public var selectedTrack: Int
    public var screenLinked: Bool
    /// The FM-1's screen as SCREEN reports it: page index, layer, menu, home (nil without the link).
    public var page: Int?, layer: Int?, menu: Int?, home: Bool?
    /// MIDI clock pulses since Start (-1: not running), and whether TRANSPORT says it's playing.
    public var clockTicks: Int
    public var playing: Bool
    /// Note-ons the FM-1 has sent since start (its keys; on Skiff with NOTES OUT ALL its sequencer too; none from a
    /// muted track): whether notes reach the phone at all.
    public var notesIn: Int = 0
}

// MARK: intents

/// What the person did, as Compose sends it: `{"intent": "play"}`, `{"intent": "setTempo", "bpm": 128.0}`.
/// PhoneCore handles the transport, the readout (tempo, rec, launch), the playback mode and the selections; P3 names it
/// doesn't do here decode as `notYet` and are logged.
public enum PhoneIntent: Equatable, Sendable {
    case retry, play, stop, rec, cancelWaiting
    case setTempo(Double)
    case setLaunch(TopArea.Launch)
    case setPlaybackMode(TopArea.Mode)
    case setTab(String)
    case setDivider(String)
    case padSelect(track: Int, entry: Int)
    case stepSelect(Int)
    /// A P3 intent PhoneCore doesn't do yet (pad launches, edits, locks): its name, logged.
    case notYet(String)

    private struct Wire: Decodable {
        let intent: String
        let bpm: Double?
        let quantize: TopArea.Launch?
        let mode: TopArea.Mode?
        let tab: String?
        let position: String?
        let track: Int?
        let entry: Int?
        let step: Int?
    }

    public enum DecodeError: Error { case unknown(String), missing(String) }

    public static func decode(_ json: String) throws -> PhoneIntent {
        let w = try JSONDecoder().decode(Wire.self, from: Data(json.utf8))
        func need<T>(_ v: T?, _ f: String) throws -> T { guard let v else { throw DecodeError.missing("\(w.intent).\(f)") }; return v }
        switch w.intent {
        case "retry": return .retry
        case "play": return .play
        case "stop": return .stop
        case "rec": return .rec
        case "cancelWaiting": return .cancelWaiting
        case "setTempo": return .setTempo(try need(w.bpm, "bpm"))
        case "setLaunch": return .setLaunch(try need(w.quantize, "quantize"))
        case "setPlaybackMode": return .setPlaybackMode(try need(w.mode, "mode"))
        case "setTab": return .setTab(try need(w.tab, "tab"))
        case "setDivider": return .setDivider(try need(w.position, "position"))
        case "padSelect": return .padSelect(track: try need(w.track, "track"), entry: try need(w.entry, "entry"))
        case "stepSelect": return .stepSelect(try need(w.step, "step"))
        case "padTap", "padSelectSound", "padNew", "padSet", "padClear", "trackSelect", "trackMute", "sceneRecall",
             "sceneStore", "stepHold", "stepAdjust", "lockToggle", "lockClear", "locksClearAll",
             "stepAction", "lanePick":
            return .notYet(w.intent)
        default: throw DecodeError.unknown(w.intent)
        }
    }
}

/// One JSON encoder for every area: sorted keys, so equal states encode to equal strings.
enum AreaJSON {
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }()
    static func encode<T: Encodable>(_ v: T) -> String { String(decoding: (try? encoder.encode(v)) ?? Data("{}".utf8), as: UTF8.self) }
}

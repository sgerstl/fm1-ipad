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
    public init(project: String = "", playing: Bool = false, rec: Bool = false, tempo: Double = 120, mode: Mode = .loop,
                launch: Launch = .bar, waiting: Int = 0, bar: Int = 1, beat: Int = 1) {
        self.project = project; self.playing = playing; self.rec = rec; self.tempo = tempo; self.mode = mode
        self.launch = launch; self.waiting = waiting; self.bar = bar; self.beat = beat
    }
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
    }
    public struct Scene: Codable, Equatable, Sendable { public var stored: Bool; public var current: Bool }
    public struct Ref: Codable, Equatable, Sendable { public var track: Int; public var entry: Int }   // track 1-based, entry 0-based
    public var rows: [Row]
    public var scenes: [Scene]
    public var selected: Ref
}

// MARK: editor (P3's EditorState)

public struct EditorArea: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case roll, drum }
    public enum Lock: String, Codable, Sendable { case off, held, latched }
    public struct Value: Codable, Equatable, Sendable { public var param: String; public var value: Int; public var locked: Bool }
    public struct Step: Codable, Equatable, Sendable {
        public var on = false
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
    public var chord: Bool
    public var lock: Lock
    public var lanes: [String]
    public var lane: String
    public var laneValues: [Int]
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
}

// MARK: intents

/// What the person did, as Compose sends it: `{"intent": "play"}`, `{"intent": "setTempo", "bpm": 128.0}`.
/// P1 handles `retry`, `play` and `stop`; the rest decode (so P2 can send them) and are logged as not yet done.
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
             "sceneStore", "stepHold", "stepAdjust", "chordToggle", "lockToggle", "lockClear", "locksClearAll",
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

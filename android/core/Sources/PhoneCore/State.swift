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
    /// How many tracks have a launch waiting for the launch point.
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

    private struct Wire: Decodable {
        let intent: String
        let bpm: Double?
        let quantize: TopArea.Launch?
        let mode: TopArea.Mode?
        let tab: String?
        let position: String?
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
        default: throw DecodeError.unknown(w.intent)
        }
    }
}

/// One JSON encoder for every area: sorted keys, so equal states encode to equal strings.
enum AreaJSON {
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }()
    static func encode<T: Encodable>(_ v: T) -> String { String(decoding: (try? encoder.encode(v)) ?? Data("{}".utf8), as: UTF8.self) }
}

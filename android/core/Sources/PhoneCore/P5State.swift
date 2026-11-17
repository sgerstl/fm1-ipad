// P5's areas (android/BRIDGE.md §2's phase table): mix, sounds, projects, and their intents. Mirrored field for field
// by android/app/.../core/P5State.kt (P1 writes both; P2 builds the screens on them). A file of its own so P4's
// edits to State.swift and PageArea.swift don't collide.
import Foundation

// MARK: mix (the Mix tab: GLO's five pages one at a time, design/structure-map.md "Mix")

public struct MixArea: Codable, Equatable, Sendable {
    public struct Section: Codable, Equatable, Sendable {
        /// "mixer", "delay", "reverb", "chorus", "global"
        public var key: String
        public var title: String
        /// The FM-1's page number for it (30…34 on Skiff), for the screen link.
        public var page: Int
    }
    public struct Row: Codable, Equatable, Sendable {
        public var track: Int                 // 1-based
        public var name: String
        public var selected: Bool
        public var level: Int                 // P_LEVEL 0…127
        public var levelText: String          // as the FM-1 shows it under the fader: "-3 dB", "OFF"
        public var pan: Int                   // −64…63 (decision 14: shown in the row's hold menu)
        public var panText: String            // "C", "L12", "R7"
        public var mute: Bool
        /// Lupe's solo (the iPad's, through PERFORM's mutes): the other tracks muted while it's on.
        public var solo: Bool
        /// The track's REVERB send (FX page knob 4), read for every track every few seconds; nil until read.
        public var reverb: Int?
        public var reverbText: String?
        public var reverbMax: Int
    }
    /// One of the four effect cards: the page's four knobs (P4's control shape) and settings that aren't knobs
    /// (2.5.1's DELAY MODE on GLO › DELAY).
    public struct Card: Codable, Equatable, Sendable {
        public var title: String
        public var controls: [PageArea.Control?]
        public var settings: [PageArea.Control]
        /// What the card's picture is drawn from (decision 30), in the pages' shape: `kind` delay, reverb, chorus or
        /// global; `values` the four knobs' raw values in the FM-1's order (0 for an empty knob); `caption` the
        /// card's named choice as the FM-1 shows it (DELAY's TIME, REVERB's TYPE, CHORUS's MODE).
        public var graph: PageArea.Graph = PageArea.Graph()
    }
    public var sections: [Section]
    /// The section on screen. Picking one sends the FM-1 there when the screen link is on (a write); GLO pressed on
    /// the FM-1 moves it here.
    public var section: String
    /// The six rows (shown on "mixer"; kept on the others so the hold menu's PAN can open from anywhere).
    public var rows: [Row]
    /// The card for delay, reverb, chorus or global; nil on mixer.
    public var card: Card?
}

/// The six tracks' output levels, 0…1 (Skiff's METER over the screen link, else Lupe's own from the notes heard),
/// sampled every 50 ms and sent only when one moves: an area of its own so the Mix rows aren't resent 20 times a second.
public struct MetersArea: Codable, Equatable, Sendable {
    public var levels: [Double]
}

// MARK: sounds (the Sounds browser in the bottom half: the track name ⌄, SAVE, the hold menu)

public struct SoundsArea: Codable, Equatable, Sendable {
    public struct Engine: Codable, Equatable, Sendable {
        public var index: Int
        public var name: String
        /// Whether this track may play it (light tracks T5–T6: not PHYS or GRAIN).
        public var offered: Bool
        /// A drum engine (DRUM, DRUM-X): its presets are kits (decision 15: a kit per track).
        public var kit: Bool
    }
    public struct Preset: Codable, Equatable, Sendable {
        public var index: Int
        public var name: String
        public var current: Bool
    }
    public struct UserSlot: Codable, Equatable, Sendable {
        public var slot: Int                  // 0…31
        public var used: Bool
        public var name: String
        public var engine: Int?
        public var engineName: String?
        public var current: Bool
    }
    /// What a pick changes: the track's own sound, or one pad's (an entry's) sound that overrides it (decision 15).
    public struct Target: Codable, Equatable, Sendable {
        public var track: Int                 // 1-based
        public var entry: Int?                // 0-based; nil: the track
    }
    /// An entry's own sound (its pad is marked: the cut corner).
    public struct EntrySound: Codable, Equatable, Sendable {
        public var kind: String               // "none", "preset", "user"
        public var engine: Int?
        public var preset: Int?
        public var slot: Int?
        public var name: String?
    }
    public var target: Target
    public var trackName: String
    /// The track's engine and preset now.
    public var engine: Int
    public var preset: Int
    public var engines: [Engine]
    /// The engine whose presets are listed (the track's, until another is browsed).
    public var viewing: Int
    public var presets: [Preset]
    /// Skiff's 32 user slots, used or empty (SAVE puts the track's sound into one).
    public var user: [UserSlot]
    /// For an entry target: its sound now.
    public var entrySound: EntrySound?
    /// Why the FM-1 kept the old sound (an engine a light track can't play), until the next pick.
    public var refusal: String?
}

// MARK: projects (the FM-1's four project slots; the iPad's Projects sheet, FM-1 side only)

public struct ProjectsArea: Codable, Equatable, Sendable {
    public struct Slot: Codable, Equatable, Sendable {
        public var slot: Int                  // 0…3
        public var used: Bool
        public var name: String
        /// The slot the music came from or was last saved to.
        public var current: Bool
    }
    public var slots: [Slot]
    /// The music's name and whether it changed since its slot was loaded or saved (what a load would lose).
    public var name: String
    public var changed: Bool
    /// Load, save or rename going on (the FM-1 stops the transport for a load or a save).
    public var busy: Bool
    /// Changed since a phone project was last read or written (PhoneProjects.swift); nil: none was, this run.
    public var phoneEdited: Bool? = nil
}

// MARK: intents

/// P5's intents, decoded. Writes are refused while read-only, as P3's are.
public enum P5Intent: Equatable, Sendable {
    // mix
    case mixSection(String)
    case setLevel(track: Int, value: Int)
    case setPan(track: Int, value: Int)
    case setReverb(track: Int, value: Int)
    case trackSolo(Int)
    case setMixParam(slot: Int, value: Int)        // the card's knob 0…3
    case setMixSetting(index: Int, value: Int)     // the card's settings (DELAY MODE)
    // sounds
    case soundsTarget(track: Int, entry: Int?)
    case soundsView(engine: Int)
    case pickPreset(engine: Int, preset: Int)
    case pickUser(slot: Int)
    case clearEntrySound
    case saveSound(slot: Int, name: String, confirmed: Bool)
    case eraseUser(slot: Int, confirmed: Bool)
    // projects
    case projectLoad(slot: Int, confirmed: Bool)
    case projectSave(confirmed: Bool)
    case projectSaveAs(slot: Int, name: String, confirmed: Bool)
    case projectRename(slot: Int, name: String)

    private struct Wire: Decodable {
        let intent: String
        let section: String?, track: Int?, value: Int?, slot: Int?, index: Int?, entry: Int?
        let engine: Int?, preset: Int?, name: String?, confirmed: Bool?
    }

    /// nil: not one of these.
    static func decode(_ json: String) throws -> P5Intent? {
        let w = try JSONDecoder().decode(Wire.self, from: Data(json.utf8))
        func need<T>(_ v: T?, _ f: String) throws -> T { guard let v else { throw PhoneIntent.DecodeError.missing("\(w.intent).\(f)") }; return v }
        let ok = w.confirmed ?? false
        switch w.intent {
        case "mixSection": return .mixSection(try need(w.section, "section"))
        case "setLevel": return .setLevel(track: try need(w.track, "track"), value: try need(w.value, "value"))
        case "setPan": return .setPan(track: try need(w.track, "track"), value: try need(w.value, "value"))
        case "setReverb": return .setReverb(track: try need(w.track, "track"), value: try need(w.value, "value"))
        case "trackSolo": return .trackSolo(try need(w.track, "track"))
        case "setMixParam": return .setMixParam(slot: try need(w.slot, "slot"), value: try need(w.value, "value"))
        case "setMixSetting": return .setMixSetting(index: try need(w.index, "index"), value: try need(w.value, "value"))
        case "soundsTarget": return .soundsTarget(track: try need(w.track, "track"), entry: w.entry)
        case "soundsView": return .soundsView(engine: try need(w.engine, "engine"))
        case "pickPreset": return .pickPreset(engine: try need(w.engine, "engine"), preset: try need(w.preset, "preset"))
        case "pickUser": return .pickUser(slot: try need(w.slot, "slot"))
        case "clearEntrySound": return .clearEntrySound
        case "saveSound": return .saveSound(slot: try need(w.slot, "slot"), name: try need(w.name, "name"), confirmed: ok)
        case "eraseUser": return .eraseUser(slot: try need(w.slot, "slot"), confirmed: ok)
        case "projectLoad": return .projectLoad(slot: try need(w.slot, "slot"), confirmed: ok)
        case "projectSave": return .projectSave(confirmed: ok)
        case "projectSaveAs": return .projectSaveAs(slot: try need(w.slot, "slot"), name: try need(w.name, "name"), confirmed: ok)
        case "projectRename": return .projectRename(slot: try need(w.slot, "slot"), name: try need(w.name, "name"))
        default: return nil
        }
    }

    /// Picking the section, the target or the engine to browse is the screen's own (a section pick also moves the
    /// FM-1's screen when linked: that part is a write, checked where it's sent).
    var writes: Bool {
        switch self {
        case .mixSection, .soundsTarget, .soundsView: false
        default: true
        }
    }
}

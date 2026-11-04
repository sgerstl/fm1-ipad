import Foundation

// The firmware seam: what the session needs from a device, whatever it runs. INFO names the firmware;
// a driver turns the session's requests into that firmware's commands and its replies and pushes back
// into the shared types (TrackList, SynthStep, ParamDesc, Push). Anything one firmware alone has (SLOOP's
// sections, backups and sample slots) stays with that firmware's driver and is reached through it.

/// A firmware Jib knows how to talk to, found from INFO.
public enum FirmwareDialect: Equatable, Sendable {
    case sloop
    /// Skiff 2.2 (github.com/illuminus5/skiff): Felucca's command numbers, six tracks, INFO's tags.
    case skiff

    /// The dialect INFO reports, or nil for firmware Jib doesn't know (it refuses to connect). `body` is
    /// INFO's whole reply, for the tags Skiff ends it with.
    public static func detect(_ info: DeviceInfo, body: [UInt8] = []) -> FirmwareDialect? {
        if info.version == DeviceInfo.expectedVersion, info.protocolVersion == DeviceInfo.expectedProtocol { return .sloop }
        if info.version == SkiffInfo.expectedVersion, let s = SkiffInfo(body), s.isSupported { return .skiff }
        return nil
    }

    /// Every firmware and version Jib speaks, for the "other firmware" message.
    public static let known = "FELUCCA SLOOP 2.8.4 (protocol 12) or Skiff 2.2 (FELUCCA v2.2)"
}

/// The parameter ids the session itself reads and follows (the Sound tab reads every one by DESC). Most
/// are Felucca's and the same on both; the chord keys moved, and SLOOP's drum and MIDI globals are SLOOP's.
public struct ParamIDs: Equatable, Sendable {
    public var level = Param.level, root = Param.root, scale = Param.scale, quant = Param.quant
    public var transpose = Param.transpose, length = Param.length, division = Param.division
    public var pan = Param.pan, mute = Param.mute, chord = Param.chord, arpMode = Param.arpMode
    /// Play direction and the track's swing (the counted playhead needs them); nil where unused.
    public var direction: Int?, swing: Int?
    /// The INSERT's type and ENV SYNC, which change how other knobs read on SLOOP's screen.
    public var insertType: Int? = Param.insertType, envSync: Int? = Param.envSync
    public var bpm = Global.bpm, globalSwing = Global.swing
    public var drumLevel: Int? = Global.drumLevel, otherChannels: Int? = Global.otherChannels, drumMap: Int? = Global.drumMap

    public init() {}
    public static let sloop = ParamIDs()

    /// The track parameters read for every track.
    public var trackReads: [Int] {
        [level, root, scale, quant, transpose, length, division, pan, mute, chord, arpMode] + [direction, swing].compactMap { $0 }
    }
    public var globalReads: [Int] { [bpm, globalSwing] + [drumLevel, otherChannels, drumMap].compactMap { $0 } }
}

/// The transport, polled on firmware without LIVE (Skiff's TRANSPORT, its keep-alive too).
public struct TransportState: Equatable, Sendable {
    public var playing: Bool
    public var countingIn: Bool
    public var armedTracks: Int
    public var selected: Int
    public init(playing: Bool, countingIn: Bool = false, armedTracks: Int = 0, selected: Int) {
        self.playing = playing; self.countingIn = countingIn; self.armedTracks = armedTracks; self.selected = selected
    }
}

/// A page of four knobs for the Sound tab, as the firmware lays its own pages out. `family` is the FM-1
/// button (FX, SEL, ENV, LFO, EDIT, GLO, ARP, SEQ); scope 0 a track parameter (whole id), 1 a global.
public struct PageSpec: Equatable, Sendable {
    public var title: String
    public var family: String
    public var scope: Int
    public var ids: [Int?]
    /// 1 / 2: the engine's EDIT pages, titled by NAMES.
    public var engineEdit = 0
    public init(title: String, family: String, scope: Int, ids: [Int?], engineEdit: Int = 0) {
        self.title = title; self.family = family; self.scope = scope; self.ids = ids; self.engineEdit = engineEdit
    }
}

/// The device's size: tracks, steps, and which tracks play what.
public struct DeviceShape: Equatable, Sendable {
    public var trackCount: Int
    public var stepCount: Int
    /// A fixed drum track (SLOOP's track 4: 16 lanes, kits, no presets); nil when every track is a synth part.
    public var drumTrack: Int?
    /// Tracks that can't play some engines (a bit per track), and those engines (a bit per engine).
    public var lightTracks: Int
    public var lightEngines: Int
    /// Each track's colour (RGB), from the firmware's own palette; at least `trackCount` of them.
    public var trackColours: [UInt32]

    public init(trackCount: Int, stepCount: Int, drumTrack: Int?, lightTracks: Int = 0, lightEngines: Int = 0,
                trackColours: [UInt32] = DeviceShape.sloopColours) {
        self.trackCount = trackCount; self.stepCount = stepCount; self.drumTrack = drumTrack
        self.lightTracks = lightTracks; self.lightEngines = lightEngines
        self.trackColours = trackColours
    }

    /// SLOOP 2.8.4's track colours (its editor CSS and firmware gfx.c TE_COL).
    public static let sloopColours: [UInt32] = [0x287CFF, 0x1ECC70, 0xFFC618, 0xFF621A]
    /// Skiff's SKIFF theme (build/gen ui_palettes.h, as picked for Jib in the Arrange spec, 2026-11-05):
    /// vermilion, teal, amber, violet, pink, lime.
    public static let skiffColours: [UInt32] = [0xFF5A36, 0x22C3B4, 0xFFBF00, 0x9580FF, 0xFF6FAE, 0xA3E635]

    /// SLOOP 2.8.4: four tracks of 64 steps, the fourth the drum track. Also what the app shows before
    /// anything is connected.
    public static let sloop = DeviceShape(trackCount: 4, stepCount: 64, drumTrack: 3)

    public func isDrums(_ t: Int) -> Bool { t == drumTrack }
    public func canPlay(track t: Int, engine e: Int) -> Bool {
        lightTracks >> t & 1 == 0 || lightEngines >> e & 1 == 0
    }
}

/// What a firmware can do beyond reading and editing tracks, steps and sounds.
public struct FirmwareCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Step positions over SysEx (SLOOP's LIVE): the playhead is polled.
    public static let livePlayhead = Self(rawValue: 1 << 0)
    /// The FM-1's page followed and set (fm1-ipad's patch to SLOOP); found at connect.
    public static let screenLink = Self(rawValue: 1 << 1)
    /// User sample slots (SMP_*).
    public static let samples = Self(rawValue: 1 << 2)
    /// SLOOP's song: sections A–D, the song order, chains, SONG REC.
    public static let sloopSong = Self(rawValue: 1 << 3)
    /// Projects read and written whole (SLOOP's backup objects).
    public static let projects = Self(rawValue: 1 << 4)
    /// User presets (UP_LIST, UP_LOAD).
    public static let userPresets = Self(rawValue: 1 << 5)
    /// REC as the FM-1's button.
    public static let recording = Self(rawValue: 1 << 6)
    /// The FM-1's master level, to quiet its speaker while the iPad plays its sound.
    public static let masterLevel = Self(rawValue: 1 << 7)
}

/// One connected device, spoken to in its firmware's dialect. One request in flight at a time.
public protocol FirmwareDriver: AnyObject, Sendable {
    var dialect: FirmwareDialect { get }
    var info: DeviceInfo { get }
    var shape: DeviceShape { get }
    var capabilities: FirmwareCapabilities { get }
    /// Pushes from the device, already in the session's terms.
    var pushes: AsyncStream<Push> { get }
    var params: ParamIDs { get }
    /// The Sound tab's pages, when the firmware's differ from the app's own (SLOOP's); nil: the app's.
    var pageLayout: [PageSpec]? { get }

    /// Whatever the driver reads once before the session does (Skiff: every DESC, to find its ids).
    func prepare() async throws

    func close() async
    /// A plain MIDI message (a note from the iPad's keyboard), outside the request queue.
    func sendMIDI(_ bytes: [UInt8])

    func tracks() async throws -> TrackList
    func selectTrack(_ t: Int) async throws -> TrackList
    func names(engine: Int) async throws -> PresetNames
    func synthStep(track: Int, index: Int) async throws -> SynthStep
    /// Writes return the step as the device stored it.
    func setSynthStep(track: Int, index: Int, _ step: SynthStep) async throws -> SynthStep
    /// The drum track's steps (only with `shape.drumTrack`).
    func drumStep(index: Int) async throws -> DrumStep
    func setDrumStep(index: Int, _ step: DrumStep) async throws -> DrumStep
    func trackParam(track: Int, id: Int) async throws -> Int
    func setTrackParam(track: Int, id: Int, value: Int) async throws -> Int
    func global(id: Int) async throws -> Int
    func setGlobal(id: Int, value: Int) async throws -> Int
    /// Scope 0: a track parameter by its whole id; 1: a global.
    func desc(scope: Int, id: Int) async throws -> ParamDesc
    /// The selected track's parameters and every global.
    func dump() async throws -> ParamDump
    /// Starts the pushes; `screenLink` also asks for the screen state where the firmware has it.
    func watch(screenLink: Bool) async throws
    func ping() async throws
    /// Loads a factory preset onto the selected track.
    func preset(engine: Int, index: Int) async throws -> (engine: Int, preset: Int)
    func userPresets() async throws -> [UserPreset]
    /// 0: loaded; anything else: empty or refused.
    func userLoad(slot: Int) async throws -> Int
    /// PLAY or STOP; the state after it, where the firmware reports one.
    func transport(play: Bool) async throws -> LiveState?
    /// The transport, on firmware that has no LIVE (nil: LIVE covers it).
    func transportState() async throws -> TransportState?
}

/// Connects to whatever is on the transport: reads INFO and hands back the matching driver, or the
/// INFO of firmware Jib doesn't know.
public enum FirmwareDetector {
    public enum Outcome: Sendable {
        case driver(FirmwareDriver)
        case unknown(DeviceInfo)
    }

    public static func connect(_ transport: SysExTransport) async throws -> Outcome {
        let c = SloopClient(transport: transport)
        await c.start()
        do {
            try await Task.sleep(for: .milliseconds(200))      // let notes queued in the USB buffer drain
            let body = try await c.send(.info)
            let i = try DeviceInfo(body)
            switch FirmwareDialect.detect(i, body: body) {
            case .sloop: return .driver(SloopDriver(client: c, info: i))
            case .skiff:
                let d = try SkiffDriver(client: c, body: body)
                try await d.prepare()
                return .driver(d)
            case nil:
                await c.close()
                return .unknown(i)
            }
        } catch {
            await c.close()
            throw error
        }
    }
}

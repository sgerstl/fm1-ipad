import Foundation

// The firmware seam: what the session needs from a device, whatever it runs. INFO names the firmware;
// a driver turns the session's requests into that firmware's commands and its replies and pushes back
// into the shared types (TrackList, SynthStep, ParamDesc, Push). Anything one firmware alone has (SLOOP's
// sections, backups and sample slots) stays with that firmware's driver and is reached through it.

/// A firmware Jib knows how to talk to, found from INFO.
public enum FirmwareDialect: Equatable, Sendable {
    case sloop

    /// The dialect INFO reports, or nil for firmware Jib doesn't know (it refuses to connect).
    public static func detect(_ info: DeviceInfo) -> FirmwareDialect? {
        if info.version == DeviceInfo.expectedVersion, info.protocolVersion == DeviceInfo.expectedProtocol { return .sloop }
        return nil
    }

    /// Every firmware and version Jib speaks, for the "other firmware" message.
    public static let known = "FELUCCA SLOOP 2.8.4 (protocol 12)"
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

    public init(trackCount: Int, stepCount: Int, drumTrack: Int?, lightTracks: Int = 0, lightEngines: Int = 0) {
        self.trackCount = trackCount; self.stepCount = stepCount; self.drumTrack = drumTrack
        self.lightTracks = lightTracks; self.lightEngines = lightEngines
    }

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
            let i = try await c.info()
            switch FirmwareDialect.detect(i) {
            case .sloop: return .driver(SloopDriver(client: c, info: i))
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

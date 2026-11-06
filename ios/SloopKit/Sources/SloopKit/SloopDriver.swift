import Foundation

/// SLOOP 2.8.4 (editor protocol 12), plus fm1-ipad's screen link when the FM-1 answers UI. Every request
/// goes through `client`; the SLOOP-only parts (LIVE, the song, backups, sample slots) are the client's
/// own calls, reached as `driver.client` by the session where the capabilities allow.
public final class SloopDriver: FirmwareDriver {
    public let client: SloopClient
    public let info: DeviceInfo
    public var dialect: FirmwareDialect { .sloop }
    public var shape: DeviceShape { .sloop }
    public var capabilities: FirmwareCapabilities {
        [.livePlayhead, .samples, .sloopSong, .projects, .userPresets, .recording, .masterLevel]
    }
    public var pushes: AsyncStream<Push> { client.pushes }
    public var params: ParamIDs { .sloop }
    public var pageLayout: [PageSpec]? { nil }
    public func prepare() async throws {}

    public init(client: SloopClient, info: DeviceInfo) {
        self.client = client
        self.info = info
    }

    public func close() async { await client.close() }
    public func sendMIDI(_ bytes: [UInt8]) { client.sendMIDI(bytes) }

    public func tracks() async throws -> TrackList { try await client.tracks() }
    public func selectTrack(_ t: Int) async throws -> TrackList { try await client.selectTrack(t) }
    public func names(engine: Int) async throws -> PresetNames { try await client.names(engine: engine) }
    public func synthStep(track: Int, index: Int) async throws -> SynthStep { try await client.synthStep(track: track, index: index) }
    public func setSynthStep(track: Int, index: Int, _ step: SynthStep) async throws -> SynthStep {
        try await client.setSynthStep(track: track, index: index, step)
    }
    public func drumStep(index: Int) async throws -> DrumStep { try await client.drumStep(index: index) }
    public func setDrumStep(index: Int, _ step: DrumStep) async throws -> DrumStep { try await client.setDrumStep(index: index, step) }
    public func trackParam(track: Int, id: Int) async throws -> Int { try await client.trackParam(track: track, id: id) }
    public func setTrackParam(track: Int, id: Int, value: Int) async throws -> Int {
        try await client.setTrackParam(track: track, id: id, value: value)
    }
    public func global(id: Int) async throws -> Int { try await client.global(id: id) }
    public func setGlobal(id: Int, value: Int) async throws -> Int { try await client.setGlobal(id: id, value: value) }
    public func desc(scope: Int, id: Int) async throws -> ParamDesc { try await client.desc(scope: scope, id: id) }
    public func dump() async throws -> ParamDump {
        try await client.dump(paramCount: info.paramCount, globalCount: info.globalCount)
    }
    /// WATCH 3: pushes and TRACK_CHANGED; 7 also the screen state (fm1-ipad firmware).
    public func watch(screenLink: Bool, scope: Bool) async throws { _ = try await client.watch(screenLink ? 7 : 3) }
    public func ping() async throws { try await client.ping() }
    public func preset(engine: Int, index: Int) async throws -> (engine: Int, preset: Int) {
        try await client.preset(engine: engine, index: index)
    }
    public func userPresets() async throws -> [UserPreset] { try await client.userPresets() }
    public func userLoad(slot: Int) async throws -> Int { try await client.userLoad(slot: slot) }
    public func transport(play: Bool) async throws -> LiveState? { try await client.transport(play: play) }
    public func transportState() async throws -> TransportState? { nil }
}

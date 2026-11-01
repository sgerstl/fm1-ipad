import Foundation

/// Something that carries whole SysEx frames to and from a SLOOP device: CoreMIDI, or the fake.
public protocol SysExTransport: AnyObject, Sendable {
    /// Complete frames from the device, in arrival order. Finishes when the device goes away.
    var frames: AsyncStream<[UInt8]> { get }
    /// Notes the device sends (its keys, with KEY OUT on). The fake sends none.
    var notes: AsyncStream<NoteEvent> { get }
    func send(_ frame: [UInt8])
}

public enum ClientError: Error, Equatable {
    case timeout(String)
    case closed
}

/// One request in flight at a time (the device holds a single incoming frame), replies matched by
/// command and arguments, pushes handed on as they come.
public actor SloopClient {
    private struct Pending {
        let id: Int
        let request: Request
        let timeout: Duration
        var attemptsLeft: Int
        let continuation: CheckedContinuation<[UInt8], Error>
    }

    private let transport: SysExTransport
    private var queue: [Pending] = []
    private var inFlight: Pending?
    private var nextID = 0
    private var reader: Task<Void, Never>?
    private var closed = false

    public nonisolated let pushes: AsyncStream<Push>
    private let pushSink: AsyncStream<Push>.Continuation

    /// Round trips of the last requests, for the connection readout.
    public private(set) var lastRoundTrip: Duration = .zero
    private var sentAt: ContinuousClock.Instant = .now

    public init(transport: SysExTransport) {
        self.transport = transport
        (pushes, pushSink) = AsyncStream.makeStream(of: Push.self, bufferingPolicy: .bufferingNewest(256))
    }

    /// A plain MIDI message (a note from the iPad's keyboard), sent at once, outside the request queue.
    public nonisolated func sendMIDI(_ bytes: [UInt8]) { transport.send(bytes) }

    public func start() {
        guard reader == nil else { return }
        let frames = transport.frames
        reader = Task { [weak self] in
            for await f in frames { await self?.receive(f) }
            await self?.close()
        }
    }

    public func close() {
        guard !closed else { return }
        closed = true
        reader?.cancel()
        inFlight?.continuation.resume(throwing: ClientError.closed)
        inFlight = nil
        for p in queue { p.continuation.resume(throwing: ClientError.closed) }
        queue = []
        pushSink.finish()
    }

    /// Sends a request and returns the matching reply's body.
    public func send(_ request: Request, timeout: Duration = .milliseconds(300), retries: Int = 1) async throws -> [UInt8] {
        if closed { throw ClientError.closed }
        return try await withCheckedThrowingContinuation { c in
            nextID += 1
            queue.append(Pending(id: nextID, request: request, timeout: timeout, attemptsLeft: retries + 1, continuation: c))
            pump()
        }
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty else { return }
        var p = queue.removeFirst()
        p.attemptsLeft -= 1
        inFlight = p
        sentAt = .now
        transport.send(p.request.bytes)
        let id = p.id, attempts = p.attemptsLeft, timeout = p.timeout
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            await self?.timedOut(id: id, attemptsLeft: attempts)
        }
    }

    private func timedOut(id: Int, attemptsLeft: Int) {
        guard let p = inFlight, p.id == id, p.attemptsLeft == attemptsLeft else { return }
        inFlight = nil
        if p.attemptsLeft > 0 { queue.insert(p, at: 0) }
        else { p.continuation.resume(throwing: ClientError.timeout(p.request.description)) }
        pump()
    }

    func receive(_ bytes: [UInt8]) {
        guard let (cmd, body) = Frame.decode(bytes) else { return }
        if Cmd.pushes.contains(cmd) {
            if let push = try? Push(cmd: cmd, body: body) { pushSink.yield(push) }
            return
        }
        guard let p = inFlight, p.request.cmd == cmd, p.request.matches(body) else { return }
        lastRoundTrip = ContinuousClock.now - sentAt
        inFlight = nil
        p.continuation.resume(returning: body)
        pump()
    }
}

// Typed calls.
public extension SloopClient {
    func info() async throws -> DeviceInfo { try DeviceInfo(await send(.info)) }
    func tracks() async throws -> TrackList { try TrackList(await send(.track)) }
    func selectTrack(_ t: Int) async throws -> TrackList { try TrackList(await send(.selectTrack(t))) }
    func names(engine: Int) async throws -> PresetNames { try PresetNames(await send(.names(engine: engine))) }
    func synthStep(track: Int, index: Int) async throws -> SynthStep {
        try TrackStepReply(await send(.trackStep(track: track, index: index))).step
    }
    func drumStep(index: Int) async throws -> DrumStep { try DrumStepReply(await send(.drumStep(index: index))).step }
    func trackParam(track: Int, id: Int) async throws -> Int {
        try ParamValue(await send(.trackParam(track: track, id: id)), cmd: Cmd.trackParam).value
    }
    func global(id: Int) async throws -> Int { try ParamValue(await send(.global(id: id)), cmd: Cmd.get).value }
    func desc(scope: Int, id: Int) async throws -> ParamDesc { try ParamDesc(await send(.desc(scope: scope, id: id))) }
    func watch(_ on: Int) async throws -> Int { Int(try await send(.watch(on)).first ?? 0) }
    func ping() async throws { _ = try await send(.ping) }
    func live() async throws -> LiveState { try LiveState(await send(.live, timeout: .milliseconds(150), retries: 0)) }
    func transport(play: Bool) async throws -> LiveState { try LiveState(await send(.transport(play: play))) }
    /// Writes return the value as the device stored it (clamped, levels of off lanes cleared).
    func setSynthStep(track: Int, index: Int, _ step: SynthStep) async throws -> SynthStep {
        try TrackStepReply(await send(.setTrackStep(track: track, index: index, step))).step
    }
    func setDrumStep(index: Int, _ step: DrumStep) async throws -> DrumStep {
        try DrumStepReply(await send(.setDrumStep(index: index, step))).step
    }
    func setTrackParam(track: Int, id: Int, value: Int) async throws -> Int {
        try ParamValue(await send(.setTrackParam(track: track, id: id, value: value)), cmd: Cmd.trackParam).value
    }
    /// Loads a factory preset onto the selected track; returns its engine and preset after the load.
    func preset(engine: Int, index: Int) async throws -> (engine: Int, preset: Int) {
        let b = try await send(.preset(engine: engine, index: index))
        return (Int(b.first ?? 0), Int(b.count > 1 ? b[1] : 0))
    }
    func dump(paramCount: Int, globalCount: Int) async throws -> ParamDump {
        try ParamDump(await send(.dump), paramCount: paramCount, globalCount: globalCount)
    }
    func userPresets() async throws -> [UserPreset] {
        var all: [UserPreset] = []
        var start = 0
        while true {
            let l = try UserPresetList(await send(.userList(start: start, count: 16)))
            all += l.used
            start += 16
            if start >= l.total { break }
        }
        return all
    }
    /// 0: loaded; 1: empty or invalid (or the drum track).
    func userLoad(slot: Int) async throws -> Int {
        let b = try await send(.userLoad(slot: slot))
        return Int(b.count > 1 ? b[1] : 1)
    }
    func setGlobal(id: Int, value: Int) async throws -> Int {
        try ParamValue(await send(.setGlobal(id: id, value: value)), cmd: Cmd.set).value
    }
}

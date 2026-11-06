import Foundation

/// Something that carries whole SysEx frames to and from a SLOOP device: CoreMIDI, or the fake.
public protocol SysExTransport: AnyObject, Sendable {
    /// Complete frames from the device, in arrival order. Finishes when the device goes away.
    var frames: AsyncStream<[UInt8]> { get }
    /// Notes the device sends (its keys, with KEY OUT on). The fake sends none.
    var notes: AsyncStream<NoteEvent> { get }
    /// MIDI clock the device sends (Skiff's CLOCK OUT); none from SLOOP or the fake.
    var clock: AsyncStream<ClockEvent> { get }
    func send(_ frame: [UInt8])
}

public extension SysExTransport {
    var clock: AsyncStream<ClockEvent> { AsyncStream { $0.finish() } }
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
        // UI (fm1-ipad firmware) is both a reply and a push: every one updates the screen state
        if cmd == Cmd.ui, let push = try? Push(cmd: cmd, body: body) { pushSink.yield(push) }
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
    /// REC, as the FM-1's button: arms, records, or stops recording. Sent once (it toggles).
    func rec() async throws -> LiveState { try LiveState(await send(.rec, retries: 0)) }
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
    /// The FM-1's screen state; throws on stock SLOOP, which doesn't answer.
    func uiState() async throws -> UIState { try UIState(await send(.uiState, timeout: .milliseconds(200), retries: 0)) }
    func uiGoto(page: Int) async throws -> UIState { try UIState(await send(.uiGoto(page: page))) }
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
    /// LIVE op 2: a key of a layer (pressed and let go). Sent once each: these toggle.
    func layerTap(layer: Int, key: Int) async throws -> [UInt8] {
        _ = try await send(.layerKey(layer: layer, key: key, down: true), retries: 0)
        // a key left held would keep the layer on: a lost key-up is sent again (releasing twice is harmless)
        if let up = try? await send(.layerKey(layer: layer, key: key, down: false), retries: 0) { return up }
        return try await send(.layerKey(layer: layer, key: key, down: false), retries: 0)
    }
    /// The FM-1's master level (speaker and headphones), 0..126; 127 gives it back to the MASTER knob. Sets a state: may be resent.
    func masterLevel(_ v: Int) async throws -> [UInt8] { try await send(.masterLevel(v)) }

    /// BK_LIST: every backup object's length and CRC-32, and a snapshot of the working loop and the
    /// settings for the GETs that follow.
    func objectList() async throws -> [Int: (length: Int, crc: UInt32)] {
        let list = try await send(.bkList)
        guard list.count >= 2, list[0] == 0 else { throw ClientError.timeout("BK_LIST rc \(list.first ?? 99)") }
        var r = 2, out: [Int: (length: Int, crc: UInt32)] = [:]
        for _ in 0..<Int(list[1]) {
            guard r + 11 <= list.count else { break }
            out[Int(list[r])] = (Int(Pack7.readU35(list[(r + 1)...])), Pack7.readU35(list[(r + 6)...]))
            r += 11
        }
        return out
    }

    /// A backup object's bytes (BK_GET, 256 at a time), from the snapshot the last BK_LIST took.
    func object(id: Int, length: Int) async throws -> [UInt8] {
        guard length >= 0, length <= 8192 else { throw ClientError.timeout("object \(id): length \(length)") }
        var out: [UInt8] = []
        while out.count < length {
            let n = min(256, length - out.count)
            let b = try await send(.bkGet(id: id, offset: out.count, count: n), timeout: .milliseconds(600))
            guard b.count > 9, b[1] == 0 else { throw ClientError.timeout("BK_GET rc \(b.count > 1 ? b[1] : 99)") }
            let chunk = Pack7.decode(Array(b[9...])).prefix(n)
            guard !chunk.isEmpty else { throw ClientError.timeout("BK_GET returned no data") }
            out += chunk
        }
        return out
    }

    /// The settings object (backup object 1), which holds the song order: LIST snapshots it, GET reads it.
    func settingsObject() async throws -> [UInt8] {
        let length = try await objectList()[1]?.length ?? 0
        guard length > 0, length <= 4096 else { throw ClientError.timeout("no settings object (length \(length))") }
        return try await object(id: 1, length: length)
    }

    /// Writes the settings object back (the song order, USB AUDIO). rc: 0 ok, 2 invalid, 3 stop the song first.
    func putSettings(_ s: [UInt8]) async throws -> Int { try await putObject(id: 1, s) }

    /// Writes a backup object (editor.c BK_PUT): 0 the working loop (loaded at once), 1 the settings, 2…5
    /// sections A–D (no bytes: the section emptied). rc: 0 ok, 2 invalid, 3 stop first.
    func putObject(id: Int, _ s: [UInt8]) async throws -> Int {
        var b = try await send(.bkPut(op: 0, id: id, args: Pack7.u35(UInt32(s.count)) + Pack7.u35(CRC32.of(s))))
        guard b.count >= 3, b[2] == 0 else { return Int(b.count >= 3 ? b[2] : 99) }
        var off = 0
        while off < s.count {
            let chunk = Array(s[off..<min(off + 256, s.count)])
            b = try await send(.bkPut(op: 1, id: id, args: Pack7.u35(UInt32(off)) + Pack7.encode(chunk)), timeout: .milliseconds(600))
            guard b.count >= 3, b[2] == 0 else { _ = try? await send(.bkPut(op: 3, id: id, args: [])); return Int(b.count >= 3 ? b[2] : 99) }
            off += chunk.count
        }
        b = try await send(.bkPut(op: 2, id: id, args: []), timeout: .seconds(5), retries: 0)    // a resent commit would answer "nothing staged"
        return Int(b.count >= 3 ? b[2] : 99)
    }

    // User sample slots (editor.c ED_SMP_*). Each returns the device's rc (0 ok; 99: no rc in the reply).

    /// SMP_INFO: every slot's zone count (0 = empty), name and data KiB.
    func sampleSlots() async throws -> [SampleSlot] { try SampleSlot.list(await send(.smpInfo, timeout: .seconds(1))) }
    /// SMP_BEGIN: erases the slot's header sector (the slot is empty from here). Resending only erases it again.
    func sampleBegin(slot: Int) async throws -> Int {
        let b = try await send(.smpBegin(slot: slot), timeout: .seconds(2))
        return Int(b.count > 1 ? b[1] : 99)
    }
    /// SMP_WRITE: rc 1 arguments, 2 erase, 3 write, 4 no BEGIN first. A write at a 4 KiB boundary erases that
    /// sector first, so a resent one writes the same bytes again.
    func sampleWrite(slot: Int, offset: Int, _ data: [UInt8]) async throws -> Int {
        let b = try await send(.smpWrite(slot: slot, offset: offset, data: data), timeout: .seconds(1))
        return Int(b.count > 4 ? b[4] : 99)
    }
    /// SMP_END: rc 1 size, 2 header, 3 data CRC, 4 flash, 5 zones, 6 no BEGIN. Sent once: the first END
    /// closes the slot, so a resent one answers 6 even when the first worked.
    func sampleEnd(slot: Int, header: [UInt8]) async throws -> Int {
        let b = try await send(.smpEnd(slot: slot, header: header), timeout: .seconds(5), retries: 0)
        return Int(b.count > 1 ? b[1] : 99)
    }
    /// SMP_ERASE: the whole slot, 20 sectors (~1 s).
    func sampleErase(slot: Int) async throws -> Int {
        let b = try await send(.smpErase(slot: slot), timeout: .seconds(10), retries: 0)
        return Int(b.count > 1 ? b[1] : 99)
    }

    func setGlobal(id: Int, value: Int) async throws -> Int {
        try ParamValue(await send(.setGlobal(id: id, value: value)), cmd: Cmd.set).value
    }
}

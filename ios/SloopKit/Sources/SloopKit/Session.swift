import Foundation
import Observation

/// What the app knows about one track. The FM-1 is the authority; this is a mirror.
public struct TrackState: Equatable, Sendable {
    public var index: Int
    public var isDrums: Bool { index == 3 }
    public var engine = 0
    public var engineName = ""
    public var preset = 0
    public var presetName = ""
    public var steps = Array(repeating: SynthStep.empty, count: 64)
    public var drumSteps = Array(repeating: DrumStep.empty, count: 64)
    public var level = 100          // P_LEVEL; the drum track's is G_DRLVL
    public var root = 0
    public var scale = 0
    public var length = 16          // P_SLEN
    public var division = 2         // P_SDIV, 1/16
    public var pan = 0
    public var mute = false
    public var loaded = false

    public init(index: Int) { self.index = index }

    public func isOn(_ i: Int) -> Bool {
        isDrums ? drumSteps[i].isOn : steps[i].isOn || steps[i].time == .tie
    }

    public var displayName: String {
        if isDrums { return "Drums" }
        let e = engineName.capitalized
        return presetName.isEmpty ? e : "\(e) · \(presetName.capitalized)"
    }
}

public enum ConnectionStatus: Equatable, Sendable {
    case searching                         // no FM-1 found
    case connecting
    case connected(version: String)
    case wrongFirmware(found: String, protocolVersion: Int)
    case lost(String)
}

/// Follows a SLOOP device: reads all four tracks, keeps them in sync from pushes and a slow
/// background re-sync, and polls LIVE for the playhead.
@MainActor @Observable
public final class SloopSession {
    public private(set) var status: ConnectionStatus = .searching
    public private(set) var info: DeviceInfo?
    public private(set) var tracks = (0..<4).map(TrackState.init)
    public private(set) var selectedTrack = 0
    public private(set) var playing = false
    public private(set) var bpm = 120
    public private(set) var swing = 0
    public private(set) var positions = Array(repeating: LiveState.TrackPosition(step: 0, length: 16, meter: 0), count: 4)
    public private(set) var isDemo = false
    public private(set) var stats = Stats()

    public struct Stats: Equatable, Sendable {
        public var polls = 0
        public var pushes = 0
        public var stepPushes = 0
        public var resyncFixes = 0         // steps a re-sync found out of date: a push that never came
        public var timeouts = 0
        public var connectedAt = Date()
        public var pollsPerSecond: Double { Double(polls) / max(1, Date().timeIntervalSince(connectedAt)) }
    }

    /// When each track's current step began (for interpolating the playhead between polls).
    private var stepStart = Array(repeating: Date.distantPast, count: 4)
    private var lastPoll = Date.distantPast

    private var client: SloopClient?
    private var tasks: [Task<Void, Never>] = []
    private var namesCache: [Int: [String]] = [:]
    private var pendingSteps: Set<Int> = []        // track * 64 + index
    private let makeTransport: () -> SysExTransport?

    /// About 20 a second once a reply's 2 ms is added. SLOOP pushes only while its USB send ring is
    /// at most half full (editor.c ed_room), so polling harder can hold the pushes back.
    public var pollInterval: Duration = .milliseconds(48)
    /// The selected track is re-read this often: the device only edits the selected track, and a
    /// push it held back shows up here at the latest. Each pass also re-reads one other track.
    public var resyncInterval: Duration = .seconds(1)

    public init(demo: Bool = false) {
        isDemo = demo
        makeTransport = demo ? { FakeSloop() } : { MIDITransport() }
    }

    public init(transport: @escaping () -> SysExTransport?) {
        makeTransport = transport
    }

    // MARK: Lifecycle

    /// Keeps looking for the device and reconnects after it goes away.
    public func run() async {
        while !Task.isCancelled {
            if let t = makeTransport() {
                await connect(t)
            } else if status != .searching, !(status.isLost) {
                status = .searching
            }
            if case .wrongFirmware = status {
                try? await Task.sleep(for: .seconds(3))
            } else {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func connect(_ transport: SysExTransport) async {
        let c = SloopClient(transport: transport)
        client = c
        await c.start()
        if case .wrongFirmware = status {} else { status = .connecting }
        do {
            try await Task.sleep(for: .milliseconds(200))      // let notes queued in the USB buffer drain
            let i = try await c.info()
            guard i.isSupported else {
                status = .wrongFirmware(found: i.version, protocolVersion: i.protocolVersion)
                await c.close()
                return
            }
            info = i
            try await readEverything()
            _ = try await c.watch(3)
            status = .connected(version: i.version.replacingOccurrences(of: "FELUCCA ", with: ""))
            stats = Stats()
        } catch {
            status = .lost("Lost the FM-1 while reading it")
            await c.close()
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.pushLoop(c) }
            group.addTask { await self.pingLoop(c) }
            group.addTask { await self.liveLoop(c) }
            group.addTask { await self.resyncLoop(c) }
            await group.next()           // any loop ending means the device went away
            group.cancelAll()
        }
        await c.close()
        client = nil
        if !Task.isCancelled { status = .lost("FM-1 disconnected") }
    }

    // MARK: Reading

    private func readEverything() async throws {
        try await readTrackList()
        for t in 0..<4 { try await readParams(t) }
        try await readGlobals()
        for t in 0..<4 { try await readSteps(t) }
    }

    private func readTrackList() async throws {
        guard let c = client, let i = info else { return }
        let list = try await c.tracks()
        selectedTrack = list.selected
        for (k, s) in list.tracks.enumerated() where k < 4 {
            tracks[k].engine = s.engine
            tracks[k].preset = s.preset
            tracks[k].mute = s.mute
            if k < 3 { tracks[k].level = s.level }
            if s.engine < i.engines.count {
                tracks[k].engineName = i.engines[s.engine]
                let names = try await presetNames(s.engine)
                tracks[k].presetName = s.preset < names.count ? names[s.preset] : "Preset \(s.preset + 1)"
            } else {
                tracks[k].engineName = "Drums"; tracks[k].presetName = ""
            }
        }
    }

    private func presetNames(_ engine: Int) async throws -> [String] {
        if let n = namesCache[engine] { return n }
        guard let c = client else { return [] }
        let n = try await c.names(engine: engine).names
        namesCache[engine] = n
        return n
    }

    private func readParams(_ t: Int) async throws {
        guard let c = client else { return }
        for id in Param.all {
            apply(track: t, id: id, value: try await c.trackParam(track: t, id: id))
        }
    }

    private func readGlobals() async throws {
        guard let c = client else { return }
        for id in Global.all { applyGlobal(id: id, value: try await c.global(id: id)) }
    }

    /// Reads a track's 64 steps; returns how many differed from what the app had.
    @discardableResult
    private func readSteps(_ t: Int) async throws -> Int {
        guard let c = client else { return 0 }
        var fixes = 0
        for i in 0..<64 {
            if t == 3 {
                let s = try await c.drumStep(index: i)
                if tracks[3].drumSteps[i] != s { tracks[3].drumSteps[i] = s; fixes += 1 }
            } else {
                let s = try await c.synthStep(track: t, index: i)
                if tracks[t].steps[i] != s { tracks[t].steps[i] = s; fixes += 1 }
            }
        }
        tracks[t].loaded = true
        return fixes
    }

    private func readStep(_ t: Int, _ i: Int) async {
        guard let c = client else { return }
        let key = t * 64 + i
        guard !pendingSteps.contains(key) else { return }
        pendingSteps.insert(key)
        defer { pendingSteps.remove(key) }
        do {
            if t == 3 { tracks[3].drumSteps[i] = try await c.drumStep(index: i) }
            else { tracks[t].steps[i] = try await c.synthStep(track: t, index: i) }
        } catch { stats.timeouts += 1 }
    }

    // MARK: Applying values

    private func apply(track t: Int, id: Int, value v: Int) {
        guard t < 4 else { return }
        switch id {
        case Param.level: if t < 3 { tracks[t].level = v }
        case Param.root: tracks[t].root = v
        case Param.scale: tracks[t].scale = v
        case Param.length: tracks[t].length = max(1, min(64, v))
        case Param.division: tracks[t].division = v
        case Param.pan: tracks[t].pan = v
        case Param.mute: tracks[t].mute = v != 0
        default: break
        }
    }

    private func applyGlobal(id: Int, value v: Int) {
        switch id {
        case Global.bpm: bpm = v
        case Global.swing: swing = v
        case Global.drumLevel: tracks[3].level = v
        default: break
        }
    }

    // MARK: Loops

    private func pushLoop(_ c: SloopClient) async {
        for await p in c.pushes {
            stats.pushes += 1
            switch p {
            case .stepChanged(let i, let t):
                stats.stepPushes += 1
                Task { await self.readStep(t, i) }
            case .reload(_, _, let t):
                selectedTrack = t
                Task {
                    try? await self.readTrackList()
                    try? await self.readParams(t)
                    try? await self.readSteps(t)
                }
            case .changed(let scope, let id, let v):
                if scope == 0 { apply(track: selectedTrack, id: id, value: v) } else { applyGlobal(id: id, value: v) }
            case .trackChanged(let t, let id, let v):
                apply(track: t, id: id, value: v)
            }
        }
    }

    private func pingLoop(_ c: SloopClient) async {
        var n = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            n += 1
            do {
                try await c.ping()
                if n % 10 == 0 { _ = try await c.watch(3) }   // watching ends on a USB reset: renew it
            } catch ClientError.closed { return } catch { stats.timeouts += 1 }
        }
    }

    private func liveLoop(_ c: SloopClient) async {
        var misses = 0
        while !Task.isCancelled {
            do {
                let l = try await c.live()
                misses = 0
                applyLive(l)
            } catch ClientError.closed {
                return
            } catch {
                misses += 1
                stats.timeouts += 1
                if misses > 40 { return }     // about 6 s with no answer: treat it as gone
            }
            try? await Task.sleep(for: pollInterval)
        }
    }

    private func resyncLoop(_ c: SloopClient) async {
        var pass = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: resyncInterval)
            do {
                let sel = selectedTrack
                stats.resyncFixes += try await readSteps(sel)
                if pass % 3 == 0 {                       // every third pass: the next other track, params, globals
                    let other = (sel + 1 + (pass / 3) % 3) % 4
                    if other == 0 { try await readTrackList(); try await readGlobals() }
                    try await readParams(sel)
                    try await readParams(other)
                    stats.resyncFixes += try await readSteps(other)
                }
            } catch ClientError.closed { return } catch { stats.timeouts += 1 }
            pass += 1
        }
    }

    func applyLive(_ l: LiveState, at now: Date = Date()) {
        stats.polls += 1
        let wasPlaying = playing
        if l.selected != selectedTrack, l.selected < 4 { selectedTrack = l.selected }
        playing = l.playing
        bpm = l.bpm
        for k in 0..<min(4, l.tracks.count) {
            let new = l.tracks[k], old = positions[k]
            if new.step != old.step || !wasPlaying {
                let dur = stepDuration(k)
                let predicted = stepStart[k].addingTimeInterval(dur)
                let advancedByOne = (old.step + 1) % max(old.length, 1) == new.step
                // The step changed somewhere between the last poll and now. Keep the phase we
                // predicted when it falls in that window; otherwise take the middle.
                if wasPlaying, advancedByOne, predicted > lastPoll, predicted <= now {
                    stepStart[k] = predicted
                } else {
                    stepStart[k] = lastPoll > now.addingTimeInterval(-0.25) ? lastPoll.addingTimeInterval(now.timeIntervalSince(lastPoll) / 2) : now
                }
            }
            positions[k] = new
            tracks[k].length = max(1, new.length)
        }
        lastPoll = now
    }

    /// Seconds per step for a track, from BPM and its division.
    public func stepDuration(_ t: Int) -> TimeInterval {
        let div = tracks[t].division
        let beats = div < Music.divisionBeats.count ? Music.divisionBeats[div] : 0.25
        return 60.0 / Double(max(bpm, 20)) * beats
    }

    /// The playhead in steps (fractional) for a track at a moment, interpolated between polls.
    public func playhead(track t: Int, at date: Date, interpolate: Bool = true) -> Double {
        let p = positions[t]
        guard playing, interpolate else { return Double(p.step) }
        let frac = date.timeIntervalSince(stepStart[t]) / stepDuration(t)
        return Double(p.step) + min(max(frac, 0), 0.999)
    }

    // MARK: Actions from the iPad

    /// Selects a track on the FM-1. SLOOP doesn't push about the editor's own TRACK, so the app
    /// updates itself at once.
    public func select(track t: Int) {
        guard t != selectedTrack else { return }
        selectedTrack = t
        guard let c = client else { return }
        Task { _ = try? await c.selectTrack(t) }
    }

    public func setPlaying(_ on: Bool) {
        playing = on
        guard let c = client else { return }
        Task { if let l = try? await c.transport(play: on) { self.applyLive(l) } }
    }
}

extension ConnectionStatus {
    var isLost: Bool { if case .lost = self { true } else { false } }
}

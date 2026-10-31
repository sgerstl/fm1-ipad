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
    public var quant = 0            // P_QNT: 0 OFF, 1 SNAP, 2 WHITE (how the FM-1's keys map to notes)
    public var transpose = 0        // P_TRN, semitones
    public var chord = 0            // P_CHORD: 0 OFF
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
        if isDrums { return presetName.isEmpty ? "Drums" : "Drums · \(presetName.capitalized)" }
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
    public private(set) var otherChannelsPlaySelected = true
    public private(set) var drumMapGM = true
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
    /// Factory preset names per engine (NAMES), all read at connect: the library's lists.
    public private(set) var namesCache: [Int: [String]] = [:]
    public private(set) var userPresets: [UserPreset] = []
    /// The drum track's kits (DESC of P_E0 while it is selected; empty until then).
    public private(set) var kitNames: [String] = []
    private var pendingSteps: Set<Int> = []        // track * 64 + index
    /// Steps and parameters the iPad wrote lately. SLOOP doesn't push about the editor's own writes,
    /// and a read already queued before a write would bring back the old value, so reads leave these
    /// alone for a moment. Keys: "s<track*64+index>", "p<track>.<id>", "g<id>".
    private var recentWrites: [String: Date] = [:]
    private var paramWrites: [String: Int] = [:]      // latest value waiting to be sent (knob drags)
    private var paramSending: Set<String> = []
    private func recentlyWritten(_ key: String) -> Bool {
        guard let d = recentWrites[key] else { return false }
        return Date().timeIntervalSince(d) < 1.5
    }
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
            deviceNotes = []          // whatever the USB buffer held from before isn't live
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
            group.addTask { await self.noteLoop(transport); try? await Task.sleep(for: .seconds(86400 * 365)) }
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
        try await readLibrary()
    }

    private func readLibrary() async throws {
        guard let c = client, let i = info else { return }
        for e in 0..<i.engines.count { _ = try await presetNames(e) }
        userPresets = try await c.userPresets()
        if selectedTrack == 3 { try await readKits() }
    }

    private func readKits() async throws {
        guard let c = client, let i = info, selectedTrack == 3 else { return }
        let d = try await c.desc(scope: 0, id: i.firstEngineParam)       // the drum track selected: the enum KIT
        if d.format == 8, !d.names.isEmpty {
            kitNames = d.names
            if tracks[3].preset < d.names.count { tracks[3].presetName = d.names[tracks[3].preset] }
        }
    }

    /// The library page asks for this: user presets may have changed on the device, and the kit names
    /// can only be read while the drum track is selected.
    public func refreshLibrary() {
        guard let c = client else { return }
        Task {
            if let u = try? await c.userPresets() { self.userPresets = u }
            if self.selectedTrack == 3, self.kitNames.isEmpty { try? await self.readKits() }
        }
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
                tracks[k].engineName = "Drums"
                tracks[k].presetName = tracks[k].preset < kitNames.count ? kitNames[tracks[k].preset] : ""
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
        var ids = Param.all
        if t == 3, let i = info { ids.append(i.firstEngineParam) }      // the drum track's kit
        for id in ids {
            let v = try await c.trackParam(track: t, id: id)
            if !recentlyWritten("p\(t).\(id)") { apply(track: t, id: id, value: v) }
        }
    }

    private func readGlobals() async throws {
        guard let c = client else { return }
        for id in Global.all {
            let v = try await c.global(id: id)
            if !recentlyWritten("g\(id)") { applyGlobal(id: id, value: v) }
        }
    }

    /// Reads a track's 64 steps; returns how many differed from what the app had.
    @discardableResult
    private func readSteps(_ t: Int) async throws -> Int {
        guard let c = client else { return 0 }
        var fixes = 0
        for i in 0..<64 {
            if t == 3 {
                let s = try await c.drumStep(index: i)
                if tracks[3].drumSteps[i] != s, !recentlyWritten("s\(3 * 64 + i)") { tracks[3].drumSteps[i] = s; fixes += 1 }
            } else {
                let s = try await c.synthStep(track: t, index: i)
                if tracks[t].steps[i] != s, !recentlyWritten("s\(t * 64 + i)") { tracks[t].steps[i] = s; fixes += 1 }
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
            if t == 3 {
                let s = try await c.drumStep(index: i)
                if !recentlyWritten("s\(key)") { tracks[3].drumSteps[i] = s }
            } else {
                let s = try await c.synthStep(track: t, index: i)
                if !recentlyWritten("s\(key)") { tracks[t].steps[i] = s }
            }
        } catch { stats.timeouts += 1 }
    }

    // MARK: Applying values

    private func apply(track t: Int, id: Int, value v: Int) {
        guard t < 4 else { return }
        if t == 3, id == info?.firstEngineParam {               // the drum track's kit
            tracks[3].preset = v
            if v < kitNames.count { tracks[3].presetName = kitNames[v] }
            return
        }
        switch id {
        case Param.level: if t < 3 { tracks[t].level = v }
        case Param.root: tracks[t].root = v
        case Param.scale: tracks[t].scale = v
        case Param.quant: tracks[t].quant = v
        case Param.transpose: tracks[t].transpose = v
        case Param.chord: tracks[t].chord = v
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
        case Global.otherChannels: otherChannelsPlaySelected = v == 0
        case Global.drumMap: drumMapGM = v == 0
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
                    if t == 3, self.kitNames.isEmpty { try? await self.readKits() }
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
        // mutes from the device too (GLO + key on the FM-1), unless the iPad just set one
        for k in 0..<4 where !recentlyWritten("p\(k).\(Param.mute)") {
            let m = l.mutes >> k & 1 == 1
            if tracks[k].mute != m { tracks[k].mute = m }
        }
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
        Task {
            _ = try? await c.selectTrack(t)
            if t == 3, self.kitNames.isEmpty { try? await self.readKits() }
        }
    }

    // MARK: Playing from the iPad's keyboard

    /// The channel the keyboard plays on: 16, which no track owns by default, so SLOOP plays the
    /// selected track with it (GLO > MIDI > OTHER = SEL, seq.c midi_route), drums included.
    public static let keyboardChannel: UInt8 = 15
    private var held: [Int: Int] = [:]        // key id -> MIDI note sent, so a note-off matches its note-on
    /// The FM-1's OCT buttons (song.octave), which the protocol doesn't report. The iPad keeps its own
    /// and follows the FM-1: a note from the FM-1's keys that only fits another octave moves it there.
    public var keyboardOctave = 0

    /// What key k (0 = F3 ... 26 = G5, as on the FM-1) plays on the selected track, as the FM-1's own
    /// keyboard would; nil for a silent key (black keys in WHITE mode).
    public func pitch(ofKey k: Int, octave: Int? = nil) -> Int? {
        let t = tracks[selectedTrack]
        return Music.keyPitch(k, root: t.root, scale: t.scale, quant: t.quant, chord: t.chord,
                              transpose: t.transpose, octave: octave ?? keyboardOctave)
    }
    /// Notes held on the FM-1's own keys right now (MIDI notes it sends), to light the iPad's keys too.
    public private(set) var deviceNotes: Set<Int> = []

    /// The key id a note from the device lights: the note itself, or on the drum track its lane.
    public func keyID(forDeviceNote n: Int) -> Int {
        guard selectedTrack == 3 else { return n }
        if drumMapGM { return Music.laneNotes.firstIndex(of: n) ?? Music.laneNotes.enumerated().min { abs($0.element - n) < abs($1.element - n) }!.offset }
        return ((n - 36) % 16 + 16) % 16
    }

    private func noteLoop(_ t: SysExTransport) async {
        for await e in t.notes {
            let n = Int(e.note)
            if e.on { deviceNotes.insert(n); followOctave(n) } else { deviceNotes.remove(n) }
        }
    }

    /// A note from the FM-1 that no key plays at the iPad's octave, but one does at another: the FM-1's
    /// OCT buttons moved, so follow them (nearest octave first).
    private func followOctave(_ n: Int) {
        guard selectedTrack < 3 else { return }
        func fits(_ o: Int) -> Bool { (0..<27).contains { pitch(ofKey: $0, octave: o) == n } }
        guard !fits(keyboardOctave) else { return }
        for d in [1, -1, 2, -2, 3, -3] where fits(keyboardOctave + d) && abs(keyboardOctave + d) <= 3 {
            keyboardOctave += d
            return
        }
    }

    /// A key down. `key` is the FM-1 key index on a synth track (0...26), the lane (0...15) on drums.
    public func keyDown(_ key: Int, velocity: Int = 100) {
        let note: Int
        if selectedTrack == 3 { note = drumMapGM ? Music.laneNotes[key % 16] : 36 + key % 16 }
        else if let p = pitch(ofKey: key) { note = p } else { return }
        held[key] = note
        client?.sendMIDI([0x90 | Self.keyboardChannel, UInt8(note & 0x7F), UInt8(min(max(velocity, 1), 127))])
    }

    public func keyUp(_ key: Int) {
        guard let note = held.removeValue(forKey: key) else { return }
        client?.sendMIDI([0x80 | Self.keyboardChannel, UInt8(note & 0x7F), 0])
    }

    /// The notes (or drum lanes) the selected track plays at the playhead, to light the keys.
    public var sounding: Set<Int> {
        guard playing else { return [] }
        let t = selectedTrack, i = positions[t].step % 64
        if t == 3 { return Set(tracks[3].drumSteps[i].lanes) }
        // a held note sounds through its TIE steps
        var k = i
        while k > 0, tracks[t].steps[k].time == .tie { k -= 1 }
        let s = tracks[t].steps[k]
        return s.time == .note ? Set(s.notes) : []
    }

    // MARK: Editing from the iPad (step 2). The app shows each change at once; the reply is what
    // the device stored, and it wins.

    public func write(track t: Int, index i: Int, _ step: SynthStep) {
        guard t < 3 else { return }
        var st = step
        if st.time != .note { st.notes = []; st.levels = []; st.ratchets = [] }
        tracks[t].steps[i] = st
        recentWrites["s\(t * 64 + i)"] = Date()
        guard let c = client else { return }
        Task {
            do {
                let stored = try await c.setSynthStep(track: t, index: i, st)
                self.tracks[t].steps[i] = stored
            } catch { self.stats.timeouts += 1 }
            self.recentWrites["s\(t * 64 + i)"] = Date()
        }
    }

    public func write(drumIndex i: Int, _ step: DrumStep) {
        tracks[3].drumSteps[i] = step
        recentWrites["s\(3 * 64 + i)"] = Date()
        guard let c = client else { return }
        Task {
            do {
                let stored = try await c.setDrumStep(index: i, step)
                self.tracks[3].drumSteps[i] = stored
            } catch { self.stats.timeouts += 1 }
            self.recentWrites["s\(3 * 64 + i)"] = Date()
        }
    }

    /// A note in a synth step on or off. Adding to a step that holds four replaces nothing and returns false.
    @discardableResult
    public func toggle(track t: Int, index i: Int, note: Int) -> Bool {
        var st = tracks[t].steps[i]
        if st.time == .note, let k = st.notes.firstIndex(of: note) {
            st.notes.remove(at: k)
            if k < st.levels.count { st.levels.remove(at: k) }
            if k < st.ratchets.count { st.ratchets.remove(at: k) }
            if st.notes.isEmpty { st.time = .rest }
        } else {
            if st.time != .note { st = SynthStep(notes: [], time: .note, accent: st.accent, slide: st.slide, velocity: st.velocity > 0 ? st.velocity : 100) }
            guard st.notes.count < 4 else { return false }
            st.notes.append(note); st.levels.append(0); st.ratchets.append(0)
        }
        write(track: t, index: i, st)
        return true
    }

    public func toggle(drumIndex i: Int, lane: Int) {
        let d = tracks[3].drumSteps[i]
        write(drumIndex: i, d.setting(lane, on: !d.has(lane)))
    }

    /// A track parameter from a knob: shown at once, sent latest-value-wins so a drag never queues up.
    public func set(track t: Int, param id: Int, to v: Int) {
        apply(track: t, id: id, value: v)
        if t == 3 && id == Param.level { sendParam("g\(Global.drumLevel)", v) { c, v in try await c.setGlobal(id: Global.drumLevel, value: v) } ; return }
        sendParam("p\(t).\(id)", v) { c, v in try await c.setTrackParam(track: t, id: id, value: v) }
    }

    public func set(global id: Int, to v: Int) {
        applyGlobal(id: id, value: v)
        sendParam("g\(id)", v) { c, v in try await c.setGlobal(id: id, value: v) }
    }

    private func sendParam(_ key: String, _ v: Int, _ op: @escaping (SloopClient, Int) async throws -> Int) {
        recentWrites[key] = Date()
        paramWrites[key] = v
        guard let c = client, !paramSending.contains(key) else { return }
        paramSending.insert(key)
        Task {
            while let next = self.paramWrites.removeValue(forKey: key) {
                _ = try? await op(c, next)
                self.recentWrites[key] = Date()
            }
            self.paramSending.remove(key)
        }
    }

    // MARK: The library (step 3)

    /// Loads a factory preset onto the selected synth track. SLOOP switches the engine if needed and
    /// keeps the pattern, mix and key; it pushes RELOAD, which re-reads the track.
    public func loadPreset(engine e: Int, index i: Int) {
        let t = selectedTrack
        guard t < 3, let info else { return }
        tracks[t].engine = e; tracks[t].preset = i
        tracks[t].engineName = info.engines[e]
        tracks[t].presetName = i < (namesCache[e]?.count ?? 0) ? namesCache[e]![i] : "Preset \(i + 1)"
        guard let c = client else { return }
        Task { _ = try? await c.preset(engine: e, index: i) }
    }

    public func loadUserPreset(_ p: UserPreset) {
        let t = selectedTrack
        guard t < 3, let info else { return }
        if p.engine < info.engines.count { tracks[t].engine = p.engine; tracks[t].engineName = info.engines[p.engine] }
        tracks[t].presetName = p.name
        guard let c = client else { return }
        Task { _ = try? await c.userLoad(slot: p.slot) }
    }

    public func toggleMute(track t: Int) {
        set(track: t, param: Param.mute, to: tracks[t].mute ? 0 : 1)
    }

    public func loadKit(_ k: Int) {
        guard let i = info else { return }
        set(track: 3, param: i.firstEngineParam, to: k)
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

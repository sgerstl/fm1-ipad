import Foundation

/// What skiff-sim answered, recorded by SkiffSimTests (SKIFF_RECORD=1): reply bodies by request.
public struct SkiffFixture: Codable, Sendable {
    var info: [UInt8] = []
    var desc: [String: [UInt8]] = [:]        // "scope.id" (track ids whole, as asked for)
    var names: [String: [UInt8]] = [:]       // engine
    var track: [UInt8] = []
    var trackDump: [String: [UInt8]] = [:]   // track
    var steps: [String: [UInt8]] = [:]       // "track.index": TRACK_STEP's reply
    var dump: [UInt8] = []
    var userList: [UInt8] = []
    var transport: [UInt8] = []
    /// MENU_DESC by index, the whole list (recorded from 2.5.1 on; the 2.2 fixture has none).
    var menu: [String: [UInt8]]? = nil

    /// Where the fixtures are read from instead of the package's resources: Android's debug demo core, whose APK has no
    /// SwiftPM resource bundle (Bundle.module traps there), copies them into the app's files.
    nonisolated(unsafe) public static var directory: URL?
    static func url(_ name: String) -> URL? {
        if let d = directory { return d.appendingPathComponent(name + ".json") }
        return Bundle.module.url(forResource: name, withExtension: "json")
    }

    public static func load(_ firmware: SkiffFirmware = .v2_2) throws -> SkiffFixture {
        guard let url = url("skiff-\(firmware.short)") else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(SkiffFixture.self, from: Data(contentsOf: url))
    }
}

/// Skiff 2.5.1's engines as its own tables have them (tests/descdump.c, by android/scripts/skiff-page-dump.sh): each
/// engine's EDIT descriptors, which DESC answers for the track's engine (editor.c ED_DESC: param_desc_of), and its
/// presets' values, which PRESET loads (hostsim.c host_preset_values, as ui.c apply_preset_to). The recorded fixture
/// holds the DESC of one engine only (the track's when it was recorded).
struct SkiffEngineTable: Decodable, Sendable {
    struct Desc: Decodable, Sendable { var label: String; var fmt: Int; var min: Int; var max: Int; var def: Int; var names: [String]?; var unit: String }
    struct Preset: Decodable, Sendable { var name: String; var e: [Int]; var env: [Int]; var mono: Int; var more: [[Int]] }
    struct Engine: Decodable, Sendable { var name: String; var edit: [Desc]; var presets: [Preset] }
    var P_E0: Int
    var engines: [Engine]

    static func load(_ firmware: SkiffFirmware) -> SkiffEngineTable? {
        guard firmware == .v2_5_1, let url = SkiffFixture.url("skiff-2.5.1-engines"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SkiffEngineTable.self, from: data)
    }
}

/// A pretend Skiff 2.2 or 2.5.1 (the fixture it's built on says which), built on what the sim answered: the recorded INFO, DESC and NAMES as they are, and
/// steps, parameters, the selection and the transport kept as state from the recorded starting point. Like
/// the device, it holds one request at a time: a frame that arrives before the last is answered is dropped.
/// While playing it sends MIDI clock at its BPM, as Skiff's CLOCK OUT does (`-demo-skiff` in the app).
public final class FakeSkiff: SysExTransport, @unchecked Sendable {
    public let frames: AsyncStream<[UInt8]>
    private let sink: AsyncStream<[UInt8]>.Continuation
    public let notes: AsyncStream<NoteEvent>
    private let notesSink: AsyncStream<NoteEvent>.Continuation
    /// 2.2 or 2.5.1, from the fixture's INFO. The page numbers on the wire are this release's (SkiffPageMap); the fake
    /// keeps its screen in Lupe's numbers, so a test names a page once for both.
    public let firmware: SkiffFirmware
    /// The fixture's INFO without a screen link tag of its own (2.5.1's sim carries `56 01 06`): `screenLink` decides.
    private let infoBody: [UInt8]
    /// MENU settings set here, by id (from the recorded list: 2.5.1's), on top of the recorded values.
    var menuValues: [Int: Int] = [:]
    /// SCREEN_GOTO's page bytes as they came (this release's numbers), for the tests of the page map.
    var gotoWire: [Int] = []
    public let clock: AsyncStream<ClockEvent>
    let clockSink: AsyncStream<ClockEvent>.Continuation
    private var clockTimer: DispatchSourceTimer?
    private let lock = NSLock()
    /// Plain MIDI sent to the FM-1 (notes from the editor's keys), as it arrived.
    public private(set) var midiIn: [[UInt8]] = []
    private let fx: SkiffFixture
    /// 2.5.1: every engine's EDIT descriptors and presets (nil on 2.2: DESC and PRESET as recorded).
    private let engineTable: SkiffEngineTable?
    private let pCount: Int, gCount: Int

    var selected = 0
    var playing = false
    var steps: [[[UInt8]]] = []              // [track][index]: the step bytes after track, index
    var params: [[Int]] = []                 // [track][id]
    var globals: [Int] = []
    var engines: [(engine: Int, preset: Int)] = []
    var watching = false
    var busy = false
    var dropped = 0
    var requests: [UInt8] = []               // commands received, in order
    var starts = 0                           // times the transport started (a stop and a PLAY after it count one)
    /// Requests this fake doesn't model, as (command, arguments): no reply, as the device, but tests expect this
    /// empty. Teach the fake from skiff-sim, a capture or Skiff's source, never from what the app happens to send.
    public private(set) var unanswered: [(cmd: UInt8, args: [UInt8])] = []
    public var unansweredCommands: [UInt8] { lock.lock(); defer { lock.unlock() }; return unanswered.map(\.cmd) }
    var replyDelay: TimeInterval = 0.002
    /// The song: each track's 16 entries (pattern 0 empty, 1...64, 65 REST; REPS byte REPS − 1, 16 on CHAIN;
    /// the entry's sound), the entry each track is on, SONG, and the pool's LENs.
    var lists: [[FakeEntry]] = []
    var entryOn: [Int] = []
    var songMode = 0
    /// PERFORM (SkiffPerform.swift): the 16 scenes (each track's entry and mute), the one recalled or stored last,
    /// LAUNCH, each track's mute and a mute staged (1 to unmute, 2 to mute; it lands 2 s on, the fake's launch point).
    var scenes: [[(entry: Int, mute: Bool)]?] = Array(repeating: nil, count: 16)
    var lastScene = 127
    /// RECALLs answered PATTERNS FULL (rc 4) before one goes: the real FM-1 still writing a track's last swap.
    var recallsStillSaving = 0
    var launch = 1
    var muted: [Bool] = []
    var stagedMute: [Int] = []
    /// LIST PLAY while playing: the entry staged for the launch point (127 none), landing 2 s on as a staged mute
    /// does. EDITOR_PROTOCOL.md LIST op 3: "the track to the entry: at once stopped, at the LAUNCH point playing";
    /// PERFORM 4 CANCEL drops it ("all that is staged: entries, mutes"). Before 2026-11-14 the fake landed every
    /// launch at once, which hid the phone's stale-lists bug.
    var stagedEntry: [Int] = []
    /// MENU > USB LEVEL (0 MASTER, 1 FIXED): the one MENU setting the fake offers (MENU_DESC index 0, id 10).
    var usbLevel = 0
    /// Armed tracks, a bit each (song.rec), as TRANSPORT op 4 toggles them: ui_input.c rec_tap.
    var armed = 0
    /// Each track's motion: (step, id, value, lock). An edit is recorded while its track is armed, playing and
    /// selected, as Skiff does (at step 0 here: the fake has no playhead).
    var motion: [[(step: Int, id: Int, value: Int, lock: Bool)]] = Array(repeating: [], count: 8)
    /// Lupe's screen link patch (skiff/README.md): INFO's `56 01 02`, SCREEN, SCREEN_GOTO, WATCH bit 2.
    var screenLink = false
    /// The EDIT engine pages' data (SkiffEdit.swift): each track's FM6 patch, the DRUM-X kit (Skiff's DEEP), the user
    /// sets' mixes (USR1 with four sounds).
    var fm6 = Array(repeating: FakeSkiff.initPatch, count: 8)
    var dxKit: [[Int]] = [[0, 0, 1, 1, 0, 6, 60, 84, 2, 10, 10, 80, 92, 4, 30], [0, 1, 0, 0, 0, 36, 20, 60, 90, 60, 40, 28, 70, 100, 70],
                          [0, 1, 0, 0, 0, 56, 0, 52, 127, 70, 52, 0, 64, 127, 64], [2, 2, 0, 0, 0, 92, 0, 18, 100, 104, 96, 0, 24, 110, 110],
                          [2, 2, 0, 0, 0, 92, 0, 70, 100, 100, 96, 0, 84, 110, 106], [0, 0, 1, 1, 0, 22, 50, 80, 6, 20, 28, 70, 92, 10, 40],
                          [3, 2, 1, 0, 0, 58, 8, 16, 10, 40, 62, 16, 22, 20, 50], [2, 1, 0, 0, 0, 64, 0, 80, 0, 36, 70, 0, 92, 10, 48]]
    var mixZones: [[(Int, Int)]] = [[(36, 47), (48, 59), (60, 71), (72, 96)], [], []]
    var mixValues: [[Int]] = Array(repeating: Array(repeating: 127, count: 16) + Array(repeating: 0, count: 32), count: 3)
    /// FM6's init voice: algorithm 1, operator 1 alone at full output, every envelope at its fullest.
    static let initPatch: FM6Patch = {
        var p = FM6Patch(bytes: Array(repeating: 0, count: 128))
        for n in 1...6 {
            for f: FM6Patch.Op in [.r1, .r2, .r3, .r4, .l1, .l2, .l3] { p.setOp(n, f, 99) }
            p.setOp(n, .coarse, 1); p.setOp(n, .detune, 7); p.setOp(n, .breakPoint, 39)
            p.setOp(n, .output, n == 1 ? 99 : n == 2 ? 70 : 0)
        }
        for f: FM6Patch.Voice in [.pr1, .pr2, .pr3, .pr4] { p[f] = 99 }
        for f: FM6Patch.Voice in [.pl1, .pl2, .pl3, .pl4] { p[f] = 50 }
        p[.transpose] = 24; p[.lfoSpeed] = 35
        for (k, c) in "INIT VOICE".utf8.enumerated() { p.bytes[118 + k] = c }
        return p
    }()
    /// Which build: 2 carries the page's cursor (8-byte SCREEN, SCREEN_GOTO's cursor), 1 the first (6 bytes).
    var screenLinkVersion = 2
    /// The page's cursor, where the page has one (`cursorRange`); reset as a page opens.
    var cursor = 0
    /// The pages with a cursor and its top (skiff/README.md): MOD's routes, the lanes, the samples, USER's slots.
    static let cursorRange: [Int: Int] = [4: 10, 16: 5, 18: 7, 19: 7, 20: 7, 22: 15, 36: 31, 37: 63, 41: 63, 42: 63]
    /// The sheets' windows (EDITOR_PROTOCOL.md "The page's cursor": the second cursor, read only): OPERATOR and ALL
    /// OPS five each, SOUND four, by Lupe page. Each sheet keeps its own, as ui.c's fm_ui[1], fm_ui[2] and dx_ui_win.
    static let windowCount: [Int: Int] = [16: 5, 17: 5, 19: 4]
    var windows: [Int: Int] = [:]
    var screenWatched = false
    /// FREE TAKE levels 2 and 3 (the screen link's seventh build, `screenLinkVersion` 7; ui_take.c and editor.c's TAKE
    /// and UNDO on branch lupe-skiff-2.5.1-freetake): the picker, pushed with WATCH bit 5 (32).
    var takeWatched = false
    var take = FakeTake()
    /// Notes played on each track since the stop (take.c free_ev from free_n0): what a free take is made of.
    var heard: [Int: [Int]] = [:]
    /// The undo ring (ui.c undo_ring, UNDO_N 6 on 2.5): each copy a track's steps, LENGTH and DIV; how far back.
    var undoCopies: [(track: Int, steps: [[UInt8]], len: Int, div: Int)] = []
    var undoBack = 0
    /// METER (the screen link's third build, `screenLinkVersion` 3): asked with WATCH bit 3, pushed while playing.
    var meterWatched = false
    private var meterLevels = [Double](repeating: 0, count: 8)
    private var meterTick = 0
    /// SCOPE (the fourth build, `screenLinkVersion` 4): asked with WATCH bit 4, pushed about 16 a second while playing:
    /// the tracks sounding now, each a wave at its note's pitch as loud as its meter, summed, triggered and scaled as
    /// the FM-1 sends it; flat once every track has fallen silent (and none while stopped: Lupe flattens it).
    var scopeWatched = false
    private var scopeNote = [Int](repeating: 60, count: 8)
    /// home, page, layer, menu, flags (the track is `selected`).
    var screen = (home: true, page: 0, layer: 0, menu: 0, flags: 0)
    /// Pages SCREEN_GOTO refuses as Skiff does for one the track's engine doesn't show (LANES on ANALOG).
    var refusedPages: Set<Int> = [18]
    var poolLen = Array(repeating: 0, count: 64)
    /// The pattern bank's stored records (pattern 0...63 → its 888 bytes), served as BACKUP objects 16...31, four a
    /// chunk, as Skiff's editor_backup.c does: GET refused (rc 5) until a LIST this connection, rc 3 while playing.
    public var bankRecords: [Int: [UInt8]] = [:]
    /// The THEME in use (UI_STATE's palette: 0 SKIFF … 5 QUARK, 6 CUSTOM) and CUSTOM's eleven colours (RGB565, BG SURF
    /// TEXT THEME ACCENT, then T1..T6), answered as Skiff does (EDITOR_PROTOCOL.md "THEME CUSTOM").
    public var themePalette = 0
    public var customColours: [UInt16]? = nil
    private var backupListed = false
    /// For tests: how many BACKUP_LISTs came (each stops the transport), and the patterns POOL EMPTY emptied.
    public private(set) var backupLists = 0
    public private(set) var emptiedPatterns: [Int] = []
    /// USER's 32 slots (engine, name; nil empty) and PROJECT's 4 (nil empty), for the SAVE pages.
    var userSlots: [(engine: Int, name: String)?] = Array(repeating: nil, count: 32)
    var projectSlots: [String?] = ["SONG ONE", nil, nil, nil]
    var musicSlot: Int? = 0
    var projectLoads = 0
    /// PROJ_NAME's "changed since then 0/1" (EDITOR_PROTOCOL.md): set by a test; a load or a save clears it.
    var musicChanged = false

    /// The sim's answers as recorded; nil if the fixture is missing from the bundle.
    public convenience init?(demo: Bool) {
        // -demo-fw 2.5.1: the 2.5.1 fixture (Skiff-Lupe 2.5.1's sim), else 2.2's
        let a0 = LaunchArgs.all
        let fw = a0.firstIndex(of: "-demo-fw").flatMap { a0.indices.contains($0 + 1) ? SkiffFirmware(version: "FELUCCA v" + a0[$0 + 1]) : nil }
        guard let fx = try? SkiffFixture.load(fw ?? .v2_2) else { return nil }
        self.init(fx)
        if demo {
            seedDemo()
            // -demo-song empty | full: the Arrange states (no song; T5's 16 entries and the pool full)
            let a = LaunchArgs.all
            screenLink = a.contains("-demo-link")       // the screen link patch, so the button map can be seen
            if a.contains("-demo-link-v1") { screenLinkVersion = 1 }   // the first build: no cursor
            if a.contains("-demo-meter") { screenLinkVersion = 3 }     // the third: METER
            if a.contains("-demo-scope") { screenLink = true; screenLinkVersion = 4 }   // the fourth: SCOPE (the link implied)
            // -demo-link-version N: the screen link's build as INFO reports it (6: Skiff-Lupe 2.5.1 as Lupe carries it)
            if let i = a.firstIndex(of: "-demo-link-version"), a.indices.contains(i + 1), let n = Int(a[i + 1]) { screenLink = true; screenLinkVersion = n }
            // -demo-track N: track N selected (1…6), -demo-engine E: on engine E (DRUM-X 14, SLICE 13: none in the fixture)
            if let i = a.firstIndex(of: "-demo-track"), a.indices.contains(i + 1), let n = Int(a[i + 1]), (1...steps.count).contains(n) { selected = n - 1 }
            if let i = a.firstIndex(of: "-demo-engine"), a.indices.contains(i + 1), let e = Int(a[i + 1]) { engines[selected].engine = e }
            if a.contains("-demo-usr") { params[selected][pCount - 8] = 3 }   // SAMPLE on USR1 (E0: 138 on 2.2, 140 on 2.5.1)
            // -demo-insert N: the selected track's INSERT TYPE (121; 9 FILTR on 2.5.1), for the INSERT card's screenshots
            if let i = a.firstIndex(of: "-demo-insert"), a.indices.contains(i + 1), let n = Int(a[i + 1]) { params[selected][121] = n; params[selected][125] = 127 }
            // -demo-free-take: 6 s in (after the demo has connected), a FREE TAKE kept on the FM-1 on the selected track (2.5.1: Lupe lands on the Timeline)
            if a.contains("-demo-free-take") {
                DispatchQueue.global().asyncAfter(deadline: .now() + 6) { [weak self] in
                    guard let self else { return }
                    self.freeTakeOnDevice(track: self.selected, notes: [60, 63, 67, 70, 72, 70, 67, 63], length: 32, bpm: 96)
                }
            }
            // -demo-take (FREE TAKE levels 2 and 3, the screen link's v7): 6 s in, a phrase played on the selected track,
            // then: -demo-take-picker the picker opened (SHIFT + SAVE), -demo-take-kept opened and kept (the landing),
            // neither: just the phrase (Lupe offers it after the 2.5 s pause)
            if a.contains("-demo-take") {
                screenLink = true; screenLinkVersion = 7
                takeGuesses = [96, 48, 192]                                  // (a phrase's, for the screenshots)
                func whenStopped(_ tries: Int, _ go: @escaping () -> Void) {   // (the demo stops once it's connected)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self else { return }
                        self.lock.lock(); let p = self.playing; self.lock.unlock()
                        if p && tries > 0 { whenStopped(tries - 1, go) } else { go() }
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 5.5) { whenStopped(40) { [weak self] in
                    guard let self else { return }
                    self.playOnDevice(track: self.selected, notes: [67, 70, 72, 70, 67, 65, 67, 67, 70, 72, 75, 74, 72, 70])
                    guard a.contains("-demo-take-picker") || a.contains("-demo-take-kept") else { return }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                        self.shiftSaveOnDevice()
                        if a.contains("-demo-take-kept") {
                            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { self.takeKeyOnDevice(keep: true) }
                        }
                    }
                } }
            }
            // -demo-user-sounds: three of USER's slots hold sounds, and P1 and P2 hold projects (the SAVE pages' screenshots)
            if a.contains("-demo-user-sounds") {
                userSlots[0] = (0, "WARM PAD"); userSlots[1] = (2, "ACID LINE"); userSlots[4] = (0, "GLASS KEYS")
                projectSlots[1] = "LIVE SET"
            }
            // -demo-chord N: the selected track's CHORD (81: 1 DIA3 … 9 POW), for the SEL pages' screenshots
            if let i = a.firstIndex(of: "-demo-chord"), a.indices.contains(i + 1), let c = Int(a[i + 1]) { params[selected][81] = c }
            // -demo-strum MS DIR (2.5.1): the selected track's STRUM (138, ms) and its DIR (139: 0 DOWN, 1 UP, 2 ALT)
            if firmware.hasDelayMode, let i = a.firstIndex(of: "-demo-strum"), a.indices.contains(i + 2),
               let ms = Int(a[i + 1]), let d = Int(a[i + 2]) { params[selected][138] = ms; params[selected][139] = d }
            // -demo-dmode N (2.5.1): GLO › DELAY's MODE (G_DMODE, GSID 27: 0 MONO, 1 STEREO, 2 PING)
            if firmware.hasDelayMode, let i = a.firstIndex(of: "-demo-dmode"), a.indices.contains(i + 1), let m = Int(a[i + 1]),
               globals.indices.contains(27) { globals[27] = m }
            // -demo-mod-walk: MOD opened on the FM-1, then KNOB 1 walks its routes, a route every 1.5 s
            if a.contains("-demo-mod-walk") {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.pressOnDevice(page: 4)
                    for k in 1...10 {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5 * Double(k)) { self?.turnCursorOnDevice(to: k) }
                    }
                }
            }
            // -demo-notes-walk: SEQ › NOTES opened on the FM-1, then KNOB 1 walks the step cursor across the bars
            if a.contains("-demo-notes-walk") {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.pressOnDevice(page: 41)
                    for (k, c) in [2, 5, 9, 14, 17, 21, 30, 6].enumerated() {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2 * Double(k + 1)) { self?.turnCursorOnDevice(to: c) }
                    }
                }
            }
            // -demo-turn ID: an encoder turned on the FM-1, one CHANGED every 40 ms for track parameter ID (profiling)
            if let i = a.firstIndex(of: "-demo-turn"), a.indices.contains(i + 1), let id = Int(a[i + 1]) { startTurning(id) }
            let which = a.firstIndex(of: "-demo-song").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
            if which != "empty" { seedSong() }
            if which == "full" {
                for i in 0..<16 { lists[4][i] = FakeEntry(p: [65, 12, 13][i % 3], r: 0) }
                poolLen = Array(repeating: 16, count: 64)
            }
        }
    }

    public init(_ fx: SkiffFixture) {
        self.fx = fx
        engineTable = SkiffEngineTable.load(SkiffInfo(fx.info)?.firmware ?? .v2_2)
        (frames, sink) = AsyncStream.makeStream(of: [UInt8].self)
        (notes, notesSink) = AsyncStream.makeStream(of: NoteEvent.self)
        (clock, clockSink) = AsyncStream.makeStream(of: ClockEvent.self)
        let info = SkiffInfo(fx.info)!
        firmware = info.firmware ?? .v2_2
        var body = fx.info
        if body.count >= 3, body[body.count - 3] == 0x56, body[body.count - 2] == 1 { body.removeLast(3) }
        infoBody = body
        pCount = info.paramCount; gCount = info.globalCount
        let tl = try! TrackList(fx.track)
        selected = tl.selected
        for t in 0..<info.trackCount {
            steps.append((0..<info.stepCount).map { Array(fx.steps["\(t).\($0)"]!.dropFirst(2)) })
            var r = ByteReader(fx.trackDump["\(t)"]!)
            _ = try! r.u8(); let e = try! r.u8(), p = try! r.u8()
            engines.append((e, p))
            params.append(try! (0..<pCount).map { _ in try r.v14() })
        }
        var r = ByteReader(fx.dump)
        _ = try! r.u8(); _ = try! r.u8()
        for _ in 0..<pCount { _ = try! r.v14() }
        globals = try! (0..<gCount).map { _ in try r.v14() }
        lists = Array(repeating: Array(repeating: FakeEntry(), count: 16), count: info.trackCount)
        entryOn = Array(repeating: 127, count: info.trackCount)
        muted = Array(repeating: false, count: info.trackCount)
        stagedMute = Array(repeating: 0, count: info.trackCount)
        stagedEntry = Array(repeating: 127, count: info.trackCount)
    }

    /// The song on the canvas's board A (vault skiff-arrange-spec.md): six lanes, linked copies, rests,
    /// a chain, an entry with a sound, T3 on 64 steps and T4 on 12.
    func seedSong() {
        func e(_ p: Int, _ reps: Int, chain: Bool = false, sound: (Int, Int) = (0, 0)) -> FakeEntry {
            FakeEntry(p: p, r: chain ? 16 : reps - 1, s0: sound.0, s1: sound.1)
        }
        let R = 65
        let song: [[FakeEntry]] = [
            [e(1, 4), e(2, 8), e(3, 1), e(2, 7), e(3, 1), e(4, 4)],
            [e(R, 4), e(5, 8), e(6, 1, chain: true), e(7, 2), e(5, 8)],
            [e(8, 2), e(9, 1), e(8, 2), e(R, 1)],
            [e(R, 4), e(10, 16), e(11, 8)],
            [e(R, 8), e(12, 4, sound: (3, 2)), e(13, 4), e(12, 4), e(12, 4)],
            [e(14, 16), e(14, 8)],
        ]
        for (t, l) in song.enumerated() where t < lists.count {
            for (i, x) in l.enumerated() { lists[t][i] = x }
            entryOn[t] = 0
        }
        poolLen = (0..<64).map { $0 < 14 ? 16 : 0 }
        poolLen[7] = 64; poolLen[8] = 64; poolLen[9] = 12            // 08, 09 on 64 steps; 10 on 12
        // three scenes kept (the Pads view's): A everywhere; B on the first two; the breakdown, drums muted
        let n = lists.count
        scenes[0] = (0..<n).map { _ in (0, false) }
        scenes[1] = (0..<n).map { ($0 < 2 ? 1 : 0, false) }
        scenes[2] = (0..<n).map { ($0 == 1 ? 1 : 0, $0 == 3 || $0 == 5) }
        lastScene = 0
        if params.count > 3 { params[2][29] = 64; params[3][29] = 12 }  // LENGTH (id 29): T3's and T4's
        songMode = 1
    }

    private func uses(_ p: Int) -> Int { lists.reduce(0) { $0 + $1.filter { $0.p == p + 1 }.count } }

    private func projectReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        [op, rc, UInt8(musicSlot ?? 127), musicChanged ? 1 : 0] + Array((musicSlot.flatMap { projectSlots[$0] } ?? "").utf8) + [0]
            + projectSlots.flatMap { n -> [UInt8] in [n == nil ? 0 : 1] + Array((n ?? "").utf8) + [0] }
    }

    private func poolReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        [op, rc] + (0..<64).flatMap { [UInt8(poolLen[$0]), UInt8(min(127, uses($0)))] }
    }

    private func performReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        let bits = (0..<16).reduce(0) { $0 | (scenes[$1] == nil ? 0 : 1 << $1) }
        var b: [UInt8] = [op, rc, UInt8(launch), UInt8(lastScene), UInt8(bits & 127), UInt8(bits >> 7 & 127), UInt8(bits >> 14 & 3)]
        for t in muted.indices { b += [muted[t] ? 1 : 0, UInt8(stagedMute[t])] }
        return b
    }

    /// PERFORM's ops, as editor_song.c does them (the fake's launch point: 2 s on).
    private func performOp(_ a: [UInt8]) -> [UInt8]? {
        guard a.count == 2 || a == [4] else { return nil }
        switch a[0] {
        case 1 where a[1] < 16:
            scenes[Int(a[1])] = lists.indices.map { (entryOn[$0] < 16 ? entryOn[$0] : 0, muted[$0]) }
            lastScene = Int(a[1])
        case 2 where a[1] < 16:
            guard let s = scenes[Int(a[1])] else { return performReply(2, 1) }
            if recallsStillSaving > 0 { recallsStillSaving -= 1; return performReply(2, 4) }
            for (t, x) in s.enumerated() where t < lists.count {
                if lists[t][x.entry].p != 0 { entryOn[t] = x.entry }
                if muted[t] != x.mute { stage(t) }
            }
            lastScene = Int(a[1])
        case 3 where Int(a[1]) < muted.count: stage(Int(a[1]))
        case 4: stagedMute = stagedMute.map { _ in 0 }; stagedEntry = stagedEntry.map { _ in 127 }
        case 5 where a[1] < 4: launch = Int(a[1])
        default: return nil
        }
        return performReply(a[0], 0)
    }

    /// A track's mute the other way: at once stopped; playing, staged (a staged one taken back), landing 2 s on.
    private func stage(_ t: Int) {
        guard playing else { muted[t].toggle(); return }
        if stagedMute[t] != 0 { stagedMute[t] = 0; return }
        stagedMute[t] = muted[t] ? 1 : 2
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            if self.stagedMute[t] != 0 { self.muted[t] = self.stagedMute[t] == 2; self.stagedMute[t] = 0 }
            self.lock.unlock()
        }
    }

    private func listReply(_ op: UInt8, _ rc: UInt8) -> [UInt8] {
        var b: [UInt8] = [op, rc, UInt8(songMode)]
        for t in lists.indices {
            let on = entryOn[t]
            let pat = on < 16 && lists[t][on].p >= 1 && lists[t][on].p <= 64 ? lists[t][on].p - 1 : 127
            // (the song's next is staged in SONG ON and ONCE; in SONG OFF nothing is, until a launch)
            let next = on < 16 && playing && songMode != 0 ? UInt8((on + 1) % 16) : 127
            b += [UInt8(on), t < stagedEntry.count && stagedEntry[t] != 127 ? UInt8(stagedEntry[t]) : next, UInt8(pat)]
            for x in lists[t] { b += [UInt8(x.p), UInt8(x.r), UInt8(x.s0), UInt8(x.s1)] }
        }
        return b
    }

    private func freePattern(after p: Int = -1) -> Int? {
        let order = Array((p + 1)..<64) + Array(0..<max(0, p + 1))
        return order.first { poolLen[$0] == 0 && uses($0) == 0 }
    }

    /// LIST2's ops, as EDITOR_PROTOCOL.md says the device does them (not every refusal it has).
    private func listOp(_ a: [UInt8]) -> [UInt8]? {
        let op = a[0]
        if op == 6 { guard a.count == 2, a[1] <= 2 else { return nil }; songMode = Int(a[1]); return listReply(6, 0) }
        guard a.count >= 3, Int(a[1]) < lists.count, a[2] < 16 else { return nil }
        let t = Int(a[1]), i = Int(a[2])
        var x = lists[t][i]
        switch op {
        case 1:
            guard a.count == 4, (1...65).contains(a[3]) else { return nil }
            if a[3] != 65 && poolLen[Int(a[3]) - 1] == 0 && uses(Int(a[3]) - 1) == 0 { return listReply(1, 1) }
            x.p = Int(a[3])
        case 2:
            guard (1...64).contains(x.p) else { return listReply(2, 1) }
            guard let n = freePattern(after: x.p - 1) else { return listReply(2, 4) }
            poolLen[n] = poolLen[x.p - 1]; x.p = n + 1
        case 3:
            guard playing else { entryOn[t] = i; stagedEntry[t] = 127; return listReply(3, 0) }
            stagedEntry[t] = i                              // replaces one staged before (a take-back stages the entry on)
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                if self.stagedEntry[t] == i { self.entryOn[t] = i; self.stagedEntry[t] = 127 }
                self.lock.unlock()
            }
            return listReply(3, 0)
        case 4:
            if playing && x.p != 65 { return listReply(4, 3) }
            let old = x.p
            x = FakeEntry()
            lists[t][i] = x
            if (1...64).contains(old) && uses(old - 1) == 0 { poolLen[old - 1] = 0 }
            return listReply(4, 0)
        case 5:
            guard a.count == 4, a[3] <= 16 else { return nil }
            if a[3] == 0 {
                guard x.p != 0, i < 15, lists[t][i + 1].p != 0 else { return listReply(5, 1) }
                x.r = 16
            } else { x.r = Int(a[3]) - 1 }
        case 7:
            guard let n = freePattern() else { return listReply(7, 4) }
            poolLen[n] = max(1, params[t][29]); x.p = n + 1
        case 8:
            guard (1...64).contains(x.p), let to = ((i + 1)..<16).first(where: { lists[t][$0].p == 0 }) else { return listReply(8, 1) }
            guard let n = freePattern(after: x.p - 1) else { return listReply(8, 4) }
            poolLen[n] = poolLen[x.p - 1]
            lists[t][to] = FakeEntry(p: n + 1, r: x.r == 16 ? 0 : x.r, s0: x.s0, s1: x.s1)
            return listReply(8, 0)
        case 9:
            guard a.count == 5, x.p != 0 else { return a.count == 5 ? listReply(9, 1) : nil }
            x.s0 = Int(a[3]); x.s1 = Int(a[4])
        default: return nil
        }
        lists[t][i] = x
        return listReply(op, 0)
    }

    /// Pushes (CHANGED, STEP_CHANGED, ...) as the device sends them while watched.
    func push(_ cmd: UInt8, _ body: [UInt8]) { if watching { sink.yield(Frame.encode(cmd, body)) } }

    /// A knob turned once on the FM-1 to `v`, for track parameter `id` of the selected track: the value kept and CHANGED
    /// pushed as editor.c's watch writes it (ED_SCOPE, ED_ID7: a wide id, 128 on, as scope 2 and its low seven bits).
    public func turnKnobOnDevice(id: Int, to v: Int) {
        lock.lock(); let sel = selected; if id < params[sel].count { params[sel][id] = v }; lock.unlock()
        push(Cmd.changed, [UInt8((id >> 7) << 1), UInt8(id & 127)] + v14(v))
    }

    private var turnTimer: DispatchSourceTimer?
    /// A knob turned slowly back and forth on the FM-1: CHANGED for `id` every 40 ms, a step each, 0…127 and back.
    func startTurning(_ id: Int) {
        var v = 0, d = 1
        let t = DispatchSource.makeTimerSource(queue: .global())
        t.schedule(deadline: .now() + 3, repeating: .milliseconds(40))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            v += d; if v >= 127 || v <= 0 { d = -d }
            self.lock.lock(); let sel = self.selected; if id < self.params[sel].count { self.params[sel][id] = v }; self.lock.unlock()
            self.push(Cmd.changed, [0, UInt8(id)] + self.v14(v))
        }
        t.resume()
        turnTimer = t
    }

    /// MOTION's reply (editor.c ed_motion_reply): track, rc, on, count, 64, the records, then their kinds when asked.
    private func motionReply(_ t: Int, rc: UInt8, kinds: Bool) -> [UInt8] {
        let m = motion[t]
        var b: [UInt8] = [UInt8(t), rc, m.isEmpty ? 0 : 1, UInt8(m.count), 64]
        for e in m { b += [UInt8(e.step | (e.id >> 7 & 1) << 6), UInt8(e.id & 127)] + v14(e.value) }
        if kinds { for e in m { b.append(e.lock ? 1 : 0) } }
        return b
    }

    private func mixReply(_ s: Int) -> [UInt8] {
        let z = mixZones[s]
        return [UInt8(s), z.isEmpty ? 1 : 0, UInt8(z.count)] + z.flatMap { [UInt8($0.0), UInt8($0.1)] } + mixValues[s].map { UInt8($0) }
    }

    private func screenBytes() -> [UInt8] {
        let wire = firmware.pageMap.device(screen.page) ?? screen.page
        let flags = screen.flags | (screenLinkVersion >= 7 && take.open ? 8 : 0)   // (56 01 7) bit 3: the picker open
        let b: [UInt8] = [screen.home ? 1 : 0, UInt8(wire), UInt8(screen.layer), UInt8(screen.menu), UInt8(selected), UInt8(flags)]
        guard screenLinkVersion >= 2 else { return b }
        let c: UInt8 = !screen.home && Self.cursorRange[screen.page] != nil ? UInt8(cursor) : 127
        // NOTES and FEEL: the second is the selection's last step (one step here, so the same); a sheet's: its window
        if !screen.home, Self.windowCount[screen.page] != nil { return b + [c, UInt8(windows[screen.page] ?? 0)] }
        return b + [c, c != 127 && [41, 42].contains(screen.page) ? c : 127]
    }

    /// A button pressed on the FM-1: its screen changes and, watched with bit 2, it says so (cmd 90).
    func pressOnDevice(page: Int?, track: Int? = nil) {
        lock.lock()
        if let page { if page != screen.page || screen.home { cursor = 0 }; screen = (false, page, 0, 0, 0) } else { screen.home = true }
        if let track { selected = track }
        let b = screenBytes(), on = screenWatched
        lock.unlock()
        if on { push(90, b) }
    }

    /// SELECT on the FM-1 on a sheet: its window down (`by` > 0) or up, within its ends (sheet_rows), and, watched, it
    /// says so. Off a sheet, nothing here (past a sheet's ends SELECT goes on to the pages beside it).
    public func selectOnDevice(by d: Int) {
        lock.lock()
        guard !screen.home, let n = Self.windowCount[screen.page] else { lock.unlock(); return }
        let w = (windows[screen.page] ?? 0) + (d > 0 ? 1 : -1)
        guard (0..<n).contains(w) else { lock.unlock(); return }
        windows[screen.page] = w
        let b = screenBytes(), on = screenWatched
        lock.unlock()
        if on { push(90, b) }
    }

    /// KNOB 1 turned on the FM-1 on a page with a cursor: it moves (clamped) and, watched, it says so.
    func turnCursorOnDevice(to c: Int) {
        lock.lock()
        guard !screen.home, let top = Self.cursorRange[screen.page] else { lock.unlock(); return }
        cursor = max(0, min(top, c))
        let b = screenBytes(), on = screenWatched
        lock.unlock()
        if on { push(90, b) }
    }

    /// FREE TAKE on the FM-1 (Skiff 2.5, ui_take.c), stopped: `notes` played on `track` (its notes out over MIDI, as
    /// NOTES OUT sends them), then SHIFT + SAVE: the picker writes the phrase into the track (fr_render: every step, LENGTH,
    /// DIV 1/16, BPM unless another track has notes) and the live sync pushes what changed, as editor.c ed_sync does for
    /// the selected track (STEP_CHANGED, then CHANGED of LENGTH, DIV and BPM). The picker isn't reported (SCREEN doesn't).
    func freeTakeOnDevice(track t: Int, notes: [Int], length: Int, bpm: Int?) {
        for n in notes {
            notesSink.yield(NoteEvent(on: true, channel: UInt8(t), note: UInt8(n)))
            notesSink.yield(NoteEvent(on: false, channel: UInt8(t), note: UInt8(n), velocity: 0))
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            guard !self.playing else { self.lock.unlock(); return }
            var changed: [Int] = []
            let per = max(1, length / max(1, notes.count))
            for i in 0..<self.steps[t].count {
                let k = i / per
                var b = self.steps[t][i]
                if i < length, i % per == 0, k < notes.count {
                    b[0] = 1; b[1] = UInt8(notes[k]); b[2] = 0; b[3] = 0; b[4] = 0; b[5] = 0; b[7] = 100   // one note (ST_NOTE 0)
                } else {
                    b[0] = 0; b[1] = 0; b[2] = 0; b[3] = 0; b[4] = 0; b[5] = 2                             // ST_REST
                }
                if b != self.steps[t][i] { self.steps[t][i] = b; changed.append(i) }
            }
            let lenID = 29, divID = 30                                       // P_SLEN, P_SDIV (core.h, both releases)
            self.params[t][lenID] = length; self.params[t][divID] = 2
            if let bpm { self.globals[0] = bpm }
            let sel = t == self.selected
            self.lock.unlock()
            guard sel else { return }                                        // (the sync pushes the selected track's only)
            for i in changed { self.push(Cmd.stepChanged, [UInt8(i), UInt8(t)]) }
            self.push(Cmd.changed, [0, UInt8(lenID)] + v14(length))
            self.push(Cmd.changed, [0, UInt8(divID)] + v14(2))
            if let bpm { self.push(Cmd.changed, [1, 0] + v14(bpm)) }
        }
    }

    // MARK: FREE TAKE, levels 2 and 3

    /// Notes played on the FM-1 with the transport stopped: out over MIDI (NOTES OUT), and kept for a free take.
    func playOnDevice(track t: Int, notes: [Int]) {
        lock.lock(); let stopped = !playing && !take.open; if stopped { heard[t, default: []] += notes }; lock.unlock()
        for n in notes {
            notesSink.yield(NoteEvent(on: true, channel: UInt8(t), note: UInt8(n)))
            notesSink.yield(NoteEvent(on: false, channel: UInt8(t), note: UInt8(n), velocity: 0))
        }
    }
    /// SHIFT + SAVE on the FM-1 (ui_input.c take_commit on the selected track); pushed when watched.
    func shiftSaveOnDevice() { onDevice { _ = $0.takeOp(8, 0, fromEditor: false) } }
    /// One of the picker's knobs turned on the FM-1 (KNOB 1…4: guess, BARS, first beat, TEMPO), `by` steps.
    func turnTakeKnobOnDevice(_ k: Int, by d: Int) {
        onDevice { f in
            guard f.take.open else { return }
            let cur = [f.take.guess, f.take.bars, f.take.first, f.take.set ? 1 : 0][k]
            _ = f.takeOp(k + 1, k == 3 ? (d > 0 ? 1 : 0) : max(0, cur + d), fromEditor: false)
        }
    }
    /// OCT+ (keep) or OCT− (put back) on the FM-1 with the picker open.
    func takeKeyOnDevice(keep: Bool) { onDevice { _ = $0.takeOp(keep ? 6 : 7, 0, fromEditor: false) } }

    /// The lock taken, the change made, then the device's pushes: SCREEN and TAKE where they changed (watched), then the
    /// selected track's steps and LENGTH, DIV, BPM, as editor.c ed_sync sends them.
    private func onDevice(_ body: (FakeSkiff) -> Void) {
        lock.lock()
        let screen0 = screenBytes(), take0 = takeBytes(), steps0 = steps, len0 = params.map { [$0[29], $0[30]] }, bpm0 = globals[0]
        body(self)
        let screen1 = screenBytes(), take1 = takeBytes()
        lock.unlock()
        if screenWatched, screen1 != screen0 { push(90, screen1) }
        if takeWatched, take1 != take0 { push(Cmd.take, take1) }
        syncPushes(steps0, len0, bpm0)
    }
    /// What changed since (the steps, LENGTH, DIV of the selected track, BPM): pushed as the live sync does.
    private func syncPushes(_ steps0: [[[UInt8]]], _ len0: [[Int]], _ bpm0: Int) {
        lock.lock()
        let t = selected
        let changed = steps[t].indices.filter { steps[t][$0] != steps0[t][$0] }
        let ld = [29, 30].enumerated().filter { params[t][$0.element] != len0[t][$0.offset] }.map { ($0.element, params[t][$0.element]) }
        let bpm = globals[0]
        lock.unlock()
        for i in changed { push(Cmd.stepChanged, [UInt8(i), UInt8(t)]) }
        for (id, v) in ld { push(Cmd.changed, [0, UInt8(id)] + v14(v)) }
        if bpm != bpm0 { push(Cmd.changed, [1, 0] + v14(bpm)) }
    }

    /// TAKE's 21 bytes (editor.c ed_take_now). The lock held.
    func takeBytes() -> [UInt8] {
        let k = take
        var b: [UInt8] = [k.open ? 1 : 0, UInt8(k.end), UInt8(k.track), UInt8(k.pattern ?? 127), UInt8(k.guesses.count), UInt8(k.guess)]
        for i in 0..<4 { let g = i < k.guesses.count ? k.guesses[i] : 0; b += [UInt8(g & 127), UInt8(g >> 7 & 127)] }
        b += [UInt8(k.bars), UInt8(k.first), UInt8(k.firsts), k.set ? 1 : 0, UInt8(k.bpm0 & 127), UInt8(k.bpm0 >> 7 & 127),
              globals.count > 2 && globals[2] != 0 ? 1 : 0]
        return b
    }

    /// TAKE op (editor.c): 1…4 set a choice to `v` as its knob would (clamped; TEMPO SET not on an external clock),
    /// 5 PLAY, 6 keep, 7 put back (the picker open only, else rc 1), 8 SHIFT + SAVE. → rc. The lock held.
    func takeOp(_ op: Int, _ v: Int, fromEditor: Bool) -> UInt8 {
        if op == 8 {
            if fromEditor, screen.menu != 0 { return 1 }                  // (SHIFT + SAVE's own conditions)
            if take.open { takeClose(keep: true); return 0 }
            // stopped with notes on the selected track: a free take. (Playing, SHIFT + SAVE takes the last loop: not
            // modelled here; nothing played: the FM-1 says so on its screen, and nothing opens)
            guard !playing, let notes = heard[selected], !notes.isEmpty else { return 0 }
            takeOpen(track: selected, notes: notes)
            return 0
        }
        guard take.open else { return 1 }
        switch op {
        case 1: take.guess = max(0, min(take.guesses.count - 1, v))
        case 2: take.bars = max(0, min(3, v))
        case 3: take.first = max(0, min(take.firsts - 1, v))
        case 4: take.set = v != 0 && !(globals.count > 2 && globals[2] != 0)
        case 5: setPlaying(!playing); return 0
        case 6, 7: takeClose(keep: op == 6); return 0
        default: return 1
        }
        takeRender()
        return 0
    }

    /// free_open: the guesses (a fixed set here: `takeGuesses`), BARS from the phrase's length, the first beat on the
    /// first note, TEMPO SET unless another track has notes or the clock is external; one undo copy; the track
    /// rewritten (fr_render).
    private func takeOpen(track t: Int, notes: [Int]) {
        let other = steps.indices.contains { $0 != t && steps[$0].contains { $0.first ?? 0 != 0 } }
        pushUndo(track: t)
        take = FakeTake(open: true, end: 0, track: t, pattern: entryOn[t] < 16 && (1...64).contains(lists[t][entryOn[t]].p) ? lists[t][entryOn[t]].p - 1 : nil,
                        guesses: takeGuesses, guess: 0, bars: notes.count > 16 ? 2 : notes.count > 8 ? 1 : 0, first: 0,
                        firsts: min(8, notes.count), set: !other && !(globals.count > 2 && globals[2] != 0), bpm0: globals[0],
                        from: steps[t], len0: params[t][29], div0: params[t][30], notes: notes)
        takeRender()
    }
    /// The guesses a take opens with (the FM-1 finds them in the phrase's timing, which the fake doesn't have): what
    /// skiff-sim built from the firmware branch answered for eight quarter notes at 120 BPM (FreeTakeSimTests).
    var takeGuesses = [90, 60, 120, 150]

    /// fr_render: the notes from the first beat on, evenly over the bars (the earlier ones as a pickup at the loop's end),
    /// every step past them a rest; LENGTH, DIV (1/8 at 8 bars), the tempo.
    private func takeRender() {
        let t = take.track, bars = [1, 2, 4, 8][take.bars], len = bars >= 8 ? 64 : 16 * bars
        let n = take.notes.count, order = Array(take.notes[take.first...] + take.notes[..<take.first])
        let per = max(1, len / max(1, n))
        for i in steps[t].indices {
            var b = steps[t][i]
            if i < len, i % per == 0, i / per < order.count {
                b[0] = 1; b[1] = UInt8(order[i / per]); b[2] = 0; b[3] = 0; b[4] = 0; b[5] = 0; b[7] = 100
            } else {
                b[0] = 0; b[1] = 0; b[2] = 0; b[3] = 0; b[4] = 0; b[5] = 2
            }
            steps[t][i] = b
        }
        params[t][29] = len; params[t][30] = bars >= 8 ? 1 : 2
        if !(globals.count > 2 && globals[2] != 0) { globals[0] = take.set ? take.guesses[take.guess] : take.bpm0 }
    }

    /// fr_close: kept (the next take starts after this one), or the track and tempo put back (unless another pattern
    /// came onto the track meanwhile: not modelled).
    private func takeClose(keep: Bool) {
        guard take.open else { return }
        take.open = false
        take.end = keep ? 1 : 2
        if keep {
            heard = [:]
        } else {
            let t = take.track
            steps[t] = take.from; params[t][29] = take.len0; params[t][30] = take.div0
            if !(globals.count > 2 && globals[2] != 0) { globals[0] = take.bpm0 }
        }
    }

    private func pushUndo(track t: Int) {
        undoCopies.removeLast(undoBack)
        undoBack = 0
        undoCopies.append((t, steps[t], params[t][29], params[t][30]))
        if undoCopies.count > 6 { undoCopies.removeFirst() }
    }
    /// ui.c undo_step: back one copy, or forward one; each swaps the track's steps, LENGTH and DIV with the copy (the
    /// tempo stays). The device's pushes follow, for the selected track.
    private func undoStep(redo: Bool) {
        if redo ? undoBack == 0 : undoBack >= undoCopies.count { return }       // (NOTHING TO UNDO / REDO)
        if redo { undoBack -= 1 }
        let i = undoCopies.count - 1 - undoBack
        let c = undoCopies[i], t = c.track
        let steps0 = steps, len0 = params.map { [$0[29], $0[30]] }, bpm0 = globals[0]
        undoCopies[i] = (t, steps[t], params[t][29], params[t][30])
        steps[t] = c.steps; params[t][29] = c.len; params[t][30] = c.div
        if !redo { undoBack += 1 }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { [weak self] in self?.syncPushes(steps0, len0, bpm0) }
    }

    /// A clock tick while playing: each track's level jumps on a step with a note and falls as the FM-1's meter does
    /// (127 / 30 a 16 ms frame); pushed every other tick (about 25 a second at 120 BPM), as editor.c ed_met_tick.
    private func meterStep(_ dt: Double) {
        lock.lock()
        meterTick += 1
        let step = (meterTick / 6) % 16, onStep = meterTick % 6 == 1
        for t in steps.indices where t < meterLevels.count {
            let fall = dt / 0.016 / 30
            meterLevels[t] = max(0, meterLevels[t] - fall)
            if onStep, steps[t][step].first ?? 0 != 0, params[t][40] == 0 {
                meterLevels[t] = 0.85
                if steps[t][step].count > 1 { scopeNote[t] = Int(steps[t][step][1]) }
            }
        }
        let b = meterLevels.prefix(steps.count).map { UInt8(min(127, max(0, Int($0 * 127)))) }
        let on = meterWatched && meterTick % 2 == 0
        let scope = scopeWatched && meterTick % 3 == 0 ? scopeFrame() : nil
        lock.unlock()
        if on { push(92, b) }
        if let scope { push(93, scope) }
    }

    /// SCOPE's 120 samples from the tracks sounding now (the lock held): each a wave of its note's pitch (2 cycles
    /// across at C3, an octave up twice as many), a saw's first harmonics on ANALOG, a sine with its octave elsewhere,
    /// started at phase 0 so the sum rises through the centre at the left as the FM-1's trigger puts it; auto-scaled
    /// to ±58 about 64. All 64 in silence.
    func scopeFrame() -> [UInt8] {
        var y = [Double](repeating: 0, count: 120)
        for t in steps.indices where t < meterLevels.count && meterLevels[t] > 0.02 {
            let cycles = min(9, max(1, 2 * pow(2, Double(scopeNote[t] - 48) / 12)))
            let saw = engines[t].engine == 0
            for i in 0..<120 {
                let ph = Double(i) / 120 * cycles * 2 * .pi
                let w = saw ? sin(ph) + sin(2 * ph) / 2 + sin(3 * ph) / 3 : sin(ph) + 0.3 * sin(2 * ph)
                y[i] += w * meterLevels[t]
            }
        }
        let peak = y.map(abs).max() ?? 0
        guard peak > 0.01 else { return [UInt8](repeating: 64, count: 120) }
        return y.map { UInt8(min(127, max(0, Int((64 + $0 / peak * 58).rounded())))) }
    }

    deinit { clockTimer?.cancel() }

    /// A few notes on each track and PLAY, so the demo has something to show (the recorded unit is blank).
    func seedDemo() {
        let roots = [48, 60, 55, 36, 64, 38]
        for t in steps.indices {
            for i in stride(from: 0, to: 16, by: t % 2 == 0 ? 2 : 4) {
                var s = steps[t][i]
                let n = UInt8(roots[t] + (i / 2) % 5 * 2)
                s.replaceSubrange(0..<8, with: [1, n, 0, 0, 0, 0, 0, 100])
                steps[t][i] = s
            }
        }
        // T1 with recorded motion (CHORUS turned up across its first bar, as skiff-sim recorded it), so Lupe's
        // motion marks show in the demo
        motion[0] = [(2, 34, 40, false), (5, 34, 96, false), (9, 34, 20, false), (12, 34, 70, false), (14, 34, 120, true),
                     (4, 36, 60, false), (10, 36, 10, false)]
        if !LaunchArgs.all.contains("-demo-stopped") { setPlaying(true) }   // -demo-stopped: idle (CPU)
    }

    /// PLAY / STOP: Start and 24 pulses a beat at the BPM while playing, Stop after.
    private func setPlaying(_ on: Bool) {
        guard on != playing || (on && clockTimer == nil) else { return }
        playing = on
        if on { starts += 1 }
        clockTimer?.cancel(); clockTimer = nil
        if on {
            clockSink.yield(.start)
            let t = DispatchSource.makeTimerSource(queue: .global())
            let interval = 60.0 / Double(max(40, globals.first ?? 120)) / 24
            t.schedule(deadline: .now() + interval, repeating: interval)
            t.setEventHandler { [weak self] in self?.clockSink.yield(.tick); self?.meterStep(interval) }
            t.resume()
            clockTimer = t
        } else {
            clockSink.yield(.stop)
        }
    }

    public func send(_ frame: [UInt8]) {
        guard let (cmd, a) = Frame.decode(frame) else {               // plain MIDI: no reply; kept for the tests
            lock.lock(); midiIn.append(frame); lock.unlock()
            return
        }
        lock.lock()
        if busy { dropped += 1; lock.unlock(); return }               // one incoming frame at a time
        busy = true
        requests.append(cmd)
        let reply = answer(cmd, a)
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + replyDelay) { [self] in
            lock.lock(); busy = false; lock.unlock()
            if let reply { sink.yield(Frame.encode(cmd, reply)) }
        }
    }

    func v14(_ v: Int) -> [UInt8] { Frame.v14(v) }

    /// DESC of an engine parameter on 2.5.1, for the selected track's engine, as editor.c writes it: scope and id as
    /// asked, FMT, MIN MAX DEF, the label and unit (8 letters, 0-terminated), a list's names (up to 24).
    private func engineDesc(_ pid: Int, _ a0: UInt8, _ a1: UInt8) -> [UInt8]? {
        guard let t = engineTable, (t.P_E0..<(t.P_E0 + 8)).contains(pid), let eng = t.engines[safe: engines[selected].engine],
              let d = eng.edit[safe: pid - t.P_E0] else { return nil }
        func str(_ s: String) -> [UInt8] { Array(s.utf8.prefix(8)).map { $0 & 0x7F } + [0] }
        var b: [UInt8] = [a0, a1, UInt8(d.fmt)] + v14(d.min) + v14(d.max) + v14(d.def) + str(d.label) + str(d.unit)
        if d.fmt == 8, let n = d.names { for x in n.prefix(min(24, d.max - d.min + 1)) { b += str(x) } }
        return b
    }

    /// PRESET's values on 2.5.1 (hostsim.c host_preset_values: the engine's eight, the ENV, VOICE from MONO, the
    /// preset's other values). No push follows: editor.c ed_load_after takes the load into the watch's copy, so the
    /// editor that asked hears nothing (the phone reads the track again itself).
    private func loadPresetValues(engine e: Int, preset pi: Int) {
        guard let t = engineTable, let p = t.engines[safe: e]?.presets[safe: pi], selected < params.count else { return }
        let s = selected
        for (k, v) in p.e.enumerated() where t.P_E0 + k < pCount { params[s][t.P_E0 + k] = v }
        for (k, v) in p.env.enumerated() where 1 + k < pCount { params[s][1 + k] = v }          // P_ATK P_DEC P_SUS P_REL
        if 37 < pCount { params[s][37] = p.mono != 0 ? 2 : 0 }                                   // P_VOICE: V_LEGATO or V_POLY
        for m in p.more where m.count == 2 && m[0] < pCount { params[s][m[0]] = m[1] }
    }
    private func id(_ scope: UInt8, _ i: UInt8) -> Int { scope == 2 ? Int(i) + 128 : Int(i) }

    private func trackList() -> [UInt8] {
        var b: [UInt8] = [UInt8(selected), UInt8(steps.count)]
        for t in steps.indices { b += [UInt8(engines[t].engine), UInt8(engines[t].preset)] + v14(params[t][0]) + [UInt8(params[t][40]), 0] }
        return b
    }

    /// User sample slots USR1..USR3 (Skiff 2.2: three, eng_sample.c SMP_SLOTS), cmds 11–15 as editor.c handles them.
    /// USR1 holds a sample so the demo has a full slot to show.
    struct SampleSlotState { var zones = 0; var name = ""; var dataLength = 0; var data: [UInt8] = []; var open = false }
    var sampleSlots: [SampleSlotState] = [FakeSkiff.kalimba.state, .init(), .init()]
    /// Each full slot's header as SMP_END wrote it (the backup's object 32 + slot is the header, then the data).
    var slotHeaders: [Int: [UInt8]] = [0: FakeSkiff.kalimba.header]

    /// USR1's demo sample: a decaying 660 Hz tone, about a second, so it can be heard back.
    static let kalimba: (state: SampleSlotState, header: [UInt8]) = {
        let n = UserSample.rate
        let s = (0..<n).map { i -> Int16 in
            let t = Double(i) / Double(UserSample.rate)
            return Int16(20000 * exp(-4 * t) * sin(2 * .pi * 660 * t))
        }
        let (h, d) = (try? UserSample.slot(name: "KALIMBA", samples: s)) ?? ([], [])
        return (SampleSlotState(zones: 1, name: "KALIMBA", dataLength: d.count, data: d), h)
    }()

    /// SMP_BEGIN / WRITE / END / ERASE / INFO (Skiff editor.c 896–951): as SLOOP's, but END has no rc 6 (a slot not
    /// open is rc 5, failed). Nil: not a sample command.
    /// As the firmware: BEGIN and ERASE take exactly one byte and INFO none, or there's no reply (ed_args_ok, editor.c
    /// 578); BEGIN, ERASE and every WRITE stop the transport first (ed_flash_stop, editor.c 542: transport_req = 2), so a
    /// song playing stops for the whole upload.
    private func sampleAnswer(_ cmd: UInt8, _ a: [UInt8]) -> [UInt8]? {
        let shape = cmd == Cmd.smpInfo ? a.isEmpty : (cmd == Cmd.smpBegin || cmd == Cmd.smpErase) ? a.count == 1 : true
        guard shape else { unanswered.append((cmd, a)); return nil }
        if cmd == Cmd.smpBegin || cmd == Cmd.smpErase || cmd == Cmd.smpWrite, let k = a.first, Int(k) < sampleSlots.count { setPlaying(false) }
        switch cmd {
        case Cmd.smpBegin, Cmd.smpErase:
            // past the last slot: no reply at all (editor.c 898, `return`)
            guard let k = a.first.map(Int.init), k < sampleSlots.count else { unanswered.append((cmd, a)); return nil }
            sampleSlots[k] = SampleSlotState(open: cmd == Cmd.smpBegin)
            slotHeaders[k] = nil
            return [a[0], 0]
        case Cmd.smpWrite:
            guard a.count >= 5, Int(a[0]) < sampleSlots.count else { return nil }
            let k = Int(a[0]), off = Int(a[1]) | Int(a[2]) << 7 | Int(a[3]) << 14
            let d = Array(Pack7.decode(Array(a[4...])).prefix(256))
            var rc: UInt8 = 0
            if off < UserSample.dataOffset || off & 0xFF != 0 || d.isEmpty || off + d.count > UserSample.slotSize
                || off != UserSample.dataOffset + sampleSlots[k].data.count { rc = 1 }
            else if sampleSlots[k].zones != 0 || !sampleSlots[k].open { rc = 4 }
            else { sampleSlots[k].data += d }
            return Array(a[0..<4]) + [rc]
        case Cmd.smpEnd:
            guard a.count >= 2, Int(a[0]) < sampleSlots.count else { return nil }
            let k = Int(a[0]), h = Pack7.decode(Array(a[1...]))
            func u32(_ o: Int) -> Int { Int(h[o]) | Int(h[o + 1]) << 8 | Int(h[o + 2]) << 16 | Int(h[o + 3]) << 24 }
            var rc: UInt8 = 0
            if !sampleSlots[k].open || sampleSlots[k].zones != 0 { rc = 5 }
            else if h.count < UserSample.headerLength { rc = 1 }
            else if UInt32(u32(0)) != UserSample.magic || h[4] != 1 || h[5] != 0 || !(1...16).contains(h[6]) || u32(16) > UserSample.maxData { rc = 2 }
            else {
                sampleSlots[k].open = false
                let len = u32(16), data = sampleSlots[k].data
                if data.count < len || CRC32.of(Array(data.prefix(len))) != UInt32(u32(20)) { rc = 3 }
                else {
                    sampleSlots[k].zones = Int(h[6]); sampleSlots[k].dataLength = len
                    sampleSlots[k].name = String(decoding: h[8..<16].prefix { $0 != 0 }, as: UTF8.self)
                    slotHeaders[k] = Array(h.prefix(UserSample.headerLength))
                }
            }
            return [a[0], rc]
        case Cmd.smpInfo:
            var b: [UInt8] = [UInt8(sampleSlots.count), UInt8(UserSample.slotSize / 1024)]
            for s in sampleSlots { b += [UInt8(s.zones)] + Array((s.zones != 0 ? s.name : "").utf8) + [0, UInt8(s.zones != 0 ? (s.dataLength + 1023) / 1024 : 0)] }
            return b
        default:
            return nil
        }
    }

    /// BACKUP_LIST / BACKUP_GET (65, 66) for the user sample slots only (objects 32..34: the header padded to 512,
    /// then the data). LIST stops the transport, as the firmware's does.
    private func sampleObject(_ k: Int) -> [UInt8] {
        guard k < sampleSlots.count, sampleSlots[k].zones != 0, let h = slotHeaders[k] else { return [] }
        return h + [UInt8](repeating: 0, count: UserSample.dataOffset - h.count) + sampleSlots[k].data.prefix(sampleSlots[k].dataLength)
    }

    /// A bank chunk (object 16...31): its four records, or nothing when all four are empty (listed as size 0).
    private func bankObject(_ c: Int) -> [UInt8] {
        let recs = (0..<4).map { bankRecords[4 * c + $0] }
        guard recs.contains(where: { $0 != nil }) else { return [] }
        return recs.flatMap { $0 ?? [UInt8](repeating: 0, count: 888) }
    }

    private func backupAnswer(_ cmd: UInt8, _ a: [UInt8]) -> [UInt8]? {
        switch cmd {
        case 65:
            setPlaying(false)                                // (LIST stops the transport, editor_backup.c; the clock with it)
            backupListed = true
            backupLists += 1
            let objs = (0..<16).map { (16 + $0, bankObject($0)) } + sampleSlots.indices.map { (32 + $0, sampleObject($0)) }
            var b: [UInt8] = [1, 0, UInt8(objs.count)]
            for (id, o) in objs { b += [UInt8(id)] + Pack7.u35(UInt32(o.count)) + Pack7.u35(CRC32.of(o)) }
            return b
        case 66:
            guard a.count >= 8 else { return a.isEmpty ? nil : [a[0], 1] }
            let id = Int(a[0])
            if (16..<32).contains(id) {
                // editor_backup.c: rc 5 before a LIST, 3 while the transport runs, 1 past the object
                guard backupListed else { return [a[0], 5] + Pack7.u35(0) + [0, 0] }
                guard !playing else { return [a[0], 3] + Pack7.u35(0) + [0, 0] }
                let o = bankObject(id - 16), off = Int(Pack7.readU35(a[1...])), n = Int(a[6]) | Int(a[7]) << 7
                guard n > 0, off + n <= o.count else { return [a[0], 1] + Pack7.u35(UInt32(off)) + [0, 0] }
                return [a[0], 0] + Pack7.u35(UInt32(off)) + [UInt8(n & 127), UInt8(n >> 7)] + Pack7.encode(Array(o[off..<(off + n)]))
            }
            guard (32..<(32 + sampleSlots.count)).contains(id) else { return [a[0], 1] }
            let o = sampleObject(Int(a[0]) - 32), off = Int(Pack7.readU35(a[1...])), n = Int(a[6]) | Int(a[7]) << 7
            let chunk = Array(o[min(off, o.count)..<min(off + n, o.count)])
            return [a[0], 0] + Pack7.u35(UInt32(off)) + [UInt8(n & 127), UInt8(n >> 7)] + Pack7.encode(chunk)
        default:
            return nil
        }
    }

    // Called with the lock held.
    private func answer(_ cmd: UInt8, _ a: [UInt8]) -> [UInt8]? {
        if (Cmd.smpBegin...Cmd.smpInfo).contains(cmd) { return sampleAnswer(cmd, a) }
        if cmd == 65 || cmd == 66 { return backupAnswer(cmd, a) }
        switch (cmd, a.count) {
        case (1, 0): return screenLink ? infoBody + [0x56, 1, UInt8(screenLinkVersion)] : infoBody
        case (90, 0) where screenLink: return screenBytes()
        case (91, 1) where screenLink, (91, 2) where screenLink && screenLinkVersion >= 2:
            // always answered: a refused page (or a cursor for a page or HOME with none) answers the screen unchanged.
            // The page is this release's (NPAGES 46 on 2.2, 47 on 2.5.1), kept here in Lupe's numbers
            let wire = Int(a[0]), npages = firmware == .v2_2 ? 46 : 47
            gotoWire.append(wire)
            let p = wire == 127 ? 127 : firmware.pageMap.lupe(wire)
            if a.count == 2 {
                guard wire != 127, let top = Self.cursorRange[p], wire < npages, !refusedPages.contains(p) else { return screenBytes() }
                screen = (false, p, 0, 0, 0); cursor = min(top, Int(a[1]))
            } else if wire == 127 { screen.home = true; screen.layer = 0; screen.menu = 0 }
            else if wire < npages, !refusedPages.contains(p) { if p != screen.page || screen.home { cursor = 0 }; screen = (false, p, 0, 0, 0) }
            return screenBytes()
        case (34, 0):
            // UI_STATE: caps, palette, font, monitor, filter, favoriteSig u28, bankSig u28
            return [0, UInt8(themePalette), 0, 0, 0] + [UInt8](repeating: 0, count: 8)
        case (39, 0):
            // COLORS: rc, flags (bit 0 a set stored, bit 1 in use), look, pack7 of the 22 bytes
            let c = customColours ?? Array(repeating: 0, count: 11)
            let bytes = c.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] }
            return [0, customColours == nil ? 0 : (themePalette == 6 ? 3 : 1), 0] + Pack7.encode(bytes)
        case (72, 1) where fx.menu != nil:
            // MENU_DESC from the recorded list (editor_menu.c: index, id, kind, value, min, max, name, names, tab), the
            // value as set here; past the list: id 127
            guard var b = fx.menu?["\(a[0])"], b.count >= 9 else { return [a[0], 127] }
            let id = Int(b[1])
            if let v = id == SkiffMenu.usbLevel ? usbLevel : menuValues[id] { b.replaceSubrange(3..<5, with: v14(v)) }
            return b
        case (73, 3) where fx.menu != nil:
            // MENU_SET: an id in the list takes the value clamped to its names (rc 0, saved); another rc 1, as editor_menu.c
            let v = (Int(a[1]) | Int(a[2]) << 7) - 8192, id = Int(a[0])
            guard let row = fx.menu?.values.first(where: { $0.count >= 9 && Int($0[1]) == id }) else { return [1, a[0]] + v14(v) }
            let top = (Int(row[7]) | Int(row[8]) << 7) - 8192
            let took = max(0, min(top, v))
            if id == SkiffMenu.usbLevel { usbLevel = took } else { menuValues[id] = took }
            return [0, a[0]] + v14(took)
        case (72, 1):
            // MENU_DESC: index → index, id, kind, value, min, max, … (the rest isn't read); past the list: id 127
            return a[0] == 0 ? [0, UInt8(SkiffMenu.usbLevel), 0] + v14(usbLevel) + v14(0) + v14(1) : [a[0], 127]
        case (73, 3):
            let v = (Int(a[1]) | Int(a[2]) << 7) - 8192
            guard Int(a[0]) == SkiffMenu.usbLevel else { return [1, a[0]] + v14(v) }
            usbLevel = max(0, min(1, v))
            return [0, a[0]] + v14(usbLevel)
        case (5, 2) where engineTable == nil && a == SkiffDriver.wire(pCount - 8) && engines[selected].engine == 4:
            // SAMPLE's SET on 2.2 (E0 138): the built-in sets, then the user's (eng_sample.c SMP_ALL_NAMES); 2.5.1's from engineTable
            return a + [8] + v14(0) + v14(5) + v14(0) + Array("SET".utf8) + [0, 0]
                + ["PIANO", "STRINGS", "CHOIR", "USR1", "USR2", "USR3"].flatMap { Array($0.utf8) + [0] }
        case (68, 2) where a[0] == 0 && Int(a[1]) < fm6.count: return [0, a[1], 0] + fm6[Int(a[1])].bytes
        case (69, 130) where a[0] == 0 && Int(a[1]) < fm6.count:
            fm6[Int(a[1])] = FM6Patch(bytes: Array(a[2...]))
            return [0, a[1], 0]
        case (74, 1) where a[0] < 8: return [a[0]] + dxKit[Int(a[0])].map { UInt8($0) }
        case (75, 16):
            // out of range: no reply, as Skiff
            let hi = [7, 3, 2, 1, 3, 1] + Array(repeating: 127, count: 10)
            guard zip(a, hi).allSatisfy({ Int($0) <= $1 }) else { return nil }
            dxKit[Int(a[0])] = a[1...].map(Int.init)
            return a
        case (81, 1) where a[0] < 3: return mixReply(Int(a[0]))
        case (81, 49) where a[0] < 3:
            let s = Int(a[0])
            if !mixZones[s].isEmpty { mixValues[s] = a[1...].map(Int.init) }
            return mixReply(s)
        case (5, 2):
            if a[0] != 1, let b = engineDesc(id(a[0], a[1]), a[0], a[1]) { return b }
            return fx.desc["\(a[0] == 1 ? 1 : 0).\(a[0] == 1 ? Int(a[1]) : id(a[0], a[1]))"]
        case (10, 1): return fx.names["\(a[0])"]
        case (27, 0): return trackList()
        case (27, 1):
            guard Int(a[0]) < steps.count else { return nil }
            selected = Int(a[0]); return trackList()
        case (30, 2):
            let t = Int(a[0]), i = Int(a[1])
            guard t < steps.count, i < steps[t].count else { return nil }
            return [a[0], a[1]] + steps[t][i]
        case (30, let n) where n >= 10:
            let t = Int(a[0]), i = Int(a[1])
            guard t < steps.count, i < steps[t].count, [10, 13, 14, 15, 18, 19].contains(n) else { return nil }
            var s = steps[t][i], w = Array(a[2...])
            if w.count == 8, s.count > 8 { w += s[8...] }               // the device keeps its own hits, chance, …
            s = w
            steps[t][i] = s
            return [a[0], a[1]] + s
        case (31, 2), (31, 4):
            let t = Int(a[0] & 0x3F), i = Int(a[1]) | Int(a[0] >> 6 & 1) << 7
            guard t < params.count, i < pCount else { return nil }
            if a.count == 4 {
                params[t][i] = (Int(a[2]) | Int(a[3]) << 7) - 8192
                if playing, t == selected, armed & (1 << t) != 0 {
                    motion[t].removeAll { $0.step == 0 && $0.id == i && !$0.lock }
                    motion[t].append((0, i, params[t][i], false))
                }
            }
            return [a[0], a[1]] + v14(params[t][i])
        case (2, 2) where a[0] == 1: return Int(a[1]) < gCount ? [1, a[1]] + v14(globals[Int(a[1])]) : nil
        case (3, 4) where a[0] == 1:
            guard Int(a[1]) < gCount else { return nil }
            globals[Int(a[1])] = (Int(a[2]) | Int(a[3]) << 7) - 8192
            return [1, a[1]] + v14(globals[Int(a[1])])
        case (4, 0):
            return [UInt8(engines[selected].engine), UInt8(engines[selected].preset)] + params[selected].flatMap(v14) + globals.flatMap(v14)
        case (22, 1):
            watching = a[0] != 0
            screenWatched = screenLink && a[0] & 4 != 0
            meterWatched = screenLink && screenLinkVersion >= 3 && a[0] & 8 != 0
            scopeWatched = screenLink && screenLinkVersion >= 4 && a[0] & 16 != 0
            let wasTake = takeWatched
            takeWatched = screenLink && screenLinkVersion >= 7 && a[0] & 32 != 0
            if takeWatched && !wasTake {                                 // newly asked: the state at once
                let b = takeBytes()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { [weak self] in self?.push(Cmd.take, b) }
            }
            return [a[0] & (screenLink ? (screenLinkVersion >= 7 ? 63 : screenLinkVersion >= 4 ? 31 : screenLinkVersion >= 3 ? 15 : 7) : 3)]
        case (25, 0): return [0]
        case (94, 0) where screenLink && screenLinkVersion >= 7: return takeBytes() + [0]
        case (94, 2) where screenLink && screenLinkVersion >= 7:
            guard (1...8).contains(a[0]) else { return nil }               // (editor.c ed_args_ok: no reply)
            // what it changed goes out after the reply, as ed_sync's pushes: SCREEN (its flags), the steps, LENGTH,
            // DIV, BPM; TAKE itself isn't pushed back (the reply told it)
            let screen0 = screenBytes(), steps0 = steps, len0 = params.map { [$0[29], $0[30]] }, bpm0 = globals[0]
            let rc = takeOp(Int(a[0]), Int(a[1]), fromEditor: true)
            let screen1 = screenBytes(), sw = screenWatched
            DispatchQueue.global().asyncAfter(deadline: .now() + replyDelay + 0.01) { [weak self] in
                if sw, screen1 != screen0 { self?.push(90, screen1) }
                self?.syncPushes(steps0, len0, bpm0)
            }
            return takeBytes() + [rc]
        case (95, 1) where screenLink && screenLinkVersion >= 7:
            guard a[0] <= 1 else { return nil }
            let refused = screen.menu != 0 || take.open                    // (as SAVE: not with the MENU or the picker)
            if !refused { undoStep(redo: a[0] == 1) }
            return [refused ? 1 : 0, UInt8(undoCopies.count), UInt8(undoBack)]
        case (16, 2):
            // UP_LIST: start, count, total, then per slot used, engine, name
            let st = Int(a[0]), n = min(Int(a[1]), 32 - st)
            return [a[0], UInt8(n), 32] + (st..<(st + n)).flatMap { k -> [UInt8] in
                guard let u = userSlots[k] else { return [0, 0, 0] }
                return [1, UInt8(u.engine)] + Array(u.name.utf8) + [0]
            }
        case (19, _) where a.count >= 2 && Int(a[0]) < 32:
            // UP_STORE: the selected track's sound, under the name (as Skiff, upper case)
            let name = String(decoding: a[1...].prefix { $0 != 0 }, as: UTF8.self).uppercased()
            userSlots[Int(a[0])] = (engines[selected].engine, name)
            return [a[0], 0]
        case (21, 1) where Int(a[0]) < 32:
            userSlots[Int(a[0])] = nil
            return [a[0], 0]
        case (9, 2) where a[0] == 0 && a[1] < 4:
            // PROJECT load: a used slot replaces the music, the transport stopped
            let k = Int(a[1]), used = projectSlots[k] != nil
            if used { setPlaying(false); musicSlot = k; projectLoads += 1; musicChanged = false }
            return [0, a[1], used ? 1 : 0]
        case (77, 0): return projectReply(0, 0)
        case (77, _) where a.count >= 2 && a[0] == 1 && a[1] < 4:
            setPlaying(false)
            projectSlots[Int(a[1])] = String(decoding: a[2...].prefix { $0 != 0 }, as: UTF8.self).uppercased()
            musicSlot = Int(a[1]); musicChanged = false
            return projectReply(1, 0)
        case (77, _) where a.count >= 2 && a[0] == 2 && a[1] < 4:
            // RENAME (EDITOR_PROTOCOL.md PROJ_NAME op 2): a used slot's name; "rc 1 refused: … RENAME of an empty slot"
            guard projectSlots[Int(a[1])] != nil else { return projectReply(2, 1) }
            projectSlots[Int(a[1])] = String(decoding: a[2...].prefix { $0 != 0 }, as: UTF8.self).uppercased()
            return projectReply(2, 0)
        case (78, 2) where a[0] == 1 || a[0] == 2:
            // CLEAR one nothing uses, or EMPTY one (its steps; it stays): stopped only
            let p = Int(a[1])
            // as skiff-sim: nothing there answers 1 before playing is refused
            guard p < 64, poolLen[p] > 0 else { return poolReply(a[0], 1) }
            if playing { return poolReply(a[0], 3) }
            if a[0] == 1 {
                guard uses(p) == 0 else { return poolReply(1, 2) }
                poolLen[p] = 0
            } else {
                emptiedPatterns.append(p)          // (pool_empty: its steps gone, the number, LEN and entries kept)
            }
            return poolReply(a[0], 0)
        case (20, 1): return [a[0], 1]
        case (8, 2):
            engines[selected] = (Int(a[0]), Int(a[1]))
            loadPresetValues(engine: Int(a[0]), preset: Int(a[1]))
            return [a[0], a[1]]
        case (80, 0): return performReply(0, 0)
        case (80, _): return performOp(a)
        case (82, 0): return listReply(0, 0)
        case (82, _): return listOp(a)
        case (78, 0): return poolReply(0, 0)
        case (78, 1) where a[0] == 3:
            if playing { return poolReply(3, 3) }
            var any = false
            for p in 0..<64 where poolLen[p] > 0 && uses(p) == 0 { poolLen[p] = 0; any = true }
            return poolReply(3, any ? 0 : 1)
        case (64, 2) where a[1] == 7:
            return motionReply(Int(a[0]), rc: 0, kinds: true)
        case (64, 6) where a[1] == 3 || a[1] == 5:
            // a recorded change (3) or a lock (5): a new record, or the one on that step and id becomes this
            let t = Int(a[0]), step = Int(a[2] & 63), id = Int(a[3]) | Int(a[2] >> 6 & 1) << 7
            let v = (Int(a[4]) | Int(a[5]) << 7) - 8192
            guard SkiffMotion.recordable(id, paramCount: pCount) else { return motionReply(t, rc: 1, kinds: a[1] == 5) }   // as motion_param
            let total = motion.reduce(0) { $0 + $1.count }
            if let k = motion[t].firstIndex(where: { $0.step == step && $0.id == id }) {
                motion[t][k] = (step, id, v, a[1] == 5)
            } else if total >= 64 {
                return motionReply(t, rc: 2, kinds: a[1] == 5)
            } else {
                motion[t].append((step, id, v, a[1] == 5))
            }
            return motionReply(t, rc: 0, kinds: a[1] == 5)
        case (64, 4) where a[1] == 4:
            let t = Int(a[0]), step = Int(a[2] & 63), id = Int(a[3]) | Int(a[2] >> 6 & 1) << 7
            motion[t].removeAll { $0.step == step && $0.id == id }
            return motionReply(t, rc: 0, kinds: false)
        case (64, 3) where a[1] == 6:
            let t = Int(a[0]), step = Int(a[2])
            motion[t].removeAll { $0.lock && (step >= 64 || $0.step == step) }
            return motionReply(t, rc: 0, kinds: true)
        case (64, 2) where a[1] == 2:
            motion[Int(a[0])] = []
            return [a[0], 0, 0, 0, 64]
        case (76, 0), (76, 1):
            if a.first == 1 { setPlaying(true) } else if a.first == 2 { setPlaying(false) }
            if a.first == 3 { setPlaying(false); setPlaying(true) }      // RESTART: from the top, playing on
            if a.first == 4 {
                // rec_tap: the selected track armed disarms them all; otherwise it's armed too (and a stopped
                // transport starts)
                let bit = 1 << selected
                armed = armed & bit != 0 ? 0 : armed | bit
                if armed & bit != 0, !playing { setPlaying(true) }
            }
            return [0, playing ? 1 : 0, 0, 0, UInt8(armed & 127), UInt8(selected)]
        default:
            unanswered.append((cmd, a))
            return nil                                       // as the device: no reply
        }
    }
}

/// FakeSkiff's FREE TAKE picker (ui_take.c `fr`), with the notes it was made from.
struct FakeTake {
    var open = false, end = 0, track = 0
    /// (before any take the firmware's `fr` is all zeros: pattern 0, as skiff-sim answers)
    var pattern: Int? = 0
    var guesses: [Int] = [], guess = 0, bars = 0, first = 0, firsts = 0
    var set = false, bpm0 = 120
    var from: [[UInt8]] = [], len0 = 16, div0 = 2
    var notes: [Int] = []
}

/// One entry of FakeSkiff's lists, as LIST2 sends it.
struct FakeEntry: Equatable {
    var p = 0, r = 0, s0 = 0, s1 = 0
}

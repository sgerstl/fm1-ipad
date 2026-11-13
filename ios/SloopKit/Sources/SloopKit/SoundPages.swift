// The FM-1's sound pages, as the firmware lays them out for the connected track: which page is which, its four
// knobs' parameters, and what the selected track's engine shows. Moved from ios/FM1/Sound.swift (2026-11-14) so the
// iPad and the Android phone share it; the iPad keeps the views and the tab mapping (extension SoundPage there).
import Foundation

public enum SoundFamily: String, CaseIterable, Identifiable, Sendable {
    case fx = "FX", sel = "SEL", env = "ENV", lfo = "LFO", edit = "EDIT", glo = "GLO", arp = "ARP", seq = "SEQ"
    public var id: String { rawValue }
}

/// One page of the FM-1 (firmware params.c PAGES): its title, button, and the parameter under each
/// knob (nil: an empty knob). scope 0 = the track's P_*, 1 = global G_*.
public struct SoundPage: Identifiable, Sendable {
    /// Its index in SLOOP's PAGES table (params.c): what the fm1-ipad firmware reports and opens.
    public let fw: Int
    public let title: String
    public let family: SoundFamily
    public let scope: Int
    public let ids: [Int?]
    public var drums = false            // the drum track has this page too (params.c page_for_drum)
    public var analogOnly = false       // EDIT > FILTER: ANALOG only (page_shown)
    public var engineEdit = 0           // 1 / 2: EDIT 1 / EDIT 2, titled by the engine (NAMES)
    public var routes: [[Int?]] = []    // Skiff's MOD: its eleven routes' parameters (PageSpec.routes)
    public var engines: [Int] = []      // Skiff's engine pages: only on these engines (PageSpec.engines)
    public var picks: [[Int?]] = []     // Skiff's LANES, LANE MIX: a lane's knobs 2–4 (PageSpec.picks)
    public var scopes: [Int] = []       // Skiff 2.5's FX › DELAY, REVERB: each knob's scope (PageSpec.scopes)
    public var knobLabels: [String?] = []   // … and KNOB 1's own name, SEND (PageSpec.knobLabels)
    public var settings: [Int] = []     // GLO › DELAY's MODE: settings that aren't knobs, in the page's scope (PageSpec.settings)
    public var id: String { "\(family.rawValue).\(title)" }

    public init(fw: Int, title: String, family: SoundFamily, scope: Int, ids: [Int?], drums: Bool = false, analogOnly: Bool = false,
                engineEdit: Int = 0, routes: [[Int?]] = [], engines: [Int] = [], picks: [[Int?]] = [], scopes: [Int] = [],
                knobLabels: [String?] = [], settings: [Int] = []) {
        self.fw = fw; self.title = title; self.family = family; self.scope = scope; self.ids = ids; self.drums = drums
        self.analogOnly = analogOnly; self.engineEdit = engineEdit; self.routes = routes; self.engines = engines
        self.picks = picks; self.scopes = scopes; self.knobLabels = knobLabels; self.settings = settings
    }

    /// Knob k's scope: 0 the track's, 1 shared by every track.
    public func scope(of k: Int) -> Int { k < scopes.count ? scopes[k] : scope }
    /// The key a knob's marks go by ("s1.4"), with its own scope.
    public func key(_ k: Int) -> String? { ids[safe: k].flatMap { $0 }.map { "s\(scope(of: k)).\($0)" } }
    /// Some knobs the track's, some every track's (FX › DELAY: the send, then the bus).
    public var mixed: Bool { Set(ids.indices.map(scope(of:))).count > 1 }

    public static let all: [SoundPage] = [
        SoundPage(fw: 5, title: "FX", family: .fx, scope: 0, ids: [33, 34, 35, 36]),
        SoundPage(fw: 6, title: "FILTER", family: .fx, scope: 0, ids: [50, nil, nil, nil], drums: true),
        SoundPage(fw: 7, title: "SLICER", family: .fx, scope: 0, ids: [45, 46, 47, 48], drums: true),
        SoundPage(fw: 8, title: "INSERT", family: .fx, scope: 0, ids: [53, 54, 55, 56], drums: true),
        SoundPage(fw: 9, title: "INSERT 2", family: .fx, scope: 0, ids: [57, nil, nil, nil], drums: true),
        SoundPage(fw: 10, title: "DLY", family: .fx, scope: 1, ids: [4, 5, 6, 7], drums: true),
        SoundPage(fw: 11, title: "REV/CHO", family: .fx, scope: 1, ids: [8, 9, 10, 11], drums: true),
        SoundPage(fw: 12, title: "SEL", family: .sel, scope: 0, ids: [25, 26, 27, 49]),
        SoundPage(fw: 13, title: "SEL 2", family: .sel, scope: 0, ids: [28, 51, 52, nil]),
        SoundPage(fw: 0, title: "ENV", family: .env, scope: 0, ids: [1, 2, 3, 4]),
        SoundPage(fw: 1, title: "ENV DEST", family: .env, scope: 0, ids: [5, 6, 7, 59]),
        SoundPage(fw: 2, title: "LFO", family: .lfo, scope: 0, ids: [9, 10, 11, 12]),
        SoundPage(fw: 3, title: "LFO 2", family: .lfo, scope: 0, ids: [60, 61, 62, nil]),
        SoundPage(fw: 4, title: "LFO DEST", family: .lfo, scope: 0, ids: [13, 14, 15, 16]),
        SoundPage(fw: 14, title: "EDIT 1", family: .edit, scope: 0, ids: [63, 64, 65, 66], engineEdit: 1),
        SoundPage(fw: 15, title: "EDIT 2", family: .edit, scope: 0, ids: [67, 68, 69, 70], engineEdit: 2),
        SoundPage(fw: 16, title: "FILTER", family: .edit, scope: 0, ids: [58, 67, 68, 70], analogOnly: true),
        SoundPage(fw: 17, title: "VOICE", family: .edit, scope: 0, ids: [37, 38, 41, 42]),
        SoundPage(fw: 18, title: "VOICE 2", family: .edit, scope: 0, ids: [43, 44, 39, 40]),
        SoundPage(fw: 19, title: "GLOBAL", family: .glo, scope: 1, ids: [0, 1, 2, 3], drums: true),
        SoundPage(fw: 20, title: "MASTER", family: .glo, scope: 1, ids: [27, 28, 29, 30], drums: true),
        SoundPage(fw: 22, title: "DRUMS", family: .glo, scope: 1, ids: [24, 25, 26, 32], drums: true),
        SoundPage(fw: 26, title: "TEXTURE", family: .glo, scope: 1, ids: [37, 38, 39, 40], drums: true),
        SoundPage(fw: 27, title: "TEXTURE 2", family: .glo, scope: 1, ids: [41, 42, 43, nil], drums: true),
        SoundPage(fw: 21, title: "SYSTEM", family: .glo, scope: 1, ids: [12, 13, 14, 15], drums: true),
        SoundPage(fw: 23, title: "MIDI", family: .glo, scope: 1, ids: [33, 34, 35, 24], drums: true),
        SoundPage(fw: 24, title: "MIDI 2", family: .glo, scope: 1, ids: [14, 36, 12, 44], drums: true),
        SoundPage(fw: 25, title: "MIDI 3", family: .glo, scope: 1, ids: [45, 46, 47, 48], drums: true),
        SoundPage(fw: 32, title: "ARP", family: .arp, scope: 0, ids: [17, 18, 19, 20]),
        SoundPage(fw: 33, title: "ARP 2", family: .arp, scope: 0, ids: [21, 22, 23, 24]),
        SoundPage(fw: 35, title: "PATTERN", family: .seq, scope: 0, ids: [29, 30, 31, 32], drums: true),
    ]

    /// The connected firmware's pages: its own layout where it gives one (Skiff, from DESC), else SLOOP's.
    @MainActor
    public static func pages(_ session: DeviceSession) -> [SoundPage] {
        guard let layout = session.pageLayout else { return all }
        var used = Set<Int>()
        return layout.enumerated().map { k, p in
            // Skiff's own PAGES index where one of its pages is this one (the screen link reports and opens
            // those); the rest past every table, never the screen link's
            var fw = 100 + k
            if session.dialect == .skiff, let d = skiffPagesByID["\(p.family).\(p.title)"] ?? skiffPages[p.title], !used.contains(d) { fw = d; used.insert(d) }
            return SoundPage(fw: fw, title: p.title, family: SoundFamily(rawValue: p.family) ?? .edit, scope: p.scope,
                             ids: p.ids, engineEdit: p.engineEdit, routes: p.routes, engines: p.engines, picks: p.picks,
                             scopes: p.scopes, knobLabels: p.knobLabels, settings: p.settings)
        }
    }

    /// Skiff 2.2's PAGES (fm1-ipad skiff/README.md) for the pages Lupe lays out: title → index. MOD's four
    /// PATTERN 2's knob is on PATTERN. The table belongs with the firmware version.
    public static let skiffPages: [String: Int] = [
        "ENV": 0, "ENV 2": 1, "LFO": 2, "LFO 2": 3, "MOD": 4, "FX": 5, "DRIVE": 6, "INSERT": 7, "INSERT 2": 8,
        "SLICER": 9, "DUCK": 10, "SCALE": 11, "CHORD": 12, "FOLLOW": 13, "EDIT 1": 14, "EDIT 2": 15,
        "OPERATOR": 16, "ALL OPS": 17, "LANES": 18, "SOUND": 19, "LANE MIX": 20, "SLICES": 21, "SAMPLES": 22,
        "VOICE": 28, "VOICE 2": 29, "DELAY": 31, "REVERB": 32, "CHORUS": 33, "GLOBAL": 34, "ARP": 39, "ARP 2": 40,
        "PATTERN": 43,
    ]

    /// Pages whose title another family's page shares: Skiff 2.5's FX › DELAY and FX › REVERB beside GLO's, at Lupe's
    /// numbers for them (SkiffPageMap; the driver gives the FM-1 its own).
    public static let skiffPagesByID: [String: Int] = ["FX.DELAY": SkiffPageMap.fxDelay, "FX.REVERB": SkiffPageMap.fxReverb]

    /// A button's pages as the FM-1's screen counts them ("FX 5/7"): on Skiff 2.5 INSERT 2 is Lupe's row only (its MIX
    /// is INSERT's PRESETS card there), so it isn't one of the FM-1's.
    @MainActor public static func counted(_ pages: [SoundPage], _ session: DeviceSession) -> [SoundPage] {
        guard session.skiffFirmware?.hasSendPages == true else { return pages }
        return pages.filter { !($0.family == .fx && $0.title == "INSERT 2") }
    }

    @MainActor
    public static func shown(_ session: DeviceSession, _ family: SoundFamily) -> [SoundPage] {
        let t = session.tracks[session.selectedTrack]
        return pages(session).filter { p in
            p.family == family && (!t.isDrums || p.drums) && (!p.analogOnly || (!t.isDrums && t.engine == 0))
                && (p.engines.isEmpty || p.engines.contains(t.engine)) && (p.title != "SAMPLES" || userSlot(session) != nil)
                && !(session.dialect == .skiff && skiffHides(p, engine: t.engine))
        }
    }

    /// Skiff's pages an engine leaves out (ui.c page_visible): the one-shot kits (DRUM, DRUM-X) have no SCL, ENV or
    /// VOICE pages; FM6, whose operators have their own envelopes, no ENV.
    public static func skiffHides(_ p: SoundPage, engine e: Int) -> Bool {
        let kit = [SkiffPages.Engine.drum, SkiffPages.Engine.drumX].contains(e)
        if kit, p.family == .sel || ["ENV", "ENV 2", "VOICE", "VOICE 2"].contains(p.title) { return true }
        return e == SkiffPages.Engine.fm6 && ["ENV", "ENV 2"].contains(p.title)
    }

    public static func page(fw: Int) -> SoundPage? { all.first { $0.fw == fw } }

    /// The user set a SAMPLE track plays (0…2 for USR1…USR3), found by the names of SAMPLE's SET (P_E0, the
    /// first engine parameter): nil on a built-in set or another engine.
    @MainActor public static func userSlot(_ session: DeviceSession) -> Int? {
        let t = session.tracks[session.selectedTrack]
        guard session.dialect == .skiff, t.engine == SkiffPages.Engine.sample,
              let e0 = pages(session).first(where: { $0.engineEdit == 1 })?.ids.first ?? nil,
              let d = session.trackDesc(e0), let usr1 = d.names.firstIndex(of: "USR1") else { return nil }
        let k = session.cell(e0).value - d.min - usr1
        return (0..<3).contains(k) ? k : nil
    }

    /// The page the FM-1's screen is on, in the connected firmware's terms. Skiff's engine pages (16–27:
    /// OPERATOR, LANES, SOUND…) are Lupe's own where it lays them out; any other stands for the EDIT button.
    @MainActor public static func page(_ session: DeviceSession, fw: Int) -> SoundPage? {
        if let p = pages(session).first(where: { $0.fw == fw }) { return p }
        if session.dialect == .skiff, (16...27).contains(fw) { return pages(session).first { $0.family == .edit } }
        return nil
    }

    /// The pages a button opens on the FM-1 for the selected track: its own, or on the drum track for a
    /// button without drum pages, the synth pages the FM-1 shows as "DRUM TRACK" (params.c page_for_drum).
    @MainActor public static func reached(_ session: DeviceSession, _ family: SoundFamily) -> [SoundPage] {
        let own = shown(session, family)
        guard own.isEmpty, session.selectedIsDrums else { return own }
        return pages(session).filter { $0.family == family && !$0.analogOnly && !$0.drums }
    }

    /// The page a parameter is on, the first one when it appears on several (as MIDI's channels do).
    @MainActor
    public static func page(_ session: DeviceSession, scope: Int, id: Int) -> SoundPage? {
        // (a send page holds the bus's globals too, but the GLO page is theirs: a knob turned there follows it)
        pages(session).first { p in
            !p.analogOnly && (p.ids.indices.contains { p.ids[$0] == id && p.scope(of: $0) == scope && !(p.mixed && p.scope(of: $0) != p.scope) }
                || (p.scope == scope && p.routes.joined().contains(id)))
        }
    }

    @MainActor
    public func title(_ session: DeviceSession) -> String {
        guard engineEdit > 0 else { return title }
        let e = session.tracks[session.selectedTrack].engine
        let t = session.editPageTitles[e] ?? []
        let name = engineEdit - 1 < t.count ? t[engineEdit - 1] : ""
        return name.isEmpty ? title : "\(title) · \(name)"
    }
}

// The pages' pictures (decision 30: pictures are back, as a setting). What each page's picture is drawn from, under its
// dials: the values of the knobs it shows (ENV's four, the LFO's, DRIVE's…), a scale's notes, FM6's patch as OPERATOR
// and ALL OPS draw it, DRUM-X's sound sheet. Trimmed in b672052 when the pictures were deleted (decision 25) and
// restored here as it was, beside `title`, `tiles` and `window`. Mix's bus cards (GLO's DELAY, REVERB, CHORUS, GLOBAL)
// get the same shape (P5Areas.swift). Mirrored by android/app/.../core/PageState.kt (P2's).
import Foundation
import SloopKit

extension PageArea {
    public enum Kind: String, Codable, Sendable {
        case none, env, lfo, drive, fx, scale, arp, analog, mod, tiles, card, fm6op, fm6all, sound
        /// Mix's bus cards: `values` are the card's knobs in the FM-1's order.
        case delay, reverb, chorus, global
        /// A track's FX pages, as the iPad draws them (ios/FM1/PageGraphs.swift). What their own four knobs don't
        /// hold comes with them: the delay bus's MIX, INSERT's MIX, DUCK's source hits.
        /// - fxdelay: `values` TIME, FEEDBACK, COLOR, the bus's MIX; `send` the track's send; `caption` the time.
        /// - fxreverb: `values` TYPE, SIZE, DAMP; `send`; `caption` the type's name.
        /// - insert: `values` TYPE, A, B, C, MIX; `caption` knob A as shown (FILTR's cutoff).
        /// - slicer: `values` SLICER, PATTERN, RATE, DEPTH.
        /// - duck: `values` DEPTH, RELEASE in thousandths of a bar; `notes` where in the bar the source hits, in
        ///   thousandths (empty: no source).
        case fxdelay, fxreverb, insert, slicer, duck
    }
    public struct Tile: Codable, Equatable, Sendable { public var label: String }

    /// FM6's patch as OPERATOR and ALL OPS draw it (FM6_GET: the track's own patch, read whole).
    public struct Fm6: Codable, Equatable, Sendable {
        public struct Op: Codable, Equatable, Sendable {
            public var output: Int
            /// RATIO as the FM-1 shows it ("2×", "0.5×", "100 Hz").
            public var ratio: String
            /// RATE 1…4 and LEVEL 1…4, 0…99.
            public var r: [Int]
            public var l: [Int]
        }
        /// 0…31 (ALGO 1…32 on the FM-1), and FEEDBACK 0…7.
        public var algorithm: Int
        public var feedback: Int
        /// The operator the FM-1's page is on, 1…6.
        public var picked: Int
        /// The FM-1's window (SCREEN's second cursor), if it reports one.
        public var lit: Int?
        public var ops: [Op]
        /// ALL OPS' other settings as one line each ("TRANSPOSE +0 st", "LFO SINE · RATE 35 · FADE 0").
        public var lines: [String]
    }

    /// DRUM-X's SOUND: the kit's sound and its windows as the FM-1 shows them (read-only on the phone).
    public struct Sheet: Codable, Equatable, Sendable {
        public struct Cell: Codable, Equatable, Sendable { public var label: String; public var value: String }
        public struct Row: Codable, Equatable, Sendable { public var title: String; public var cells: [Cell] }
        public var lane: Int
        public var lanes: [String]
        public var rows: [Row]
        public var lit: Int?
        public var note: String?
    }

    public struct Graph: Codable, Equatable, Sendable {
        public var kind: Kind = .none
        public var values: [Int] = []
        public var root = 0
        public var notes: [Int] = []
        public var caption: String?
        public var side: String?
        public var routes: [Route] = []
        public var tiles: [Tile] = []
        public var picked = 0
        public var title: String?
        public var fm6: Fm6?
        public var sheet: Sheet?
        /// fxdelay and fxreverb: the track's send to the bus (0…127).
        public var send = 127
    }

}

@MainActor extension PageContext {
    // MARK: dense pages (OPERATOR, ALL OPS, SOUND), from SkiffEditStore's reads

    /// The track's FM6 patch, as ios/FM1/FM6Pages.swift reads it. nil until it has been read.
    func fm6() -> PageArea.Fm6? {
        guard let p = session.skiffEdit?.patches[track] else { return nil }
        let e0 = SoundPage.pages(session).first { $0.engineEdit == 1 }?.ids.first ?? nil
        let macro = e0.map { session.cell($0).value } ?? 0
        let algorithm = (1...32).contains(macro) ? macro - 1 : p[.algorithm]
        let fbMacro = (e0.map { $0 + 1 }).map { session.cell($0).value } ?? 0
        let feedback = min(7, max(0, p[.feedback] + fbMacro))
        let ops = (1...6).map { n in
            PageArea.Fm6.Op(output: p.op(n, .output), ratio: Self.ratio(p, n),
                            r: [FM6Patch.Op.r1, .r2, .r3, .r4].map { p.op(n, $0) }, l: [FM6Patch.Op.l1, .l2, .l3, .l4].map { p.op(n, $0) })
        }
        let waves = ["TRI", "SAW DN", "SAW UP", "SQUARE", "SINE", "RANDOM"]
        let tr = p[.transpose] - 24
        let lines = ["TRANSPOSE \(tr > 0 ? "+" : "")\(tr) st",
                     "LFO \(waves[min(5, p[.lfoWave])]) · RATE \(p[.lfoSpeed]) · FADE \(p[.lfoDelay])",
                     "VIBRATO \(p[.pitchDepth]) · TREMOLO \(p[.ampDepth])"]
        return PageArea.Fm6(algorithm: algorithm, feedback: feedback, picked: min(max(cursor ?? 0, 0), 5) + 1, lit: litWindow,
                            ops: ops, lines: lines)
    }

    /// RATIO as the FM-1 shows it: ratio mode "0.5×", or the fixed mode's 1, 10, 100, 1K Hz.
    static func ratio(_ p: FM6Patch, _ n: Int) -> String {
        let fc = p.op(n, .coarse)
        if p.op(n, .mode) == 1 { return ["1", "10", "100", "1K"][fc & 3] + " Hz" }
        return fc == 0 ? "0.5×" : "\(fc)×"
    }

    /// The FM-1's window (SCREEN's second cursor) on this page.
    var litWindow: Int? {
        guard let s = session.deviceScreen, !s.home, s.page == page.fw else { return nil }
        return s.cursor2
    }

    /// DRUM-X's sound under the FM-1's lane cursor, in the windows ui_dx.c has (PITCH, DECAY NOISE, COLOR LEVEL, MODE).
    func soundSheet() -> PageArea.Sheet? {
        let l = lane
        guard let k = session.skiffEdit?.kit[l] else { return nil }
        func ab(_ i: Int) -> [PageArea.Sheet.Cell] {
            [PageArea.Sheet.Cell(label: "\(DXLane.names[i]) A", value: "\(k.a[i])"), PageArea.Sheet.Cell(label: "\(DXLane.names[i]) B", value: "\(k.b[i])")]
        }
        func name(_ v: Int, _ names: [String]) -> String { names[safe: v] ?? "\(v)" }
        let level = (page.picks[safe: l]?.first ?? nil).map { control(scope: 0, id: $0, label: "LEVEL").value } ?? "–"
        let rows = [
            PageArea.Sheet.Row(title: "PITCH", cells: ab(0) + ab(1)),
            PageArea.Sheet.Row(title: "DECAY NOISE", cells: ab(2) + ab(3)),
            PageArea.Sheet.Row(title: "COLOR LEVEL", cells: ab(4) + [.init(label: "LEVEL", value: level), .init(label: "DRIVE", value: name(k.drive, ["OFF", "ON"]))]),
            PageArea.Sheet.Row(title: "MODE", cells: [.init(label: "WAVE", value: name(k.wave, ["SIN", "FM", "MTL", "BEL"])),
                                                      .init(label: "FILTER", value: name(k.filter, ["LP", "BP", "HP"])),
                                                      .init(label: "SNAP", value: name(k.snap, ["OFF", "ON"])),
                                                      .init(label: "P SHAPE", value: name(k.pitchShape, ["DECAY", "LONG", "NOISE", "SINE"]))]),
        ]
        return PageArea.Sheet(lane: l, lanes: pageLaneShort, rows: rows, lit: litWindow,
                              note: "The kit is the project's: every DRUM-X track plays it, MORPH blending A into B.")
    }

    /// The page's own knob k: its raw value (0 for an empty knob) and its text.
    func raw4(_ k: Int) -> Int {
        guard let id = page.ids[safe: k] ?? nil else { return 0 }
        return page.scope(of: k) == 0 ? session.cell(id).value : session.globalCell(id).value
    }
    func shown4(_ k: Int) -> String? {
        guard let id = page.ids[safe: k] ?? nil else { return nil }
        return control(scope: page.scope(of: k), id: id).value
    }

    func graph() -> PageArea.Graph {
        var g = PageArea.Graph()
        switch page.title {
        case "ENV", "ENV 2":
            g.kind = .env; g.values = (0..<4).map { raw(page.title, $0) ?? 0 }
        case "LFO", "LFO 2":
            g.kind = .lfo; g.values = (0..<4).map { raw("LFO", $0) ?? 0 }; g.caption = shown("LFO", 0)
        case "MOD":
            guard isMod else { break }
            g.kind = .mod; g.picked = route
            g.routes = (0..<11).map { r in
                let ids = page.routes[r]
                if r < 7 {
                    let f = pageModFixed[r]
                    return PageArea.Route(group: f.group, label: f.label, amount: (ids.first.flatMap { $0 }).map { session.cell($0).value } ?? 0, empty: false)
                }
                // a matrix slot: its SOURCE and DEST names, AMOUNT as the bar; no source set is an empty slot
                let src = ids[safe: 0] ?? nil, dst = ids[safe: 1] ?? nil, amt = ids[safe: 2] ?? nil
                let srcV = src.map { session.cell($0).value } ?? 0
                let empty = srcV == 0
                let label = empty ? "\(r - 6) —" : "\(r - 6) \(src.map { control(scope: 0, id: $0).value } ?? "")"
                _ = dst
                return PageArea.Route(group: "SLOTS", label: label, amount: amt.map { session.cell($0).value } ?? 0, empty: empty)
            }
        case "FX":
            g.kind = .fx; g.values = (0..<4).map { raw("FX", $0) ?? 0 }
        case "DRIVE":
            g.kind = .drive; g.values = [raw("DRIVE", 0) ?? 0, raw("DRIVE", 1) ?? 0, raw("DRIVE", 2) ?? 0]
            g.caption = shown("DRIVE", 1); g.side = "drive \(raw("DRIVE", 0) ?? 0) · tone \(raw("DRIVE", 2) ?? 0)"
        case "SCALE":
            let root = raw("SCALE", 0) ?? 0, sc = raw("SCALE", 1) ?? 2
            g.kind = .scale; g.root = ((root % 12) + 12) % 12
            let scale = Music.scales[safe: sc]
            g.notes = scale?.intervals ?? []
            g.side = "\(Music.noteNames[g.root]) \(scale?.name.lowercased() ?? "") · ● root"
        case "ARP", "ARP 2":
            g.kind = .arp
            g.values = (0..<4).map { raw("ARP", $0) ?? 0 } + (0..<4).map { raw("ARP 2", $0) ?? 0 }
            g.side = [shown("ARP", 0), shown("ARP", 2).map { "\($0) oct" }, shown("ARP", 1), shown("ARP", 3).map { "gate \($0)" }]
                .compactMap { $0 }.joined(separator: " · ")
        case "EDIT 1", "EDIT 2":
            // ANALOG's OSC and filter pictures; the other engines' pictures aren't ported (the panel stays empty)
            guard !session.selectedIsDrums, session.tracks[track].engine == 0 else { break }
            g.kind = .analog
            g.values = (0..<4).map { raw("EDIT 1", $0) ?? 0 } + (0..<2).map { raw("EDIT 2", $0) ?? 0 }
            g.caption = "OSC · \(shown("EDIT 1", 0) ?? "")"; g.side = "FILTER · \(shown("EDIT 2", 0) ?? "")"
        case "LANES", "LANE MIX":
            guard isLanes else { break }
            g.kind = .tiles; g.tiles = pageLaneNames.map { PageArea.Tile(label: $0) }; g.picked = lane
        case "OPERATOR", "ALL OPS":
            g.kind = .card
            g.title = cursor.map { "\(page.title) · \($0 + 1)" } ?? page.title
            if let fm6 = fm6() { g.kind = page.title == "OPERATOR" ? .fm6op : .fm6all; g.fm6 = fm6 }
        case "SOUND":
            g.kind = .card
            g.title = cursor.map { "\(page.title) · \($0 + 1)" } ?? page.title
            if let sheet = soundSheet() { g.kind = .sound; g.sheet = sheet }
        case "DELAY" where page.family == .fx:
            // the send, then the bus's TIME FEEDBACK COLOR; the bus's MIX is GLO › DELAY's knob 4
            let glo = SoundPage.pages(session).first { $0.title == "DELAY" && $0.family != .fx && $0.scope == 1 }
            let mix = (glo?.ids[safe: 3] ?? nil).map { session.globalCell($0).value } ?? 127
            g.kind = .fxdelay; g.send = raw4(0); g.values = [raw4(1), raw4(2), raw4(3), mix]; g.caption = shown4(1)
        case "REVERB" where page.family == .fx:
            g.kind = .fxreverb; g.send = raw4(0); g.values = [raw4(1), raw4(2), raw4(3)]; g.caption = shown4(1)
        case "INSERT":
            // its MIX is INSERT 2's knob (the PRESETS encoder on 2.5.1)
            let mixID = SoundPage.pages(session).first { $0.title == "INSERT 2" }?.ids.first ?? nil
            g.kind = .insert; g.values = (0..<4).map(raw4) + [mixID.map { session.cell($0).value } ?? 127]; g.caption = shown4(1)
        case "SLICER":
            g.kind = .slicer; g.values = (0..<4).map(raw4)
        case "DUCK":
            // BY, DEPTH, RELEASE. The source's steps over a bar at its division (a kit ducks on its KICK lane only),
            // and RELEASE as a part of the bar at the tempo, as the iPad's DuckDrawing has them
            g.kind = .duck
            let src = raw4(0)
            var release = 0
            if src > 0, src - 1 < session.tracks.count, src - 1 != track {
                let st = session.tracks[src - 1]
                let ticks = CountedPlayhead.divisionTicks[safe: st.division] ?? 6, len = max(1, st.length)
                let nb = max(1, Int(96 / ticks)), kit = session.isKit(src - 1)
                g.notes = (0..<min(nb, 64)).filter { i in
                    let k = i % len
                    return k < st.steps.count && (kit ? st.gridSteps[k].has(0) : st.isOn(k))
                }.map { Int((Double($0) * ticks / 96 * 1000).rounded()) }
                let bar = 4 * 60 / Double(max(40, session.bpm))
                release = Int((SkiffLFO.fadeSeconds(max(1, raw4(2))) / bar * 1000).rounded())
            }
            g.values = [raw4(1), release]
        case "SLICES":
            g.kind = .card      // the markers can't be read or moved from here (no command reaches them): the card says so
            g.title = "SLICES"
        default: break
        }
        return g
    }
}

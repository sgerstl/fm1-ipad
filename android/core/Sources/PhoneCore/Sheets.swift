// The sheets (decision 25): FM6's OPERATOR and ALL OPS, DRUM-X's SOUND. Their four knobs are a window over a table
// (Skiff ui.c sheet_t), not track parameters: what the FM-1's knobs turn there is the window's row, which SELECT
// moves (the screen link's second cursor), of the operator or sound picked (its first cursor). Ported from Skiff
// 2.5.1's ui_fm6.c (FM_F, fm_val, fm_knob) and ui_dx.c (DX_WIN, dx_cards, dx_knob), checked against them card by
// card and value by value by PageParityTests (android/fixtures/skiff/skiff-2.5.1-pages.json). The values come from
// SkiffEditStore's reads: FM6_GET (the track's patch) and KIT_GET (the project's kit, one sound at a time); a knob
// set from the phone writes them back whole (FM6_PUT, KIT_PUT), as the iPad's sheets do.
import Foundation
import SloopKit

/// One card of a sheet: what it shows and what turning it writes.
struct SheetCard {
    enum Field {
        case op(FM6Patch.Op)          // the picked operator's
        case ratio, fine              // the operator's RATIO (one knob over both modes) and FINE
        case voice(FM6Patch.Voice)    // the patch's
        case algorithm, feedback      // what plays: EDIT 1's ALGO and FEEDBACK on the patch
        case dxA(Int), dxB(Int)       // a DRUM-X sound's value at A or B (PITCH, P MOD, DECAY, NOISE, COLOR)
        case dxLevel                  // its lane's level (a track parameter, as EDIT > LANES)
        case dxDrive, dxWave, dxFilter, dxSnap, dxShape
    }
    enum Text { case number, signed(Int), curve, note, pitch, lfoHz, wave, onOff, plus1, names([String]) }
    let label: String
    let field: Field
    let text: Text
    var unit: String = ""
}

enum Sheets {
    static let curves = ["-LIN", "-EXP", "+EXP", "+LIN"]                        // ui_fm6.c FM_CURVE
    static let fm6Waves = ["TRI", "SAW DN", "SAW UP", "SQUARE", "SINE", "RANDOM"] // FM_WAVE
    static let fixedRanges = ["1", "10", "100", "1K"]                            // FM_HZ
    static let dxWaves = ["SIN", "FM", "MTL", "BEL"], dxFilters = ["LP", "BP", "HP"], dxShapes = ["DECAY", "LONG", "NOISE", "SINE"]
    static let onOff = ["OFF", "ON"]
    static let soundNames = ["BD", "SD", "CP", "CH", "OH", "TM", "RS", "CB"]      // ui_dx.c DX_LANE_ABBR
    static let fm6WindowNames = [["TONE", "ENV 1", "ENV 2", "KEYS", "MORE"], ["ALGO", "PITCH 1", "PITCH 2", "LFO", "DEPTH"]]
    static let soundWindowNames = ["PITCH · P MOD", "DECAY · NOISE", "COLOR · LEVEL", "MODE"]

    /// ui_fm6.c FM_F: OPERATOR's five windows, then ALL OPS'.
    static let fm6: [[[SheetCard?]]] = [
        [[SheetCard(label: "OUTPUT", field: .op(.output), text: .number), SheetCard(label: "RATIO", field: .ratio, text: .number),
          SheetCard(label: "FINE", field: .fine, text: .number), SheetCard(label: "DETUNE", field: .op(.detune), text: .signed(7))],
         [SheetCard(label: "RATE 1", field: .op(.r1), text: .number), SheetCard(label: "LEVEL 1", field: .op(.l1), text: .number),
          SheetCard(label: "RATE 2", field: .op(.r2), text: .number), SheetCard(label: "LEVEL 2", field: .op(.l2), text: .number)],
         [SheetCard(label: "RATE 3", field: .op(.r3), text: .number), SheetCard(label: "LEVEL 3", field: .op(.l3), text: .number),
          SheetCard(label: "RATE 4", field: .op(.r4), text: .number), SheetCard(label: "LEVEL 4", field: .op(.l4), text: .number)],
         [SheetCard(label: "L CURVE", field: .op(.leftCurve), text: .curve), SheetCard(label: "L DEPTH", field: .op(.leftDepth), text: .number),
          SheetCard(label: "R DEPTH", field: .op(.rightDepth), text: .number), SheetCard(label: "R CURVE", field: .op(.rightCurve), text: .curve)],
         [SheetCard(label: "BREAK", field: .op(.breakPoint), text: .note), SheetCard(label: "KEY RATE", field: .op(.rateScale), text: .number),
          SheetCard(label: "VELOCITY", field: .op(.velocity), text: .number), SheetCard(label: "LFO AMP", field: .op(.ampMod), text: .number)]],
        [[SheetCard(label: "ALGO", field: .algorithm, text: .plus1), SheetCard(label: "FEEDBACK", field: .feedback, text: .number),
          SheetCard(label: "TRANSP", field: .voice(.transpose), text: .signed(24), unit: "ST"), nil],
         [SheetCard(label: "RATE 1", field: .voice(.pr1), text: .number), SheetCard(label: "PITCH 1", field: .voice(.pl1), text: .pitch, unit: "ST"),
          SheetCard(label: "RATE 2", field: .voice(.pr2), text: .number), SheetCard(label: "PITCH 2", field: .voice(.pl2), text: .pitch, unit: "ST")],
         [SheetCard(label: "RATE 3", field: .voice(.pr3), text: .number), SheetCard(label: "PITCH 3", field: .voice(.pl3), text: .pitch, unit: "ST"),
          SheetCard(label: "RATE 4", field: .voice(.pr4), text: .number), SheetCard(label: "PITCH 4", field: .voice(.pl4), text: .pitch, unit: "ST")],
         [SheetCard(label: "WAVE", field: .voice(.lfoWave), text: .wave), SheetCard(label: "RATE", field: .voice(.lfoSpeed), text: .lfoHz, unit: "HZ"),
          SheetCard(label: "FADE", field: .voice(.lfoDelay), text: .number), SheetCard(label: "KEY SYNC", field: .voice(.lfoKeySync), text: .onOff)],
         [SheetCard(label: "VIBRATO", field: .voice(.pitchDepth), text: .number), SheetCard(label: "VIB SENS", field: .voice(.pitchSens), text: .number),
          SheetCard(label: "TREMOLO", field: .voice(.ampDepth), text: .number), nil]],
    ]

    /// ui_dx.c DX_WIN: SOUND's four windows.
    static let sound: [[SheetCard]] = {
        func ab(_ i: Int) -> [SheetCard] {
            [SheetCard(label: "\(DXLane.names[i]) A", field: .dxA(i), text: .number), SheetCard(label: "\(DXLane.names[i]) B", field: .dxB(i), text: .number)]
        }
        return [ab(0) + ab(1), ab(2) + ab(3),
                ab(4) + [SheetCard(label: "LEVEL", field: .dxLevel, text: .number), SheetCard(label: "DRIVE", field: .dxDrive, text: .onOff)],
                [SheetCard(label: "WAVE", field: .dxWave, text: .names(dxWaves)), SheetCard(label: "FILTER", field: .dxFilter, text: .names(dxFilters)),
                 SheetCard(label: "SNAP", field: .dxSnap, text: .onOff), SheetCard(label: "P SHAPE", field: .dxShape, text: .names(dxShapes))]]
    }()

    // MARK: Skiff's number text (ui_fm6.c fm_signed, fm_tenths, fm_hundredths; note_name)

    static func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }
    static func tenths(_ v: Int, sign: Bool) -> String {
        let a = abs(v)
        return (v < 0 ? "-" : sign && v > 0 ? "+" : "") + "\(a / 10).\(a % 10)"
    }
    static func hundredths(_ v: Int) -> String { "\(v / 100).\(v / 10 % 10)\(v % 10)" }
    static func noteName(_ n: Int) -> String { ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][n % 12] + "\(n / 12 - 1)" }

    /// RATIO's knob position: x0.5, x1 … x31 (coarse 0…31), then 1, 10, 100, 1K HZ (fixed, coarse 0…3).
    static func ratioPos(_ p: FM6Patch, _ n: Int) -> Int { p.op(n, .mode) == 1 ? 32 + (p.op(n, .coarse) & 3) : p.op(n, .coarse) }
}

extension PageContext {
    var isSheet: Bool { ["OPERATOR", "ALL OPS", "SOUND"].contains(page.title) }
    /// The window the FM-1's knobs are on (the screen link's second cursor), 0 until it says.
    var window: Int {
        guard let s = session.deviceScreen, !s.home, s.page == page.fw, let w = s.cursor2, w != 127 else { return 0 }
        return w
    }
    var windowCount: Int { page.title == "SOUND" ? Sheets.sound.count : 5 }
    /// OPERATOR's operator, 1…6 (its first cursor).
    var operatorPicked: Int { min(max(cursor ?? 0, 0), 5) + 1 }

    func sheetCards() -> [SheetCard?] {
        let w = min(max(window, 0), windowCount - 1)
        switch page.title {
        case "OPERATOR": return Sheets.fm6[0][w]
        case "ALL OPS": return Sheets.fm6[1][w]
        default: return Sheets.sound[w]
        }
    }

    /// The sheet's header, as the FM-1's: "OPERATOR 3", "ALL OPS", "SOUND SD".
    var sheetTitle: String {
        switch page.title {
        case "OPERATOR": return "OPERATOR \(operatorPicked)"
        case "SOUND": return "SOUND \(Sheets.soundNames[lane])"
        default: return page.title
        }
    }

    /// EDIT 1's ALGO and FEEDBACK (the engine's first two): what plays is the patch's unless they say otherwise.
    var engineFirst: Int? { SoundPage.pages(session).first { $0.engineEdit == 1 }?.ids.first ?? nil }

    /// The four controls the FM-1's knobs turn on the sheet now; empty wells until its patch or sound has been read.
    func sheetControls() -> [PageArea.Control?] {
        sheetCards().map { card in card.flatMap { sheetControl($0) } }
    }

    func sheetControl(_ c: SheetCard) -> PageArea.Control? {
        guard let (raw, max) = sheetValue(c.field) else { return nil }
        let (text, unit) = sheetText(c, raw)
        let shown = unit.isEmpty ? text : unit == "x" || unit == "%" ? "\(text)\(unit)" : "\(text) \(unit)"
        let names: [String]? = switch c.text {
        case .curve: Sheets.curves
        case .wave: Sheets.fm6Waves
        case .onOff: Sheets.onOff
        case .names(let n): n
        default: nil
        }
        return PageArea.Control(label: c.label, value: shown, raw: raw, min: 0, max: max, list: names != nil, ringless: false,
                                fixed: false, locked: false, names: names)
    }

    /// A card's raw value and its top (0 the bottom), from the store's reads.
    func sheetValue(_ f: SheetCard.Field) -> (Int, Int)? {
        let n = operatorPicked
        switch f {
        case .op, .ratio, .fine, .voice, .algorithm, .feedback:
            guard let p = session.skiffEdit?.patches[track] else { return nil }
            switch f {
            case .op(let o): return (p.op(n, o), o.max)
            case .ratio: return (Sheets.ratioPos(p, n), 35)
            case .fine: return (p.op(n, .fine), 99)
            case .voice(let v): return (p[v], v.max)
            case .algorithm:
                let macro = engineFirst.map { session.cell($0).value } ?? 0
                return ((1...32).contains(macro) ? macro - 1 : p[.algorithm], 31)
            case .feedback:
                let macro = engineFirst.map { session.cell($0 + 1).value } ?? 0
                return (min(7, max(0, p[.feedback] + macro)), 7)
            default: return nil
            }
        case .dxLevel:
            guard let id = page.picks[safe: lane]?.first ?? nil else { return nil }
            return (session.cell(id).value, 127)
        default:
            guard let k = session.skiffEdit?.kit[lane] else { return nil }
            switch f {
            case .dxA(let i): return (k.a[i], 127)
            case .dxB(let i): return (k.b[i], 127)
            case .dxDrive: return (k.drive, 1)
            case .dxWave: return (k.wave, 3)
            case .dxFilter: return (k.filter, 2)
            case .dxSnap: return (k.snap, 1)
            case .dxShape: return (k.pitchShape, 3)
            default: return nil
            }
        }
    }

    /// fm_val's and dx_cards' text for a card at `raw` (RATIO and FINE read the operator's other fields too).
    func sheetText(_ c: SheetCard, _ raw: Int) -> (String, String) {
        switch c.field {
        case .ratio:
            if raw >= 32 { return (Sheets.fixedRanges[(raw - 32) & 3], "HZ") }
            return (raw == 0 ? "0.5" : "\(raw)", "x")
        case .fine:
            guard let p = session.skiffEdit?.patches[track] else { return ("\(raw)", "") }
            return Self.fineText(mode: p.op(operatorPicked, .mode), coarse: p.op(operatorPicked, .coarse), fine: raw)
        case .dxLevel:
            guard let id = page.picks[safe: lane]?.first ?? nil else { return ("\(raw)", "") }
            let f = formatValue(session.trackDesc(id), raw, skiff: true).shown
            return f.hasSuffix("%") ? (String(f.dropLast()), "%") : (f, "")
        default: break
        }
        switch c.text {
        case .number: return ("\(raw)", c.unit)
        case .signed(let off): return (Sheets.signed(raw - off), c.unit)
        case .plus1: return ("\(raw + 1)", c.unit)
        case .curve: return (Sheets.curves[raw & 3], "")
        case .note: return (Sheets.noteName(raw + 21), "")
        case .pitch: return (Sheets.tenths(SkiffSheetTables.pitchTenths[raw % 100], sign: true), c.unit)
        case .lfoHz: return (Sheets.tenths(SkiffSheetTables.lfoHz10[raw % 100], sign: false), c.unit)
        case .wave: return (Sheets.fm6Waves[raw % 6], "")
        case .onOff: return (raw != 0 ? "ON" : "OFF", "")
        case .names(let n): return (n[safe: raw] ?? "\(raw)", "")
        }
    }

    /// FINE: the ratio the operator plays, or a fixed operator's frequency (ui_fm6.c fm_val FMF_FINE).
    static func fineText(mode: Int, coarse: Int, fine: Int) -> (String, String) {
        if mode == 1 {
            let h = SkiffSheetTables.fixedHz100[(coarse & 3) * 100 + fine % 100]
            return (h < 1000 ? Sheets.hundredths(h) : h < 10000 ? Sheets.tenths(h / 10, sign: false) : "\(h / 100)", "HZ")
        }
        return (Sheets.hundredths(coarse != 0 ? coarse * (100 + fine) : (100 + fine) / 2), "")
    }
}

extension PhoneCore {
    /// One read of the sheet showing, if one is (the track's patch, or the sound under the FM-1's cursor).
    func pollSheet() async {
        let s = session
        guard s.isConnected, s.dialect == .skiff, s.screenLinked, let screen = s.deviceScreen, let fw = Self.soundPage(of: screen),
              let page = SoundPage.page(s, fw: fw), let store = s.skiffEdit else { return }
        switch page.title {
        case "OPERATOR", "ALL OPS": await store.readPatch(track: s.selectedTrack)
        case "SOUND": await store.readKit(lane: min(max(screen.cursor ?? 0, 0), 7))
        default: break
        }
    }

    /// setParam on a sheet: the card's field set as the FM-1's knob sets it (fm_knob, dx_knob), written whole.
    func setSheet(_ ctx: PageContext, slot: Int, value: Int) {
        guard let card = ctx.sheetCards()[safe: slot] ?? nil, let store = session.skiffEdit else { log("setParam: no knob \(slot + 1) on this window"); return }
        let t = ctx.track, n = ctx.operatorPicked, lane = ctx.lane
        switch card.field {
        case .op(let o): store.editPatch(track: t) { $0.setOp(n, o, value) }
        case .ratio:
            let x = min(max(value, 0), 35)
            store.editPatch(track: t) { $0.setOp(n, .mode, x >= 32 ? 1 : 0); $0.setOp(n, .coarse, x >= 32 ? x - 32 : x) }
        case .fine: store.editPatch(track: t) { $0.setOp(n, .fine, value) }
        case .voice(let v): store.editPatch(track: t) { $0[v] = value }
        case .algorithm:
            // what plays, into the patch; EDIT 1's ALGO to PAT (fm_knob FMF_ALG)
            store.editPatch(track: t) { $0[.algorithm] = value }
            if let e0 = ctx.engineFirst { session.set(track: t, param: e0, to: 0) }
        case .feedback:
            store.editPatch(track: t) { $0[.feedback] = value }
            if let e0 = ctx.engineFirst { session.set(track: t, param: e0 + 1, to: 0) }
        case .dxLevel:
            if let id = ctx.page.picks[safe: lane]?.first ?? nil { session.set(track: t, param: id, to: value) }
        case .dxA(let i): store.editKit(lane: lane) { $0.a[i] = min(max(value, 0), 127) }
        case .dxB(let i): store.editKit(lane: lane) { $0.b[i] = min(max(value, 0), 127) }
        case .dxDrive: store.editKit(lane: lane) { $0.drive = min(max(value, 0), 1) }
        case .dxWave: store.editKit(lane: lane) { $0.wave = min(max(value, 0), 3) }
        case .dxFilter: store.editKit(lane: lane) { $0.filter = min(max(value, 0), 2) }
        case .dxSnap: store.editKit(lane: lane) { $0.snap = min(max(value, 0), 1) }
        case .dxShape: store.editKit(lane: lane) { $0.pitchShape = min(max(value, 0), 3) }
        }
        publishNow(["page"])
    }
}

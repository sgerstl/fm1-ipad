import SloopKit
import SwiftUI

// FM6's OPERATOR and ALL OPS (ui_fm6.c): the track's own patch, read and written whole (FM6_GET, FM6_PUT). Each sheet's
// five windows are rows here; the FM-1's window (SCREEN's second cursor) is lit. The operator is picked on tiles (on the
// FM-1, PRESETS turns it) and shared by both sheets, and with the screen link's cursor it's the FM-1's.

enum FM6 {
    /// The 32 algorithms (fm6_core.c FM6_ALG, ui_graph.c FM6_CELL): the carriers, who modulates whom (a, b: a into b),
    /// the operator with feedback, and each operator's place in the chart (column, row; row 0 the carriers).
    struct Algorithm { let carriers: Set<Int>; let routes: [(Int, Int)]; let feedback: Int; let cells: [Int: (col: Int, row: Int)] }

    static let algorithms: [Algorithm] = {
        // carriers | routes | feedback | cells (op:col,row from 1 to 6)
        let rows = [
            "1,3|2>1 4>3 5>4 6>5|6|0,0 0,1 1,0 1,1 1,2 1,3", "1,3|2>1 4>3 5>4 6>5|2|0,0 0,1 2,0 2,1 2,2 2,3",
            "1,4|2>1 3>2 5>4 6>5|6|0,0 0,1 0,2 1,0 1,1 1,2", "1,4|2>1 3>2 5>4 6>5|6|0,0 0,1 0,2 1,0 1,1 1,2",
            "1,3,5|2>1 4>3 6>5|6|0,0 0,1 1,0 1,1 2,0 2,1", "1,3,5|2>1 4>3 6>5|6|0,0 0,1 1,0 1,1 2,0 2,1",
            "1,3|2>1 4>3 5>3 6>5|6|0,0 0,1 1,0 1,1 2,1 2,2", "1,3|2>1 4>3 5>3 6>5|4|0,0 0,1 1,0 2,1 1,1 1,2",
            "1,3|2>1 4>3 5>3 6>5|2|0,0 0,1 2,0 2,1 3,1 3,2", "1,4|2>1 3>2 5>4 6>4|3|0,0 0,1 0,2 1,0 1,1 2,1",
            "1,4|2>1 3>2 5>4 6>4|6|0,0 0,1 0,2 1,0 1,1 2,1", "1,3|2>1 4>3 5>3 6>3|2|0,0 0,1 3,0 2,1 3,1 4,1",
            "1,3|2>1 4>3 5>3 6>3|6|0,0 0,1 2,0 1,1 2,1 3,1", "1,3|2>1 4>3 5>4 6>4|6|0,0 0,1 1,0 1,1 0,2 1,2",
            "1,3|2>1 4>3 5>4 6>4|2|0,0 0,1 2,0 2,1 1,2 2,2", "1|2>1 3>1 5>1 4>3 6>5|6|1,0 0,1 1,1 1,2 2,1 2,2",
            "1|2>1 3>1 5>1 4>3 6>5|2|1,0 2,1 0,1 0,2 1,1 1,2", "1|2>1 3>1 4>1 5>4 6>5|3|1,0 0,1 2,1 1,1 1,2 1,3",
            "1,4,5|2>1 3>2 6>4 6>5|6|0,0 0,1 0,2 1,0 2,0 1,1", "1,2,4|3>1 3>2 5>4 6>4|3|0,0 1,0 0,1 2,0 2,1 3,1",
            "1,2,4,5|3>1 3>2 6>4 6>5|3|0,0 1,0 0,1 2,0 3,0 2,1", "1,3,4,5|2>1 6>3 6>4 6>5|6|0,0 0,1 1,0 2,0 3,0 2,1",
            "1,2,4,5|3>2 6>4 6>5|6|0,0 1,0 1,1 2,0 3,0 2,1", "1,2,3,4,5|6>3 6>4 6>5|6|0,0 1,0 2,0 3,0 4,0 3,1",
            "1,2,3,4,5|6>4 6>5|6|0,0 1,0 2,0 3,0 4,0 3,1", "1,2,4|3>2 5>4 6>4|6|0,0 1,0 1,1 2,0 2,1 3,1",
            "1,2,4|3>2 5>4 6>4|3|0,0 1,0 1,1 3,0 3,1 4,1", "1,3,6|2>1 4>3 5>4|5|0,0 0,1 1,0 1,1 1,2 2,0",
            "1,2,3,5|4>3 6>5|6|0,0 1,0 2,0 2,1 3,0 3,1", "1,2,3,6|4>3 5>4|5|0,0 1,0 2,0 2,1 2,2 3,0",
            "1,2,3,4,5|6>5|6|0,0 1,0 2,0 3,0 4,0 4,1", "1,2,3,4,5,6||6|0,0 1,0 2,0 3,0 4,0 5,0",
        ]
        return rows.map { r in
            let f = r.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let routes = f[1].split(separator: " ").map { p -> (Int, Int) in
                let ab = p.split(separator: ">").compactMap { Int($0) }
                return (ab[0], ab[1])
            }
            var cells: [Int: (Int, Int)] = [:]
            for (k, c) in f[3].split(separator: " ").enumerated() {
                let cr = c.split(separator: ",").compactMap { Int($0) }
                cells[k + 1] = (cr[0], cr[1])
            }
            return Algorithm(carriers: Set(f[0].split(separator: ",").compactMap { Int($0) }), routes: routes,
                             feedback: Int(f[2]) ?? 6, cells: cells)
        }
    }()

    /// msfa's pitch envelope levels (fm6_core.c FM6_PENV_TAB): a step is 3/8 of a semitone.
    static let pitchTab: [Int] = [
        -128, -116, -104, -95, -85, -76, -68, -61, -56, -52, -49, -46, -43, -41, -39, -37, -35, -33, -32, -31, -30, -29,
        -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6,
        -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
        26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 38, 40, 43, 46, 49, 53, 58, 65, 73, 82, 92, 103, 115, 127]
    /// msfa's LFO rates 0…99 in Hz (Skiff tools/gen_tables.py FM6_LFO_SOURCE).
    static let lfoHz: [Double] = [
        0.062541, 0.125031, 0.312393, 0.437120, 0.624610, 0.750694, 0.936330, 1.125302, 1.249609, 1.436782,
        1.560915, 1.752081, 1.875117, 2.062494, 2.247191, 2.374451, 2.560492, 2.686728, 2.873976, 2.998950,
        3.188013, 3.369840, 3.500175, 3.682224, 3.812065, 4.000800, 4.186202, 4.310716, 4.501260, 4.623209,
        4.814636, 4.930480, 5.121901, 5.315191, 5.434783, 5.617346, 5.750431, 5.946717, 6.062811, 6.248438,
        6.431695, 6.564264, 6.749460, 6.868132, 7.052186, 7.250580, 7.375719, 7.556294, 7.687577, 7.877738,
        7.993605, 8.181967, 8.372405, 8.504848, 8.685079, 8.810573, 8.986341, 9.122423, 9.300595, 9.500285,
        9.607994, 9.798158, 9.950249, 10.117361, 11.251125, 11.384335, 12.562814, 13.676149, 13.904338, 15.092062,
        16.366612, 16.638935, 17.869907, 19.193858, 19.425019, 20.833333, 21.034918, 22.502250, 24.003841, 24.260068,
        25.746653, 27.173913, 27.578599, 29.052876, 30.693677, 31.191516, 32.658393, 34.317090, 34.674064, 36.416606,
        38.197097, 38.550501, 40.387722, 40.749796, 42.625746, 44.326241, 44.883303, 46.772685, 48.590865, 49.261084]

    static func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }
    static func tenths(_ t: Int) -> String { "\(t < 0 ? "-" : t > 0 ? "+" : "")\(abs(t) / 10).\(abs(t) % 10)" }
    /// RATIO as the FM-1 shows it: ratio mode "0.5" or the coarse, fixed mode 1, 10, 100, 1K Hz.
    static func ratio(_ p: FM6Patch, _ n: Int) -> String {
        let fc = p.op(n, .coarse)
        if p.op(n, .mode) == 1 { return ["1", "10", "100", "1K"][fc & 3] + " Hz" }
        return fc == 0 ? "0.5×" : "\(fc)×"
    }
    static func fine(_ p: FM6Patch, _ n: Int) -> String {
        let fc = p.op(n, .coarse), ff = p.op(n, .fine)
        if p.op(n, .mode) == 1 {
            let hz = pow(10, Double(fc & 3) + Double(ff) / 100)
            return hz < 10 ? String(format: "%.2f Hz", hz) : hz < 100 ? String(format: "%.1f Hz", hz) : "\(Int(hz)) Hz"
        }
        let h = fc > 0 ? fc * (100 + ff) : (100 + ff) / 2
        return "\(h / 100).\(String(format: "%02d", h % 100))"
    }
}

/// The operator tiles: OP1…OP6, each one's ratio under it; a silent one (OUTPUT 0) dim.
private struct OperatorTiles: View {
    let patch: FM6Patch?
    let op: Int
    let pick: (Int) -> Void

    var body: some View {
        PickTiles(titles: (1...6).map { "OP\($0)" }, details: (1...6).map { n in patch.map { FM6.ratio($0, n) } ?? "" },
                  dim: Set((1...6).filter { patch?.op($0, .output) == 0 }.map { $0 - 1 }), picked: op - 1, label: "Operator") { pick($0 + 1) }
    }
}

struct FM6OperatorPage: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    @Binding var op0: Int
    let activate: () -> Bool

    var body: some View {
        let t = session.selectedTrack, tint = Theme.track[t]
        let p = session.skiffEdit?.patches[t]
        let n = min(max(op0, 0), 5) + 1
        VStack(alignment: .leading, spacing: 10) {
            OperatorTiles(patch: p, op: n) { op0 = $0 - 1; _ = activate() }
            if let p {
                SheetRows(ui: ui, rows: rows(t, n), lit: lit, tint: tint, activate: activate)
                FM6EnvelopeGraph(patch: p, op: n, algorithm: FM6.algorithms[algorithm(p)], tint: tint)
                    .frame(height: 128).recessed(8)
            } else {
                Text("Reading the patch…").font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(minHeight: 44)
            }
        }
        .task(id: t) { await session.skiffEdit?.readPatch(track: t) }
        .onChange(of: session.deviceScreen) { a, b in if SkiffEdit.concerns(page, a, b) { Task { await session.skiffEdit?.readPatch(track: t) } } }
    }

    private var lit: Int? {
        guard let s = session.deviceScreen, !s.home, s.page == page.fw else { return nil }
        return s.cursor2
    }
    private func algorithm(_ p: FM6Patch) -> Int { FM6Sheet.shownAlgorithm(session, p) }

    private func rows(_ t: Int, _ n: Int) -> [(title: String, knobs: [(() -> KnobSpec)?])] {
        let s = FM6Sheet(session: session, track: t)
        return [("TONE", [s.op(n, .output, "OUTPUT", 0), s.ratioKnob(n), s.op(n, .fine, "FINE", 2) { FM6.fine($0, n) },
                          s.op(n, .detune, "DETUNE", 3) { FM6.signed($0.op(n, .detune) - 7) }]),
                ("ENV 1", [s.op(n, .r1, "RATE 1", 0), s.op(n, .l1, "LEVEL 1", 1), s.op(n, .r2, "RATE 2", 2), s.op(n, .l2, "LEVEL 2", 3)]),
                ("ENV 2", [s.op(n, .r3, "RATE 3", 0), s.op(n, .l3, "LEVEL 3", 1), s.op(n, .r4, "RATE 4", 2), s.op(n, .l4, "LEVEL 4", 3)]),
                ("KEYS", [s.op(n, .leftCurve, "L CURVE", 0, choices: FM6Sheet.curves), s.op(n, .leftDepth, "L DEPTH", 1),
                          s.op(n, .rightDepth, "R DEPTH", 2), s.op(n, .rightCurve, "R CURVE", 3, choices: FM6Sheet.curves)]),
                ("MORE", [s.op(n, .breakPoint, "BREAK", 0) { Music.noteName($0.op(n, .breakPoint) + 21) }, s.op(n, .rateScale, "KEY RATE", 1),
                          s.op(n, .velocity, "VELOCITY", 2), s.op(n, .ampMod, "LFO AMP", 3)])]
    }
}

struct FM6AllOpsPage: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    let op0: Int
    let activate: () -> Bool

    var body: some View {
        let t = session.selectedTrack, tint = Theme.track[t]
        let p = session.skiffEdit?.patches[t]
        VStack(alignment: .leading, spacing: 10) {
            if let p {
                let s = FM6Sheet(session: session, track: t)
                SheetRows(ui: ui, rows: [
                    ("ALGO", [s.algorithmKnob(), s.feedbackKnob(), s.voice(.transpose, "TRANSP", 2) { "\(FM6.signed($0[.transpose] - 24)) st" }, nil]),
                    ("PITCH 1", [s.voice(.pr1, "RATE 1", 0), s.pitch(.pl1, "PITCH 1", 1), s.voice(.pr2, "RATE 2", 2), s.pitch(.pl2, "PITCH 2", 3)]),
                    ("PITCH 2", [s.voice(.pr3, "RATE 3", 0), s.pitch(.pl3, "PITCH 3", 1), s.voice(.pr4, "RATE 4", 2), s.pitch(.pl4, "PITCH 4", 3)]),
                    ("LFO", [s.voice(.lfoWave, "WAVE", 0, choices: ["TRI", "SAW DN", "SAW UP", "SQUARE", "SINE", "RANDOM"]),
                             s.voice(.lfoSpeed, "RATE", 1) { String(format: "%.1f Hz", FM6.lfoHz[min(99, $0[.lfoSpeed])]) },
                             s.voice(.lfoDelay, "FADE", 2), s.voice(.lfoKeySync, "KEY SYNC", 3, choices: ["OFF", "ON"])]),
                    ("DEPTH", [s.voice(.pitchDepth, "VIBRATO", 0), s.voice(.pitchSens, "VIB SENS", 1), s.voice(.ampDepth, "TREMOLO", 2), nil]),
                ], lit: lit, tint: tint, activate: activate)
                FM6AlgorithmChart(patch: p, algorithm: FM6Sheet.shownAlgorithm(session, p), picked: min(max(op0, 0), 5) + 1,
                                  feedback: FM6Sheet.shownFeedback(session, p), tint: tint)
                    .frame(height: 168).recessed(8)
            } else {
                Text("Reading the patch…").font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(minHeight: 44)
            }
        }
        .task(id: t) { await session.skiffEdit?.readPatch(track: t) }
        .onChange(of: session.deviceScreen) { a, b in if SkiffEdit.concerns(page, a, b) { Task { await session.skiffEdit?.readPatch(track: t) } } }
    }

    private var lit: Int? {
        guard let s = session.deviceScreen, !s.home, s.page == page.fw else { return nil }
        return s.cursor2
    }
}

/// The knobs over a track's patch (ui_fm6.c fm_val, fm_knob): each a read-modify-write of the whole patch.
@MainActor struct FM6Sheet {
    let session: DeviceSession
    let track: Int
    static let curves = ["-LIN", "-EXP", "+EXP", "+LIN"]

    private var e0: Int? { SoundPage.pages(session).first { $0.engineEdit == 1 }?.ids.first ?? nil }

    /// ALGO shows what plays: the track's ALGO macro (P_E0) when it's set, else the patch's.
    @MainActor static func shownAlgorithm(_ s: DeviceSession, _ p: FM6Patch) -> Int {
        let e0 = SoundPage.pages(s).first { $0.engineEdit == 1 }?.ids.first ?? nil
        let m = e0.map { s.cell($0).value } ?? 0
        return (1...32).contains(m) ? m - 1 : p[.algorithm]
    }
    /// FEEDBACK shows the patch's plus the FEEDBACK macro (P_E1), within 0…7.
    @MainActor static func shownFeedback(_ s: DeviceSession, _ p: FM6Patch) -> Int {
        let e1 = (SoundPage.pages(s).first { $0.engineEdit == 1 }?.ids.first ?? nil).map { $0 + 1 }
        return min(7, max(0, p[.feedback] + (e1.map { s.cell($0).value } ?? 0)))
    }

    func op(_ n: Int, _ f: FM6Patch.Op, _ label: String, _ slot: Int, choices: [String]? = nil,
            shown: ((FM6Patch) -> String)? = nil) -> () -> KnobSpec {
        { [session, track] in
            let p = session.skiffEdit?.patches[track] ?? FM6Patch(bytes: [])
            return .plain("fm6.\(track).op\(n).\(f)", label, p.op(n, f), 0...f.max, shown: shown?(p), choices: choices, slot: slot) { v in
                session.skiffEdit?.editPatch(track: track) { $0.setOp(n, f, v) }
            }
        }
    }
    func voice(_ f: FM6Patch.Voice, _ label: String, _ slot: Int, choices: [String]? = nil,
               shown: ((FM6Patch) -> String)? = nil) -> () -> KnobSpec {
        { [session, track] in
            let p = session.skiffEdit?.patches[track] ?? FM6Patch(bytes: [])
            return .plain("fm6.\(track).\(f)", label, p[f], 0...f.max, shown: shown?(p), choices: choices, slot: slot) { v in
                session.skiffEdit?.editPatch(track: track) { $0[f] = v }
            }
        }
    }
    /// PITCH n: the level in semitones (FM6_PENV_TAB × 15 / 4, tenths), 50 the centre.
    func pitch(_ f: FM6Patch.Voice, _ label: String, _ slot: Int) -> () -> KnobSpec {
        voice(f, label, slot) { "\(FM6.tenths(FM6.pitchTab[min(99, $0[f])] * 15 / 4)) st" }
    }
    /// RATIO: one knob over both modes, 0…31 the ratio's coarse, 32…35 fixed 1 Hz to 1 kHz.
    func ratioKnob(_ n: Int) -> () -> KnobSpec {
        { [session, track] in
            let p = session.skiffEdit?.patches[track] ?? FM6Patch(bytes: [])
            let pos = p.op(n, .mode) == 1 ? 32 + (p.op(n, .coarse) & 3) : p.op(n, .coarse)
            return .plain("fm6.\(track).op\(n).ratio", "RATIO", pos, 0...35, shown: FM6.ratio(p, n), slot: 1) { v in
                session.skiffEdit?.editPatch(track: track) { $0.setOp(n, .mode, v >= 32 ? 1 : 0); $0.setOp(n, .coarse, v >= 32 ? v - 32 : v) }
            }
        }
    }
    /// ALGO: the patch's, and the ALGO macro back to PAT (0) as the FM-1 does, so what's set is what plays.
    @MainActor func algorithmKnob() -> () -> KnobSpec {
        let e0 = self.e0
        return { [session, track] in
            let p = session.skiffEdit?.patches[track] ?? FM6Patch(bytes: [])
            let a = Self.shownAlgorithm(session, p)
            return .plain("fm6.\(track).algo", "ALGO", a, 0...31, shown: "\(a + 1)", spoken: "algorithm \(a + 1)", slot: 0) { v in
                session.skiffEdit?.editPatch(track: track) { $0[.algorithm] = v }
                if let e0, session.cell(e0).value != 0 { session.set(track: track, param: e0, to: 0) }
            }
        }
    }
    /// FEEDBACK: the patch's, and the FEEDBACK macro back to 0.
    @MainActor func feedbackKnob() -> () -> KnobSpec {
        let e1 = e0.map { $0 + 1 }
        return { [session, track] in
            let p = session.skiffEdit?.patches[track] ?? FM6Patch(bytes: [])
            let f = Self.shownFeedback(session, p)
            return .plain("fm6.\(track).fb", "FEEDBACK", f, 0...7, slot: 1) { v in
                session.skiffEdit?.editPatch(track: track) { $0[.feedback] = v }
                if let e1, session.cell(e1).value != 0 { session.set(track: track, param: e1, to: 0) }
            }
        }
    }
}

/// The algorithm as Skiff charts it (ui_graph.c graph_fm6): carriers on the output bus, modulators stacked above
/// with their routes, the feedback loop; the picked operator lit, a silent one dim.
struct FM6AlgorithmChart: View {
    let patch: FM6Patch
    let algorithm: Int
    let picked: Int
    let feedback: Int
    let tint: Color

    var body: some View {
        let alg = FM6.algorithms[min(max(algorithm, 0), 31)]
        Canvas { ctx, size in
            let maxCol = alg.cells.values.map(\.col).max() ?? 0, maxRow = alg.cells.values.map(\.row).max() ?? 0
            // fitted to the height: the bus near the foot, the top row under the label with room for the feedback loop
            let bw: CGFloat = 34, bh: CGFloat = 24, dx: CGFloat = 46
            let bus = size.height - 14
            let dy = min(34, (bus - 10 - bh - 14) / CGFloat(max(1, maxRow)))
            func centre(_ op: Int) -> CGPoint {
                let c = alg.cells[op] ?? (0, 0)
                return CGPoint(x: size.width / 2 + CGFloat(c.col) * dx - CGFloat(maxCol) * dx / 2, y: bus - 10 - bh / 2 - CGFloat(c.row) * dy)
            }
            let line = GraphicsContext.Shading.color(Theme.textSecondary)
            // the output bus and its arrow
            let cs = alg.carriers.map { centre($0).x }
            var b = Path(); b.move(to: CGPoint(x: (cs.min() ?? 0) - 10, y: bus)); b.addLine(to: CGPoint(x: (cs.max() ?? 0) + 40, y: bus))
            ctx.stroke(b, with: line, lineWidth: 1.5)
            var arrow = Path(); let ax = (cs.max() ?? 0) + 40
            arrow.move(to: CGPoint(x: ax - 6, y: bus - 4)); arrow.addLine(to: CGPoint(x: ax, y: bus)); arrow.addLine(to: CGPoint(x: ax - 6, y: bus + 4))
            ctx.stroke(arrow, with: line, lineWidth: 1.5)
            for c in alg.carriers { var p = Path(); let o = centre(c); p.move(to: CGPoint(x: o.x, y: o.y + bh / 2)); p.addLine(to: CGPoint(x: o.x, y: bus)); ctx.stroke(p, with: line, lineWidth: 1.5) }
            // routes: down from the source, across over the target, down into it
            for (a, t) in alg.routes {
                let s = centre(a), d = centre(t), y = d.y - bh / 2 - 5
                var p = Path(); p.move(to: CGPoint(x: s.x, y: s.y + bh / 2)); p.addLine(to: CGPoint(x: s.x, y: y))
                p.addLine(to: CGPoint(x: d.x, y: y)); p.addLine(to: CGPoint(x: d.x, y: d.y - bh / 2))
                ctx.stroke(p, with: line, lineWidth: 1.5)
            }
            // the feedback loop: out of the right side, up, back in on top
            let f = centre(alg.feedback)
            var loop = Path()
            loop.move(to: CGPoint(x: f.x + bw / 2, y: f.y)); loop.addLine(to: CGPoint(x: f.x + bw / 2 + 8, y: f.y))
            loop.addLine(to: CGPoint(x: f.x + bw / 2 + 8, y: f.y - bh / 2 - 7)); loop.addLine(to: CGPoint(x: f.x, y: f.y - bh / 2 - 7))
            loop.addLine(to: CGPoint(x: f.x, y: f.y - bh / 2))
            ctx.stroke(loop, with: .color(feedback > 0 ? Theme.text : Theme.textTertiary), lineWidth: 1.5)
            // the boxes
            for op in 1...6 {
                let o = centre(op), r = CGRect(x: o.x - bw / 2, y: o.y - bh / 2, width: bw, height: bh)
                let box = Path(roundedRect: r, cornerRadius: 5), silent = patch.op(op, .output) == 0
                let fill: Color = op == picked ? Theme.text : alg.carriers.contains(op) ? tint : Theme.control
                ctx.fill(box, with: .color(fill))
                let ink: Color = op == picked ? Theme.onColour : silent ? Theme.textTertiary : alg.carriers.contains(op) ? Theme.onColour : Theme.text
                ctx.draw(Text("\(op)").font(.system(size: 13, weight: .semibold)).foregroundStyle(ink), at: o)
            }
            ctx.draw(Text("ALG \(String(format: "%02d", algorithm + 1))").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary),
                     at: CGPoint(x: 12, y: 12), anchor: .topLeading)
            ctx.draw(Text(caption(alg)).font(.system(size: 11)).foregroundStyle(Theme.textSecondary),
                     at: CGPoint(x: size.width - 12, y: 12), anchor: .topTrailing)
        }
        .accessibilityElement()
        .accessibilityLabel("Algorithm \(algorithm + 1)")
        .accessibilityValue(caption(FM6.algorithms[min(max(algorithm, 0), 31)]))
    }

    private func caption(_ alg: FM6.Algorithm) -> String {
        if patch.op(picked, .output) == 0 { return "OP\(picked) IS SILENT: OUTPUT 0" }
        if alg.carriers.contains(picked) { return "OP\(picked) GOES TO THE OUTPUT" }
        let to = alg.routes.filter { $0.0 == picked }.map { "OP\($0.1)" }
        return "OP\(picked) MODULATES " + to.joined(separator: ", ")
    }
}

/// Each operator's envelope as a line over the note (a sketch of ui_fm6.c fm_lines, not msfa's own curve): the rates
/// as times, the levels as heights, held at LEVEL 3 until key-up; carriers thick, modulators thin, the picked one white.
struct FM6EnvelopeGraph: View {
    let patch: FM6Patch
    let op: Int
    let algorithm: FM6.Algorithm
    let tint: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width - 24, h = size.height - 28, x0: CGFloat = 12, y0: CGFloat = 12
            let held = w * 0.72
            func time(_ r: Int) -> CGFloat { 0.02 + pow(CGFloat(99 - r) / 99, 2) * 1.2 }
            func points(_ n: Int) -> [CGPoint] {
                let r = [FM6Patch.Op.r1, .r2, .r3, .r4].map { patch.op(n, $0) }
                let l = [FM6Patch.Op.l1, .l2, .l3, .l4].map { CGFloat(patch.op(n, $0)) / 99 }
                let t1 = time(r[0]), t2 = t1 + time(r[1]), t3 = t2 + time(r[2])
                let scale = (held - 20) / max(t3, 0.3)
                let y = { (v: CGFloat) in y0 + h - v * h * CGFloat(patch.op(n, .output)) / 99 }
                return [CGPoint(x: x0, y: y(l[3])), CGPoint(x: x0 + t1 * scale, y: y(l[0])), CGPoint(x: x0 + t2 * scale, y: y(l[1])),
                        CGPoint(x: x0 + t3 * scale, y: y(l[2])), CGPoint(x: x0 + held, y: y(l[2])),
                        CGPoint(x: x0 + held + min(w - held, time(r[3]) * (w - held) / 1.2), y: y(l[3]))]
            }
            var key = Path(); key.move(to: CGPoint(x: x0 + held, y: y0)); key.addLine(to: CGPoint(x: x0 + held, y: y0 + h))
            ctx.stroke(key, with: .color(Theme.textTertiary), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            let order = (1...6).filter { !algorithm.carriers.contains($0) } + (1...6).filter { algorithm.carriers.contains($0) }
            for n in order where n != op {
                var p = Path(); p.addLines(points(n))
                let carrier = algorithm.carriers.contains(n)
                ctx.stroke(p, with: .color(tint.opacity(carrier ? 1 : 0.6)), lineWidth: carrier ? 4 : 2)
            }
            let pts = points(op)
            var p = Path(); p.addLines(pts)
            ctx.stroke(p, with: .color(Theme.text), lineWidth: algorithm.carriers.contains(op) ? 5 : 3)
            for q in pts[1...4] where q != pts[4] || true {
                ctx.stroke(Path(ellipseIn: CGRect(x: q.x - 4.5, y: q.y - 4.5, width: 9, height: 9)), with: .color(Theme.text), lineWidth: 1.5)
            }
            ctx.draw(Text("KEY UP").font(.system(size: 10)).foregroundStyle(Theme.textTertiary), at: CGPoint(x: x0 + held + 4, y: y0), anchor: .topLeading)
            ctx.draw(Text("OP\(op) \(algorithm.carriers.contains(op) ? "CARRIER" : "MODULATOR")").font(.system(size: 11)).foregroundStyle(Theme.textSecondary),
                     at: CGPoint(x: x0, y: size.height - 6), anchor: .bottomLeading)
        }
        .accessibilityElement()
        .accessibilityLabel("Operator envelopes, operator \(op) picked")
    }
}

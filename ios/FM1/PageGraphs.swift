import SloopKit
import SwiftUI

// Shape's page graphs, as Skiff draws them under its four cards (firmware ui_graph.c graph_adsr / graph_lfo,
// ui_pgraph.c graph_drive / delay / reverb / chorus / voice), in Skiff's own 240 × 140 drawing space stretched to
// the panel, in the track's colour. What moves and when: qa/shape-2026-11-05/animation.md.

/// Skiff's graph space: 240 wide, 140 tall (its panel: x 12…228).
private let gw = 240.0, gh = 140.0

private struct Space {
    let size: CGSize
    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x / gw * size.width, y: y / gh * size.height) }
    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(x: x / gw * size.width, y: y / gh * size.height, width: w / gw * size.width, height: h / gh * size.height)
    }
    func line(_ pts: [(Double, Double)]) -> Path { Path { $0.addLines(pts.map { p($0.0, $0.1) }) } }
    /// Skiff's small type (AF_S) with its baseline at y.
    func text(_ ctx: GraphicsContext, _ s: String, _ x: Double, _ base: Double, _ c: Color, size: CGFloat = 11,
              weight: Font.Weight = .regular, anchor: UnitPoint = .bottomLeading) {
        ctx.draw(Text(s).font(.system(size: size, weight: weight)).foregroundColor(c), at: p(x, base), anchor: anchor)
    }
}

private let lineColour = Theme.stepEmpty          // T_LINE
private let dimColour = Theme.textTertiary        // T_DIM
private let midColour = Theme.textSecondary       // T_MID

/// The page's graph, picked by its title (Skiff's PAGES); nil: a page Jib draws no graph for yet.
struct PageGraph: View {
    let session: DeviceSession
    let page: SoundPage
    let hot: Int?

    static func has(_ p: SoundPage) -> Bool {
        ["ENV", "ENV 2", "LFO", "LFO 2", "LFO DEST", "DRIVE", "DELAY", "REVERB", "CHORUS", "VOICE"].contains(p.title)
    }

    var body: some View {
        let colour = Theme.track[session.selectedTrack]
        Group {
            switch page.title {
            case "ENV", "ENV 2": EnvGraph(session: session, ids: page.ids, colour: colour, hot: hot)
            case "LFO", "LFO 2": LiveLFOGraph(session: session, colour: colour)
            case "LFO DEST": LFODestGraph(session: session, page: page, colour: colour, hot: hot)
            case "DRIVE": Canvas { ctx, sz in DriveDrawing(v: values).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Drive transfer curve", "\(valueName(1)), drive \(values[0])")
            case "DELAY": Canvas { ctx, sz in DelayDrawing(v: values).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Echoes", "every \(valueName(0)), feedback \(values[1])")
            case "REVERB": Canvas { ctx, sz in ReverbDrawing(v: values).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Reverb tail", "\(valueName(0)), size \(values[1])")
            case "CHORUS": Canvas { ctx, sz in ChorusDrawing(v: values).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Chorus", valueName(2))
            case "VOICE": Canvas { ctx, sz in VoiceDrawing(v: values, glide: glideText).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Voice", valueName(0))
            default: EmptyView()
            }
        }
        .frame(height: 128)
        .recessed(8)
    }

    /// The page's four values (0 for an empty slot), the track's or the globals.
    private var values: [Int] {
        let src = page.scope == 0 ? session.params : session.globals
        return page.ids.map { id in id.flatMap { $0 < src.count ? src[$0] : nil } ?? 0 }
    }
    private func desc(_ k: Int) -> ParamDesc? {
        guard let id = page.ids[k] else { return nil }
        return page.scope == 0 ? session.trackDesc(id) : session.globalDescs[id]
    }
    private func valueName(_ k: Int) -> String { formatValue(desc(k), values[k]).shown }
    private var glideText: String { values[1] == 0 ? "NO GLIDE" : valueName(1) }
}

private extension View {
    func graphLabel(_ label: String, _ value: String) -> some View {
        accessibilityElement().accessibilityLabel(label).accessibilityValue(value)
    }
}

// MARK: ENV, ENV 2: the curve and its three points, dragged

/// graph_adsr: attack linear, decay and release exponential, the time axis the parameter value; the peak, the
/// decay's end and the release's start as square handles, the knob just turned's white (ATTACK the peak; DECAY,
/// SUSTAIN the decay's end; SUSTAIN, RELEASE the release's start). Dragging a handle sets its values.
struct EnvGraph: View {
    let session: DeviceSession
    let ids: [Int?]
    let colour: Color
    let hot: Int?
    @State private var grabbed: Int?

    private var v: [Int] { ids.map { id in id.flatMap { $0 < session.params.count ? session.params[$0] : nil } ?? 0 } }

    /// x1 (peak), the decay's length, x3 (the release's start), top, bottom, sustain 0…1, in Skiff's space.
    private static func geometry(_ v: [Int]) -> (x1: Double, d: Double, x3: Double, r: Double, top: Double, bot: Double, sus: Double) {
        let a = 4 + Double(v[0] * 50 / 127), d = 6 + Double(v[1] * 50 / 127), r = 6 + Double(v[3] * 60 / 127)
        return (12 + a, d, 226 - r, r, 6 * gh / 100, 88 * gh / 100, Double(v[2]) / 127)
    }

    var body: some View {
        GeometryReader { g in
            Canvas { ctx, sz in draw(ctx, Space(size: sz)) }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { e in drag(e, g.size) }.onEnded { _ in grabbed = nil })
        }
        .accessibilityElement()
        .accessibilityLabel("Envelope shape")
        .accessibilityValue("attack \(v[0]), decay \(v[1]), sustain \(v[2]), release \(v[3])")
    }

    private func draw(_ ctx: GraphicsContext, _ s: Space) {
        let v = self.v, k = Self.geometry(v)
        func y(_ lvl: Double) -> Double { k.bot - lvl * (k.bot - k.top) }
        for gy in [k.top, (k.top + k.bot) / 2, k.bot] { ctx.fill(Path(s.r(12, gy, 216, 1)), with: .color(lineColour)) }
        var pts: [(Double, Double)] = [(12, k.bot), (k.x1, k.top)]
        var e = 1.0
        let kd = 1 - 4.6 / k.d
        for i in stride(from: 1.0, through: k.d, by: 1) { e *= kd; pts.append((k.x1 + i, y(k.sus + (1 - k.sus) * e))) }
        pts.append((k.x3, y(k.sus)))
        e = 1
        let kr = 1 - 4.6 / k.r
        for i in stride(from: 1.0, through: k.r, by: 1) { e *= kr; pts.append((k.x3 + i, y(k.sus * e))) }
        var fill = s.line(pts)
        fill.addLine(to: s.p(pts.last!.0, k.bot)); fill.closeSubpath()
        ctx.fill(fill, with: .color(colour.opacity(0.14)))
        ctx.stroke(s.line(pts), with: .color(colour), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        let handles = [(k.x1, k.top), (k.x1 + k.d, y(k.sus)), (k.x3, y(k.sus))]
        for (i, h) in handles.enumerated() {
            // the one dragged; else as Skiff: the peak lit by ATTACK, the decay's end by DECAY and SUSTAIN, the
            // release's start by SUSTAIN and RELEASE
            let on = grabbed.map { $0 == i } ?? hot.map { $0 == i || (i > 0 && $0 == i + 1) } ?? false
            let c = s.p(h.0, h.1), r = CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)
            ctx.fill(Path(roundedRect: r.insetBy(dx: -2, dy: -2), cornerRadius: 3), with: .color(Theme.well))
            ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(on ? Theme.text : colour))
        }
    }

    /// The handle nearest the finger (within 40 pt) follows it: the peak sets ATTACK; the decay's end DECAY and
    /// SUSTAIN; the release's start RELEASE and SUSTAIN.
    private func drag(_ e: DragGesture.Value, _ size: CGSize) {
        let v = self.v, k = Self.geometry(v), s = Space(size: size)
        func y(_ lvl: Double) -> Double { k.bot - lvl * (k.bot - k.top) }
        if grabbed == nil {
            let hs = [s.p(k.x1, k.top), s.p(k.x1 + k.d, y(k.sus)), s.p(k.x3, y(k.sus))]
            let near = hs.enumerated().min { hypot($0.element.x - e.startLocation.x, $0.element.y - e.startLocation.y) < hypot($1.element.x - e.startLocation.x, $1.element.y - e.startLocation.y) }
            guard let n = near, hypot(n.element.x - e.startLocation.x, n.element.y - e.startLocation.y) < 40 else { return }
            grabbed = n.offset
        }
        let x = Double(e.location.x / max(1, size.width)) * gw, yy = Double(e.location.y / max(1, size.height)) * gh
        let sus = Int(((k.bot - yy) / (k.bot - k.top) * 127).rounded())
        switch grabbed {
        case 0: set(0, Int(((x - 16) * 127 / 50).rounded()))
        case 1: set(1, Int(((x - k.x1 - 6) * 127 / 50).rounded())); set(2, sus)
        case 2: set(3, Int(((226 - x - 6) * 127 / 60).rounded())); set(2, sus)
        default: break
        }
    }

    private func set(_ slot: Int, _ value: Int) {
        guard let id = ids[slot] else { return }
        let d = session.trackDesc(id)
        let n = min(max(value, d?.min ?? 0), d?.max ?? 127)
        if id < session.params.count, session.params[id] != n { session.set(track: session.selectedTrack, param: id, to: n) }
    }
}

// MARK: LFO, LFO 2: the wave as it runs

/// graph_lfo: the LFO's 2 s from its restart (then the last 2 s, scrolling), at its real rate, a dot where it is
/// now. Its seven values come from the LFO and LFO 2 pages; the restart and the clock from Skiff's NOTES OUT and
/// MIDI clock (LFOClock). Live whatever Reduce Motion says, as Skiff's ANIM OFF leaves it: it's the instrument's
/// state, not decoration.
struct LiveLFOGraph: View {
    let session: DeviceSession
    let colour: Color

    /// When Shape first showed an LFO: the stand-in restart while Jib sees none, shared so every LFO graph shows
    /// the same moment.
    @MainActor static let opened = Date()
    private var opened: Date { Self.opened }
    private var lfo: SkiffLFO { SkiffLFO.of(session) }

    var body: some View {
        let lfo = self.lfo, track = session.selectedTrack, bpm = Double(session.bpm)
        TimelineView(.animation) { tl in
            Canvas { ctx, sz in
                let s = Space(size: sz)
                let n = session.lfoClock.lfoNow(lfo, track: track, bpm: bpm, opened: opened, at: tl.date)
                let view = lfo.view(cyclesNow: n.cycles, since: n.since, bpm: n.bpm, count: 217)
                let cy = gh / 2, a = 38 * gh / 100
                ctx.fill(Path(s.r(12, cy, 216, 1)), with: .color(Theme.tones[2]))
                let pts = view.values.enumerated().map { (12 + Double($0.offset), cy - $0.element * a) }
                ctx.stroke(s.line(pts), with: .color(colour), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                let k = min(216, Int((view.now * 216).rounded()))
                let dot = s.p(12 + Double(k), cy - view.values[k] * a)
                ctx.fill(Path(roundedRect: CGRect(x: dot.x - 5, y: dot.y - 5, width: 10, height: 10), cornerRadius: 2), with: .color(Theme.text))
                s.text(ctx, caption(lfo, n.bpm), 228, 16, midColour, anchor: .bottomTrailing)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("LFO wave, running")
        .accessibilityValue("\(LFOGraph.names[safe: lfo.wave] ?? "wave"), \(caption(lfo, bpm))")
    }

    private func caption(_ l: SkiffLFO, _ bpm: Double) -> String {
        let names = ["", "4BAR", "2BAR", "1/1", "1/2", "1/4", "1/8", "8T", "1/16", "16T", "1/32"]
        if l.sync > 0 { return "\(names[safe: l.sync] ?? "SYNC") at \(Int(bpm.rounded())) BPM" }
        let hz = SkiffLFO.hz(l.rate)
        return hz < 10 ? String(format: "%.2f Hz", hz) : String(format: "%.1f Hz", hz)
    }
}

extension SkiffLFO {
    /// The selected track's LFO, from its LFO and LFO 2 pages.
    @MainActor static func of(_ session: DeviceSession) -> SkiffLFO {
        let pages = SoundPage.pages(session)
        func val(_ title: String, _ k: Int) -> Int {
            guard let id = pages.first(where: { $0.title == title })?.ids[safe: k] ?? nil, id < session.params.count else { return 0 }
            return session.params[id]
        }
        return SkiffLFO(rate: val("LFO", 0), wave: val("LFO", 1), phase: val("LFO", 2), fade: val("LFO", 3),
                        sync: val("LFO 2", 0), trig: val("LFO 2", 1), polarity: val("LFO 2", 2))
    }
}

// MARK: LFO DEST: each destination moving as far as its depth

/// Jib's LFO DEST (Skiff 2.2 has the depths on MOD): each destination's row carries the running LFO, as tall as
/// its depth (±64 = the whole swing), the one of the knob just turned in the track's colour.
struct LFODestGraph: View {
    let session: DeviceSession
    let page: SoundPage
    let colour: Color
    let hot: Int?

    var body: some View {
        let lfo = SkiffLFO.of(session), track = session.selectedTrack, bpm = Double(session.bpm)
        let rows: [(String, Int)] = page.ids.map { id in
            guard let id, id < session.params.count else { return ("", 0) }
            return (session.trackDesc(id)?.label ?? "", session.params[id])
        }
        TimelineView(.animation) { tl in
            Canvas { ctx, sz in
                let s = Space(size: sz)
                let n = session.lfoClock.lfoNow(lfo, track: track, bpm: bpm, opened: LiveLFOGraph.opened, at: tl.date)
                let view = lfo.view(cyclesNow: n.cycles, since: n.since, bpm: n.bpm, count: 121)
                for (i, row) in rows.enumerated() where !row.0.isEmpty {
                    let yc = 22 + Double(i) * 32, amp = Double(row.1) / 64 * 12
                    let lit = hot == i
                    let c = lit ? colour : row.1 != 0 ? Color(hex: 0x6E6E76) : Color(hex: 0x3A3A42)
                    s.text(ctx, row.0, 12, yc + 4, lit ? colour : midColour, weight: lit ? .semibold : .regular)
                    let pts = view.values.enumerated().map { (80 + Double($0.offset) * 148 / 120, yc - $0.element * amp) }
                    ctx.stroke(s.line(pts), with: .color(c), lineWidth: lit ? 2.5 : 1.6)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("LFO destinations, moving with the LFO")
        .accessibilityValue(rows.filter { !$0.0.isEmpty }.map { "\($0.0) \($0.1)" }.joined(separator: ", "))
    }
}

// MARK: DRIVE (ui_pgraph.c graph_drive, fx.c ins_shape)

private struct DriveDrawing {
    let v: [Int]                                  // DIST, TYPE, TONE

    static func softclip(_ x: Int) -> Int {
        let a = min(abs(x), 65536)
        let y = Int(32767 * tanh(Double(a) / 32768))
        return x < 0 ? -y : y
    }
    static func mulq15(_ a: Int, _ b: Int) -> Int { (a * b) >> 15 }
    static func shape(_ ty: Int, _ v: Int, _ sh: Int) -> Int {
        switch ty {
        case 0: return softclip(v)
        case 1: return min(max(v, -24000), 24000)
        case 2:
            var u = Int(UInt32(truncatingIfNeeded: v + 16384) & 0xFFFF) - 32768
            u = 16384 - abs(u)
            return u + (u >> 1)
        case 3: return ((v + ((1 << sh) >> 1)) >> sh) << sh
        case 4: return v > 0 ? min(v, 20000) : softclip(v) >> 1
        default: return v
        }
    }
    /// pg_drive_at: the TYPE (SOFT HARD FOLD CRUSH FUZZ) at DIST d, input x (±32768).
    static func at(_ type: Int, _ d: Int, _ x: Int) -> Int {
        guard d != 0 else { return x }
        if type == 3 { return mulq15(shape(3, x, d / 11), 32000 - d * 20) }
        let g = 4096 + d * d * 2, y0 = ((x >> 2) * g) >> 10
        let y = type == 0 ? softclip(y0 + 2400) - softclip(2400) : shape(type, y0, 0)
        return mulq15(min(max(y, -40000), 40000), 30000 - d * 120)
    }
    /// pg_drive_wave: a sine's cycle of 88 samples through it, CRUSH's hold, TONE's two-pole low-pass.
    static func wave(_ type: Int, _ d: Int, _ tone: Int) -> [Int] {
        let hm = type == 3 ? (1 << (d >> 5)) - 1 : 0
        var lp1 = 0, lp2 = 0, h = 0, out = [Int](repeating: 0, count: 88)
        let k = min(max((type == 3 ? 32700 - d * 40 : 32000 - d * 95) + tone * 150, 2000), 32700)
        for i in 0..<176 {
            let ph = Double(UInt32(truncatingIfNeeded: i &* 48_806_447)) / 4_294_967_296
            let x = Int(32767 * sin(ph * 2 * .pi)) * 3 / 4
            if i & hm == 0 { h = at(type, d, x) }
            lp1 += mulq15(h - lp1, k)
            lp2 += mulq15(lp1 - lp2, k)
            if i >= 88 { out[i - 88] = d != 0 ? lp2 : x }
        }
        return out
    }

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let d = v[0], type = min(max(v[1], 0), 4), tone = v[2]
        let ys = (0...116).map { i in 66 - Double(Self.at(type, d, (i - 58) * 32768 / 58)) * 58 / 32768 }
        var under = s.line(ys.enumerated().map { (12 + Double($0.offset), $0.element) })
        under.addLine(to: s.p(128, 124)); under.addLine(to: s.p(12, 124)); under.closeSubpath()
        ctx.fill(under, with: .color(c.opacity(0.14)))
        ctx.fill(Path(s.r(12, 66, 116, 1)), with: .color(lineColour))
        ctx.fill(Path(s.r(70, 8, 1, 117)), with: .color(lineColour))
        ctx.fill(Path(s.r(140, 88, 87, 1)), with: .color(lineColour))
        ctx.stroke(s.line([(12, 124), (128, 8)]), with: .color(dimColour), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        ctx.stroke(s.line(ys.enumerated().map { (12 + Double($0.offset), $0.element) }), with: .color(c), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        let w = Self.wave(type, d, tone)
        var wf = s.line(w.enumerated().map { (140 + Double($0.offset), 88 - Double($0.element) * 32 / 32768) })
        wf.addLine(to: s.p(227, 88)); wf.addLine(to: s.p(140, 88)); wf.closeSubpath()
        ctx.fill(wf, with: .color(c.opacity(0.14)))
        ctx.stroke(s.line(w.enumerated().map { (140 + Double($0.offset), 88 - Double($0.element) * 32 / 32768) }), with: .color(c), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        let names = ["SOFT", "HARD", "FOLD", "CRUSH", "FUZZ"]
        s.text(ctx, names[type], 140, 26, d != 0 ? c : dimColour, size: 13, weight: .semibold)
        if type == 3, d != 0 { s.text(ctx, "\(16 - d / 11) BITS, HOLD \(1 << (d >> 5))", 140, 42, midColour) }
    }
}

// MARK: DELAY (ui_pgraph.c graph_delay)

private struct DelayDrawing {
    let v: [Int]                                  // TIME, FEEDBACK, COLOR, MIX

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let sixths = [24, 12, 6, 3, 8, 4, 48, 96, 192, 384, 18, 9, 36]
        let tap = sixths[((v[0] % 13) + 13) % 13], win = max(tap * 4, 96), unit = win > 96 ? 96 : 24
        let n = win / unit
        let w = Double(min(max(tap * 208 / win - 3, 2), 13))
        for i in 0..<n {
            let x = 14 + Double(i * unit * 208 / win)
            ctx.fill(Path(s.r(x, 123, 2, 3)), with: .color(dimColour))
            // the beat's number beside its tick (Skiff's type is smaller than the tick is tall)
            if n <= 8 || i % 4 == 0 { s.text(ctx, "\(i + 1)", x + 4, 135, midColour, size: 10) }
        }
        var lvl = 1000
        for i in 0..<9 where lvl >= 40 {
            let x = 14 + Double(i * tap * 208 / win), h = Double(lvl / 10)
            if x + w > 228 { break }
            let col = i == 0 ? Theme.text : c.opacity(1 - Double(15 + 50 * (i - 1) / 6) / 100)
            ctx.fill(Path(roundedRect: s.r(x, 120 - h, w, h), cornerRadius: 2), with: .color(col))
            lvl = i > 0 ? lvl * v[1] * 230 / 32768 : v[3] * 1000 / 127
        }
        s.text(ctx, "DRY", 14, 16, midColour)
    }
}

// MARK: REVERB (ui_pgraph.c graph_reverb)

private struct ReverbDrawing {
    let v: [Int]                                  // TYPE, SIZE, DAMP

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let er: [Double] = [84, 60, 72, 46, 52]
        let hall = v[0] == 2
        let len = Double((40 + v[1] * 144 / 127) * (hall ? 2 : 1)), k = 1 - 3 / len
        let dim = Double(20 + v[2] * 60 / 127) / 100
        for (i, h) in er.enumerated() { ctx.fill(Path(s.r(12 + Double(i * 6), 126 - h, 3, h)), with: .color(Theme.text)) }
        var e = 1.0
        for x in 44...228 {
            let h = 84 * e, top = h * dim, t = Double(x - 44) / 184
            ctx.fill(Path(s.r(Double(x), 126 - h, 1.2, top)), with: .color(c.opacity(0.45 - t * 0.3)))
            ctx.fill(Path(s.r(Double(x), 126 - h + top, 1.2, h - top)), with: .color(c.opacity(1 - t * 0.6)))
            e *= k
        }
        if v[0] == 1 {
            s.text(ctx, "SPRING", 12, 17, midColour)
            // the coil: 13/256 of a turn a pixel (sine_i(x × 0x0D000000))
            let coil: [(Double, Double)] = (64...228).map { x in
                let turn = Double(x - 64) * 13 / 256
                return (Double(x), 13 + sin(turn * 2 * .pi) * 3)
            }
            ctx.stroke(s.line(coil), with: .color(midColour), lineWidth: 1)
        } else {
            s.text(ctx, hall ? "HALL" : "ROOM", 12, 17, midColour)
        }
    }
}

// MARK: CHORUS (ui_pgraph.c graph_chorus)

private struct ChorusDrawing {
    let v: [Int]                                  // RATE, DEPTH, MODE, FEEDBACK

    static func sine(_ ph: UInt32) -> Double { sin(Double(ph) / 4_294_967_296 * 2 * .pi) }

    /// pg_cho_resp: FLANGER's comb, PHASER's two notches, across 0…216 (Q15 as 1).
    func resp(_ mode: Int, _ x: Int) -> Double {
        let fb = v[3], dp = v[1]
        if mode == 1 {
            let n = UInt32(4 + dp * 6 / 127)
            var s = Self.sine(UInt32(truncatingIfNeeded: x) &* n &* 9_942_053 &+ 0x4000_0000) * 32768
            s = abs(s)
            let kk = (s * s / 32768) * (s * s / 32768) / 32768
            return (s * Double(127 - fb) + kk * Double(fb)) / 127 * Double(127 + fb) / 127 / 32768
        }
        var h = 32768.0
        for k in 0..<2 {
            let d = Double(x - (k == 1 ? 150 : 66)), w = Double(10 + dp / 8), r = d - (d < 0 ? -2 : 2) * w
            h -= 30000 * w * w / (w * w + d * d)
            h += Double(fb * 128) * w * w / (w * w + r * r)
        }
        return max(0, h) / 32768
    }

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let mode = v[2]
        if mode == 1 || mode == 2 {
            let pts = (0...216).map { (12 + Double($0), 124 - resp(mode, $0) * 40) }
            var under = s.line(pts); under.addLine(to: s.p(228, 124)); under.addLine(to: s.p(12, 124)); under.closeSubpath()
            ctx.fill(under, with: .color(c.opacity(0.22)))
            ctx.stroke(s.line(pts), with: .color(c), lineWidth: 2.5)
            ctx.fill(Path(s.r(12, 84, 216, 1)), with: .color(lineColour))
            s.text(ctx, mode == 1 ? "THE DRY AND ITS COPY: A COMB, SWEPT" : "FOUR STAGES: TWO NOTCHES, SWEPT", 12, 16, midColour)
            return
        }
        let a = Double(v[1] * 44 / 127), b = a * Double(v[3]) / 127
        let inc = (UInt32.max / 216) &* UInt32(1 + v[0] * 5 / 127)
        ctx.fill(Path(s.r(12, 74, 216, 1)), with: .color(midColour))
        if v[3] != 0 {
            let pts = stride(from: 0, through: 216, by: 2).map { (12 + Double($0), 74 + Self.sine(UInt32($0) &* inc &- 0x3000_0000) * b) }
            ctx.stroke(s.line(pts), with: .color(midColour), lineWidth: 1)
        }
        let pts = stride(from: 0, through: 216, by: 2).map { (12 + Double($0), 74 + Self.sine(UInt32($0) &* inc) * a) }
        ctx.stroke(s.line(pts), with: .color(c), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        s.text(ctx, "DRY AND ITS DRIFTING COPY", 12, 16, midColour)
    }
}

// MARK: VOICE (ui_pgraph.c graph_voice)

private struct VoiceDrawing {
    let v: [Int]                                  // VOICE, GLIDE, GLIDE MODE, PRIORITY
    let glide: String

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let says = ["POLY: A VOICE A NOTE", "MONO: ONE VOICE, NEW ATTACK", "LEG: ONE VOICE, NO NEW ATTACK", "UNI: ALL VOICES, ONE NOTE"]
        let g = v[1], w = Double(g != 0 ? 6 + g * 90 / 127 : 0)
        s.text(ctx, says[v[0] & 3], 12, 16, midColour)
        ctx.fill(Path(roundedRect: s.r(12, 92, 88, 11), cornerRadius: 2), with: .color(midColour))
        ctx.stroke(s.line([(100, 97), (100 + w, 39)]), with: .color(c), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        ctx.fill(Path(roundedRect: s.r(100 + w, 34, 128 - w, 11), cornerRadius: 2), with: .color(c))
        if g != 0 {
            ctx.fill(Path(s.r(100, 116, 1, 9)), with: .color(dimColour))
            ctx.fill(Path(s.r(100 + w, 116, 1, 9)), with: .color(dimColour))
            ctx.fill(Path(s.r(100, 120, w, 1)), with: .color(dimColour))
        }
        s.text(ctx, glide, 100 + w / 2, 135, midColour, anchor: .bottom)
    }
}

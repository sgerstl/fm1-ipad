import SloopKit
import SwiftUI

// Shape's page graphs, as Skiff draws them under its four cards (firmware ui_graph.c graph_adsr / graph_lfo,
// ui_pgraph.c graph_drive / delay / reverb / chorus / voice), in Skiff's own 240 × 140 drawing space stretched to
// the panel, in the track's colour. What moves and when: qa/shape-2026-11-05/animation.md.

/// Skiff's graph space: 240 wide, 140 tall (its panel: x 12…228).
private let gw = 240.0, gh = 140.0

private struct Space {
    let size: CGSize
    /// The drawing's height in Skiff's pixels: 140 for the graphs drawn from the panel's top, about 96 for FX,
    /// SLICER and DUCK, which Skiff draws in the panel under its cards.
    var gh = 140.0
    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x / gw * size.width, y: y / gh * size.height) }
    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(x: x / gw * size.width, y: y / gh * size.height, width: w / gw * size.width, height: h / gh * size.height)
    }
    /// A point of the view back in Skiff's space.
    func back(_ pt: CGPoint) -> (Double, Double) { (Double(pt.x / max(1, size.width)) * gw, Double(pt.y / max(1, size.height)) * gh) }
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
    /// The pages of a merged card (LFO + LFO 2, INSERT + INSERT 2): one graph from all their values.
    var rows: [SoundPage] = []
    let hot: Int?
    @Binding var modRoute: Int

    static func has(_ p: SoundPage) -> Bool {
        ["ENV", "ENV 2", "LFO", "LFO 2", "LFO DEST", "MOD", "FX", "DRIVE", "INSERT", "INSERT 2", "SLICER", "DUCK",
         "DELAY", "REVERB", "CHORUS", "GLOBAL", "VOICE", "ARP", "ARP 2", "SCALE", "CHORD", "FOLLOW"].contains(p.title)
    }
    /// Drawn in the panel under the cards on Skiff, shorter than the graphs drawn from the panel's top.
    static let short: Set<String> = ["FX", "SLICER", "DUCK", "SCALE"]
    @Environment(\.graphsDeferred) private var deferred

    var body: some View {
        let _ = BodyCounter.tick("PageGraph")
        let colour = Theme.track[session.selectedTrack]
        Group {
            if deferred {
                Color.clear      // (the sound panel sliding in: drawn once it settles, the well holding its place)
            } else {
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
            case "FX": Canvas { ctx, sz in FXDrawing(v: values).draw(ctx, Space(size: sz, gh: 96), colour) }
                .graphLabel("Sends", "distortion \(values[0]), chorus \(values[1]), delay \(values[2]), reverb \(values[3])")
            case "INSERT", "INSERT 2": Canvas { ctx, sz in InsertDrawing(v: insertValues).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Insert", insertName)
            case "SLICER": Canvas { ctx, sz in SlicerDrawing(v: values).draw(ctx, Space(size: sz, gh: 96), colour) }
                .graphLabel("Slicer pattern", "\(valueName(0)), pattern \(values[1])")
            case "DUCK": Canvas { ctx, sz in duck.draw(ctx, Space(size: sz, gh: 96), colour) }
                .graphLabel("Ducking over a bar", valueName(0))
            case "GLOBAL": Canvas { ctx, sz in GlobalDrawing(swing: values[1]).draw(ctx, Space(size: sz), colour) }
                .graphLabel("Swing over a bar", "SWING \(50 + values[1] * 50 / 250) to \(50 - values[1] * 50 / 250)")
            case "SCALE": Canvas { ctx, sz in ScaleDrawing(root: values[0], scale: values[1]).draw(ctx, Space(size: sz, gh: 96), colour) }
                .graphLabel("The scale on the 12 keys", "\(SkiffChord.noteNames[((values[0] % 12) + 12) % 12]) scale")
            case "CHORD":
                let d = chordDrawing
                Canvas { ctx, sz in d.draw(ctx, Space(size: sz, gh: 120), colour) }
                    .graphLabel("The chord a key plays", d.spoken)
            case "FOLLOW":
                let d = followDrawing
                Canvas { ctx, sz in d.draw(ctx, Space(size: sz, gh: 120), colour) }
                    .graphLabel("The chord it follows", d.spoken)
            case "ARP", "ARP 2": Canvas { ctx, sz in ArpDrawing(v: arpValues).draw(ctx, Space(size: sz), colour) }
                .graphLabel("The arpeggio over 16 steps", "\(Music.arpModes[safe: arpValues[0]] ?? "OFF"), an example on C E G")
            case "MOD": ModGraph(session: session, page: page, route: $modRoute, colour: colour)
            default: EmptyView()
            }
            }
        }
        .frame(height: Self.short.contains(page.title) ? 88 : page.title == "MOD" ? 168 : 128)   // MOD: eleven routes' text
        .recessed(8)
    }

    /// A parameter of the selected track by its page and knob (the SEL pages' graphs read each other's).
    private func value(_ title: String, _ k: Int) -> Int? {
        (SoundPage.pages(session).first { $0.title == title }?.ids[safe: k] ?? nil).map { session.cell($0).value }
    }
    private static let kitEngines: Set<Int> = [10, 13, 14]           // DRUM, SLICE, DRUM-X: their keys aren't chords

    /// CHORD: the chord on the track's ROOT from C4, as Skiff shows it before a chord is played (the last one played
    /// isn't sent to an editor); OFF and a kit say so instead.
    private var chordDrawing: ChordDrawing {
        let t = session.tracks[session.selectedTrack]
        let mode = values[0], voicing = values[safe: 1] ?? 0
        if mode == 0 { return ChordDrawing(note: ("CHORD KEYS OFF", "K1 DIA3: IN-KEY CHORDS")) }
        if Self.kitEngines.contains(t.engine) { return ChordDrawing(note: ("NO CHORDS ON KITS", nil)) }
        let root = value("SCALE", 0) ?? 0, scale = value("SCALE", 1) ?? 0
        let oneVoice = (value("VOICE", 0) ?? 0) != 0 && (value("ARP", 0) ?? 0) == 0
        guard let c = SkiffChord.make(note: 60 + root, mode: mode, voicing: voicing, root: root, scale: scale, oneVoice: oneVoice) else {
            return ChordDrawing(note: ("CHORD KEYS OFF", nil))
        }
        return ChordDrawing(name: SkiffChord.name(root: c.root, mask: c.mask), caption: oneVoice ? "ROOT ONLY" : "ON ROOT",
                            notes: c.notes, accent: c.root % 12, keysColour: nil)
    }

    /// FOLLOW: the track it follows and how. The chord that track plays live isn't sent to an editor, so Lupe draws
    /// what it can say: OFF, a kit, or the track and the mode, with the live chord left to the FM-1's screen.
    private var followDrawing: ChordDrawing {
        let me = session.selectedTrack, l = values[0] - 1
        guard l >= 0, l < session.trackCount, l != me else { return ChordDrawing(note: ("FOLLOW OFF", "K1 A TRACK TO FOLLOW")) }
        if Self.kitEngines.contains(session.tracks[l].engine) { return ChordDrawing(note: ("T\(l + 1) PLAYS A KIT", "NO CHORDS TO FOLLOW")) }
        let modes = ["KEY", "SCALE", "FIT"], notes = ["ROOT", "LOW", "HIGH", "LAST"]
        let mode = modes[safe: values[safe: 1] ?? 0] ?? "KEY", by = (values[safe: 1] ?? 0) == 2 ? "ROOT" : notes[safe: values[safe: 2] ?? 0] ?? "ROOT"
        return ChordDrawing(note: ("FOLLOWS T\(l + 1) · \(mode) BY ITS \(by)", "ITS LIVE CHORD SHOWS ON THE FM-1"), noteColour: Theme.track[l])
    }

    /// ARP's MODE RATE OCTAVE GATE and ARP 2's SWING CHANCE HOLD ORDER, for either card's graph (they draw the same).
    private var arpValues: [Int] {
        let ps = SoundPage.pages(session)
        let ids = ["ARP", "ARP 2"].flatMap { t in ps.first { $0.title == t }?.ids ?? [nil, nil, nil, nil] }
        return ids.map { id in id.map { session.cell($0).value } ?? 0 } + Array(repeating: 0, count: max(0, 8 - ids.count))
    }

    /// INSERT's TYPE A B C and INSERT 2's MIX, from the merged card's rows.
    private var insertValues: [Int] {
        let all = (rows.isEmpty ? [page] : rows).flatMap { p in p.ids.map { id in id.map { session.cell($0).value } } }
        let v = all.compactMap { $0 }
        return v.count >= 5 ? Array(v.prefix(5)) : v + Array(repeating: 127, count: max(0, 5 - v.count))
    }
    private var insertName: String { InsertDrawing.names[safe: insertValues[0]] ?? "OFF" }

    /// DUCK's source: its steps over a bar at the tempo.
    private var duck: DuckDrawing {
        let v = values, src = v[0], me = session.selectedTrack
        guard src > 0, src - 1 < session.tracks.count, src - 1 != me else { return DuckDrawing(depth: v[1], release: 0, hits: nil, colour: .clear) }
        let s = session.tracks[src - 1]
        let ticks = CountedPlayhead.divisionTicks[safe: s.division] ?? 6, len = max(1, s.length)
        let nb = max(1, Int(96 / ticks))
        let hits = (0..<min(nb, 64)).filter { i in
            let k = i % len
            // a kit (DRUM, DRUM-X) ducks on its KICK lane only
            let kit = session.isDrums(src - 1) || s.engineName.uppercased().hasPrefix("DRUM")
            return k < s.steps.count && (kit ? s.gridSteps[k].has(0) : s.isOn(k))
        }.map { Double($0) * ticks / 96 }
        let bar = 4 * 60 / Double(max(40, session.bpm))
        let rel = SkiffLFO.fadeSeconds(max(1, v[2])) / bar
        return DuckDrawing(depth: v[1], release: rel, hits: hits, colour: Theme.track[src - 1])
    }

    /// The page's four values (0 for an empty slot), the track's or the globals.
    private var values: [Int] {
        // the track's from their cells: this graph redraws when its own parameters change
        if page.scope == 0 { return page.ids.map { id in id.map { session.cell($0).value } ?? 0 } }
        // the globals' own cells: this graph redraws when its own globals change, not when any does
        return page.ids.map { id in id.map { session.globalCell($0).value } ?? 0 }
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

    private var v: [Int] { ids.map { id in id.map { session.cell($0).value } ?? 0 } }

    /// x1 (peak), the decay's length, x3 (the release's start), top, bottom, sustain 0…1, in Skiff's space.
    private static func geometry(_ v: [Int]) -> (x1: Double, d: Double, x3: Double, r: Double, top: Double, bot: Double, sus: Double) {
        let a = 4 + Double(v[0] * 50 / 127), d = 6 + Double(v[1] * 50 / 127), r = 6 + Double(v[3] * 60 / 127)
        return (12 + a, d, 226 - r, r, 6 * gh / 100, 88 * gh / 100, Double(v[2]) / 127)
    }

    var body: some View {
        GeometryReader { g in
            let s = Space(size: g.size), k = Self.geometry(v)
            let y = { (l: Double) in k.bot - l * (k.bot - k.top) }
            let handles = [s.p(k.x1, k.top), s.p(k.x1 + k.d, y(k.sus)), s.p(k.x3, y(k.sus))]
            ZStack(alignment: .topLeading) {
                // the graph itself takes no touch: a drag on it scrolls the page
                Canvas { ctx, sz in draw(ctx, Space(size: sz)) }
                    .allowsHitTesting(false)
                // each handle a 44 pt target of its own, and only a drag that starts there moves it
                ForEach(0..<3, id: \.self) { i in
                    Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
                        .position(handles[i])
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("env"))
                            .onChanged { e in grabbed = i; drag(i, e.location, g.size) }
                            .onEnded { _ in grabbed = nil })
                        .accessibilityHidden(true)
                }
            }
            .coordinateSpace(name: "env")
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

    /// A handle follows the finger: the peak sets ATTACK; the decay's end DECAY and SUSTAIN; the release's start
    /// RELEASE and SUSTAIN.
    private func drag(_ handle: Int, _ p: CGPoint, _ size: CGSize) {
        let k = Self.geometry(v)
        let x = Double(p.x / max(1, size.width)) * gw, yy = Double(p.y / max(1, size.height)) * gh
        let sus = Int(((k.bot - yy) / (k.bot - k.top) * 127).rounded())
        switch handle {
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
        if session.cell(id).value != n { session.set(track: session.selectedTrack, param: id, to: n) }
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
    @State private var visible = true                  // scrolled off: the wave stops drawing

    /// When Shape first showed an LFO: the stand-in restart while Jib sees none, shared so every LFO graph shows
    /// the same moment.
    @MainActor static let opened = Date()
    private var opened: Date { Self.opened }
    private var lfo: SkiffLFO { SkiffLFO.of(session) }

    var body: some View {
        let lfo = self.lfo, track = session.selectedTrack, bpm = Double(session.bpm)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !visible)) { tl in
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
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
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
            guard let id = pages.first(where: { $0.title == title })?.ids[safe: k] ?? nil else { return 0 }
            return session.cell(id).value
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
    @State private var visible = true

    var body: some View {
        let lfo = SkiffLFO.of(session), track = session.selectedTrack, bpm = Double(session.bpm)
        let rows: [(String, Int)] = page.ids.map { id in
            guard let id else { return ("", 0) }
            return (session.trackDesc(id)?.label ?? "", session.cell(id).value)
        }
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !visible)) { tl in
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
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
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
        // the tail as two shapes under horizontal gradients (the damped top, the body), not 370 one-column fills: it
        // redraws on every change while a knob turns, and the columns cost the Mixer its frames (2026-11-06)
        var tops: [(Double, Double)] = [], mids: [(Double, Double)] = []
        var e = 1.0
        for x in 44...229 {
            let h = 84 * e
            tops.append((Double(x), 126 - h)); mids.append((Double(x), 126 - h + h * dim))
            e *= k
        }
        let band = Path { p in
            p.addLines(tops.map { s.p($0.0, $0.1) })
            p.addLines(mids.reversed().map { s.p($0.0, $0.1) })
            p.closeSubpath()
        }
        let body = Path { p in
            p.addLines(mids.map { s.p($0.0, $0.1) })
            p.addLine(to: s.p(229, 126)); p.addLine(to: s.p(44, 126))
            p.closeSubpath()
        }
        let from = s.p(44, 0), to = s.p(228, 0)
        ctx.fill(band, with: .linearGradient(Gradient(colors: [c.opacity(0.45), c.opacity(0.15)]), startPoint: from, endPoint: to))
        ctx.fill(body, with: .linearGradient(Gradient(colors: [c.opacity(1), c.opacity(0.4)]), startPoint: from, endPoint: to))
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

// MARK: FX (ui_graph.c graph_fx): the four sends as sliders under their columns

private struct FXDrawing {
    let v: [Int]                                  // DIST, CHORUS, DELAY, REVERB

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        for i in 0..<4 {
            let x = 30 + Double(i) * 60 - 2, h = Double(v[i] * 76 / 127)      // under each column's middle
            ctx.fill(Path(roundedRect: s.r(x, 6, 4, 82), cornerRadius: 2), with: .color(Theme.tones[2]))
            if h > 3 { ctx.fill(Path(roundedRect: s.r(x, 88 - h, 4, h), cornerRadius: 2), with: .color(c)) }
            let cap = s.r(x - 4, 85 - h, 12, 6)
            ctx.fill(Path(roundedRect: CGRect(x: cap.midX - 9, y: cap.minY, width: 18, height: max(6, cap.height)), cornerRadius: 3), with: .color(c))
        }
    }
}

// MARK: The curve and the wave (ui_pgraph.c pg_curve_graph), DRIVE's look, shared with INSERT

private func curveGraph(_ ctx: GraphicsContext, _ s: Space, _ c: Color, at: (Int) -> Int, wave w: [Int]) {
    let ys = (0...116).map { i in 66 - Double(at((i - 58) * 32768 / 58)) * 58 / 32768 }
    let pts = ys.enumerated().map { (12 + Double($0.offset), $0.element) }
    var under = s.line(pts)
    under.addLine(to: s.p(128, 124)); under.addLine(to: s.p(12, 124)); under.closeSubpath()
    ctx.fill(under, with: .color(c.opacity(0.14)))
    ctx.fill(Path(s.r(12, 66, 116, 1)), with: .color(lineColour))
    ctx.fill(Path(s.r(70, 8, 1, 117)), with: .color(lineColour))
    ctx.fill(Path(s.r(140, 88, 87, 1)), with: .color(lineColour))
    ctx.stroke(s.line([(12, 124), (128, 8)]), with: .color(dimColour), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    ctx.stroke(s.line(pts), with: .color(c), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    let wp = w.enumerated().map { (140 + Double($0.offset), 88 - Double($0.element) * 32 / 32768) }
    var wf = s.line(wp)
    wf.addLine(to: s.p(227, 88)); wf.addLine(to: s.p(140, 88)); wf.closeSubpath()
    ctx.fill(wf, with: .color(c.opacity(0.14)))
    ctx.stroke(s.line(wp), with: .color(c), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
}

// MARK: INSERT + INSERT 2 (ui_pgraph.c graph_insert, fx.c ins_*)

private struct InsertDrawing {
    let v: [Int]                                  // TYPE, A, B, C, MIX
    static let names = ["OFF", "SOFT", "HARD", "FOLD", "FUZZ", "CRUSH", "PHASR", "FLANG", "CHOR"]

    static func sine(_ ph: UInt32) -> Int { Int(32767 * sin(Double(ph) / 4_294_967_296 * 2 * .pi)) }
    static func tri(_ q: UInt32) -> Int { let t = q >> 16; return Int(t < 32768 ? t << 1 : (65535 - t) << 1) }
    /// LEVEL_Q12: 0 off, else (v − 112) / 2 dB.
    static func level(_ v: Int) -> Int { v <= 0 ? 0 : Int((4096 * pow(10, Double(v - 112) / 40)).rounded()) }
    /// ins_lpk: the one-pole low-pass of cutoff index c (SVF_G), Q16.
    static func lpk(_ c: Int) -> Int {
        let f = 30 * pow(16000.0 / 30, Double(min(max(c, 0), 127)) / 127)
        let g = Int(4096 * tan(Double.pi * min(f, 0.45 * 44100) / 44100))
        return (g << 16) / (4096 + g)
    }
    static func mixq(_ m: Int) -> Int { m >= 127 ? 32768 : m <= 0 ? 0 : m * 258 }
    /// IT_* to DriveDrawing's shapes (SOFT HARD FOLD CRUSH FUZZ).
    static let shapeOf = [0: -1, 1: 0, 2: 1, 3: 2, 4: 4, 5: 3]

    /// pg_ins_curve: the drives' transfer blended by MIX; the swept ones' sweep over a cycle.
    func at(_ x: Int) -> Int {
        let ty = v[0], a = v[1], b = v[2], c = v[3], mix = Self.mixq(v[4])
        guard ty > 0, mix > 0 else { return x }
        if ty >= 6 {
            let ph = UInt32(truncatingIfNeeded: x + 32768) << 16
            var s = ty == 8 ? Self.sine(ph) : Self.tri(ph) - 32768
            if ty == 7 { s = Int((UInt32(s + 32768) * UInt32(s + 32768)) >> 16) - 32768 }
            return s * b / 127
        }
        let y = ty == 5 ? DriveDrawing.shape(3, x, 15 - (min(max(a, 0), 127) >> 3))
            : (DriveDrawing.shape(Self.shapeOf[ty] ?? 0, ((x >> 3) * (4096 + a * a * 3)) >> 9, 0) * Self.level(c)) >> 12
        return x + Int((Int64(min(max(y, -40000), 40000) - x) * Int64(mix)) >> 15)
    }

    func wave() -> [Int] {
        let ty = v[0], b = v[2], c = v[3]
        let hold = [64, 48, 40, 32, 24, 20, 16, 12, 10, 8, 6, 5, 4, 3, 2, 1][min(max(b, 0), 127) >> 3]
        let kq = Self.lpk(ty == 5 ? c : b)
        var lp1 = 0, lp2 = 0, h = 0, out = [Int](repeating: 0, count: 88)
        for i in 0..<176 {
            let x = Self.sine(UInt32(truncatingIfNeeded: i &* 48_806_447)) * 3 / 4
            let y: Int
            if ty >= 6 {
                y = at((i % 44) * 65536 / 44 - 32768)
            } else {
                if ty != 5 || i % hold == 0 { h = at(x) }
                lp1 += ((h - lp1) * kq >> 16) * 2
                lp2 += ((lp1 - lp2) * kq >> 16) * 2
                y = ty != 0 ? lp2 : x
            }
            if i >= 88 { out[i - 88] = y }
        }
        return out
    }

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        curveGraph(ctx, s, c, at: at, wave: wave())
        s.text(ctx, Self.names[safe: v[0]] ?? "OFF", 140, 26, v[0] != 0 && v[4] != 0 ? c : dimColour, size: 13, weight: .semibold)
    }
}

// MARK: SLICER (ui_graph.c graph_slicer)

private struct SlicerDrawing {
    let v: [Int]                                  // SLICER (OFF GATE STUT), PATTERN 1…16, RATE, DEPTH
    static let patterns: [UInt16] = [0x5555, 0xB6DB, 0x5249, 0xB777, 0x6D6D, 0x0F0F, 0x1111, 0x54A5,
                                     0x5333, 0xA929, 0xAAFF, 0xD501, 0xAAAA, 0xAB6B, 0xBB5D, 0x7597]

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let pat = Self.patterns[((v[1] - 1) % 16 + 16) % 16], mode = v[0]
        let open = Double(70 - v[3] * 70 / 127)
        let col = mode == 0 ? dimColour : c
        for i in 0..<16 {
            let x = Double(12 + i * 13 + (i / 4) * 4)
            if pat >> i & 1 == 1 {
                ctx.fill(Path(roundedRect: s.r(x, 8, 9, 72), cornerRadius: 2), with: .color(mode == 0 ? Theme.tones[2] : col))
            } else if mode == 2 {
                for y in stride(from: 8.0, to: 80, by: 4) { ctx.fill(Path(s.r(x, y, 9, 1)), with: .color(col)) }
            } else {
                ctx.fill(Path(roundedRect: s.r(x, 77, 9, 3), cornerRadius: 1), with: .color(Theme.tones[2]))
                if open > 3 { ctx.fill(Path(roundedRect: s.r(x, 80 - open, 9, open), cornerRadius: 2), with: .color(Theme.tones[2])) }
            }
        }
    }
}

// MARK: SCALE, CHORD, FOLLOW (ui_graph.c graph_scale, graph_chord, graph_follow)

private let blackKeys: [Bool] = [false, true, false, true, false, false, true, false, true, false, true, false]

/// SCALE: the 12 keys as rounded bars, black keys high and white low: in the scale the track's colour, the root
/// white (Skiff's accent), out of it the raised grey.
private struct ScaleDrawing {
    let root: Int
    let scale: Int

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let mask = SkiffChord.scaleMask(scale)
        for i in 0..<12 {
            let deg = ((i - root) % 12 + 12) % 12
            let col: Color = (mask >> deg) & 1 != 0 ? (deg == 0 ? Theme.text : c) : Theme.tones[2]
            ctx.fill(Path(roundedRect: s.r(Double(13 + i * 18 + 3), blackKeys[i] ? 6 : 38, 10, 52), cornerRadius: 3), with: .color(col))
        }
    }
}

/// CHORD and FOLLOW: a chord's name over the keys from the C below its lowest note (two octaves, three for a wide
/// one), its notes in the track's colour and its root white; or, where there's no chord to draw, two lines that say
/// why (Skiff's panel_note).
private struct ChordDrawing {
    var name = "", caption = ""
    var notes: [Int] = []
    var accent = 0
    var keysColour: Color?
    var note: (String, String?)?
    var noteColour: Color?

    init(name: String, caption: String, notes: [Int], accent: Int, keysColour: Color?) {
        self.name = name; self.caption = caption; self.notes = notes; self.accent = accent; self.keysColour = keysColour
    }
    init(note: (String, String?), noteColour: Color? = nil) { self.note = note; self.noteColour = noteColour }

    var spoken: String {
        if let note { return [note.0, note.1].compactMap { $0 }.joined(separator: ", ").lowercased() }
        return "\(name), \(notes.map { Music.spokenNoteName($0) }.joined(separator: ", "))"
    }

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        if let note {
            s.text(ctx, note.0, 120, 56, noteColour ?? Theme.text, size: 13, weight: .semibold, anchor: .bottom)
            if let b = note.1 { s.text(ctx, b, 120, 76, midColour, anchor: .bottom) }
            return
        }
        guard let first = notes.first, let last = notes.last else { return }
        s.text(ctx, name, 14, 26, Theme.text, size: 17, weight: .semibold)
        s.text(ctx, caption, 226, 26, midColour, anchor: .bottomTrailing)
        let lo = first - first % 12, cnt = last - lo < 24 ? 24 : 36, w = 216 / cnt
        for i in 0..<cnt {
            let n = lo + i, on = notes.contains(n)
            let col: Color = !on ? Theme.tones[2] : n % 12 == accent ? Theme.text : (keysColour ?? c)
            ctx.fill(Path(roundedRect: s.r(Double(13 + i * w), blackKeys[n % 12] ? 36 : 62, Double(w - 2), 48), cornerRadius: w > 6 ? 3 : 2),
                     with: .color(col))
        }
    }
}

// MARK: ARP, ARP 2 (ui_pgraph.c graph_arp)

/// The arp's notes over 16 of its steps as arp_step plays them, on an example chord (C E G: the protocol doesn't say
/// which keys the FM-1 holds) through OCTAVE and MODE: a tile as long as GATE, the off steps late by SWING, every fourth
/// step white, the steps CHANCE would skip (a fixed pick) outlined; OFF all dim.
private struct ArpDrawing {
    let v: [Int]                                  // MODE RATE OCTAVE GATE, SWING CHANCE HOLD ORDER

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let m = v[0], oct = max(1, v[2])
        var list: [Int] = []
        for o in 0..<oct { for n in [60, 64, 67] where list.count < 64 { list.append(min(127, n + 12 * o)) } }
        if m == 6 { list = [67] }                                         // REPEAT
        if m == 8 { list.append(min(127, list[0] + 12 * oct)) }           // UP+8
        let len = list.count
        let pitch = min(18, 102 / len), th = pitch >= 12 ? 10 : pitch > 3 ? pitch - 1 : 2
        let base = 115 - (102 - (len - 1) * pitch) / 2
        let gw = 2 + v[3] * 10 / 127, sw = v[4] * 12 / 250
        for i in 0..<len {
            let y = Double(base - i * pitch)
            for x in stride(from: 30, through: 228, by: 3) { ctx.fill(Path(s.r(Double(x), y, 1, 1)), with: .color(lineColour)) }
            if pitch >= 12 { s.text(ctx, Music.noteNames[list[i] % 12], 12, y + 4, dimColour) }
        }
        s.text(ctx, "EXAMPLE: C E G", 228, 13, dimColour, anchor: .bottomTrailing)
        for i in 0..<16 {
            let k = i % (2 * len > 2 ? 2 * len - 2 : 1)
            let x = 30 + i * 124 / 10 + (i & 1 == 1 ? sw : 0)
            let hash = UInt32(truncatingIfNeeded: UInt64(i) &* 2654435761)
            var r: Int
            switch m {
            case 2: r = len - 1 - i % len
            case 3: r = k < len ? k : 2 * len - 2 - k
            case 7: r = k < len ? len - 1 - k : k - (len - 1)
            case 4, 13: r = Int(hash >> 20) % len
            case 9, 10:
                var q = i % len
                if m == 10 { q = len - 1 - q }
                r = q & 1 == 1 ? len - 1 - q / 2 : q / 2
            case 11: r = len < 2 ? 0 : k & 1 == 1 ? len - 1 : k / 2
            case 12: r = len < 2 ? 0 : k & 1 == 1 ? 1 + k / 2 : 0
            default: r = i % len
            }
            var rows = [r]
            if m == 14 { rows = (0..<3).map { min(len - 1, (i % oct) * 3 + $0) } }   // CHORD: the held notes together
            let skip = Int(hash >> 25 & 127) > v[5]
            for row in rows {
                let y = base - row * pitch - th / 2
                let col: Color = m == 0 ? dimColour : i % 4 == 0 ? Theme.text : c
                let rect = Path(roundedRect: s.r(Double(x), Double(y), Double(gw), Double(th)), cornerRadius: 1.5)
                if skip { ctx.stroke(rect, with: .color(midColour), lineWidth: 1) } else { ctx.fill(rect, with: .color(col)) }
            }
        }
    }
}

// MARK: DUCK (ui_graph.c graph_duck)

/// The track's level over a bar of its source's hits: full, down by DEPTH at each hit (the source's colour under
/// it; a drum source's kick lane only), back in a line over RELEASE. BY OFF (or the track itself): the empty box.
private struct DuckDrawing {
    let depth: Int
    let release: Double                           // RELEASE as a part of the bar
    let hits: [Double]?                           // where in the bar (0…1) the source hits
    let colour: Color

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        ctx.fill(Path(s.r(8, 10, 224, 62)), with: .color(Theme.tones[2]))
        guard let hits else { return }
        for h in hits { ctx.fill(Path(s.r(8 + h * 224, 78, 3, 8)), with: .color(colour)) }
        for x in 0..<224 {
            let tau = Double(x) / 224
            var dip = 0.0
            if let last = hits.last(where: { $0 <= tau }) ?? hits.last {
                let dt = last <= tau ? tau - last : tau + 1 - last
                if release > 0, dt < release { dip = 62 * Double(depth) / 127 * (release - dt) / release }
            }
            ctx.fill(Path(s.r(8 + Double(x), 10 + dip, 1.2, 62 - dip)), with: .color(c))
        }
    }
}

// MARK: MOD (ui_graph.c graph_mod): the fixed routes' grid, the matrix's slots, the route picked lit

struct ModGraph: View {
    let session: DeviceSession
    let page: SoundPage
    @Binding var route: Int
    let colour: Color

    static let cx: [Double] = [84, 124, 166, 208]

    private func value(_ id: Int?) -> Int { id.map { session.cell($0).value } ?? 0 }
    private func shown(_ id: Int?) -> String { formatValue(id.flatMap { session.trackDesc($0) }, value(id)).shown }

    var body: some View {
        GeometryReader { g in
            Canvas { ctx, sz in draw(ctx, Space(size: sz)) }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { e in pick(Space(size: g.size).back(e.location)) })
        }
        .accessibilityElement()
        .accessibilityLabel("Modulation routes")
        .accessibilityValue("route \(route + 1) of 11")
        .accessibilityAdjustableAction { d in route = min(10, max(0, route + (d == .increment ? 1 : -1))) }
    }

    /// A tap on a value in the grid or a slot's row picks that route (as KNOB 1 does).
    private func pick(_ p: (Double, Double)) {
        let (x, y) = p
        if y < 64 {
            let row = y < 42 ? 0 : 1
            guard let col = Self.cx.indices.min(by: { abs(Self.cx[$0] - x) < abs(Self.cx[$1] - x) }), x > 60 else { return }
            let q = row * 4 + col
            if q < 7 { route = q }
        } else {
            let k = Int((y - 67) / 18)
            if (0..<4).contains(k) { route = 7 + k }
        }
    }

    private func draw(_ ctx: GraphicsContext, _ s: Space) {
        let cols = ["PITCH", "CUT", "SHAPE", "AMP"]
        for (k, n) in cols.enumerated() { s.text(ctx, n, Self.cx[k], 16, midColour, anchor: .bottom) }
        for q in 0..<8 {
            let base = 35 + 21 * Double(q / 4), x = Self.cx[q % 4]
            if q % 4 == 0 { s.text(ctx, q == 0 ? "LFO" : "ENV", 12, base, Theme.text, weight: .semibold) }
            let sel = q < 7 && q == route
            let id = q < 7 ? page.routes[safe: q]?.first ?? nil : nil
            // the grid's values without their unit, as Skiff writes them; the route picked white (Skiff's T_THEME)
            let text = q < 7 ? splitUnit(shown(id)).value : "–"
            if sel { ctx.fill(Path(roundedRect: s.r(x - 19, base - 14, 39, 19), cornerRadius: 4), with: .color(Theme.text)) }
            let v = q < 7 ? value(id) : 0
            s.text(ctx, text, x, base + 1, sel ? Theme.onColour : v == 0 ? dimColour : colour, size: 12, weight: .semibold, anchor: .bottom)
        }
        ctx.fill(Path(s.r(8, 64, 224, 1)), with: .color(lineColour))
        for k in 0..<4 {
            let r = page.routes[safe: 7 + k] ?? [nil, nil, nil]
            let y = 67 + 18 * Double(k), sel = route == 7 + k
            let on = value(r[safe: 0] ?? nil) != 0 && value(r[safe: 1] ?? nil) != 0 && value(r[safe: 2] ?? nil) != 0
            let col = sel ? Theme.onColour : on ? colour : dimColour, ar = sel ? Theme.onColour : on ? Theme.text : dimColour
            if sel { ctx.fill(Path(roundedRect: s.r(6, y, 228, 17), cornerRadius: 4), with: .color(Theme.text)) }
            s.text(ctx, "\(8 + k)", 12, y + 13, sel ? Theme.onColour : midColour)
            s.text(ctx, shown(r[safe: 0] ?? nil), 34, y + 13, col, weight: .semibold)
            ctx.stroke(s.line([(78, y + 8), (95, y + 8)]), with: .color(ar), lineWidth: 1)
            ctx.stroke(s.line([(91, y + 4), (95, y + 8), (91, y + 12)]), with: .color(ar), lineWidth: 1)
            s.text(ctx, shown(r[safe: 1] ?? nil), 102, y + 13, col, weight: .semibold)
            s.text(ctx, shown(r[safe: 2] ?? nil), 228, y + 13, col, weight: .semibold, anchor: .bottomTrailing)
        }
    }
}

// MARK: GLOBAL (ui_pgraph.c graph_global)

/// A bar's 16 steps (a beat's tallest), the off steps late by SWING+ over a mark where they would be straight,
/// the beats numbered, the long and short steps' share.
private struct GlobalDrawing {
    let swing: Int

    func draw(_ ctx: GraphicsContext, _ s: Space, _ c: Color) {
        let push = Double(swing * 13 / 250)
        for i in 0..<16 {
            var x = Double(14 + i * 13)
            let h: Double = i % 4 == 0 ? 74 : i % 2 == 0 ? 52 : 40
            if i % 2 == 1 {
                ctx.fill(Path(s.r(x, 125, 7, 3)), with: .color(dimColour))
                x += push
            }
            let col = i % 4 == 0 ? Theme.text : i % 2 == 0 ? c : c.opacity(0.65)
            ctx.fill(Path(roundedRect: s.r(x, 120 - h, 7, h), cornerRadius: 1.5), with: .color(col))
        }
        for i in 0..<4 { s.text(ctx, "\(i + 1)", Double(14 + i * 52), 36, midColour, size: 13, weight: .semibold) }
        s.text(ctx, "SWING \(50 + swing * 50 / 250):\(50 - swing * 50 / 250)", 228, 16, midColour, anchor: .bottomTrailing)
    }
}


extension EnvironmentValues {
    /// The graphs wait (the sound panel still sliding in): their wells hold the place, drawn once it settles.
    @Entry var graphsDeferred = false
}

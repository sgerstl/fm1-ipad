import SloopKit
import SwiftUI

/// The FM-1's page graphs, drawn from the same values as the knobs beside them (firmware ui_draw.c),
/// so the iPad and the device never disagree. Read-only: the knobs set the values.

/// ENV: attack linear, decay and release exponential (~99 % after the set time), the time axis the
/// parameter value, as graph_adsr draws it. The segment of the knob being turned is lit.
struct EnvelopeGraph: View {
    let attack: Int, decay: Int, sustain: Int, release: Int
    let colour: Color
    var active: Int?                     // 0 A, 1 D, 2 S, 3 R

    var body: some View {
        Canvas { ctx, size in
            let segs = segments()
            let sx = size.width / 240, bot: CGFloat = 90
            let sy = size.height / (bot + 6)
            func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * sx, y: p.y * sy) }
            // the floor
            ctx.fill(Path(CGRect(x: 0, y: (bot + 1) * sy, width: size.width, height: 1)), with: .color(.white.opacity(0.12)))
            // the fill under the curve, faint
            var area = Path()
            area.move(to: pt(CGPoint(x: 6, y: bot)))
            for s in segs { for p in s { area.addLine(to: pt(p)) } }
            if let last = segs.last?.last { area.addLine(to: pt(CGPoint(x: last.x, y: bot))) }
            area.closeSubpath()
            ctx.fill(area, with: .color(colour.opacity(0.12)))
            // the curve, the turned segment brighter and thicker
            for (k, s) in segs.enumerated() {
                var p = Path()
                p.addLines(s.map(pt))
                let on = active == k
                ctx.stroke(p, with: .color(on ? Theme.text : colour), style: StrokeStyle(lineWidth: on ? 3 : 2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Envelope shape")
        .accessibilityValue("attack \(attack), decay \(decay), sustain \(sustain), release \(release)")
    }

    /// The four segments in the FM-1's 240-wide drawing space.
    private func segments() -> [[CGPoint]] {
        let a = 4 + Double(attack) * 50 / 127, d = Int(6 + Double(decay) * 50 / 127), r = Int(6 + Double(release) * 60 / 127)
        let top = 8.0, bot = 90.0, sus = Double(sustain) / 127
        func y(_ lvl: Double) -> Double { bot - lvl * (bot - top) }
        let x0 = 6.0, x1 = x0 + a, x3 = 232.0 - Double(r)
        let attackSeg = [CGPoint(x: x0, y: bot), CGPoint(x: x1, y: top)]
        var decaySeg = [CGPoint(x: x1, y: top)], e = 1.0
        let kd = 1 - 4.6 / Double(d)
        for i in 1...d { e *= kd; decaySeg.append(CGPoint(x: x1 + Double(i), y: y(sus + (1 - sus) * e))) }
        let sustainSeg = [decaySeg.last!, CGPoint(x: x3, y: y(sus))]
        var releaseSeg = [CGPoint(x: x3, y: y(sus))]
        e = 1
        let kr = 1 - 4.6 / Double(r)
        for i in 1...r { e *= kr; releaseSeg.append(CGPoint(x: x3 + Double(i), y: y(sus * e))) }
        return [attackSeg, decaySeg, sustainSeg, releaseSeg]
    }
}

/// LFO: two cycles of the wave from its phase, as graph_lfo draws it (S&H as stepped random levels).
struct LFOGraph: View {
    let wave: Int, phase: Int
    let colour: Color

    static let names = ["SIN", "TRI", "SAW", "SQR", "S&H"]

    var body: some View {
        Canvas { ctx, size in
            let mid = size.height / 2, amp = size.height * 0.42
            ctx.fill(Path(CGRect(x: 0, y: mid, width: size.width, height: 1)), with: .color(.white.opacity(0.12)))
            var p = Path()
            let n = 240
            for x in 0..<n {
                let v = value(at: x)
                let pt = CGPoint(x: CGFloat(x) / CGFloat(n - 1) * size.width, y: mid - CGFloat(v) * amp)
                if x == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(colour), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityElement()
        .accessibilityLabel("LFO wave")
        .accessibilityValue("\(Self.names[safe: wave] ?? "wave \(wave)"), phase \(phase)")
    }

    /// -1 ... 1 at column x of 240 (firmware voice.c lfo_wave, dsp.c osc_tri / osc_sine).
    private func value(at x: Int) -> Double {
        let ph = UInt32(truncatingIfNeeded: (UInt64(phase & 127) << 25) &+ UInt64(x) &* UInt64(0xFFFF_FFFF / 120))
        switch wave {
        case 1:
            let s = Int(ph >> 15)
            return Double(s < 65536 ? s - 32768 : 98303 - s) / 32768
        case 2: return Double(Int(ph >> 16) - 32768) / 32768
        case 3: return ph < 0x8000_0000 ? 1 : -1
        case 4:
            let h = UInt32(truncatingIfNeeded: UInt64(x / 20) &* 2_654_435_761)
            return Double(Int(h >> 16) - 32768) / 32768
        default: return sin(Double(ph) / 4_294_967_296 * 2 * .pi)
        }
    }
}

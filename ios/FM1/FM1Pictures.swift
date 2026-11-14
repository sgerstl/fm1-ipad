import SloopKit
import SwiftUI

// The Mix pop-up's pictures redrawn from the FM-1's own drawings (vault decision 34, board 77; Skiff 2.5.1's
// `ui_pgraph.c`, formulas with file and line in `design/boards/fm1-screens/NOTES.md`): GLO › DELAY, REVERB, CHORUS and
// GLOBAL in the FM-1's coordinates (x 0–240, canvas y 0–137, so its 1.7 : 1), square corners and whole-pixel stepped
// tails, no gradients or fades it doesn't draw. Colour stays global: where the FM-1 uses the selected track's colour
// these use a light grey, its darker mixes kept apart as greys (`mix`), white stays white. iPhone only (PhoneMixPopup).

struct FM1Picture: View {
    let session: DeviceSession
    let page: SoundPage

    static let titles: Set<String> = ["DELAY", "REVERB", "CHORUS", "GLOBAL"]
    static let size = CGSize(width: 240, height: 137)

    // the FM-1's theme roles, in Lupe's greys
    private let c = Theme.textSecondaryRaised          // the track colour's place
    private let surf = Theme.well                      // T_SURF
    private let white = Theme.text, mid = Theme.textSecondary, dim = Theme.textTertiary, line = Theme.stepEmpty

    /// ux_mix(a, b, p): from a toward b by p %.
    private func mix(_ a: Color, _ b: Color, _ p: Double) -> Color {
        let x = UIColor(a), y = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        x.getRed(&r1, green: &g1, blue: &b1, alpha: &a1); y.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(min(max(p, 0), 100) / 100)
        return Color(red: r1 + (r2 - r1) * k, green: g1 + (g2 - g1) * k, blue: b1 + (b2 - b1) * k)
    }

    /// Knob k's raw value and what it shows.
    private func knob(_ k: Int) -> (value: Int, shown: String) {
        guard let id = page.ids[safe: k] ?? nil else { return (0, "") }
        let s = KnobSpec.param(session, scope: page.scope(of: k), id: id, slot: k)
        return (s.value, s.shown)
    }

    var body: some View {
        Canvas { ctx, sz in
            // the FM-1's canvas scaled to fit, centred
            let k = min(sz.width / Self.size.width, sz.height / Self.size.height)
            ctx.translateBy(x: (sz.width - Self.size.width * k) / 2, y: (sz.height - Self.size.height * k) / 2)
            ctx.scaleBy(x: k, y: k)
            switch page.title {
            case "DELAY": delay(ctx)
            case "REVERB": reverb(ctx)
            case "CHORUS": chorus(ctx)
            default: global(ctx)
            }
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .accessibilityHidden(true)            // the dials beside it say every value
    }

    private func rect(_ ctx: GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: Color) {
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(col))
    }
    private func text(_ ctx: GraphicsContext, _ s: String, _ x: Double, baseline y: Double, _ col: Color, size: CGFloat = 9, trailing: Bool = false) {
        ctx.draw(Text(s).font(.lupe(size, .semibold)).foregroundStyle(col), at: CGPoint(x: x, y: y), anchor: trailing ? .bottomTrailing : .bottomLeading)
    }

    // MARK: DELAY (ui_pgraph.c:21–78)

    /// TIME in sixths of a 1/16 (DLY_6TH), read from the name the FM-1 gives it.
    private static func sixths(_ name: String) -> Double {
        let n = name.uppercased().replacingOccurrences(of: " ", with: "")
        let table: [String: Double] = ["1/32": 3, "1/16T": 4, "1/16": 6, "1/16D": 9, "1/8T": 8, "8T": 8, "1/8": 12, "1/8D": 18,
                                       "1/4T": 16, "4T": 16, "1/4": 24, "1/4D": 36, "1/2T": 32, "1/2": 48, "1/2D": 72,
                                       "1BAR": 96, "1/1": 96, "2BAR": 192, "16T": 4]
        return table[n] ?? 12
    }

    private func delay(_ ctx: GraphicsContext) {
        let tap = Self.sixths(knob(0).shown), fb = Double(knob(1).value), mixV = Double(knob(3).value)
        let win = max(tap * 4, 96)
        // the ruler: a tick a beat (or a bar when TIME is longer than a beat), numbered
        let beat = tap > 24 ? 96.0 : 24.0
        let ticks = Int(win / beat)
        for i in 0...ticks {
            let x = 14 + Double(i) * beat * 208 / win
            guard x <= 228 else { break }
            rect(ctx, x, 123, 2, 3, dim)
            if ticks <= 8 || i % 4 == 0 { text(ctx, "\(i + 1)", x, baseline: 136, dim, size: 8) }
        }
        let w = min(max(tap * 208 / win - 3, 2), 13)
        var h = 100.0
        for i in 0..<9 {
            let x = 14 + Double(i) * tap * 208 / win
            if i == 0 {
                rect(ctx, x, 120 - 100, w, 100, white)          // the dry hit
            } else {
                h = i == 1 ? mixV * 1000 / 127 / 10 : h * fb * 230 / 32768
                let hp = h.rounded(.down)
                if hp < 4 || x > 228 { break }
                rect(ctx, x, 120 - hp, w, hp, mix(c, surf, 15 + 50 * Double(i - 1) / 6))
            }
        }
        text(ctx, "DRY", 14, baseline: 16, mid)
    }

    // MARK: REVERB (ui_pgraph.c:82–147)

    private func reverb(_ ctx: GraphicsContext) {
        let type = knob(0).value, size = Double(knob(1).value), damp = Double(knob(2).value)
        // early reflections: five white bars
        for (i, h) in [84.0, 60, 72, 46, 52].enumerated() { rect(ctx, 12 + Double(i) * 6, 126 - h, 3, h, white) }
        // the tail, a column a pixel, whole-pixel heights (the staircase into the floor); a dark top band DAMP sets
        var len = 40 + size * 144 / 127
        if type == 2 { len *= 2 }
        let kk = 1 - 3 / len
        let dimP = (20 + damp * 60 / 127) / 100
        var e = 1.0
        for x in 44...228 {
            let h = (84 * e).rounded(.down)
            if h >= 1 {
                let f = Double(x - 44) / 184
                let band = (h * dimP).rounded(.down)
                // (1.5 wide over a 1 pt step: scaled up, 1-wide columns showed hairline seams between them)
                rect(ctx, Double(x), 126 - h, 1.5, band, mix(c, surf, 55 + 30 * f))
                rect(ctx, Double(x), 126 - h + band, 1.5, h - band, mix(c, surf, 60 * f))
            }
            e *= kk
        }
        text(ctx, ["ROOM", "SPRING", "HALL"][safe: type] ?? "ROOM", 12, baseline: 17, mid)
        if type == 1 {
            // SPRING: a 1 px coil, ±3 px round y 13
            var p = Path()
            for x in 64...228 {
                let y = 13 + 3 * sin(Double(x - 64) * 13 / 256 * 2 * .pi)
                if x == 64 { p.move(to: CGPoint(x: Double(x), y: y)) } else { p.addLine(to: CGPoint(x: Double(x), y: y)) }
            }
            ctx.stroke(p, with: .color(mid), lineWidth: 1)
        }
    }

    // MARK: CHORUS (ui_pgraph.c:152–243)

    private func chorus(_ ctx: GraphicsContext) {
        let rate = Double(knob(0).value), depth = Double(knob(1).value), mode = knob(2).value, fb = Double(knob(3).value)
        if mode == 0 {
            rect(ctx, 12, 74, 216, 1, mid)                        // the dry
            let a = depth * 44 / 127, cycles = 1 + rate * 5 / 127
            func wave(_ amp: Double, _ phase: Double) -> Path {
                var p = Path()
                for x in stride(from: 0.0, through: 216, by: 2) {
                    let y = 74 - amp * sin((x / 216 * cycles + phase) * 2 * .pi)
                    if x == 0 { p.move(to: CGPoint(x: 12 + x, y: y)) } else { p.addLine(to: CGPoint(x: 12 + x, y: y)) }
                }
                return p
            }
            if fb > 0 { ctx.stroke(wave(a * fb / 127, 3.0 / 16), with: .color(mid), lineWidth: 1) }
            ctx.stroke(wave(a, 0), with: .color(c), lineWidth: 3)
            text(ctx, "DRY AND ITS DRIFTING COPY", 12, baseline: 16, mid)
        } else {
            // FLANGER's comb or PHASER's two notches: the response as a 3 px line, filled under it (25 % colour)
            func resp(_ x: Double) -> Double {
                if mode == 1 {
                    let teeth = 4 + depth * 6 / 127
                    let r = abs(cos(x / 216 * teeth * .pi))
                    return pow(r, 1 + fb / 32) * (0.6 + 0.4 * fb / 127)
                }
                let w = 10 + depth / 8
                var r = 1.0
                for n in [66.0, 150] {
                    r -= exp(-pow((x - n) / w, 2))
                    if fb > 0 { r += 0.4 * fb / 127 * exp(-pow((x - n - w * 1.5) / (w * 0.6), 2)) }
                }
                return min(max(r, 0), 1.4)
            }
            rect(ctx, 12, mode == 1 ? 84 : 84, 216, 1, line)
            var p = Path()
            for x in 0...216 {
                let y = 124 - resp(Double(x)) * 40
                rect(ctx, 12 + Double(x), y, 1.5, 124 - y, mix(c, surf, 75))
                if x == 0 { p.move(to: CGPoint(x: 12, y: y)) } else { p.addLine(to: CGPoint(x: 12 + Double(x), y: y)) }
            }
            ctx.stroke(p, with: .color(c), lineWidth: 3)
            text(ctx, mode == 1 ? "THE DRY AND ITS COPY: A COMB, SWEPT" : "FOUR STAGES: TWO NOTCHES, SWEPT", 12, baseline: 16, mid)
        }
    }

    // MARK: GLOBAL (ui_pgraph.c:431–468)

    private func global(_ ctx: GraphicsContext) {
        let swing = Double(knob(1).value)
        let push = (swing * 13 / 250).rounded(.down)
        for i in 0..<16 {
            let x = 14 + Double(i) * 13
            if i % 4 == 0 { rect(ctx, x, 120 - 74, 7, 74, white) }
            else if i % 2 == 0 { rect(ctx, x, 120 - 52, 7, 52, c) }
            else {
                rect(ctx, x, 125, 7, 3, dim)                       // where the off step would be without swing
                rect(ctx, x + push, 120 - 40, 7, 40, mix(c, surf, 35))
            }
        }
        for i in 0..<4 { text(ctx, "\(i + 1)", 14 + 52 * Double(i), baseline: 36, mid, size: 12) }
        let a = Int(50 + swing * 50 / 250), b = 100 - a
        text(ctx, "SWING \(a):\(b)", 228, baseline: 16, mid, trailing: true)
    }
}

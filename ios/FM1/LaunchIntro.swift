import SwiftUI

// Lupe's launch intro (Scott: "Build it", 2026-11-05), ported from the approved prototype on refs/heads/lupe-icon,
// design/brand/intro-prototype.html (PLANS.full), its timings and drawing:
//   zoom 0.42 s: the icon grows from home-screen size past the screen, its corners straightening, the scope off with
//     only the graticule (from the launch screen: the icon on #0A0A0B, crossfading into the dark scope as it grows);
//   power-on 0.22 s: a bright line blooms open vertically, one soft green flash (a single flash: WCAG 2.3.1);
//   one pass of the Lissajous in 1.06 s: the white-hot beam, the phosphor trail cooling from pale green-white to deep
//     green, the faint full figure under it;
//   settle 0.4 s: the beam eases to the icon's rest, the phosphor stops cooling, so the last frame is the icon;
//   the name "lupe" from (end of trace + 35 % of settle) × 0.8, fading in over 0.52 s in #F4F4F6 with a soft glow;
//   hold 0.4 s; then the CRT switch-off: squash to a line 0.12 s, pinch to a dot 0.1 s, the dot blips out over 0.18 s
//   while the app fades up behind it. About 2.9 s.
// The prototype's phosphor is a canvas it fades every frame (60 a second); here each bit of trail is drawn from its
// age in those frames, so the picture is the same at any frame rate. A tap skips to the app. Reduce Motion: the
// finished logo fades in, then crossfades to the app.

struct LaunchIntro: View {
    let done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false
    /// -intro-at T: the intro held at T seconds (comparing frames with the prototype).
    private let frozen: Double? = {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-intro-at").flatMap { a.indices.contains($0 + 1) ? Double(a[$0 + 1]) : nil }
    }()

    var body: some View {
        TimelineView(.animation(paused: finished || frozen != nil)) { tl in
            let t = frozen ?? tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                var scene = IntroScene(size: size)
                if reduceMotion { scene.drawReduced(&ctx, t: t) } else { scene.draw(&ctx, t: t) }
            }
            .onChange(of: t >= (reduceMotion ? IntroScene.reducedEnd : IntroScene.plan.end)) { _, over in if over, frozen == nil { finish() } }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }                       // a tap skips straight to the app
        .accessibilityElement()
        .accessibilityLabel("Lupe")
        .accessibilityHint("Starting. Tap to skip.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
        .onAppear { start = Date() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        done()
    }
}

/// The prototype's drawing at time t (seconds since the intro started), in a view of `size`.
struct IntroScene {
    struct Plan {
        let zoom = 0.42, flash = 0.22, trace = 1.06, settle = 0.4, nameAt = 0.35, name = 0.52, hold = 0.4
        let squash = 0.12, pinch = 0.1, blip = 0.18
        var tz: Double { zoom }
        var tf: Double { tz + flash }
        var tt: Double { tf + trace }
        var ts: Double { tt + settle }
        /// The name: 20 % sooner than 35 % into the settle, about as the trace finishes.
        var na: Double { (tt + settle * nameAt) * 0.8 }
        var tn: Double { max(ts, na + name) }
        var th: Double { tn + hold }
        var to1: Double { th + squash }
        var to2: Double { to1 + pinch }
        var end: Double { to2 + blip }
    }
    static let plan = Plan()
    /// Reduce Motion: the logo fades in (about 0.28 s), stays to 1.6 s, then crossfades to the app (about 0.33 s).
    static let reducedEnd = 1.6 + 0.34

    static let beamAt = 0.31
    static let old = (14.0, 107.0, 30.0), fresh = (200.0, 255.0, 176.0)
    static let glass = Color(red: 10 / 255, green: 10 / 255, blue: 11 / 255)

    let size: CGSize
    let S: Double, ox: Double, oy: Double, W: Double, H: Double
    /// The home screen's icon, where the zoom starts (the launch screen draws it there).
    let iconSide: Double

    init(size: CGSize) {
        self.size = size
        W = size.width; H = size.height
        S = min(W, H) * 0.525                               // the scope square
        ox = (W - S) / 2; oy = (H - S * 1.32) / 2          // the scope and the name centred as one group
        iconSide = UIDevice.current.userInterfaceIdiom == .pad ? 83.5 : 60
    }

    // MARK: Geometry, as the prototype's

    /// The figure in the icon's 100-unit square: x = sin(3t + 0.9 sin 2t), y = sin 2t.
    static func fig(_ u: Double) -> (Double, Double) {
        let t = (u + beamAt) * 2 * .pi
        return (50 + sin(3 * t + 0.9 * sin(2 * t)) * 28, 50 + sin(2 * t) * 28)
    }
    func X(_ v: Double) -> Double { ox + v / 100 * S }
    func Y(_ v: Double) -> Double { oy + v / 100 * S }
    func P(_ u: Double) -> CGPoint { let f = Self.fig(u); return CGPoint(x: X(f.0), y: Y(f.1)) }
    static func ease(_ x: Double) -> Double { 1 - pow(1 - min(1, max(0, x)), 3) }
    static func green(_ a: Double) -> Color { Color(red: 85 / 255, green: 1, blue: 136 / 255).opacity(a) }
    static func rgb(_ c: (Double, Double, Double), _ a: Double = 1) -> Color { Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255).opacity(a) }

    // MARK: The frame

    mutating func draw(_ ctx: inout GraphicsContext, t: Double) {
        let p = Self.plan
        let full = CGRect(origin: .zero, size: size)
        ctx.fill(Path(full), with: .color(Self.glass))
        if t < p.tz {
            zoom(&ctx, e: Self.ease(t / p.tz))
        } else if t < p.tf {
            graticule(&ctx, 1)
            let e = (t - p.tz) / p.flash, h = S * pow(e, 2.2), a = 1 - e * 0.85
            var c = ctx
            c.addFilter(.shadow(color: Self.rgb((200, 255, 176)), radius: S * 0.04))
            let rect = CGRect(x: ox - S * 0.15 * (1 - e), y: oy + S / 2 - max(2, h / 2), width: S * (1 + 0.3 * (1 - e)), height: max(2, h))
            c.fill(Path(rect), with: .color(Self.rgb((220, 255, 210), a)))
            ctx.fill(Path(full), with: .color(Color(red: 51 / 255, green: 1, blue: 102 / 255).opacity(0.10 * (1 - e))))
        } else if t < p.th {
            scope(&ctx, t: t)
        } else {
            off(&ctx, dt: t - p.th)
        }
    }

    /// 1. The icon grows to full size, the scope off: the launch screen's icon crossfades into the dark scope while
    /// the room around it goes from the launch screen's #0A0A0B to black.
    private func zoom(_ ctx: inout GraphicsContext, e: Double) {
        let full = CGRect(origin: .zero, size: size)
        ctx.fill(Path(full), with: .color(.black.opacity(e)))
        let side = iconSide + (max(W, H) * 1.05 - iconSide) * e
        let r = CGRect(x: (W - side) / 2, y: (H - side) / 2, width: side, height: side)
        let shape = Path(roundedRect: r, cornerRadius: side * 0.225 * (1 - e), style: .continuous)
        ctx.fill(shape, with: .color(Self.glass))
        var g = ctx
        g.opacity = e
        graticule(&g, 0.6)
        var art = ctx
        art.opacity = max(0, 1 - e * 3)                       // the icon's art gone by a third of the zoom
        art.clip(to: shape)
        art.draw(Image("LupeIcon"), in: r)
    }

    /// 3–5: the trace, the settle, the name.
    private func scope(_ ctx: inout GraphicsContext, t: Double) {
        let p = Self.plan
        graticule(&ctx, 1)
        floorFigure(&ctx, min(1, (t - p.tf) / 0.4))
        trail(&ctx, t: t)
        beam(&ctx, u: beamU(t), a: 1)
        if t >= p.na { name(&ctx, Self.ease((t - p.na) / p.name)) }
    }

    /// Where the beam is: one pass in the trace, then eased 0.02 on to its rest.
    func beamU(_ t: Double) -> Double {
        let p = Self.plan
        let trace = min(1, max(0, (t - p.tf) / p.trace))
        let settle = t < p.tt ? 0 : min(1, (t - p.tt) / p.settle)
        return trace + (settle > 0 ? 0.02 * Self.ease(settle) : 0)
    }

    /// The prototype's phosphor frames (60 a second) between τ and t: each cools it by 10 % toward deep green and
    /// fades it by 5.5 %, at full rate while tracing, less as it settles (1 − ease), not at all once settled.
    static func coolFrames(from tau: Double, to t: Double) -> Double {
        let p = plan
        guard t > tau else { return 0 }
        var f = 0.0
        let a = min(tau, p.tt), b = min(t, p.tt)
        if b > a { f += (b - a) }
        // in the settle: ∫ (1 − ease(s)) = ∫ (1 − s)³ = ((1 − s₁)⁴ − (1 − s₂)⁴) / 4, in settle's time
        let s1 = min(1, max(0, (max(tau, p.tt) - p.tt) / p.settle)), s2 = min(1, max(0, (t - p.tt) / p.settle))
        if s2 > s1 { f += (pow(1 - s1, 4) - pow(1 - s2, 4)) / 4 * p.settle }
        return f * 60
    }

    /// When the beam passed u (the trail's paint time).
    static func paintTime(_ u: Double) -> Double {
        let p = plan
        if u <= 1 { return p.tf + u * p.trace }
        // u = 1 + 0.02 ease(s): s = 1 − (1 − y)^(1/3)
        let y = min(1, (u - 1) / 0.02)
        return p.tt + (1 - pow(1 - y, 1.0 / 3)) * p.settle
    }

    /// The phosphor: every bit of the path the beam has drawn, coloured and faded by its age.
    private func trail(_ ctx: inout GraphicsContext, t: Double) {
        let uNow = beamU(t)
        guard uNow > 0 else { return }
        let n = max(2, Int(ceil(uNow * 600)))
        var segs: [(Path, Double)] = []
        for i in 0..<n {
            let u0 = uNow * Double(i) / Double(n), u1 = uNow * Double(i + 1) / Double(n)
            let age = Self.coolFrames(from: Self.paintTime((u0 + u1) / 2), to: t)
            var path = Path(); path.move(to: P(u0)); path.addLine(to: P(u1))
            segs.append((path, age))
        }
        // the glow the prototype's shadow left in the phosphor, cooling with it
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: S * 0.015))
            for (path, age) in segs {
                let k = pow(0.9, age), a = 0.9 * pow(0.945, age)
                g.stroke(path, with: .color(Self.rgb(Self.mix(Self.old, (51, 255, 102), k), a)),
                         style: StrokeStyle(lineWidth: S * 0.028 * 1.6, lineCap: .round))
            }
        }
        for (path, age) in segs {
            let k = pow(0.9, age), a = pow(0.945, age)
            ctx.stroke(path, with: .color(Self.rgb(Self.mix(Self.old, Self.fresh, k), a)),
                       style: StrokeStyle(lineWidth: S * 0.028, lineCap: .round, lineJoin: .round))
        }
    }
    static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ k: Double) -> (Double, Double, Double) {
        (a.0 + (b.0 - a.0) * k, a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k)
    }

    private func graticule(_ ctx: inout GraphicsContext, _ a: Double) {
        let lw = max(1, S / 400)
        var v = 14.0
        while v <= 86 {
            var p = Path()
            p.move(to: CGPoint(x: X(v), y: Y(14))); p.addLine(to: CGPoint(x: X(v), y: Y(86)))
            p.move(to: CGPoint(x: X(14), y: Y(v))); p.addLine(to: CGPoint(x: X(86), y: Y(v)))
            ctx.stroke(p, with: .color(Self.green(0.10 * a)), lineWidth: lw)
            v += 12
        }
        var ticks = Path()
        for k in 0...30 {
            let v = 14 + 2.4 * Double(k)
            ticks.move(to: CGPoint(x: X(v), y: Y(48.8))); ticks.addLine(to: CGPoint(x: X(v), y: Y(51.2)))
            ticks.move(to: CGPoint(x: X(48.8), y: Y(v))); ticks.addLine(to: CGPoint(x: X(51.2), y: Y(v)))
        }
        ctx.stroke(ticks, with: .color(Self.green(0.16 * a)), lineWidth: lw)
    }

    /// The faint full figure still lit.
    private func floorFigure(_ ctx: inout GraphicsContext, _ a: Double) {
        var p = Path()
        for i in 0...600 { let pt = P(Double(i) / 600); i == 0 ? p.move(to: pt) : p.addLine(to: pt) }
        ctx.stroke(p, with: .color(Color(red: 51 / 255, green: 1, blue: 102 / 255).opacity(0.2 * a)),
                   style: StrokeStyle(lineWidth: S * 0.022, lineJoin: .round))
    }

    private func beam(_ ctx: inout GraphicsContext, u: Double, a: Double) {
        let c = P(u), r = S * 0.11
        let g = Gradient(stops: [.init(color: .white.opacity(a), location: 0), .init(color: .white.opacity(0.95 * a), location: 0.18),
                                 .init(color: Self.green(0.85 * a), location: 0.38), .init(color: Self.green(0), location: 1)])
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(g, center: c, startRadius: 0, endRadius: r))
        let d = S * 0.024
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - d, y: c.y - d, width: d * 2, height: d * 2)), with: .color(.white.opacity(a)))
    }

    /// The name, in the app's white with a soft white glow. The typeface is a placeholder (the prototype's Josefin
    /// Sans Light) until the wordmark is chosen: the system's light face here.
    private func name(_ ctx: inout GraphicsContext, _ a: Double) {
        var c = ctx
        c.opacity = a
        c.addFilter(.shadow(color: .white.opacity(0.45), radius: S * 0.015))
        let text = Text("lupe").font(.system(size: S * 0.16, weight: .light)).tracking(S * 0.02)
            .foregroundColor(Color(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF6 / 255))
        c.draw(text, at: CGPoint(x: W / 2, y: oy + S * 1.3), anchor: UnitPoint(x: 0.5, y: 0.78))   // its baseline there
    }

    /// 6. The switch-off: the picture squashes to a line, the line pinches to a dot, the dot blips out over the app.
    private mutating func off(_ ctx: inout GraphicsContext, dt: Double) {
        let p = Self.plan, cy = oy + S * 0.66, cx = W / 2
        let full = CGRect(origin: .zero, size: size)
        if dt < p.squash {
            ctx.fill(Path(full), with: .color(.black))
            let e = Self.ease(dt / p.squash), sy = max(0.004, 1 - e)
            var c = ctx
            c.translateBy(x: 0, y: cy); c.scaleBy(x: 1, y: sy); c.translateBy(x: 0, y: -cy)
            c.fill(Path(full), with: .color(Self.glass))
            scope(&c, t: p.th)                                // the held frame
            ctx.fill(Path(CGRect(x: 0, y: cy - H * sy / 2, width: W, height: H * sy)), with: .color(Self.rgb((200, 255, 190), 0.5 * e)))
        } else if dt < p.squash + p.pinch {
            ctx.fill(Path(full), with: .color(.black))
            let e = Self.ease((dt - p.squash) / p.pinch), w = W * 0.9 * (1 - e) + S * 0.03
            var c = ctx
            c.addFilter(.shadow(color: Self.rgb((200, 255, 190)), radius: S * 0.03))
            c.fill(Path(CGRect(x: cx - w / 2, y: cy - S * 0.006, width: w, height: S * 0.012)), with: .color(Self.rgb((242, 255, 240))))
        } else {
            // the app comes up behind: this view's black goes as the dot blips out
            let e = min(1, (dt - p.squash - p.pinch) / p.blip)
            ctx.blendMode = .copy
            ctx.fill(Path(full), with: .color(.black.opacity(1 - Self.ease(e))))
            ctx.blendMode = .normal
            let r = S * (0.03 + 0.05 * sin(min(1, e * 1.6) * .pi)), a = 1 - e
            let g = Gradient(stops: [.init(color: .white.opacity(a), location: 0), .init(color: Self.rgb((200, 255, 190), 0.8 * a), location: 0.3),
                                     .init(color: Self.green(0), location: 1)])
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 3, y: cy - r * 3, width: r * 6, height: r * 6)),
                     with: .radialGradient(g, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r * 3))
        }
    }

    // MARK: Reduce Motion: the finished logo fades in, then crossfades to the app

    mutating func drawReduced(_ ctx: inout GraphicsContext, t: Double) {
        let full = CGRect(origin: .zero, size: size)
        let fadeIn = min(1, t / 0.28), out = t < 1.6 ? 0 : min(1, (t - 1.6) / 0.33)
        ctx.blendMode = .copy
        ctx.fill(Path(full), with: .color(Self.glass.opacity(1 - out)))
        ctx.blendMode = .normal
        var c = ctx
        c.opacity = fadeIn * (1 - out)
        // the rest pose: the trail as the prototype's settled() lays it (one pass, a frame's cooling each 1/60)
        let rest = Self.plan.ts + 10                         // long after: nothing moves
        scope(&c, t: rest)
    }
}

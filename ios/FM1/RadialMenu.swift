import SwiftUI

// The phone's hold menu (design/boards/radial-menu.html; Android's HoldMenuHost, Scott 2026-11-14, decisions 31 and 36):
// the iPad's and iPhone's options, drawn as a wheel. A filled circle in the track's colour at about 45 % over the page
// grows under the finger (64 pt, an elastic grow-in: Labs › Hold menu spring); beside it a thin rim on a shallow curve
// (nearly vertical, a gentle bow: Scott, 2026-11-14), and on that curve
// up to five choices, each on its own 22 pt stalk from the rim, so every stalk is the same short length (more where the
// screen is tall enough for them all). More than fit, the column spans the screen's usable height, header to foot
// (Scott, 2026-11-15), and a small triangle past either end says there are more that way, and a drag turns the wheel and the others roll into the arc along the curve, fading as they near
// its ends; it opens with the first choice at the arc's top and settles on a choice when the finger lifts. Five or fewer
// are just the arc. The arc stays on screen under the header and flips side near an edge (Settings › Menus open). The
// page dims and a tap outside closes. A choice that loses work asks once more in place (red outline, its words naming
// what goes; taps ignored for 0.4 s). A tap picks, never a drag. Reduce Motion: fades, and the wheel turns without
// travelling. iPhone only (FanMenu routes).

struct RadialMenu: View {
    let title: String
    let items: [MenuItem]
    let at: CGPoint
    let layer: CGSize
    var tint: Int?
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: [MenuItem] = []
    @State private var start = Date()
    @AppStorage(MenuSide.key) private var hand = MenuSide.left
    @State private var confirming: Int?
    @State private var confirmAt = Date.distantPast
    @AccessibilityFocusState private var confirmFocused: Bool
    /// The wheel's turn in choices (0: the first choice at the arc's top), and its easing to where it settles.
    @State private var turnFrom: Double = 0
    @State private var turnTo: Double = 0
    @State private var turnAt = Date.distantPast
    @State private var dragFrom: Double?
    /// Takes touches once the opening finger is up (HoldFinger), or after 3 s whatever happens.
    @State private var timedOut = false
    /// How far the layer sits in from the screen's physical left and right edges (the safe area's margins).
    @State private var margins = (leading: CGFloat(0), trailing: CGFloat(0))
    private var armed: Bool { (!HoldFinger.shared.down || timedOut) && !closing }
    /// Set as it's told to close: while it fades out it takes no touches, so a hold that starts at once reaches the pad
    /// under it rather than the menu that's leaving (2026-11-14: that hold was lost with the menu).
    @State private var closing = false
    private func dismiss() { closing = true; close() }

    /// Under the header line (48 pt and its hairline), so no choice sits over the tabs.
    static let headerClear: CGFloat = 56
    static let itemW: CGFloat = 240, itemH: CGFloat = 48,   // (240: board 79's longer choices and their second lines fit)
    step: CGFloat = 56, hub: CGFloat = 32
    /// The stalks (decision 36): every one 22 pt, from the rim to the choice's near edge.
    static let stalk: CGFloat = 22
    /// The choices' curve (Scott, 2026-11-14, after cbdc2ad: shallower, nearly vertical with a gentle bow): their near
    /// edges on a circle of radius `bow` centred far behind the finger, the middle choice's `near` out from the finger.
    /// Across five choices (±112 pt) the ends come in 16 pt.
    static let bow: CGFloat = 400, near: CGFloat = 76
    /// The rim the stalks start from: the same curve 22 pt in, so it clears the hub (32) by 22 at the middle.
    static var rim: CGFloat { bow - stalk }
    /// The end triangles (more choices beyond): 10 wide, 7 tall, this far past the end choice's edge.
    static let arrowW: CGFloat = 10, arrowH: CGFloat = 7, arrowGap: CGFloat = 8
    /// Choices in the arc at once.
    static let inView = 5
    /// How long a turn takes to settle (the board's ease-out).
    static let settle = 0.32

    private var colour: Color { tint.map { Theme.track[$0] } ?? Theme.text }

    struct Spot { var edgeX: CGFloat, cy: CGFloat, left: Bool, node: CGPoint, foot: CGPoint }

    /// How far out the middle choice's near edge can sit on that side: `near`, or less where the screen's edge is closer,
    /// down to `minNear` (the rim then still clears the hub).
    static let minNear: CGFloat = hub + stalk
    /// `edges`: the screen's physical left and right edges in the menu layer's coordinates (the layer sits inside the
    /// safe area; the menu may run into its margins, the Dynamic Island's side included: Scott, 2026-11-14).
    static func room(_ x: CGFloat, _ edges: ClosedRange<CGFloat>, left: Bool) -> CGFloat {
        left ? x - edges.lowerBound - 8 - itemW : edges.upperBound - 8 - itemW - x
    }
    /// Which side the arc opens on (Scott, 2026-11-14): always away from the playing hand (Settings › Menus open), left
    /// of the finger for the right hand, wherever the press is; the other side only when the choices can't fit there.
    static func opensLeft(_ x: CGFloat, _ edges: ClosedRange<CGFloat>, hand: MenuSide) -> Bool {
        let away = hand == .left
        if room(x, edges, left: away) >= minNear { return away }
        if room(x, edges, left: !away) >= minNear { return !away }
        return room(x, edges, left: true) >= room(x, edges, left: false)
    }

    /// The curve's centre: level with the arc's middle, `bow − near` behind the finger (on the side away from the choices).
    static func centre(finger: CGPoint, mid: CGFloat, left: Bool, edges: ClosedRange<CGFloat>) -> CGPoint {
        let n = max(minNear, min(near, room(finger.x, edges, left: left)))      // closer in where the edge is near
        return CGPoint(x: left ? finger.x - n + bow : finger.x + n - bow, y: mid)
    }

    /// The choice at position `p` on the arc (0 the middle, ±2 its ends; between whole choices while the wheel turns):
    /// its centre height, its near edge where that height meets the curve, the node there, and the stalk's foot 22 pt
    /// in toward the curve's centre, on the rim.
    static func spot(p: Double, centre c: CGPoint, left: Bool, edges: ClosedRange<CGFloat>) -> Spot {
        let cy = c.y + CGFloat(p) * step
        let dy = cy - c.y
        let dx = sqrt(max(0, bow * bow - dy * dy))
        var node = CGPoint(x: left ? c.x - dx : c.x + dx, y: cy)
        node.x = left ? max(edges.lowerBound + 8 + itemW, node.x) : min(edges.upperBound - 8 - itemW, node.x)   // 8 in from the physical edge
        let vx = node.x - c.x, vy = node.y - c.y, len = max(1, sqrt(vx * vx + vy * vy))
        let foot = CGPoint(x: node.x - vx / len * stalk, y: node.y - vy / len * stalk)
        return Spot(edgeX: node.x, cy: cy, left: left, node: node, foot: foot)
    }

    /// The arc's middle height: level with the finger, moved only as far as keeps the whole arc under the header and
    /// above the foot.
    static func mid(_ y: CGFloat, shown n: Int, _ h: CGFloat, arrows: Bool) -> CGFloat {
        let half = CGFloat(n - 1) / 2 * step + itemH / 2 + (arrows ? arrowGap + arrowH : 0)
        return min(max(y, headerClear + half), h - 16 - half)
    }

    /// A menu that scrolls (Scott, 2026-11-15): its column spans the screen's usable height, from under the header to 8 pt
    /// above the foot, the triangles at its ends, so as many choices show as fit. `half`: from the column's middle to the
    /// choices' outer reach (the triangles beyond it).
    static func column(_ h: CGFloat) -> (mid: CGFloat, half: CGFloat) {
        let top = headerClear, bottom = h - 8
        return ((top + bottom) / 2, (bottom - top) / 2 - arrowGap - arrowH)
    }
    /// How many whole choices that column holds (never fewer than the arc's five).
    static func fullColumn(_ h: CGFloat) -> Int {
        max(inView, Int(((2 * column(h).half - itemH) / step).rounded(.down)) + 1)
    }

    /// The circle's size as it grows in: past its size (`spring` 0…1 sets how far), one undershoot, settle.
    static func hubScale(_ p: Double, spring: Double) -> Double {
        if p >= 1 { return 1 }
        func ease(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
        if spring <= 0 { return ease(p) }
        let over = 1 + 0.35 * spring, under = 1 - 0.1 * spring
        if p < 0.45 { return over * ease(p / 0.45) }
        if p < 0.75 { return over + (under - over) * ease((p - 0.45) / 0.30) }
        return under + (1 - under) * ease((p - 0.75) / 0.25)
    }

    /// The wheel's turn now: the drag's, or easing from where it was to where it settles.
    private func turn(_ date: Date) -> Double {
        let t = min(1, max(0, date.timeIntervalSince(turnAt) / (reduceMotion ? 0.001 : Self.settle)))
        let e = 1 - pow(1 - t, 3)
        return turnFrom + (turnTo - turnFrom) * e
    }

    private func settle(to target: Double, from now: Double) {
        turnFrom = now; turnTo = target; turnAt = Date()
    }

    var body: some View {
        let list = shown.isEmpty ? items : shown
        let n = list.count
        // more than fit: the full-height column, scrolling; the rest (as many as the full column holds) all show, level with
        // the finger as before
        let wheel = n > max(Self.inView, Self.fullColumn(layer.height))
        let visible = wheel ? Self.fullColumn(layer.height) : n
        let most = Double(max(0, n - visible))
        let edges = (-margins.leading)...(layer.width + margins.trailing)
        let left = Self.opensLeft(at.x, edges, hand: hand)
        let mid = wheel ? Self.column(layer.height).mid : Self.mid(at.y, shown: visible, layer.height, arrows: false)
        // how far the choices reach from the middle: the full column's, or the choices' own
        let reach = wheel ? Self.column(layer.height).half : CGFloat(visible - 1) / 2 * Self.step + Self.itemH / 2
        TimelineView(.animation) { tl in
            // ms since it opened, at the Labs speed
            let e = tl.date.timeIntervalSince(start) * 1000 * Labs.menuSpeed.value / 100
            let fade = min(1, e / 150)
            let tn = wheel ? turn(tl.date) : 0
            // each choice's place on the arc, and how much of it shows: whole within the arc, fading past its ends
            let pos: [Double] = (0..<n).map { Double($0) - tn - Double(visible - 1) / 2 }
            // the shallow curve's centre, far behind the finger, level with the arc's middle
            let centre = Self.centre(finger: at, mid: mid, left: left, edges: edges)
            let spots = pos.map { Self.spot(p: $0, centre: centre, left: left, edges: edges) }
            let seen: [Double] = pos.map { p in
                guard wheel else { return 1 }
                return min(1, max(0, 1 - (abs(p) - Double(visible - 1) / 2) / 0.8))
            }
            ZStack(alignment: .topLeading) {
                // the page behind stays as it is (Scott, 2026-11-15: no page-wide dim; the soft backing behind the choices is
                // the only darkening); a tap outside the choices still closes
                Color.clear
                    .padding(.leading, -margins.leading).padding(.trailing, -margins.trailing)   // (over the margins too)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .accessibilityHidden(true)
                Canvas { ctx, _ in
                    let c = at
                    // a soft black field behind the choices and stalks, following the arc, so the pads under the menu stop
                    // competing (Scott, 2026-11-14): 70 %, feathered by a blur, faded in with the menu
                    do {
                        let reachY = reach + (wheel ? Self.arrowGap + Self.arrowH : 0) + 14
                        let r0 = Self.rim - 12, r1 = Self.bow + Self.itemW + 12
                        let a0 = asin(min(1, reachY / r0)) * 180 / .pi, a1 = asin(min(1, reachY / r1)) * 180 / .pi
                        let base = left ? 180.0 : 0.0
                        var field = Path()
                        field.addArc(center: centre, radius: r1, startAngle: .degrees(base - a1), endAngle: .degrees(base + a1), clockwise: false)
                        field.addArc(center: centre, radius: r0, startAngle: .degrees(base + a0), endAngle: .degrees(base - a0), clockwise: true)
                        field.closeSubpath()
                        ctx.drawLayer { l in
                            l.addFilter(.blur(radius: 8))
                            l.fill(field, with: .color(.black.opacity(0.53 * fade)))      // (Scott, 2026-11-15: 88 % → 53 %)
                        }
                    }
                    let s = reduceMotion ? 1 : Self.hubScale(min(1, e / 460), spring: Labs.menuSpring.value / 100)
                    let hubA = reduceMotion ? fade : 1
                    let r = Self.hub * s
                    let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(circle, with: .color(SelectionTint.fill(tint ?? 0, percent: 45).opacity(tint == nil ? 0 : hubA)))
                    if tint == nil { ctx.fill(circle, with: .color(Theme.control.opacity(hubA))) }
                    ctx.stroke(circle, with: .color(colour.opacity(hubA)), lineWidth: 1.5)
                    // the wheel's rim: the choices' shallow curve 22 pt in, drawing out from its middle as the menu opens; on a
                    // wheel a small triangle past each end in the track colour while there are choices beyond that end
                    let rimP = reduceMotion ? 1 : min(1, max(0, (e - 100) / 260))
                    if rimP > 0 {
                        let reachY = reach
                        let half = asin(min(1, reachY / Self.rim)) * 180 / .pi
                        let base = left ? 180.0 : 0.0
                        var rimPath = Path()
                        rimPath.addArc(center: centre, radius: Self.rim, startAngle: .degrees(base - half * rimP), endAngle: .degrees(base + half * rimP), clockwise: false)
                        // a dashed knob scale (board 78, tile 8): 3 pt dashes, 1.5 thick, 5 pt gaps, the track colour at 80 %
                        ctx.stroke(rimPath, with: .color(colour.opacity(0.8 * (reduceMotion ? fade : 1))), style: StrokeStyle(lineWidth: 1.5, lineCap: .butt, dash: [3, 5]))
                        if wheel {
                            // more above (the wheel turned on from the first) and more below (not yet at the last), each blending out
                            // as that end is reached
                            let up = min(1, max(0, tn / 0.5)), down = min(1, max(0, (most - tn) / 0.5))
                            let ay = reachY + Self.arrowGap
                            for (sign, a) in [(-1.0, up), (1.0, down)] where a > 0 {
                                let y = centre.y + CGFloat(sign) * ay
                                let dx = sqrt(max(0, Self.rim * Self.rim - (y - centre.y) * (y - centre.y)))
                                let x = left ? centre.x - dx : centre.x + dx
                                var tri = Path()
                                let tip = CGPoint(x: x, y: y + CGFloat(sign) * Self.arrowH)
                                tri.move(to: tip)
                                tri.addLine(to: CGPoint(x: x - Self.arrowW / 2, y: y))
                                tri.addLine(to: CGPoint(x: x + Self.arrowW / 2, y: y))
                                tri.closeSubpath()
                                ctx.fill(tri, with: .color(colour.opacity(a * rimP * (reduceMotion ? fade : 1))))
                            }
                        }
                    }
                    for (k, sp) in spots.enumerated() where seen[k] > 0 {
                        let d0 = 160 + Double(min(max(0, k - Int(tn)), 7)) * 30
                        let t = min(1, max(0, (e - d0) / 180))
                        let drawn = reduceMotion ? 1 : 1 - (1 - t) * (1 - t)
                        let a = (reduceMotion ? fade : 1) * (confirming != nil && confirming != k ? 0.3 : 1) * seen[k]
                        if drawn > 0 {
                            var line = Path(); line.move(to: sp.foot)
                            line.addLine(to: CGPoint(x: sp.foot.x + (sp.node.x - sp.foot.x) * drawn, y: sp.foot.y + (sp.node.y - sp.foot.y) * drawn))
                            ctx.stroke(line, with: .color(Theme.textTertiary.opacity(a)), style: StrokeStyle(lineWidth: 1, lineCap: .round))   // (1 pt mid-grey, tile 8)
                        }
                        let nodeA = (reduceMotion ? 1 : min(1, max(0, (e - d0 - 140) / 120))) * a
                        if nodeA > 0 { ctx.fill(Path(CGRect(x: sp.node.x - 3, y: sp.node.y - 3, width: 6, height: 6)), with: .color(Theme.textSecondary.opacity(nodeA))) }   // (a 6 pt square node)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                ForEach(Array(list.enumerated()), id: \.offset) { k, item in
                    let sp = spots[k]
                    let d0 = 160 + Double(min(max(0, k - Int(tn)), 7)) * 30
                    let t = min(1, max(0, (e - d0 - 100) / 220))
                    let inP = reduceMotion ? fade : 1 - (1 - t) * (1 - t)
                    if seen[k] > 0 {
                        row(k, item, sp)
                            .opacity(inP * (confirming != nil && confirming != k ? 0.3 : 1) * seen[k])
                            .allowsHitTesting(seen[k] >= 0.5)
                            .scaleEffect(reduceMotion ? 1 : (0.96 + 0.04 * inP) * (0.9 + 0.1 * seen[k]))
                            .offset(x: (sp.left ? sp.edgeX - Self.itemW : sp.edgeX) + (reduceMotion ? 0 : (sp.left ? 10 : -10) * (1 - inP)),
                                    y: sp.cy - Self.itemH / 2)
                            .accessibilityHidden(seen[k] < 0.5)
                    }
                }
            }
        }
        .frame(width: layer.width, height: layer.height, alignment: .topLeading)
        // the layer's place on the screen: how far its sides sit in from the physical edges (the safe area's margins)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { f in
            let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? f.maxX
            margins = (max(0, f.minX), max(0, screen - f.maxX))
        }
        // not until the finger that opened it lifts: taking touches under a finger still down cancelled the held pad's
        // gesture mid-press, and the next hold anywhere opened nothing (2026-11-14)
        .allowsHitTesting(armed)
        // a drag anywhere on the menu turns the wheel (a tap still picks: the choices take taps only)
        .simultaneousGesture(DragGesture(minimumDistance: 6).onChanged { v in
            guard wheel else { return }
            let now = turn(Date())
            if dragFrom == nil { dragFrom = now }
            let raw = (dragFrom ?? 0) - Double(v.translation.height / Self.step)
            // a little give past either end, taken back on release
            let t = raw < 0 ? raw * 0.35 : raw > most ? most + (raw - most) * 0.35 : raw
            turnFrom = t; turnTo = t; turnAt = .distantPast
        }.onEnded { v in
            guard wheel, let from = dragFrom else { return }
            dragFrom = nil
            let target = (from - Double(v.predictedEndTranslation.height / Self.step)).rounded()
            settle(to: min(max(target, 0), most), from: turn(Date()))
        }, including: wheel ? .all : .subviews)       // (no layer-wide drag on a short menu: only a wheel turns)
        .onAppear { start = Date(); turnFrom = 0; turnTo = 0 }
        .task { try? await Task.sleep(for: .seconds(3)); timedOut = true }
        // the opening finger's lift, seen at the window whatever it started on (a pad's or block's own gesture can be cancelled
        // by the menu covering it, and then never says it ended)
        .background(FingersUpWatch { HoldFinger.shared.down = false })
        .onDisappear { HoldFinger.shared.down = false }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityScrollAction { edge in
            // VoiceOver's three-finger swipe turns the wheel a page (WCAG 2.5.7: the drag has another way in)
            guard wheel else { return }
            let now = turn(Date())
            settle(to: min(max(now + (edge == .bottom ? -Double(visible) : Double(visible)), 0), most), from: now)
        }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.downArrow) { guard wheel else { return .ignored }; let now = turn(Date()); settle(to: min(now + 1, most).rounded(), from: now); return .handled }
        .onKeyPress(.upArrow) { guard wheel else { return .ignored }; let now = turn(Date()); settle(to: max(now - 1, 0).rounded(), from: now); return .handled }
    }

    private func row(_ k: Int, _ item: MenuItem, _ sp: Spot) -> some View {
        let asking = confirming == k
        // a tap picks, never a drag that ends somewhere else (a drag to scroll ended on Clear and cleared a pad, 2026-11-14)
        return Group {
            // board 78, tile 6: a fully round pill on the dark panel, the icon in a 30 pt disc of the track colour at the left
            // (drawn in the dark on-colour), the label after it in Barlow regular; no edge bar
            HStack(spacing: 10) {
                if asking {
                    Text(item.confirm ?? item.title).font(.lupe(14, .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 6)
                } else {
                    ZStack {
                        Circle().fill(item.enabled ? colour : colour.opacity(0.4))
                        if let i = item.icon {
                            Image(systemName: i).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.onColour)
                        }
                    }
                    .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.title).font(.lupe(item.sub != nil || item.title.count > 20 ? 14 : 16)).lineLimit(item.sub == nil ? 2 : 1)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(item.enabled ? Theme.text : Theme.textTertiary)
                        if let sub = item.sub {
                            Text(sub).font(.lupe(11)).foregroundStyle(Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.75)
                        }
                    }
                }
                Spacer(minLength: 0)
                if item.checked { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) }
                if item.children != nil { Text("›").font(.lupe(17, .semibold)).foregroundStyle(Theme.textSecondary) }
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 9).padding(.trailing, 16)            // (the disc 9 in: centred on the pill's end curve)
            .frame(width: Self.itemW, height: Self.itemH)
            .background {
                Capsule().fill(Theme.panel)
                    .overlay { if asking { Capsule().strokeBorder(Theme.recText, lineWidth: 2) } }
            }
            .contentShape(Capsule())
        }
        .onTapGesture { pick(k, item) }      // (a choice that can't be made: its words in the tertiary grey; pick() refuses it)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pick(k, item) }
        .accessibilityLabel(asking ? "Confirm: \(item.confirm ?? item.title)" : item.title + (item.sub.map { ", \($0)" } ?? ""))
        .accessibilityAddTraits(item.checked ? .isSelected : [])
        .accessibilityFocused($confirmFocused, equals: true)
        .accessibilityHint(asking ? "Can't be undone. Tap away to keep everything" : "")
    }

    private func pick(_ k: Int, _ item: MenuItem) {
        guard item.enabled else { return }
        if let children = item.children {
            // a second set of choices in the same place, the entrance again
            withAnimation(.easeOut(duration: 0.15)) { shown = children().flatMap { $0 }.filter { !$0.note }; confirming = nil }
            turnFrom = 0; turnTo = 0; turnAt = .distantPast
            start = Date()
        } else if item.confirm != nil, confirming != k {
            confirmAt = Date()
            withAnimation(.easeOut(duration: 0.15)) { confirming = k }
            confirmFocused = true
            UIAccessibility.post(notification: .announcement, argument: item.confirm)
        } else if item.confirm != nil, Date().timeIntervalSince(confirmAt) < 0.4 {
            return            // the second tap of a quick double tap can't confirm
        } else {
            dismiss(); item.action?()
        }
    }
}

/// Whether the finger that opened a hold menu is still down: the openers (a pad, a track head, a Timeline block) set it
/// as their hold fires and clear it as that finger lifts; the radial menu takes no touches until then.
@MainActor @Observable
final class HoldFinger {
    static let shared = HoldFinger()
    var down = false
}

/// Calls `up` when the last finger on the window lifts. Watches the window's touches and never claims one.
struct FingersUpWatch: UIViewRepresentable {
    let up: () -> Void
    func makeUIView(context: Context) -> Host { let v = Host(); v.isUserInteractionEnabled = false; v.up = up; return v }
    func updateUIView(_ v: Host, context: Context) { v.up = up }
    static func dismantleUIView(_ v: Host, coordinator: ()) { v.detach() }

    final class Host: UIView {
        var up: (() -> Void)?
        private var watcher: Watcher?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let w = window else { return }
            let g = Watcher(); g.host = self
            w.addGestureRecognizer(g); watcher = g
        }
        func detach() { watcher?.view?.removeGestureRecognizer(watcher!); watcher = nil }
    }

    final class Watcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
        weak var host: Host?
        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false; delaysTouchesBegan = false; delaysTouchesEnded = false; delegate = self
        }
        convenience init() { self.init(target: nil, action: nil) }
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { check(event) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { check(event) }
        private func check(_ event: UIEvent) {
            let down = (event.allTouches ?? []).contains { $0.phase != .ended && $0.phase != .cancelled }
            if !down { host?.up?() }
            state = .failed
        }
    }
}

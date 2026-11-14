import SwiftUI

// The phone's hold menu (design/boards/radial-menu.html; Android's HoldMenuHost, Scott 2026-11-14, decisions 31 and 36):
// the iPad's and iPhone's options, drawn as a wheel. A filled circle in the track's colour at about 45 % over the page
// grows under the finger (64 pt, an elastic grow-in: Labs › Hold menu spring); round it a thin rim, the wheel, linked
// back to the hub by one spoke level with the finger (Scott's option A, 2026-11-14), and on a
// short arc beyond the rim up to five choices, each on its own 22 pt stalk from the rim, so every stalk is the same short
// length. More than five: a drag turns the wheel and the others roll into the arc along the curve, fading as they near
// its ends; it opens with the first choice at the arc's top and settles on a choice when the finger lifts. Five or fewer
// are just the arc. The arc stays on screen under the header and flips side near an edge (Settings › Handedness). The
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
    @AppStorage(Handedness.key) private var hand = Handedness.right
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
    private var armed: Bool { (!HoldFinger.shared.down || timedOut) && !closing }
    /// Set as it's told to close: while it fades out it takes no touches, so a hold that starts at once reaches the pad
    /// under it rather than the menu that's leaving (2026-11-14: that hold was lost with the menu).
    @State private var closing = false
    private func dismiss() { closing = true; close() }

    /// Under the header line (48 pt and its hairline), so no choice sits over the tabs.
    static let headerClear: CGFloat = 56
    static let itemW: CGFloat = 200, itemH: CGFloat = 48, step: CGFloat = 56, hub: CGFloat = 32
    /// The stalks (decision 36): every one 22 pt, from the rim to the choice's near edge.
    static let stalk: CGFloat = 22
    /// The arc the choices' near edges sit on: five choices 56 apart fit it within about ±48° of level.
    static let arc: CGFloat = 150
    static var rim: CGFloat { arc - stalk }
    /// Choices in the arc at once.
    static let inView = 5
    /// How long a turn takes to settle (the board's ease-out).
    static let settle = 0.32

    private var colour: Color { tint.map { Theme.track[$0] } ?? Theme.text }

    struct Spot { var edgeX: CGFloat, cy: CGFloat, left: Bool, node: CGPoint, foot: CGPoint }

    /// Which side the arc opens on: away from the playing hand where there's room, else the other side.
    static func opensLeft(_ x: CGFloat, _ w: CGFloat, hand: Handedness) -> Bool {
        let reach = arc + itemW + 8
        let fitsLeft = x - reach >= 0, fitsRight = x + reach <= w
        return hand == .right ? (fitsLeft || !fitsRight) : !(fitsRight || !fitsLeft)
    }

    /// The choice at position `p` on the arc (0 the middle, ±2 its ends; between whole choices while the wheel turns):
    /// its centre height, its near edge where that height meets the arc, the node there, and the stalk's foot 22 pt in
    /// toward the finger, on the rim.
    static func spot(p: Double, finger: CGPoint, mid: CGFloat, left: Bool, w: CGFloat) -> Spot {
        let cy = mid + CGFloat(p) * step
        let dy = cy - finger.y
        let dx = sqrt(max(0, arc * arc - dy * dy))
        var node = CGPoint(x: left ? finger.x - dx : finger.x + dx, y: cy)
        node.x = left ? max(8 + itemW, node.x) : min(w - 8 - itemW, node.x)        // kept on screen sideways
        let vx = node.x - finger.x, vy = node.y - finger.y, len = max(1, sqrt(vx * vx + vy * vy))
        let foot = CGPoint(x: node.x - vx / len * stalk, y: node.y - vy / len * stalk)
        return Spot(edgeX: node.x, cy: cy, left: left, node: node, foot: foot)
    }

    /// The arc's middle height: level with the finger, moved only as far as keeps the whole arc under the header and
    /// above the foot.
    static func mid(_ y: CGFloat, shown n: Int, _ h: CGFloat) -> CGFloat {
        let half = CGFloat(n - 1) / 2 * step + itemH / 2
        return min(max(y, headerClear + half), h - 16 - half)
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
        let wheel = n > Self.inView
        let visible = min(n, Self.inView)
        let most = Double(max(0, n - Self.inView))
        let left = Self.opensLeft(at.x, layer.width, hand: hand)
        let mid = Self.mid(at.y, shown: visible, layer.height)
        TimelineView(.animation) { tl in
            // ms since it opened, at the Labs speed
            let e = tl.date.timeIntervalSince(start) * 1000 * Labs.menuSpeed.value / 100
            let fade = min(1, e / 150)
            let tn = wheel ? turn(tl.date) : 0
            // each choice's place on the arc, and how much of it shows: whole within the arc, fading past its ends
            let pos: [Double] = (0..<n).map { Double($0) - tn - Double(visible - 1) / 2 }
            // the arc and its rim centre on the finger's x and the arc's middle (level with the finger unless the screen's edge moved it)
            let centre = CGPoint(x: at.x, y: mid)
            let spots = pos.map { Self.spot(p: $0, finger: centre, mid: mid, left: left, w: layer.width) }
            let seen: [Double] = pos.map { p in
                guard wheel else { return 1 }
                return min(1, max(0, 1 - (abs(p) - 2) / 0.8))
            }
            ZStack(alignment: .topLeading) {
                // the page behind, dimmed; a tap outside the choices closes
                Color.black.opacity(0.45 * fade)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .accessibilityHidden(true)
                Canvas { ctx, _ in
                    let c = at
                    let s = reduceMotion ? 1 : Self.hubScale(min(1, e / 460), spring: Labs.menuSpring.value / 100)
                    let hubA = reduceMotion ? fade : 1
                    let r = Self.hub * s
                    let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                    ctx.fill(circle, with: .color(SelectionTint.fill(tint ?? 0, percent: 45).opacity(tint == nil ? 0 : hubA)))
                    if tint == nil { ctx.fill(circle, with: .color(Theme.control.opacity(hubA))) }
                    ctx.stroke(circle, with: .color(colour.opacity(hubA)), lineWidth: 1.5)
                    // the wheel: a thin rim round the arc's centre, drawing round as the menu opens, and one spoke from the hub
                    // to the rim's middle (Scott's option A: the rim links the stalks back to the hub)
                    let rimP = reduceMotion ? 1 : min(1, max(0, (e - 100) / 260))
                    if rimP > 0 {
                        let rr = Self.rim * (reduceMotion ? 1 : 0.9 + 0.1 * rimP)
                        let base = left ? 180.0 : 0.0
                        let ink = colour.opacity(0.55 * (reduceMotion ? fade : 1))
                        var rimPath = Path()
                        rimPath.addArc(center: centre, radius: rr, startAngle: .degrees(base - 70 * rimP), endAngle: .degrees(base + 70 * rimP), clockwise: false)
                        ctx.stroke(rimPath, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        let dir: CGFloat = left ? -1 : 1
                        let rimMid = CGPoint(x: centre.x + dir * rr, y: centre.y)
                        let vx = rimMid.x - c.x, vy = rimMid.y - c.y, len = max(1, sqrt(vx * vx + vy * vy))
                        let from = CGPoint(x: c.x + vx / len * Self.hub, y: c.y + vy / len * Self.hub)
                        var spoke = Path()
                        spoke.move(to: from)
                        spoke.addLine(to: CGPoint(x: from.x + (rimMid.x - from.x) * rimP, y: from.y + (rimMid.y - from.y) * rimP))
                        ctx.stroke(spoke, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                    for (k, sp) in spots.enumerated() where seen[k] > 0 {
                        let d0 = 160 + Double(min(max(0, k - Int(tn)), 7)) * 30
                        let t = min(1, max(0, (e - d0) / 180))
                        let drawn = reduceMotion ? 1 : 1 - (1 - t) * (1 - t)
                        let a = (reduceMotion ? fade : 1) * (confirming != nil && confirming != k ? 0.3 : 1) * seen[k]
                        if drawn > 0 {
                            var line = Path(); line.move(to: sp.foot)
                            line.addLine(to: CGPoint(x: sp.foot.x + (sp.node.x - sp.foot.x) * drawn, y: sp.foot.y + (sp.node.y - sp.foot.y) * drawn))
                            ctx.stroke(line, with: .color(colour.opacity(a)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }
                        let nodeA = (reduceMotion ? 1 : min(1, max(0, (e - d0 - 140) / 120))) * a
                        if nodeA > 0 { ctx.fill(Path(ellipseIn: CGRect(x: sp.node.x - 3, y: sp.node.y - 3, width: 6, height: 6)), with: .color(colour.opacity(nodeA))) }
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
        .onDisappear { HoldFinger.shared.down = false }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityScrollAction { edge in
            // VoiceOver's three-finger swipe turns the wheel a page (WCAG 2.5.7: the drag has another way in)
            guard wheel else { return }
            let now = turn(Date())
            settle(to: min(max(now + (edge == .bottom ? -Double(Self.inView) : Double(Self.inView)), 0), most), from: now)
        }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.downArrow) { guard wheel else { return .ignored }; let now = turn(Date()); settle(to: min(now + 1, most).rounded(), from: now); return .handled }
        .onKeyPress(.upArrow) { guard wheel else { return .ignored }; let now = turn(Date()); settle(to: max(now - 1, 0).rounded(), from: now); return .handled }
    }

    private func row(_ k: Int, _ item: MenuItem, _ sp: Spot) -> some View {
        let asking = confirming == k
        // a tap picks, never a drag that ends somewhere else (a drag to scroll ended on Clear and cleared a pad, 2026-11-14)
        return Group {
            HStack(spacing: 8) {
                if asking {
                    Text(item.confirm ?? item.title).font(.lupe(14, .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                } else {
                    if let i = item.icon { Image(systemName: i).font(.system(size: 15, weight: .semibold)).frame(width: 20) }
                    Text(item.title).font(.lupe(item.title.count > 20 ? 14 : 17)).lineLimit(2).minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(item.enabled ? Theme.text : Theme.textTertiary)
                }
                Spacer(minLength: 0)
                if item.checked { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) }
                if item.children != nil { Text("›").font(.lupe(17, .semibold)).foregroundStyle(Theme.textSecondary) }
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, sp.left ? 14 : 16).padding(.trailing, sp.left ? 16 : 14)
            .frame(width: Self.itemW, height: Self.itemH)
            .background {
                RoundedRectangle(cornerRadius: 12).fill(Theme.panel)
                    .overlay(alignment: sp.left ? .trailing : .leading) {
                        // the edge the line arrives at carries the track's colour
                        if !asking { RoundedRectangle(cornerRadius: 1.5).fill(colour).frame(width: 3).padding(.vertical, 8) }
                    }
                    .overlay { if asking { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.recText, lineWidth: 2) } }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .onTapGesture { pick(k, item) }      // (a choice that can't be made: its words in the tertiary grey; pick() refuses it)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pick(k, item) }
        .accessibilityLabel(asking ? "Confirm: \(item.confirm ?? item.title)" : item.title)
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

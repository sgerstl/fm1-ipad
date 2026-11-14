import SwiftUI

// The phone's hold menu (design/boards/radial-menu.html; Android's HoldMenuHost, Scott 2026-11-14, decision 31): the
// iPad's and iPhone's options, drawn the Android way. A filled circle in the track's colour at about 45 % over the page
// grows under the finger (64 pt, an elastic grow-in: Labs › Hold menu spring), lines 1.5 pt in the track's colour run
// out from its edge one by one to each choice, each ending in a small node; the choices are 48 pt rounded rows stacked
// round the finger's height, bowed along a 120 pt circle, opening left near the right edge. The page dims and a tap
// outside closes. A choice that loses work asks once more in place (red outline, its words naming what goes; taps
// ignored for 0.4 s). More than six: the rest behind "More…". Reduce Motion: fades only. iPhone only (FanMenu routes).

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
    @State private var confirming: Int?
    @State private var confirmAt = Date.distantPast
    @AccessibilityFocusState private var confirmFocused: Bool

    static let itemW: CGFloat = 236, itemH: CGFloat = 48, radius: CGFloat = 120, step: CGFloat = 56, hub: CGFloat = 32

    private var colour: Color { tint.map { Theme.track[$0] } ?? Theme.text }

    /// No more than six in one place: the rest behind "More…" (Android's paged).
    static func paged(_ items: [MenuItem], per: Int = 6) -> [MenuItem] {
        guard items.count > per else { return items }
        let rest = Array(items.dropFirst(per - 1))
        return Array(items.prefix(per - 1)) + [.submenu(title: "More…") { [rest] }]
    }

    struct Spot { var edgeX: CGFloat, cy: CGFloat, left: Bool }

    /// Android's holdSpots: stacked `step` apart round the finger's height, kept on the screen, each pushed out to where
    /// its height meets the circle round the finger.
    static func spots(_ x: CGFloat, _ y: CGFloat, _ n: Int, _ w: CGFloat, _ h: CGFloat) -> [Spot] {
        let left = x > w - (radius + itemW + 24)
        let lowest = h - 16 - itemH / 2 - CGFloat(n - 1) * step
        let top = max(8 + itemH / 2, min(lowest, y - CGFloat(n - 1) * step / 2))
        return (0..<n).map { k in
            let cy = top + CGFloat(k) * step, dy = cy - y
            var dx = sqrt(max(0, radius * radius - dy * dy)); if dx <= 0 { dx = 24 }
            let edge = left ? max(8 + itemW, x - dx) : min(w - 8 - itemW, x + dx)
            return Spot(edgeX: edge, cy: cy, left: left)
        }
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

    var body: some View {
        let list = shown.isEmpty ? Self.paged(items) : shown
        let spots = Self.spots(at.x, at.y, list.count, layer.width, layer.height)
        TimelineView(.animation) { tl in
            // ms since it opened, at the Labs speed
            let e = tl.date.timeIntervalSince(start) * 1000 * Labs.menuSpeed.value / 100
            let fade = min(1, e / 150)
            ZStack(alignment: .topLeading) {
                // the page behind, dimmed; a tap outside the choices closes
                Color.black.opacity(0.45 * fade)
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
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
                    for (k, sp) in spots.enumerated() {
                        let end = CGPoint(x: sp.edgeX, y: sp.cy)
                        let ang = atan2(end.y - c.y, end.x - c.x)
                        let a0 = CGPoint(x: c.x + cos(ang) * Self.hub, y: c.y + sin(ang) * Self.hub)
                        let d0 = 160 + Double(k) * 30
                        let t = min(1, max(0, (e - d0) / 180))
                        let drawn = reduceMotion ? 1 : 1 - (1 - t) * (1 - t)
                        let a = (reduceMotion ? fade : 1) * (confirming != nil && confirming != k ? 0.3 : 1)
                        if drawn > 0 {
                            var line = Path(); line.move(to: a0)
                            line.addLine(to: CGPoint(x: a0.x + (end.x - a0.x) * drawn, y: a0.y + (end.y - a0.y) * drawn))
                            ctx.stroke(line, with: .color(colour.opacity(a)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }
                        let nodeA = (reduceMotion ? 1 : min(1, max(0, (e - d0 - 140) / 120))) * a
                        if nodeA > 0 { ctx.fill(Path(ellipseIn: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6)), with: .color(colour.opacity(nodeA))) }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                ForEach(Array(list.enumerated()), id: \.offset) { k, item in
                    let sp = spots[k]
                    let d0 = 160 + Double(k) * 30
                    let t = min(1, max(0, (e - d0 - 100) / 220))
                    let inP = reduceMotion ? fade : 1 - (1 - t) * (1 - t)
                    row(k, item, sp)
                        .opacity(inP * (confirming != nil && confirming != k ? 0.3 : 1))
                        .scaleEffect(reduceMotion ? 1 : 0.96 + 0.04 * inP)
                        .offset(x: (sp.left ? sp.edgeX - Self.itemW : sp.edgeX) + (reduceMotion ? 0 : (sp.left ? 10 : -10) * (1 - inP)),
                                y: sp.cy - Self.itemH / 2)
                }
            }
        }
        .frame(width: layer.width, height: layer.height, alignment: .topLeading)
        .onAppear { start = Date() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .onKeyPress(.escape) { close(); return .handled }
    }

    private func row(_ k: Int, _ item: MenuItem, _ sp: Spot) -> some View {
        let asking = confirming == k
        return Button { pick(k, item) } label: {
            HStack(spacing: 8) {
                if asking {
                    Text(item.confirm ?? item.title).font(.lupe(14, .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                } else {
                    if let i = item.icon { Image(systemName: i).font(.system(size: 15, weight: .semibold)).frame(width: 20) }
                    Text(item.title).font(.lupe(17)).lineLimit(1).minimumScaleFactor(0.75)
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
        .buttonStyle(PressSink())
        .disabled(!item.enabled)
        .accessibilityLabel(asking ? "Confirm: \(item.confirm ?? item.title)" : item.title)
        .accessibilityAddTraits(item.checked ? .isSelected : [])
        .accessibilityFocused($confirmFocused, equals: true)
        .accessibilityHint(asking ? "Can't be undone. Tap away to keep everything" : "")
    }

    private func pick(_ k: Int, _ item: MenuItem) {
        guard item.enabled else { return }
        if let children = item.children {
            // a second set of choices in the same place, the entrance again
            withAnimation(.easeOut(duration: 0.15)) { shown = Self.paged(children().flatMap { $0 }.filter { !$0.note }); confirming = nil }
            start = Date()
        } else if item.confirm != nil, confirming != k {
            confirmAt = Date()
            withAnimation(.easeOut(duration: 0.15)) { confirming = k }
            confirmFocused = true
            UIAccessibility.post(notification: .announcement, argument: item.confirm)
        } else if item.confirm != nil, Date().timeIntervalSince(confirmAt) < 0.4 {
            return            // the second tap of a quick double tap can't confirm
        } else {
            close(); item.action?()
        }
    }
}

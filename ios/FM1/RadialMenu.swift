import SwiftUI

// The phone's hold menu (design/boards/radial-menu.html; Android's HoldMenuHost, Scott 2026-11-14, decision 31): the
// iPad's and iPhone's options, drawn the Android way. A filled circle in the track's colour at about 45 % over the page
// grows under the finger (64 pt, an elastic grow-in: Labs › Hold menu spring), lines 1.5 pt in the track's colour run
// out from its edge one by one to each choice, each ending in a small node; the choices are 48 pt rounded rows stacked
// round the finger's height, bowed along a circle 22 pt out from the hub (decision 36: short stalks), opening left near the right edge. The page dims and a tap
// outside closes. A choice that loses work asks once more in place (red outline, its words naming what goes; taps
// ignored for 0.4 s). Too many to fit below the header: the column scrolls (decision 36), no second page. Reduce Motion: fades only. iPhone only (FanMenu routes).

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
    @State private var scroll = ScrollPosition(y: 0)
    @State private var scrollY: CGFloat = 0
    @State private var confirming: Int?
    @State private var confirmAt = Date.distantPast
    @AccessibilityFocusState private var confirmFocused: Bool

    /// Under the header line (48 pt and its hairline), so no choice sits over the tabs.
    static let headerClear: CGFloat = 56
    static let itemW: CGFloat = 236, itemH: CGFloat = 48, step: CGFloat = 56, hub: CGFloat = 32
    /// The stalks (decision 36, Scott 2026-11-14): about a quarter of the first build's, so the options hug the circle.
    static let stalk: CGFloat = 22
    static var radius: CGFloat { hub + stalk }
    /// Rows above or below the circle's reach still sit this far out from the finger, so the column bends along the arc.
    static let minReach: CGFloat = 14

    private var colour: Color { tint.map { Theme.track[$0] } ?? Theme.text }

    struct Spot { var edgeX: CGFloat, cy: CGFloat, left: Bool }

    /// Where the option column may sit: under the header, 16 pt off the foot (centres of the first and last rows).
    static func window(_ h: CGFloat) -> ClosedRange<CGFloat> { (headerClear + itemH / 2)...(h - 16 - itemH / 2) }
    /// Whether n options need to scroll in this height.
    static func scrolls(_ n: Int, _ h: CGFloat) -> Bool { CGFloat(n - 1) * step > window(h).upperBound - window(h).lowerBound }

    /// One option's near edge at centre height `cy`: out from the finger to where that height meets the circle of
    /// `radius`, never nearer than `minReach`, so the column hugs the circle along its arc. Opens left near the right edge.
    static func spot(_ x: CGFloat, _ y: CGFloat, cy: CGFloat, _ w: CGFloat) -> Spot {
        let left = x > w - (radius + itemW + 24)
        let dy = cy - y
        let dx = max(minReach, sqrt(max(0, radius * radius - dy * dy)))
        let edge = left ? max(8 + itemW, x - dx) : min(w - 8 - itemW, x + dx)
        return Spot(edgeX: edge, cy: cy, left: left)
    }

    /// The rows' centres when they all fit: stacked `step` apart round the finger's height, kept in the window.
    static func fitted(_ y: CGFloat, _ n: Int, _ h: CGFloat) -> [CGFloat] {
        let win = window(h)
        let top = max(win.lowerBound, min(win.upperBound - CGFloat(n - 1) * step, y - CGFloat(n - 1) * step / 2))
        return (0..<n).map { top + CGFloat($0) * step }
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
        let list = shown.isEmpty ? items : shown
        let scrolling = Self.scrolls(list.count, layer.height)
        let win = Self.window(layer.height)
        // scrolling: the column's rows from the window's top, moved by the scroll; otherwise round the finger
        let centres = scrolling ? (0..<list.count).map { win.lowerBound + CGFloat($0) * Self.step - scrollY } : Self.fitted(at.y, list.count, layer.height)
        let spots = centres.map { Self.spot(at.x, at.y, cy: $0, layer.width) }
        // a row scrolled past the window's edge fades over its own height (and its stalk with it)
        let seen: [Double] = centres.map { cy in
            guard scrolling else { return 1 }
            let over = max(win.lowerBound - cy, cy - win.upperBound)
            return Double(min(1, max(0, 1 - over / (Self.itemH * 0.8))))
        }
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
                        let a = (reduceMotion ? fade : 1) * (confirming != nil && confirming != k ? 0.3 : 1) * seen[k]
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
                if scrolling {
                    // too many to fit (decision 36): one column that scrolls with a drag, the circle staying put; the rows
                    // slide along the arc as they go, and fade at the window's clipped edges
                    ScrollView(.vertical) {
                        ZStack(alignment: .topLeading) {
                            Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                            ForEach(Array(list.enumerated()), id: \.offset) { k, item in
                    let sp = spots[k]
                    let d0 = 160 + Double(min(k, 8)) * 30
                    let t = min(1, max(0, (e - d0 - 100) / 220))
                    let inP = reduceMotion ? fade : 1 - (1 - t) * (1 - t)
                    row(k, item, sp)
                        .opacity(inP * (confirming != nil && confirming != k ? 0.3 : 1))
                        .scaleEffect(reduceMotion ? 1 : 0.96 + 0.04 * inP)
                        .offset(x: (sp.left ? sp.edgeX - Self.itemW : sp.edgeX) + (reduceMotion ? 0 : (sp.left ? 10 : -10) * (1 - inP)),
                                y: CGFloat(k) * Self.step)
                            }
                        }
                        .frame(width: layer.width, height: CGFloat(list.count - 1) * Self.step + Self.itemH, alignment: .topLeading)
                    }
                    .scrollPosition($scroll)
                    .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, y in scrollY = y }
                    .scrollIndicators(.visible)
                    .frame(width: layer.width, height: win.upperBound - win.lowerBound + Self.itemH)
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                               .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    .offset(y: win.lowerBound - Self.itemH / 2)
                } else {
                    ForEach(Array(list.enumerated()), id: \.offset) { k, item in
                    let sp = spots[k]
                    let d0 = 160 + Double(min(k, 8)) * 30
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
        }
        .frame(width: layer.width, height: layer.height, alignment: .topLeading)
        .onAppear {
            start = Date()
            // scrolling: open with the rows round the finger's height, as far as the column goes
            let n = (shown.isEmpty ? items : shown).count
            if Self.scrolls(n, layer.height) {
                let win = Self.window(layer.height)
                let natural = at.y - CGFloat(n - 1) * Self.step / 2
                let most = CGFloat(n - 1) * Self.step - (win.upperBound - win.lowerBound)
                let y = min(max(win.lowerBound - natural, 0), most)
                scroll = ScrollPosition(y: y); scrollY = y
            }
        }
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
            withAnimation(.easeOut(duration: 0.15)) { shown = children().flatMap { $0 }.filter { !$0.note }; confirming = nil }
            scroll = ScrollPosition(y: 0); scrollY = 0
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

import SloopKit
import SwiftUI

// The Pads' layout and the selected pad: the grid every pad glides in between layouts, the selected pad's border with
// the track controls hanging from it, and how those unroll when a pad is picked.

/// The pads in `columns` columns of `cell`-sized places with `gap` between, row after row.
/// A Layout, so a change of columns or size inside an animation moves each pad from its old frame to its new one.
struct PadGrid: Layout {
    var columns: Int
    var cell: CGSize
    var gap: CGFloat
    /// Between rows, when it differs from between columns (the grid's rows line up with the track heads beside them).
    var rowGap: CGFloat? = nil
    private var rg: CGFloat { rowGap ?? gap }

    private func block(_ n: Int) -> CGSize {
        let rows = (n + columns - 1) / max(1, columns)
        return CGSize(width: CGFloat(columns) * cell.width + CGFloat(columns - 1) * gap,
                      height: CGFloat(rows) * cell.height + CGFloat(max(0, rows - 1)) * rg)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { block(subviews.count) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, v) in subviews.enumerated() {
            let c = i % columns, r = i / columns
            v.place(at: CGPoint(x: bounds.minX + CGFloat(c) * (cell.width + gap), y: bounds.minY + CGFloat(r) * (cell.height + rg)),
                    proposal: ProposedViewSize(cell))
        }
    }
}

/// The selected pad's frame and the track controls' tab hanging from it, one outline: the tab wider than the pad, under
/// it (or over it, `up`), flush with its left edge (or right, `right`), a concave fillet where the pad's side meets the
/// tab's edge.
struct PadTabShape: Shape {
    var cell: CGRect
    var tab: CGSize
    var up: Bool
    var right: Bool
    /// How far the tint comes straight down out of the pad before the tab widens: the grid's gap, so the tab's top
    /// stands that far below the pads beside it (Scott, 2026-11-09).
    var drop: CGFloat = 0
    static let f: CGFloat = 10
    /// The corners: the pad's own radius in that row, so the tint lines up with the pads beside it.
    var r: CGFloat = 12

    /// The pad's place and size animate, so the tint travels with the pad and its knobs on the spring: drawn from the
    /// final place at once, it jumped while they glided (Scott, 2026-11-08: "separate motion from their background").
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(cell.minX, cell.minY), AnimatablePair(cell.width, cell.height)) }
        set { cell = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }

    func path(in rect: CGRect) -> Path {
        let r = r, f = Self.f, w = cell.width, h = cell.height + drop, W = max(tab.width, w + f), H = tab.height
        var p = Path()          // drawn with the tab under the pad, flush left, from (0, 0); then mirrored into place
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addArc(tangent1End: CGPoint(x: w, y: 0), tangent2End: CGPoint(x: w, y: r), radius: r)
        p.addLine(to: CGPoint(x: w, y: h - f))
        p.addQuadCurve(to: CGPoint(x: w + f, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: W - r, y: h))
        p.addArc(tangent1End: CGPoint(x: W, y: h), tangent2End: CGPoint(x: W, y: h + r), radius: r)
        p.addLine(to: CGPoint(x: W, y: h + H - r))
        p.addArc(tangent1End: CGPoint(x: W, y: h + H), tangent2End: CGPoint(x: W - r, y: h + H), radius: r)
        p.addLine(to: CGPoint(x: r, y: h + H))
        p.addArc(tangent1End: CGPoint(x: 0, y: h + H), tangent2End: CGPoint(x: 0, y: h + H - r), radius: r)
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: r, y: 0), radius: r)
        p.closeSubpath()
        var t = CGAffineTransform.identity
        if right { t = t.concatenating(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)) }
        if up { t = t.concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: cell.height)) }
        return p.applying(t).applying(CGAffineTransform(translationX: cell.minX, y: cell.minY))
    }
}

/// The selected pad's controls unrolling out of its edge as it's picked (and rolling back in as another is), the
/// border fading with them: a reveal, not a scale, so nothing floats half-size over the grid (Scott, 2026-11-08).
struct Emerge: ViewModifier, Animatable {
    var p: CGFloat
    let pad: CGRect, tab: CGRect, up: Bool

    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    static func transition(_ s: PadsPage.SelectedGeometry, row: Bool) -> AnyTransition {
        let tab = row ? .zero : CGRect(origin: s.tabAt, size: CGSize(width: s.tab.width, height: s.tab.height + s.drop))
        return .modifier(active: Emerge(p: 0, pad: s.frame, tab: tab, up: s.up),
                         identity: Emerge(p: 1, pad: s.frame, tab: tab, up: s.up))
    }

    func body(content: Content) -> some View {
        let h = tab.height * p
        content
            .mask(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                    // the pad and its border, wide enough for the fillets where the tab meets it
                    Rectangle().frame(width: pad.width + 2 * PadTabShape.f + 2, height: pad.height + 2)
                        .offset(x: pad.minX - PadTabShape.f - 1, y: pad.minY - 1)
                    // the tab, revealed from the pad's edge, with room round it for its shadow (the mask cut it off)
                    let m: CGFloat = tab.width > 0 ? 32 : 0
                    Rectangle().frame(width: tab.width + 2 * m, height: h + m)
                        .offset(x: tab.minX - m, y: up ? tab.maxY - h - m : tab.minY)
                }
            }
            // in step with the pad's own face fading (a faster tint left the old pad blank for a beat)
            .opacity(Double(p))
    }
}

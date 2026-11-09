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
    /// The tab's own corners (the pad's are `r`): nested round the knobs' tiles, not round the pad.
    var tabR: CGFloat = 12
    /// The inner turn into the tab: the next pad's corner radius plus the gap, so it follows that corner.
    var turn: CGFloat = 0
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
        // the inner turn from the pad into the tab: a true arc, the corner radius plus the gap, so it runs parallel to
        // the next pad's corner across the gap (Scott, 2026-11-09: the 10 pt bend didn't match the corners)
        let r = r, f = turn > 0 ? turn : Self.f
        let w = cell.width, h = cell.height + drop, W = max(tab.width, w + f + tabR), H = tab.height
        var p = Path()          // drawn with the tab under the pad, flush left, from (0, 0); then mirrored into place
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addArc(tangent1End: CGPoint(x: w, y: 0), tangent2End: CGPoint(x: w, y: r), radius: r)
        p.addLine(to: CGPoint(x: w, y: h - f))
        p.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w + f, y: h), radius: f)
        p.addLine(to: CGPoint(x: W - tabR, y: h))
        p.addArc(tangent1End: CGPoint(x: W, y: h), tangent2End: CGPoint(x: W, y: h + tabR), radius: tabR)
        p.addLine(to: CGPoint(x: W, y: h + H - tabR))
        p.addArc(tangent1End: CGPoint(x: W, y: h + H), tangent2End: CGPoint(x: W - tabR, y: h + H), radius: tabR)
        p.addLine(to: CGPoint(x: tabR, y: h + H))
        p.addArc(tangent1End: CGPoint(x: 0, y: h + H), tangent2End: CGPoint(x: 0, y: h + H - tabR), radius: tabR)
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
    /// Room beside the pad for the tint's inner turn (up to the radius plus the gap).
    static let fillet: CGFloat = 40
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
                // room round both for the tab's shadow on every side (Scott, 2026-11-09: it was cut off in a hard-edged
                // band on the pad beside the selected one, where only the pad's strip let it through)
                let m: CGFloat = tab.width > 0 ? 32 : 0
                ZStack(alignment: .topLeading) {
                    Color.clear
                    // the pad and its border, wide enough for the fillets where the tab meets it
                    Rectangle().frame(width: pad.width + 2 * Self.fillet + 2 + 2 * m, height: pad.height + 2 + 2 * m)
                        .offset(x: pad.minX - Self.fillet - 1 - m, y: pad.minY - 1 - m)
                    // the tab, revealed from the pad's edge
                    // (its far edge's room grows with the reveal, so no more of the tab shows early)
                    Rectangle().frame(width: tab.width + 2 * m, height: h + m + m * p)
                        .offset(x: tab.minX - m, y: up ? tab.maxY - h - m * p : tab.minY - m)
                }
            }
            // (no fade: the controls roll out of their pad and back in, Scott 2026-11-09: "not a crossfade")
    }
}


/// A track's lane (PadsPage.lanes): the tag (`tag`, from the left) with corners `tagR` (the chip's 7 + its 12 inset),
/// joined to the band (`height`) from the tag's right edge, where pad A starts, to the right; the band's corner there is
/// a pad's (`padR`, flush under pad A) and the turn from pad A's side into the tag's foot `padR` too. A tag as tall as
/// the band: one band (Half).
struct LaneShape: Shape {
    var tag: CGSize
    var height: CGFloat
    var tagR: CGFloat
    var padR: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(tag.height, height), tagR) }
        set { tag.height = newValue.first.first; height = newValue.first.second; tagR = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let X = rect.maxX, bx = tag.width, h = height, th = min(tag.height, h), rt = min(tagR, th / 2)
        var p = Path()
        p.move(to: CGPoint(x: rt, y: 0))
        p.addLine(to: CGPoint(x: X, y: 0))
        p.addLine(to: CGPoint(x: X, y: h))
        if th >= h - 0.5 {
            // one band: the tag as tall as it
            p.addLine(to: CGPoint(x: rt, y: h))
            p.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: 0, y: h - rt), radius: rt)
        } else {
            let rb = min(padR, (h - th) / 2), rc = min(padR, (h - th) / 2)
            p.addLine(to: CGPoint(x: bx + rb, y: h))
            p.addArc(tangent1End: CGPoint(x: bx, y: h), tangent2End: CGPoint(x: bx, y: h - rb), radius: rb)
            p.addLine(to: CGPoint(x: bx, y: th + rc))
            p.addArc(tangent1End: CGPoint(x: bx, y: th), tangent2End: CGPoint(x: bx - rc, y: th), radius: rc)
            p.addLine(to: CGPoint(x: rt, y: th))
            p.addArc(tangent1End: CGPoint(x: 0, y: th), tangent2End: CGPoint(x: 0, y: th - rt), radius: rt)
        }
        p.addLine(to: CGPoint(x: 0, y: rt))
        p.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: rt, y: 0), radius: rt)
        p.closeSubpath()
        return p
    }
}


/// The track controls' box joined to the selected track's lane (Scott, 2026-11-09: one strip, no shadow): the box
/// (`box`) hanging straight off the lane's edge, concave ears `ear` where its sides meet that edge (none on the left
/// under pad A, where the box carries the band's end straight down), its far corners `r`; `up`: hanging above.
struct LaneTabShape: Shape {
    var box: CGRect
    var earL: CGFloat
    var earR: CGFloat
    var r: CGFloat
    var up: Bool

    func path(in rect: CGRect) -> Path {
        // drawn hanging down from y 0 (half a point into the lane, no hairline), then flipped for `up`
        let w = box.width, h = box.height, t: CGFloat = -0.5
        var p = Path()
        p.move(to: CGPoint(x: -earL, y: t))
        p.addLine(to: CGPoint(x: w + earR, y: t))
        if earR > 0 { p.addArc(tangent1End: CGPoint(x: w, y: t), tangent2End: CGPoint(x: w, y: t + earR), radius: earR) }
        p.addLine(to: CGPoint(x: w, y: h - r))
        p.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w - r, y: h), radius: r)
        p.addLine(to: CGPoint(x: r, y: h))
        p.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: 0, y: h - r), radius: r)
        if earL > 0 {
            p.addLine(to: CGPoint(x: 0, y: t + earL))
            p.addArc(tangent1End: CGPoint(x: 0, y: t), tangent2End: CGPoint(x: -earL, y: t), radius: earL)
        } else {
            p.addLine(to: CGPoint(x: 0, y: t))
        }
        p.closeSubpath()
        var m = CGAffineTransform(translationX: box.minX, y: up ? box.maxY : box.minY)
        if up { m = m.scaledBy(x: 1, y: -1) }
        return p.applying(m)
    }
}

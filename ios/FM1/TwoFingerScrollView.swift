import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The grids' scroll view. One finger pans it, two too (Scott, 2026-11-07: two fingers alone missed too often, "not
/// having reliable pan is super annoying"); the grid's edits begin with a hold (its ring) or a tap instead. A drag
/// from where `panFrom` says no (a note's grip) or after the hold took is the grid's, not a pan. A trackpad's scroll
/// pans it too. Reports its offset so headers and the playhead can follow, and scrolls to `request` when it changes.
struct TwoFingerScrollView<Content: View>: UIViewRepresentable {
    var contentSize: CGSize
    @Binding var offset: CGPoint
    var request: ScrollRequest?
    /// The grid's rows, top to bottom, and their height. When rows come or go above the view (the piano
    /// roll's padding rebalancing around a new note), the offset moves with them in the same update, so
    /// the row under the finger stays put.
    var rowKeys: [Int]? = nil
    var rowHeight: CGFloat = 0
    /// Where a horizontal pan comes to rest: a multiple of this (a bar), never between.
    var snapX: CGFloat? = nil
    /// The grid's hold (seconds) before a one-finger drag carries or boxes notes: a ring fills around the finger
    /// over that time, so you can see when it's ready (Scott, 2026-11-06). Nil: no hold on this grid.
    var holdRing: Double? = nil
    /// Where (in the grid's points) one finger may start a pan; nil: anywhere. The piano roll's note grips say no.
    var panFrom: ((CGPoint) -> Bool)? = nil
    @ViewBuilder var content: () -> Content

    struct ScrollRequest: Equatable {
        var x: CGFloat
        var id: Int
    }

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset, snapX: snapX) }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = GridScrollView()
        sv.shouldPan = { [unowned c = context.coordinator] in c.shouldPan($0) }
        sv.panGestureRecognizer.allowedScrollTypesMask = .all
        sv.delaysContentTouches = false
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = true
        sv.indicatorStyle = .white
        sv.backgroundColor = .clear
        sv.bounces = true
        sv.alwaysBounceHorizontal = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.delegate = context.coordinator
        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.sizingOptions = []
        // the grid is content, not a screen: no safe-area insets (a landscape iPhone has them on both sides)
        host.safeAreaRegions = []
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        sv.addSubview(host.view)
        sv.contentSize = contentSize
        context.coordinator.host = host
        // every touch on the grid, watched without taking it: a second finger hands the gesture to the pan, and a
        // still first finger gets the hold's ring
        let watch = TouchWatch()
        watch.delegate = context.coordinator
        context.coordinator.watch(watch)
        sv.addGestureRecognizer(watch)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        let c = context.coordinator
        c.holdRing = holdRing
        c.panFrom = panFrom
        // the hosted grid joins the view-controller tree once it's on screen: outside it, on a landscape
        // iPhone, it laid out and drew but never showed (2026-11-04)
        c.host?.rootView = content()
        var y = sv.contentOffset.y, shifted = false
        if let keys = rowKeys, let old = c.lastRowKeys, keys != old, rowHeight > 0 {
            let top = max(0, min(old.count - 1, Int((y / rowHeight).rounded())))
            if old.indices.contains(top), let now = keys.firstIndex(of: old[top]) {
                y += CGFloat(now - top) * rowHeight
                shifted = now != top
            }
        }
        c.lastRowKeys = rowKeys
        if sv.contentSize != contentSize {
            sv.contentSize = contentSize
            c.host?.view.frame = CGRect(origin: .zero, size: contentSize)
        }
        if shifted {
            c.adjusting = true
            sv.contentOffset.y = min(max(0, y), max(0, contentSize.height - sv.bounds.height))
            c.adjusting = false
            let o = sv.contentOffset
            DispatchQueue.main.async { if c.offset.wrappedValue != o { c.offset.wrappedValue = o } }
        }
        if let r = request, r != c.lastRequest {
            c.lastRequest = r
            let maxX = max(0, contentSize.width - sv.bounds.width)
            sv.setContentOffset(CGPoint(x: min(max(0, r.x), maxX), y: sv.contentOffset.y), animated: true)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var host: UIHostingController<Content>?
        var holdRing: Double?
        var panFrom: ((CGPoint) -> Bool)?
        private let ring = HoldRing()
        private var downAt: CGPoint?
        /// The first finger's landing, in the grid's points, and when.
        private var landed: (p: CGPoint, t: TimeInterval)?
        /// A one-finger pan moved by hand: where it began (window points), the offset then, its last point and time,
        /// and its speed (points a second, for the throw).
        struct HandPan { var from: CGPoint, offset: CGPoint, last: CGPoint, at: TimeInterval, speed: CGPoint = .zero }
        private var drag: HandPan?
        var offset: Binding<CGPoint>
        var lastRequest: ScrollRequest?
        var lastRowKeys: [Int]?
        var adjusting = false          // a shift made inside updateUIView: the binding is set after it
        let snapX: CGFloat?
        init(offset: Binding<CGPoint>, snapX: CGFloat?) { self.offset = offset; self.snapX = snapX }

        func watch(_ w: TouchWatch) {
            w.down = { [unowned self] t in
                guard let v = host?.view else { return }
                let p = t.location(in: v)
                landed = (p, t.timestamp)
                guard let hold = holdRing else { return }
                downAt = p
                ring.start(at: p, in: v.layer, duration: hold)
            }
            w.moved = { [unowned self] t in
                guard let v = host?.view else { return }
                let p = t.location(in: v)
                if let a = downAt, hypot(p.x - a.x, p.y - a.y) > 8 { ring.cancel(); downAt = nil }   // the hold's own 8 pt
                // A finger moving off before the hold took is a pan, moved here by hand: the scroll view's own pan
                // had already failed by then, beaten by the grid's SwiftUI gestures, and a failed one can't come back
                // (2026-11-07, "doesn't work at all"; its state read 5, failed, at 10 pt). A drag from a grip, or
                // after the hold, stays the grid's.
                let w = t.location(in: nil)
                if let d = drag { follow(d, w, t.timestamp); return }
                guard let (l, at) = landed, hypot(p.x - l.x, p.y - l.y) > 10 else { return }
                if let hold = holdRing, t.timestamp - at >= hold { return }
                guard panFrom?(l) ?? true, let sv = v.superview as? UIScrollView, !sv.isDragging, !sv.isDecelerating else { return }
                drag = HandPan(from: w, offset: sv.contentOffset, last: w, at: t.timestamp)
                cancelGrid()
                NotificationCenter.default.post(name: .gridPannedByHand, object: nil)
            }
            w.up = { [unowned self] in ring.cancel(); downAt = nil; landed = nil; if let d = drag { drag = nil; settle(d) } }
            // Two fingers: a pan. A gesture the grid began on the first finger, a few milliseconds before the second
            // landed, made iOS refuse the pan for the whole touch (2026-11-06). Cancel it.
            w.second = { [unowned self] in cancelGrid() }
        }
        /// One finger pans unless it began on a grip, or stayed still through the hold (the ring filled: the drag is
        /// the hold's paint, carry or box). Two fingers always pan.
        func shouldPan(_ g: UIPanGestureRecognizer) -> Bool {
            guard g.numberOfTouches < 2, let (p, t) = landed else { return true }
            if let hold = holdRing, ProcessInfo.processInfo.systemUptime - t >= hold { return false }
            return panFrom?(p) ?? true
        }
        private func follow(_ d: HandPan, _ w: CGPoint, _ t: TimeInterval) {
            guard let sv = host?.view.superview as? UIScrollView else { return }
            let maxX = max(0, sv.contentSize.width - sv.bounds.width), maxY = max(0, sv.contentSize.height - sv.bounds.height)
            sv.contentOffset = CGPoint(x: min(max(0, d.offset.x - (w.x - d.from.x)), maxX),
                                       y: min(max(0, d.offset.y - (w.y - d.from.y)), maxY))
            var n = d
            let dt = t - d.at
            if dt > 0.004 {
                let v = CGPoint(x: (w.x - d.last.x) / dt, y: (w.y - d.last.y) / dt)
                n.speed = CGPoint(x: d.speed.x * 0.4 + v.x * 0.6, y: d.speed.y * 0.4 + v.y * 0.6)
                n.last = w; n.at = t
            }
            drag = n
        }
        /// The finger lifts: as the scroll view's own pan ends, on the nearest bar in the direction it was thrown.
        private func settle(_ d: HandPan) {
            guard let sv = host?.view.superview as? UIScrollView else { return }
            var target = sv.contentOffset
            let maxY = max(0, sv.contentSize.height - sv.bounds.height)
            target.y = min(max(0, target.y - d.speed.y * 0.15), maxY)
            if let w = snapX, w > 0 {
                let maxX = max(0, sv.contentSize.width - sv.bounds.width)
                let start = sv.contentOffset.x / w, vx = -d.speed.x / 1000
                let bar: CGFloat = abs(vx) > 0.3 ? (vx > 0 ? start.rounded(.up) : start.rounded(.down)) : start.rounded()
                target.x = min(max(0, bar * w), maxX)
            }
            if target != sv.contentOffset { sv.setContentOffset(target, animated: true) }
        }
        /// A pan took the touch: the grid's one-finger gesture (a tap about to land, a hold not yet taken) stops.
        private func cancelGrid() {
            ring.cancel(); downAt = nil
            guard let v = host?.view else { return }
            for g in Self.recognizers(in: v) where g.isEnabled { g.isEnabled = false; g.isEnabled = true }
            NotificationCenter.default.post(name: .gridPanned, object: nil)
        }
        private static func recognizers(in v: UIView) -> [UIGestureRecognizer] {
            (v.gestureRecognizers ?? []) + v.subviews.flatMap { recognizers(in: $0) }
        }
        /// The watch takes nothing from anyone.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
        func scrollViewDidScroll(_ sv: UIScrollView) {
            guard !adjusting else { return }
            let o = sv.contentOffset
            if o != offset.wrappedValue { offset.wrappedValue = o }
        }
        func scrollViewWillBeginDragging(_ sv: UIScrollView) {
            cancelGrid()
            NotificationCenter.default.post(name: .gridPannedByHand, object: nil)
        }
        /// A pan ends on the nearest bar in the direction it was thrown.
        func scrollViewWillEndDragging(_ sv: UIScrollView, withVelocity v: CGPoint, targetContentOffset target: UnsafeMutablePointer<CGPoint>) {
            guard let w = snapX, w > 0 else { return }
            let maxX = max(0, sv.contentSize.width - sv.bounds.width)
            let start = sv.contentOffset.x / w
            let bar: CGFloat = abs(v.x) > 0.3 ? (v.x > 0 ? start.rounded(.up) : start.rounded(.down)) : (target.pointee.x / w).rounded()
            target.pointee.x = min(max(0, bar * w), maxX)
        }
    }
}

extension Notification.Name {
    static let gridPannedByHand = Notification.Name("gridPannedByHand")
    /// A pan took a grid's touch: its own gesture was cancelled, so a slide's or a hold's state starts over.
    static let gridPanned = Notification.Name("gridPanned")
}

/// The grid's scroll view: its pan runs alongside the grid's own gestures instead of losing to one that began first
/// (it then cancels that one), and asks `shouldPan` before it starts.
final class GridScrollView: UIScrollView {
    var shouldPan: ((UIPanGestureRecognizer) -> Bool)?
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if g === panGestureRecognizer, let ask = shouldPan, !ask(panGestureRecognizer) { return false }
        return super.gestureRecognizerShouldBegin(g)
    }
    @objc func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool {
        g === panGestureRecognizer && o.view !== self && o.view?.isDescendant(of: self) == true
    }
}

/// Watches the touches on a grid and never recognizes: the first finger down, its moves, a second finger, all up.
final class TouchWatch: UIGestureRecognizer {
    var down: ((UITouch) -> Void)?, moved: ((UITouch) -> Void)?, second: (() -> Void)?, up: (() -> Void)?
    private var touching = Set<UITouch>()

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }
    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent) {
        let was = touching.count
        touching.formUnion(t)
        if was == 0, touching.count == 1, let f = touching.first { down?(f) }
        if was < 2, touching.count >= 2 { second?() }
    }
    override func touchesMoved(_ t: Set<UITouch>, with e: UIEvent) {
        if touching.count == 1, let f = touching.first { moved?(f) }
    }
    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent) { lift(t) }
    override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent) { lift(t) }
    private func lift(_ t: Set<UITouch>) {
        touching.subtract(t)
        guard touching.isEmpty else { return }
        up?()
        state = .failed
    }
    override func reset() { touching = [] }
}

/// A ring around a still finger that fills over the hold's time; full, it pulses out (the hold took: carry or box).
/// It appears 0.1 s in, already that far round, so a tap never flashes it. Reduce Motion: no fill, the full ring
/// shows when the hold takes and fades.
final class HoldRing {
    private let box = CALayer(), track = CAShapeLayer(), fill = CAShapeLayer()
    private var pending: [DispatchWorkItem] = []
    static let radius: CGFloat = 36             // clear of a fingertip (about 44 pt across)
    static let delay = 0.1

    init() {
        let r = Self.radius
        let path = UIBezierPath(arcCenter: .zero, radius: r, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true).cgPath
        for (l, a) in [(track, 0.22), (fill, 0.95)] {
            l.path = path
            l.fillColor = nil
            l.strokeColor = UIColor(Theme.text).withAlphaComponent(a).cgColor
            l.lineWidth = 3
            l.lineCap = .round
            box.addSublayer(l)
        }
        box.zPosition = 10
    }

    func start(at p: CGPoint, in host: CALayer, duration: Double) {
        cancel()
        let still = UIAccessibility.isReduceMotionEnabled
        let show = DispatchWorkItem { [self] in
            CATransaction.begin(); CATransaction.setDisableActions(true)
            box.position = p
            box.opacity = 1
            box.transform = CATransform3DIdentity
            fill.strokeEnd = 1
            host.addSublayer(box)
            CATransaction.commit()
            let a = CABasicAnimation(keyPath: "strokeEnd")
            a.fromValue = Self.delay / duration
            a.toValue = 1
            a.duration = duration - Self.delay
            fill.add(a, forKey: "fill")
        }
        let took = DispatchWorkItem { [self] in
            if still {
                CATransaction.begin(); CATransaction.setDisableActions(true)
                box.position = p; fill.strokeEnd = 1; box.opacity = 1
                host.addSublayer(box)
                CATransaction.commit()
            }
            CATransaction.begin()
            CATransaction.setAnimationDuration(still ? 0.25 : 0.2)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock { [self] in if box.opacity == 0 { box.removeFromSuperlayer() } }
            if !still { box.transform = CATransform3DMakeScale(1.18, 1.18, 1) }
            box.opacity = 0
            CATransaction.commit()
        }
        pending = still ? [took] : [show, took]
        if !still { DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: show) }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: took)
    }

    func cancel() {
        pending.forEach { $0.cancel() }
        pending = []
        fill.removeAllAnimations()
        box.removeFromSuperlayer()
    }
}

extension View {
    /// Keeps a grid and the timeline's view box together: the grid reports where it is, and scrolls to a
    /// bar picked on the timeline (`scroll` takes the offset and a request id). A grid that appears picks
    /// up the bar the other grid was on.
    func followsView(ui: EditorUI, grid: GridMetrics, offset: CGPoint, scroll: @escaping (CGFloat, Int) -> Void) -> some View {
        self
            .onChange(of: offset.x) { _, x in ui.viewStep = x / grid.stepWidth }
            .onChange(of: ui.viewJump) { _, j in if let j { scroll(CGFloat(j.bar) * grid.barWidth, j.id) } }
            .onAppear {
                let bar = Int((ui.viewStep / 16).rounded())
                if abs(offset.x - CGFloat(bar) * grid.barWidth) > 1 { scroll(CGFloat(bar) * grid.barWidth, -1 - bar) }
            }
    }
}

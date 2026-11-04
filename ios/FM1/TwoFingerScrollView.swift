import SwiftUI
import UIKit

/// A scroll view that pans with two fingers only, so one finger always reaches the cells
/// (design brief, "Grid gestures"). A trackpad's two-finger scroll pans it too. Reports its offset
/// so headers and the playhead can follow, and scrolls to `request` when it changes.
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
    @ViewBuilder var content: () -> Content

    struct ScrollRequest: Equatable {
        var x: CGFloat
        var id: Int
    }

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset, snapX: snapX) }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.panGestureRecognizer.minimumNumberOfTouches = 2
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
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        sv.addSubview(host.view)
        sv.contentSize = contentSize
        context.coordinator.host = host
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        let c = context.coordinator
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

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var host: UIHostingController<Content>?
        var offset: Binding<CGPoint>
        var lastRequest: ScrollRequest?
        var lastRowKeys: [Int]?
        var adjusting = false          // a shift made inside updateUIView: the binding is set after it
        let snapX: CGFloat?
        init(offset: Binding<CGPoint>, snapX: CGFloat?) { self.offset = offset; self.snapX = snapX }
        func scrollViewDidScroll(_ sv: UIScrollView) {
            guard !adjusting else { return }
            let o = sv.contentOffset
            if o != offset.wrappedValue { offset.wrappedValue = o }
        }
        func scrollViewWillBeginDragging(_ sv: UIScrollView) {
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

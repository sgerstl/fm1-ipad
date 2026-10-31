import SwiftUI
import UIKit

/// A scroll view that pans with two fingers only, so one finger always reaches the cells
/// (design brief, "Grid gestures"). A trackpad's two-finger scroll pans it too. Reports its offset
/// so headers and the playhead can follow, and scrolls to `request` when it changes.
struct TwoFingerScrollView<Content: View>: UIViewRepresentable {
    var contentSize: CGSize
    @Binding var offset: CGPoint
    var request: ScrollRequest?
    @ViewBuilder var content: () -> Content

    struct ScrollRequest: Equatable {
        var x: CGFloat
        var id: Int
    }

    func makeCoordinator() -> Coordinator { Coordinator(offset: $offset) }

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
        if sv.contentSize != contentSize {
            sv.contentSize = contentSize
            c.host?.view.frame = CGRect(origin: .zero, size: contentSize)
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
        init(offset: Binding<CGPoint>) { self.offset = offset }
        func scrollViewDidScroll(_ sv: UIScrollView) {
            let o = sv.contentOffset
            if o != offset.wrappedValue { offset.wrappedValue = o }
        }
        func scrollViewWillBeginDragging(_ sv: UIScrollView) {
            NotificationCenter.default.post(name: .gridPannedByHand, object: nil)
        }
    }
}

extension Notification.Name {
    static let gridPannedByHand = Notification.Name("gridPannedByHand")
}

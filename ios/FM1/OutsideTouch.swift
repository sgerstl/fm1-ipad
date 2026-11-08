import SwiftUI
import UIKit

// A menu or panel closes on a touch anywhere outside it, and that touch still reaches the page (Scott, 2026-11-08:
// "the rest of the stuff on the page to remain interactable, so if I see something I want to adjust, i don't have to
// tap first before the menu goes away"). No catcher over the page: a recognizer on the window sees the touch begin,
// closes the popover, and fails at once, so every control and gesture under the finger behaves as if nothing were open.

@MainActor
enum OutsideTouch {
    /// When a popover last closed this way. The touch that closed it may be on the very key that opens it (the tempo
    /// readout): that key asks `justClosed` and leaves it shut, so the touch reads as "close", not "close, reopen".
    static var lastClose: Date = .distantPast
    static var justClosed: Bool { Date().timeIntervalSince(lastClose) < 0.5 }
}

extension View {
    /// Closes with `close` on any touch outside this view's bounds, passing the touch through.
    func closesOnOutsideTouch(_ close: @escaping () -> Void) -> some View {
        background(OutsideTouchWatch(close: close).allowsHitTesting(false))
    }
}

private struct OutsideTouchWatch: UIViewRepresentable {
    let close: () -> Void

    func makeUIView(context: Context) -> WatchView {
        let v = WatchView()
        v.isUserInteractionEnabled = false
        v.close = close
        return v
    }
    func updateUIView(_ v: WatchView, context: Context) { v.close = close }
    static func dismantleUIView(_ v: WatchView, coordinator: ()) { v.detach() }

    final class WatchView: UIView {
        var close: (() -> Void)?
        private var watcher: Watcher?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let w = window else { return }
            let g = Watcher()
            g.host = self
            w.addGestureRecognizer(g)
            watcher = g
        }

        /// Taken off the window once the touches going on end, never during them: a recognizer removed mid-touch
        /// cancelled the touch for every gesture under it (a pad's drag, whose hold had opened the menu).
        func detach() {
            watcher?.retire()
            watcher = nil
        }

        func touched(at p: CGPoint) {
            guard !bounds.contains(convert(p, from: nil)) else { return }
            OutsideTouch.lastClose = Date()
            close?()
        }
    }

    /// Sees a touch begin and never claims it.
    final class Watcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
        weak var host: WatchView?

        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
            delegate = self
        }
        convenience init() { self.init(target: nil, action: nil) }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy o: UIGestureRecognizer) -> Bool { false }

        private var retired = false

        func retire() {
            host = nil
            retired = true
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let t = touches.first { host?.touched(at: t.location(in: nil)) }
            state = .failed
        }

        // UIKit resets a recognizer when the touches it saw have all ended: the safe moment to go
        override func reset() {
            super.reset()
            guard retired else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.view?.removeGestureRecognizer(self)
            }
        }
    }
}

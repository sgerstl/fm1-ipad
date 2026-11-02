import UIKit

/// -show-touches (screen recordings only): a circle under each finger, drawn in a window above the
/// app that takes no touches, and every touch's start and end written to Documents/touches.log
/// (Unix seconds), so an edit can keep the actions and cut the waits between them.
@MainActor
enum TouchShow {
    private static var overlay: UIWindow?

    static func installIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-show-touches"), overlay == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let main = scene.windows.first else { return }
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 10
        w.isUserInteractionEnabled = false          // touches pass through to the app below
        w.backgroundColor = .clear
        w.rootViewController = NoStatusBar()       // (a window without one brings the status bar back)
        w.rootViewController?.view.backgroundColor = .clear
        w.isHidden = false
        overlay = w
        let watcher = TouchWatcher(target: nil, action: nil)
        watcher.overlay = w
        main.addGestureRecognizer(watcher)
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    static let logURL = URL.documentsDirectory.appending(path: "touches.log")

    static func log(_ what: String, _ p: CGPoint) {
        let line = String(format: "%.3f %@ %.0f %.0f\n", Date().timeIntervalSince1970, what, p.x, p.y)
        if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
    }
}

private final class NoStatusBar: UIViewController {
    override var prefersStatusBarHidden: Bool { true }
}

/// Sees every touch in the window and never claims one: it stays possible while fingers are down,
/// then fails, so the app's own gestures and controls behave as without it.
private final class TouchWatcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
    weak var overlay: UIWindow?
    private var dots: [ObjectIdentifier: UIView] = [:]

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches {
            let p = t.location(in: nil)
            let d = UIView(frame: CGRect(x: 0, y: 0, width: 52, height: 52))
            d.layer.cornerRadius = 26
            d.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            d.layer.borderColor = UIColor.white.cgColor
            d.layer.borderWidth = 3
            d.layer.shadowColor = UIColor.black.cgColor
            d.layer.shadowOpacity = 0.35
            d.layer.shadowRadius = 6
            d.center = p
            d.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            overlay?.rootViewController?.view.addSubview(d)
            UIView.animate(withDuration: 0.12) { d.transform = .identity }
            dots[ObjectIdentifier(t)] = d
            TouchShow.log("down", p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches { dots[ObjectIdentifier(t)]?.center = t.location(in: nil) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }

    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            TouchShow.log("up", t.location(in: nil))
            guard let d = dots.removeValue(forKey: ObjectIdentifier(t)) else { continue }
            UIView.animate(withDuration: 0.35, animations: {
                d.alpha = 0
                d.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }, completion: { _ in d.removeFromSuperview() })
        }
        if dots.isEmpty { state = .failed }
    }

    override func reset() { dots.values.forEach { $0.removeFromSuperview() }; dots = [:] }
}

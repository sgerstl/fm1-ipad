import SloopKit
import SwiftUI

// Edge action wells for a dragged pad (board 81, tile 81.4; Scott's pick 2026-11-15; batch item 12; layout decision 41): while a held pad is
// lifted into a drag, three wells sit flush on the screen's edges, square on the edge side and rounded 12 inside, 1.5 pt
// dashes on the three inner sides, resting as dark glass (black 62 % over a 12 pt blur of what's behind). Bottom Clear,
// right Edit, left Duplicate. Decision 41: Cancel at the bottom; the top split between Clear steps and Delete pattern. Each slides in from its own edge as the pad lifts (Labs › Wells: slide,
// staggered 30 ms: bottom, left, right) and back out faster on the drop. As the pad's centre nears a well a glow builds
// on it in the track colour (red for Clear), growing with closeness (Labs › Wells: glow distance); closer still it goes
// hot (Labs › Wells: hot distance): solid fill, solid border, dark label, a light tick, the lifted pad tilting toward it.
// Reduce Motion: fades, no slides. VoiceOver keeps the hold menu. iPhone and iPad.

enum EdgeAction: CaseIterable, Equatable {
    // decision 41 (Scott, 2026-11-15): Cancel at the bottom, Clear steps and Delete pattern sharing the top, Edit right,
    // Duplicate left
    case cancel, clearSteps, delete, edit, duplicate
    var title: String {
        switch self { case .cancel: "Cancel"; case .clearSteps: "Clear steps"; case .delete: "Delete pattern"; case .edit: "Edit"; case .duplicate: "Duplicate" }
    }
    var icon: String {
        switch self { case .cancel: "xmark"; case .clearSteps: "eraser"; case .delete: "trash"; case .edit: "pencil"; case .duplicate: "plus.square.on.square" }
    }
    var edge: Edge { switch self { case .cancel: .bottom; case .clearSteps, .delete: .top; case .edit: .trailing; case .duplicate: .leading } }
    /// The order they slide in (bottom, top, left, right).
    var stagger: Double { switch self { case .cancel: 0; case .clearSteps, .delete: 0.03; case .duplicate: 0.06; case .edit: 0.09 } }
    /// Laid out along its edge (the bottom and top wells) rather than up it.
    var across: Bool { edge == .top || edge == .bottom }
}

/// The pad being dragged, for the wells: its centre (global) and its track.
struct PadDragShow: Equatable {
    var centre: CGPoint
    var track: Int
}

@MainActor enum EdgeWellsGeometry {
    /// Board 81.4 at the iPhone's 874 × 402: the bottom well 434 × 52, the side wells 64 wide and 238 tall, centred; the
    /// iPad's are the same sizes, scaled up by its height for the side wells.
    static func rect(_ a: EdgeAction, in screen: CGSize) -> CGRect {
        let sideH = min(screen.height * 0.6, max(238, screen.height * 0.5))
        let topW = min(2 * 260 + 8, screen.width * 0.6), half = (topW - 8) / 2, topX = (screen.width - topW) / 2
        switch a {
        case .cancel:
            let w = min(434, screen.width * 0.5)
            return CGRect(x: (screen.width - w) / 2, y: screen.height - 52, width: w, height: 52)
        case .clearSteps: return CGRect(x: topX, y: 0, width: half, height: 52)
        case .delete: return CGRect(x: topX + half + 8, y: 0, width: half, height: 52)
        // the side well on the Dynamic Island's side widens by the Island's margin, so its icon and label clear it (it stays
        // attached to the edge; the content sits in the inner 64)
        case .duplicate:
            let w = 64 + island.leading
            return CGRect(x: 0, y: (screen.height - sideH) / 2, width: w, height: sideH)
        case .edit:
            let w = 64 + island.trailing
            return CGRect(x: screen.width - w, y: (screen.height - sideH) / 2, width: w, height: sideH)
        }
    }

    /// The Dynamic Island's margin on each side in landscape (the iPhone only; the iPad has none): the window's safe area on
    /// the side the Island is on by the orientation, 0 on the other.
    @MainActor static var island: (leading: CGFloat, trailing: CGFloat) {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first else { return (0, 0) }
        let insets = window.safeAreaInsets
        switch scene.interfaceOrientation {
        case .landscapeRight: return (insets.left, 0)        // the device's top (the Island) on the left
        case .landscapeLeft: return (0, insets.right)
        default: return (0, 0)
        }
    }

    /// How far a point is from a well's rectangle (0 inside).
    static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return hypot(dx, dy)
    }

    /// The glow and hot distances for a well, by its axis (Scott, 2026-11-15): the glow a share of the screen's extent
    /// along that axis (the height for the top and bottom wells, the width for the sides), the hot distance its own.
    static func reach(_ a: EdgeAction, in screen: CGSize) -> (glow: CGFloat, hot: CGFloat) {
        switch a.edge {
        case .leading, .trailing:
            (screen.width * CGFloat(Labs.wellGlowSide.value) / 100, CGFloat(Labs.wellHotSide.value))
        default:
            (screen.height * CGFloat(Labs.wellGlow.value) / 100, CGFloat(Labs.wellHot.value))
        }
    }

    /// 0…1: how near the pad's centre is to the well: 0 from the glow distance out, rising evenly to 1 at the hot distance.
    static func closeness(_ a: EdgeAction, centre: CGPoint, screen: CGSize, off: Set<EdgeAction> = []) -> Double {
        if off.contains(a) { return 0 }
        let d = distance(centre, rect(a, in: screen)), r = reach(a, in: screen)
        return Double(max(0, min(1, (r.glow - d) / max(1, r.glow - r.hot))))
    }

    /// The well a drop at `centre` lands in: of those within their hot distance, the one it's deepest into.
    /// `off`: wells that refuse a drop now (Delete pattern while playing): never hot.
    static func hot(centre: CGPoint, screen: CGSize, off: Set<EdgeAction> = []) -> EdgeAction? {
        EdgeAction.allCases.filter { !off.contains($0) }
            .map { a in (a, distance(centre, rect(a, in: screen)) / max(1, reach(a, in: screen).hot)) }
            .filter { $0.1 <= 1 }
            .min { $0.1 < $1.1 }?.0
    }

    /// The window's size (the drag's points are the window's): the whole screen on a phone, the app's window on an iPad
    /// in Split View or Stage Manager.
    @MainActor static var screen: CGSize {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return .zero }
        return (scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first)?.bounds.size ?? scene.screen.bounds.size
    }
}

/// The wells that refuse a drop now: Delete pattern while playing (it shows greyed with "Stop first").
@MainActor func offWells(_ session: DeviceSession) -> Set<EdgeAction> { session.playing ? [.delete] : [] }

/// The wells layer: over the whole screen (safe areas included), drawing nothing while no pad is dragged.
struct EdgeWells: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            // one space for the wells, the lifted pad and the drop (PadsPage.dropAt): the window's, where the drag's
            // points are. This layer may sit inside the iPad's scaled canvas, so it's drawn in window points and the
            // canvas's scale and offset are undone for it (Scott, 2026-11-15: on the iPad the lifted pad sat off to the
            // side of the finger). The phone: scale 1 at the window's origin, as before.
            let f = g.frame(in: .global)
            let k = max(0.01, f.width / max(1, g.size.width))
            let screen = EdgeWellsGeometry.screen == .zero ? f.size : EdgeWellsGeometry.screen
            let drag = ui.padDrag
            let off = offWells(session)
            let hot = drag.flatMap { EdgeWellsGeometry.hot(centre: $0.centre, screen: screen, off: off) }
            ZStack(alignment: .topLeading) {
                ForEach(EdgeAction.allCases, id: \.self) { a in
                    if let d = drag {
                        well(a, drag: d, hot: hot == a, off: off.contains(a), screen: screen)
                            .transition(transition(a))
                    }
                }
                // the lifted pad, over the wells, tilting toward a hot one
                if let d = drag, let face = ui.padDragFace {
                    let size = ui.padDragSize
                    let tilt: (Double, (x: CGFloat, y: CGFloat, z: CGFloat)) = switch hot {
                        case .edit: (14, (0, 1, 0)); case .duplicate: (-14, (0, 1, 0)); case .cancel: (-14, (1, 0, 0))
                        case .clearSteps, .delete: (14, (1, 0, 0)); case nil: (0, (0, 1, 0))
                    }
                    face
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(k)                 // (its face is drawn at the canvas's size: window points here)
                        .frame(width: size.width * k, height: size.height * k)
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : tilt.0), axis: tilt.1, perspective: 0.6)
                        .scaleEffect(reduceMotion ? 1 : 1.06)
                        .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                        .animation(.easeOut(duration: 0.15), value: hot)
                        .position(x: d.centre.x, y: d.centre.y)
                }
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .scaleEffect(1 / k, anchor: .topLeading)
            .offset(x: -f.minX / k, y: -f.minY / k)
            .animation(animation(drag != nil), value: drag != nil)
            .animation(.easeOut(duration: 0.12), value: hot)
            .sensoryFeedback(.impact(weight: .light), trigger: hot) { _, new in new != nil }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)          // (VoiceOver keeps the hold menu)
    }

    private func animation(_ coming: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        let d = Labs.wellSlide.value
        return coming ? .timingCurve(0.2, 0.8, 0.2, 1, duration: d) : .easeIn(duration: d * 0.72)
    }

    private func transition(_ a: EdgeAction) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: a.edge).animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: Labs.wellSlide.value).delay(a.stagger)),
                           removal: .move(edge: a.edge))
    }

    private func well(_ a: EdgeAction, drag: PadDragShow, hot: Bool, off: Bool, screen: CGSize) -> some View {
        let r = EdgeWellsGeometry.rect(a, in: screen)
        // Cancel neutral (white-ish when hot), Delete red, the others the track's colour
        let tint: Color = switch a { case .cancel: Theme.text; case .delete: Theme.rec; default: Theme.track[drag.track] }
        let glow = hot ? 1 : EdgeWellsGeometry.closeness(a, centre: drag.centre, screen: screen, off: off ? [a] : [])
        let e = a.edge
        let shape = UnevenRoundedRectangle(topLeadingRadius: e == .bottom || e == .trailing ? 12 : 0,
                                           bottomLeadingRadius: e == .top || e == .trailing ? 12 : 0,
                                           bottomTrailingRadius: e == .top || e == .leading ? 12 : 0,
                                           topTrailingRadius: e == .bottom || e == .leading ? 12 : 0)
        // the hot one grows 8 into the screen
        let grown: CGRect = {
            guard hot else { return r }
            switch e {
            case .bottom: return CGRect(x: r.minX - 4, y: r.minY - 8, width: r.width + 8, height: r.height + 8)
            case .top: return CGRect(x: r.minX - 4, y: r.minY, width: r.width + 8, height: r.height + 8)
            case .trailing: return CGRect(x: r.minX - 8, y: r.minY - 8, width: r.width + 8, height: r.height + 16)
            case .leading: return CGRect(x: r.minX, y: r.minY - 8, width: r.width + 8, height: r.height + 16)
            }
        }()
        return ZStack {
            // resting: dark glass (a 12 pt blur of what's behind, black 62 % over it)
            shape.fill(.ultraThinMaterial).opacity(hot ? 0 : 1)
            shape.fill(Color.black.opacity(0.62)).opacity(hot ? 0 : 1)
            // the glow building in its colour, then the hot fill (Cancel's a soft white, not a colour)
            shape.fill(tint.opacity(hot ? (a == .cancel ? 0.85 : 1) : (a == .cancel ? 0.18 : 0.35) * glow))
            InnerDashes(edge: e, radius: 12)
                .stroke(hot ? tint : Theme.textSecondary.opacity(0.55 + 0.45 * glow),
                        style: StrokeStyle(lineWidth: 1.5, dash: hot ? [] : [5, 4]))
            labelView(a, hot: hot, off: off)
                .padding(.leading, a == .duplicate ? EdgeWellsGeometry.island.leading : 0)
                .padding(.trailing, a == .edit ? EdgeWellsGeometry.island.trailing : 0)
        }
        .opacity(off ? 0.45 : 1)
        .frame(width: grown.width, height: grown.height)
        .shadow(color: tint.opacity(hot ? 0.5 : 0.4 * glow), radius: 16 * glow)
        .offset(x: grown.minX, y: grown.minY)
    }

    @ViewBuilder private func labelView(_ a: EdgeAction, hot: Bool, off: Bool) -> some View {
        let ink = hot ? Theme.onColour : Theme.text
        let icon = Image(systemName: a.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(hot ? Theme.onColour : Theme.textSecondary)
        if a.across {
            HStack(spacing: 8) {
                icon
                VStack(alignment: .leading, spacing: 0) {
                    Text(a.title).font(.lupe(14, .semibold)).foregroundStyle(ink)
                    if off { Text("Stop first").font(.lupe(11)).foregroundStyle(Theme.textSecondary) }
                }
            }
        } else {
            VStack(spacing: 4) { icon; Text(a.title).font(.lupe(13, .semibold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7) }
        }
    }

}

/// A well's outline on its three inner sides only (the side on the screen's edge has none), rounded `radius` inside.
struct InnerDashes: Shape {
    let edge: Edge
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, rect.width / 2, rect.height / 2)
        switch edge {
        case .bottom:         // open at the bottom
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .trailing:       // open on the right
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .leading:        // open on the left
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .top:            // open at the top
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        return p
    }
}

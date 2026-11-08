import SloopKit
import SwiftUI

// A track's menu at the finger (a long press on a track anywhere): what's open, the layer that shows it, and the
// press that opens it.

struct TrackMenu: Equatable {
    var track: Int
    var at: CGPoint
}

/// A track's menu, beside the finger (long-press a track): its sound, a sample, clearing its steps.
/// Shared by the iPad's track box and the phone's track chips; kept inside `canvasSize`.
struct TrackMenuLayer: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.canvasSize) private var canvas

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let m = ui.trackMenu {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { ui.trackMenu = nil }
                    .accessibilityHidden(true)
                // the pad press menu's look, as every long-press menu (Scott, 2026-11-08): MenuPanel's rows and title
                let groups = Self.groups(session, ui, track: m.track)
                let rows = groups.reduce(0) { $0 + $1.count }
                let tall = 44 + CGFloat(rows) * MenuPanel.rowHeight + CGFloat(max(0, groups.count - 1)) * 9
                MenuPanel(title: "Track \(m.track + 1) · \(Entries.trackName(m.track, session: session))", groups: groups,
                          close: { ui.trackMenu = nil })
                    .id(m.track)
                    .fixedSize()
                    // beside the finger (to its right, centred on it), kept on screen
                    .offset(x: min(max(m.at.x + 28, 12), canvas.width - 312), y: min(max(m.at.y - 50, 12), canvas.height - tall - 12))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                .accessibilityAddTraits(.isModal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ui.trackMenu)
    }

    /// Its items: Select sound (the sound panel, for the track), a sample, its motion, its steps.
    @MainActor static func groups(_ session: DeviceSession, _ ui: EditorUI, track t: Int) -> [[MenuItem]] {
        var g: [[MenuItem]] = []
        // the sound, from here: the sound panel slides out over the page (Scott, 2026-11-08: "Select sound"), not on the
        // Sounds tab, where the browser is the page itself
        if !(ui.songTab && ui.page == .library) {
            g.append([MenuItem(title: "Select sound", icon: "square.grid.2x2") { ui.chooseSound(session, track: t) }])
        }
        var more: [MenuItem] = []
        if !session.isDrums(t), session.capabilities.contains(.samples) {
            // the grid turns over to the sampler; Use on track puts the take on this track
            more.append(MenuItem(title: "Record sample…", icon: "mic") {
                session.select(track: t)
                ui.presetsPanel = false
                ui.timelineOpen = false
                ui.page = .sequencer
                ui.sampler = SamplerRequest(track: t)
            })
        }
        if let mo = session.motion[t], !mo.events.isEmpty {
            // Skiff's motion: knob moves recorded into the steps (and steps' locks)
            more.append(MenuItem(title: "Clear motion (\(mo.steps.count) step\(mo.steps.count == 1 ? "" : "s"))", icon: "waveform.path.badge.minus") {
                session.clearMotion(track: t)
            })
        }
        if !more.isEmpty { g.append(more) }
        let empty = session.stepIndices.allSatisfy { !session.tracks[t].isOn($0) }
        g.append([MenuItem(title: empty ? "Clear all steps: none yet" : "Clear all steps", icon: "trash", enabled: !empty) {
            ui.lastClear = session.clearAll(track: t)
        }])
        return g
    }
}

/// A long press on a track: its menu beside the finger (TrackMenuLayer: Sounds…, a sample, clearing its steps), the track
/// selected, as the Timeline's track names have it (Scott, 2026-11-07: the Pads strip had none).
struct TrackMenuPress: ViewModifier {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    @State private var pressAt: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
                .onChanged { pressAt = $0.location })
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                session.select(track: track)
                ui.trackMenu = TrackMenu(track: track, at: pressAt)
            })
            .accessibilityAction(named: "Track menu") { ui.trackMenu = TrackMenu(track: track, at: CGPoint(x: 200, y: 160 + CGFloat(track) * 48)) }
    }
}

extension View {
    func trackMenuPress(session: DeviceSession, ui: EditorUI, track: Int) -> some View {
        modifier(TrackMenuPress(session: session, ui: ui, track: track))
    }
}

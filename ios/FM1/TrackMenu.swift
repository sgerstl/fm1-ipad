import SloopKit
import SwiftUI

// A track's menu at the finger (a long press on a track anywhere): what's open, the layer that shows it, and the
// press that opens it.

struct TrackMenu: Equatable {
    var track: Int
    var at: CGPoint

    /// Opened by VoiceOver's action, which has no finger: a place beside the track list.
    static func voiceOver(track: Int) -> TrackMenu { TrackMenu(track: track, at: CGPoint(x: 200, y: 160 + CGFloat(track) * 48)) }
}

/// A track's menu, beside the finger (long-press a track): its sound, a sample, clearing its steps. Shared by the iPad's
/// track box and the phone's track chips; placed as every menu is (PlacedMenu: away from the playing hand, the page
/// still live under a touch that closes it). Its layer is the canvas, so `TrackMenu.at` (AppView.space) is local.
struct TrackMenuLayer: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Color.clear.allowsHitTesting(false)   // the layer's full size, for the placement; takes no touches
                if let m = ui.trackMenu {
                    // the empty pads' fan, in the track's tint (Scott, 2026-11-09: "the track header longpress should
                    // get the same treatment")
                    FanMenu(title: "Track \(m.track + 1) · \(Entries.trackName(m.track, session: session))",
                            items: Self.groups(session, ui, track: m.track).flatMap { $0 }.filter { !$0.note }, at: m.at, layer: g.size,
                            tint: m.track, close: { ui.trackMenu = nil }, open: { _ in })
                        .id(m.track)
                        .transition(.opacity.animation(.easeIn(duration: Labs.menuClose.value)))
                }
            }
        }
    }

    /// Its items: Select sound (the sound panel, for the track), a sample, its motion, its steps.
    @MainActor static func groups(_ session: DeviceSession, _ ui: EditorUI, track t: Int) -> [[MenuItem]] {
        var g: [[MenuItem]] = []
        // the sound, from here: the sound panel slides out over the page (Scott, 2026-11-08: "Select sound"), not on the
        // Sounds tab, where the browser is the page itself
        if !(ui.shell && ui.page == .library) {
            g.append([MenuItem(title: "Select sound", icon: "square.grid.2x2") { ui.chooseSound(session, track: t) }])
        }
        var more: [MenuItem] = []
        if !session.isDrums(t), session.capabilities.contains(.samples) {
            // SLOOP: the grid turns over to the sampler. Skiff: the Song tab's editor slides down and the sampler up into
            // its panel (SongTab). Use on track puts the take on this track.
            more.append(MenuItem(title: "Record sample…", icon: "mic") {
                session.select(track: t)
                ui.presetsPanel = false
                ui.soundPanel = nil
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
        var clears: [MenuItem] = []
        // Skiff's song: every pad on the track's row emptied (its list rewritten empty), asked once more in place, with
        // the count and any pattern that goes with them (Scott, 2026-11-10: "it should probably say clear all pads")
        if let store = session.skiffSong, let l = store.song?.tracks[safe: t] {
            let n = l.entries.filter { !$0.isEmpty }.count
            let none = l.entries.map { _ in SongEntry(pattern: 0) }
            let why = n > 0 ? store.blocked(track: t, to: none) : nil
            let gone = n > 0 ? store.erased([t: none]) : []
            let name = Entries.trackName(t, session: session)
            let title = n == 0 ? "Clear all pads: none yet" : why.map { $0.hasPrefix("Stop") ? "Clear all pads (stop first)" : "Clear all pads: \($0)" } ?? "Clear all pads"
            var confirm = "Clear \(n == 1 ? "1 pad" : "all \(n) pads") on T\(t + 1) \(name)"
            if !gone.isEmpty { confirm += ", erasing \(gone.count == 1 ? "pattern" : "patterns") " + gone.map { String(format: "%02d", $0 + 1) }.joined(separator: ", ") }
            clears.append(.destructive(title: title, icon: "square.slash", enabled: n > 0 && why == nil, confirm: confirm) {
                Task { _ = await store.rewrite(track: t, to: none, confirmed: true) }
            })
        }
        // the steps of the pattern it's on (what this always cleared: one pattern, not the pads), with Undo
        let on = session.skiffSong?.song?.tracks[safe: t]?.patternOn
        let stepsTitle = on.map { "Clear pattern \(String(format: "%02d", $0 + 1))'s steps" } ?? "Clear all steps"
        clears.append(MenuItem(title: empty ? stepsTitle + ": none yet" : stepsTitle, icon: "trash", enabled: !empty) {
            ui.lastClear = session.clearAll(track: t)
        })
        g.append(clears)
        return g
    }
}

/// A long press on a track: its menu beside the finger (TrackMenuLayer: Sounds…, a sample, clearing its steps), the track
/// selected, as the Timeline's track names have it (Scott, 2026-11-07: the Pads strip had none).
struct TrackMenuPress: ViewModifier {
    let session: DeviceSession
    let ui: EditorUI?
    let track: Int
    @State private var pressAt: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
                .onChanged { pressAt = $0.location })
            .simultaneousGesture(LongPressGesture(minimumDuration: holdToMenu).onEnded { _ in
                session.select(track: track)
                ui?.trackMenu = TrackMenu(track: track, at: pressAt)
            })
            .accessibilityAction(named: "Track menu") { ui?.trackMenu = .voiceOver(track: track) }
    }
}

extension View {
    func trackMenuPress(session: DeviceSession, ui: EditorUI?, track: Int) -> some View {
        modifier(TrackMenuPress(session: session, ui: ui, track: track))
    }
}

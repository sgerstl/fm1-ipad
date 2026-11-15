import SloopKit
import SwiftUI

// A duplicated Timeline block sprouts into its place (Scott, 2026-11-15, as the pads' duplicate does): it grows out of
// the block it copies, travels to its place and settles with a small overshoot (spring 0.32 s, damping 0.68), then one
// soft ring in the track colour. Reduce Motion: it fades in place, then the ring. iPhone and iPad.

struct TimelineSprout: Equatable {
    var track: Int
    var entry: Int               // the new block's first entry
    var fromStart: Double        // where the copied block starts, in ticks
    var id = UUID()
    var landed = false
    var ring = false

    /// Starts it (after the rewrite has landed): the flight, then the ring, then gone.
    @MainActor static func run(_ ui: EditorUI, track t: Int, entry e: Int, fromStart: Double, reduceMotion: Bool) {
        let s = TimelineSprout(track: t, entry: e, fromStart: fromStart)
        ui.timelineSprout = s
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            guard ui.timelineSprout?.id == s.id else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.32, dampingFraction: 0.68)) { ui.timelineSprout?.landed = true }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 340))
            guard ui.timelineSprout?.id == s.id else { return }
            withAnimation(.easeOut(duration: 0.6)) { ui.timelineSprout?.ring = true }
            try? await Task.sleep(for: .milliseconds(650))
            if ui.timelineSprout?.id == s.id { ui.timelineSprout = nil }
        }
    }
}

extension View {
    /// The block whose first entry is `entry` on `track`: if it's sprouting, it starts `dx` away (where its source
    /// block is) at 60 % and settles, then rings.
    func timelineSprout(_ ui: EditorUI, track: Int, entry: Int, dx: CGFloat, radius: CGFloat = 6) -> some View {
        modifier(SproutBlock(ui: ui, track: track, entry: entry, dx: dx, radius: radius))
    }
}

private struct SproutBlock: ViewModifier {
    let ui: EditorUI
    let track: Int
    let entry: Int
    let dx: CGFloat
    let radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let s = ui.timelineSprout, s.track == track, s.entry == entry {
            content
                .scaleEffect(reduceMotion || s.landed ? 1 : 0.6)
                .offset(x: reduceMotion || s.landed ? 0 : dx)
                .opacity(reduceMotion && !s.landed ? 0 : 1)
                .overlay {
                    RoundedRectangle(cornerRadius: radius + 3).strokeBorder(Theme.track[track], lineWidth: 2)
                        .padding(-4)
                        .scaleEffect(s.ring ? 1.12 : 1)
                        .opacity(s.ring ? 0 : (s.landed ? 1 : 0))
                        .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}

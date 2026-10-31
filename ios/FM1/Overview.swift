import SloopKit
import SwiftUI

/// The track selector: one component on every tab, in one place. Its box of chips and names never
/// changes (top left, the left column's width, 44 pt rows). The timeline, each track's 64 steps, is
/// attached to its right and accordions open on the Sequencer and shut elsewhere. Only the visible
/// width animates; the rows keep their full layout, so nothing reflows mid-animation. A tap selects
/// the track on the FM-1, so the selection is the device's and carries across tabs by itself.
struct Overview: View {
    let session: SloopSession
    var expanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let rowHeight: CGFloat = 44
    static let height: CGFloat = 204                     // 8 + 4 × 44 + 3 × 4 + 8
    static let boxWidth: CGFloat = 320                   // the chips-and-names box = the left column
    static let fullWidth: CGFloat = Theme.canvas.width - 48
    static let gap: CGFloat = 2
    /// The timeline starts at the box's edge: 64 cells fill what is left of the row.
    static let timelineWidth: CGFloat = fullWidth - boxWidth - 4 - 8
    static let cell = CGSize(width: (timelineWidth - 6 - 63 * gap) / 64, height: 20)
    static var rowWidth: CGFloat { fullWidth - 8 }

    var body: some View {
        let visible = expanded ? Self.fullWidth : Self.boxWidth
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { t in row(t) }
        }
        .frame(width: visible - 8, alignment: .leading)
        .clipped()
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: visible, height: Self.height, alignment: .leading)
        .panel()
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: expanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tracks")
    }

    private func row(_ t: Int) -> some View {
        let track = session.tracks[t]
        let selected = session.selectedTrack == t
        let hitWidth = expanded ? Self.rowWidth : Self.boxWidth - 8
        return HStack(spacing: 0) {
            // The chip is its own key: on the selected track it mutes and unmutes; on another track it
            // selects, so a stray tap can't mute a track you weren't on.
            Button { selected ? session.toggleMute(track: t) : session.select(track: t) } label: {
                TrackChip(track: t, muted: track.mute)
                    .frame(width: 44, height: Self.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel(selected ? (track.mute ? "Unmute track \(t + 1)" : "Mute track \(t + 1)") : "Track \(t + 1)")
            .accessibilityValue(track.mute ? "muted" : "")
            Button { session.select(track: t) } label: { rowBody(t, track: track, selected: selected, hitWidth: hitWidth) }
                .buttonStyle(.plain)
                .accessibilityLabel("Track \(t + 1), \(track.displayName)\(track.mute ? ", muted" : "")")
                .accessibilityValue(expanded ? "\((0..<track.length).filter(track.isOn).count) of \(track.length) steps on" : "")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityHint(selected ? "" : "Selects the track on the FM-1")
        }
        .frame(width: Self.rowWidth, height: Self.rowHeight, alignment: .leading)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(selected ? 0.06 : 0))
                .frame(width: hitWidth)
        }
    }

    private func rowBody(_ t: Int, track: TrackState, selected: Bool, hitWidth: CGFloat) -> some View {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(track.displayName)
                        .font(.system(size: 15, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                    if track.mute {
                        Text("muted").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: Self.boxWidth - 8 - 44 - 4, alignment: .leading)
                .padding(.leading, 4)
                ZStack(alignment: .leading) {
                    Canvas { ctx, _ in draw(ctx, track) }
                    OverviewPlayhead(session: session, track: t, running: expanded)
                }
                .frame(width: Self.timelineWidth - 6, height: Self.cell.height)
                .padding(3)
                .recessed(5)
                .opacity(expanded ? (track.mute ? 0.45 : 1) : 0)
            }
            .frame(width: Self.rowWidth - 44, height: Self.rowHeight, alignment: .leading)
            // collapsed, the hidden timeline catches no taps (clipping alone doesn't stop hit-testing)
            .contentShape(Path(CGRect(x: 0, y: 0, width: hitWidth - 44, height: Self.rowHeight)))
    }

    private func draw(_ ctx: GraphicsContext, _ track: TrackState) {
        let w = Self.cell.width, h = Self.cell.height
        for i in 0..<64 {
            let r = CGRect(x: CGFloat(i) * (w + Self.gap), y: 0, width: w, height: h)
            let p = Path(roundedRect: r, cornerRadius: 3)
            if i >= track.length {
                ctx.fill(p, with: .color(Theme.stepOutside))
            } else if track.isOn(i) {
                ctx.fill(p, with: .color(Theme.track[track.index]))
                ctx.fill(Path(CGRect(x: r.minX + 2, y: r.minY, width: w - 4, height: 1)), with: .color(.white.opacity(0.35)))
            } else {
                ctx.fill(p, with: .color(Theme.stepEmpty))
            }
        }
    }
}

/// The playhead in one overview row; it redraws on its own so the rows don't.
private struct OverviewPlayhead: View {
    let session: SloopSession
    let track: Int
    var running = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !session.playing || !running)) { tl in
            let pos = session.playhead(track: track, at: tl.date, interpolate: !reduceMotion)
            let pitch = Overview.cell.width + Overview.gap
            Capsule()
                .fill(Theme.text)
                .frame(width: 2, height: Overview.cell.height + 10)
                .shadow(color: Theme.text.opacity(0.5), radius: 3)
                .offset(x: CGFloat(pos) * pitch - 1)
                .opacity(session.playing ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A track's number on its colour, raised. Muted, it sinks into the panel and greys, as a pressed
/// toggle does (the brief's physical rule), with the colour kept as a thin underline.
struct TrackChip: View {
    let track: Int
    var size: CGFloat = 28
    var muted = false
    var body: some View {
        Text("\(track + 1)")
            .font(.system(size: size > 28 ? 15 : 13, weight: .semibold))
            .foregroundStyle(muted ? Theme.textSecondary : Theme.onColour)
            .frame(width: size, height: size)
            .background {
                if muted {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.pressed).recessed(7)
                        .overlay(alignment: .bottom) { Capsule().fill(Theme.track[track]).frame(width: size - 12, height: 2).padding(.bottom, 4) }
                } else {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.pad(track))
                        .overlay(RoundedRectangle(cornerRadius: 7).inset(by: 0.5).stroke(.white.opacity(0.35), lineWidth: 1)
                            .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
                        .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                }
            }
            .accessibilityHidden(true)
    }
}

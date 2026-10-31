import SloopKit
import SwiftUI

/// All four tracks across all 64 steps, for reading. Tapping a row selects that track on the FM-1.
struct Overview: View {
    let session: SloopSession
    static let cell = CGSize(width: 15, height: 12)
    static let gap: CGFloat = 2

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { t in
                row(t)
            }
        }
        // rows reach to 4 pt from the panel edge so their highlight has room; their content sits at 12
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("All tracks")
    }

    private func row(_ t: Int) -> some View {
        let track = session.tracks[t]
        let selected = session.selectedTrack == t
        return Button { session.select(track: t) } label: {
            HStack(spacing: 12) {
                TrackChip(track: t)
                Text(track.displayName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .frame(width: 154, alignment: .leading)
                ZStack(alignment: .leading) {
                    Canvas { ctx, _ in draw(ctx, track) }
                    OverviewPlayhead(session: session, track: t)
                }
                .frame(width: 64 * (Self.cell.width + Self.gap) - Self.gap, height: Self.cell.height)
                .padding(3)
                .recessed(5)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(selected ? 0.06 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Track \(t + 1), \(track.displayName)")
        .accessibilityValue("\((0..<track.length).filter(track.isOn).count) of \(track.length) steps on")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(selected ? "" : "Selects the track on the FM-1")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !session.playing)) { tl in
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

struct TrackChip: View {
    let track: Int
    var size: CGFloat = 28
    var body: some View {
        Text("\(track + 1)")
            .font(.system(size: size > 28 ? 15 : 13, weight: .semibold))
            .foregroundStyle(Theme.onColour)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 7).fill(Theme.pad(track))
                    .overlay(RoundedRectangle(cornerRadius: 7).inset(by: 0.5).stroke(.white.opacity(0.35), lineWidth: 1)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            )
            .accessibilityHidden(true)
    }
}

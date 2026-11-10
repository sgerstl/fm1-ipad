import SloopKit
import SwiftUI

// The timeline's compact form (the Song tab's top half): its environment values, the lane marks, the mode keys and the
// selected row's tab.

extension EnvironmentValues {
    /// A lane's height: 80 on the Arrange page, less in the Song tab's top half (its divider sets it).
    @Entry var arrangeLaneHeight: CGFloat = SkiffArrangePage.fullLaneHeight
    /// The Song tab's top half: no inspector, the pattern pool a drawer, a block tapped pins the editor below,
    /// and while playing each track's playing block bright and outlined, the others dimmed.
    @Entry var arrangeCompact = false
}

/// The Song tab's playback marks over a lane, while playing (SongPlayback; Skiff's README: SONG OFF / ON / ONCE,
/// LAUNCH): on the block playing, its pass of its REPS ("2/4"), or ↻ looping (Loop entry); a quiet outline on the
/// block it goes to next (Play song, Play once), with a wrap mark when that's the first again; END on the last
/// (Play once); a launch waiting: a pulsing outline and its countdown. Its own 4 Hz timeline, so the lane's blocks
/// don't redraw for it; marks per track (tracks drift apart). Reduce Motion: no pulse.
struct LaneMarks: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int
    let blocks: [SongBlock]
    let barWidth: CGFloat
    let laneHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func x(_ ticks: Double) -> CGFloat { CGFloat(ticks / SongPlacement.ticksPerBar) * barWidth }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { tl in
            let m = store.marks(track, launchIn: session.ticksToLaunch(track))
            let h = laneHeight - 12
            ZStack(alignment: .topLeading) {
                ForEach(blocks) { b in
                    let w = max(8, x(b.length) - 4)
                    ZStack(alignment: .topLeading) {
                        if m.playing == b.id { playingBadge(m).frame(width: w, height: h, alignment: .topTrailing) }
                        if m.next == b.id {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.text.opacity(0.55), lineWidth: 1.5).padding(2)
                            if m.wraps { badge(Image(systemName: "arrow.uturn.backward"), "").frame(width: w, height: h, alignment: .topLeading) }
                        }
                        if m.playing == b.id, m.ends { badge(nil, "END").frame(width: w, height: h, alignment: .bottomTrailing) }
                        if m.queued == b.id {
                            // waiting, as the pads now draw it (2026-11-10, board 48): the time to its launch traced round
                            // it in the track's colour, closing as it lands; no countdown numbers
                            LaunchTrace(left: { session.ticksToLaunch(track) }, colour: Theme.track[track], radius: 6, width: 2.5)
                                .frame(width: w, height: h)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: w, height: h)
                    .offset(x: x(b.start) + 2, y: 6)
                }
            }
        }
        .accessibilityHidden(true)          // (each block says its state itself)
    }

    @ViewBuilder private func playingBadge(_ m: SongPlayback.Marks) -> some View {
        if m.loops { badge(Image(systemName: "repeat"), "") }
        else if let p = m.pass, m.reps > 1 { badge(nil, "\(p)/\(m.reps)") }
    }

    private func badge(_ icon: Image?, _ text: String) -> some View {
        HStack(spacing: 2) {
            icon?.font(.system(size: 9, weight: .bold))
            if !text.isEmpty { Text(text).font(.lupe(10, .bold)).monospacedDigit() }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 4).frame(height: 14)
        .background(Capsule().fill(Theme.page.opacity(0.85)))
        .padding(3)
    }

    /// A launch's countdown in beats (24 ticks), as short as fits: "now", "1 beat", "3 beats".
    static func countdown(_ ticks: Double?, _ launch: SongPlayback.Launch) -> String {
        guard let t = ticks else { return launch == .loop ? "pass end" : launch == .bar ? "next bar" : "next beat" }
        let beats = Int((t / 24).rounded(.up))
        return beats <= 0 ? "now" : beats == 1 ? "1 beat" : "\(beats) beats"
    }

    /// What a block's state is, for VoiceOver.
    static func spoken(_ m: SongPlayback.Marks, block b: SongBlock, launch: SongPlayback.Launch) -> String? {
        var parts: [String] = []
        if m.playing == b.id {
            parts.append("playing")
            if m.loops { parts.append("looping") } else if let p = m.pass { parts.append("pass \(p) of \(m.reps)") }
            if m.ends { parts.append("the last: the song ends after it") }
        }
        if m.next == b.id { parts.append(m.wraps ? "next, back to the start" : "next") }
        if m.queued == b.id {
            let at = ["at the end of the pass", "at the next bar", "at the next beat", "now"][launch.rawValue]
            parts.append("queued, starts \(at)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

/// SONG OFF / ON / ONCE (LIST op 6) as what each does: Loop entry, Play song, Play once. In the top bar beside play and
/// stop; the FM-1's own changes come back with the lists (polled), so the two stay in step.
struct SongModeKeys: View {
    let store: SkiffSongStore

    var body: some View {
        SegmentedKeys(label: "Playback", options: ["Loop entry", "Play song", "Play once"], selected: store.song?.mode.rawValue ?? -1,
                      enabled: [!store.offline, !store.offline, !store.offline]) { k in
            Task { await store.send(.song(SongMode(rawValue: k) ?? .on)) }
        }
        // (Scott, 2026-11-06: say it plainly)
        .accessibilityHint("Loop entry: each track repeats the block it's on. Play song: each track plays its blocks in order and starts over. Play once: plays through once and stops.")
    }
}

/// The knobs' tab under (or over) the selected row: its body the box's rect, a point into the row (no seam), with a
/// concave 8 pt fillet where it leaves the row's edge (both sides when it hangs free, beside a panel). Flush with the
/// row's right end it also fills the row's rounded corner there; nowhere else does it reach into the row, where the
/// playing block, drawn larger, comes within 8 pt of the edge (2026-11-07: an 8 pt overlap clipped it).
struct RowTab: Shape {
    var down: Bool
    var flushRight: Bool
    static let fillet: CGFloat = 8, radius: CGFloat = 12, corner: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let f = Self.fillet, r = Self.radius, c = Self.corner, x0 = rect.minX, x1 = rect.maxX, h = rect.height
        var p = Path()
        // drawn hanging down from y = 0 (the row's edge), then flipped for a tab above the row
        p.move(to: CGPoint(x: x0 - f, y: -1))
        if flushRight {
            p.addLine(to: CGPoint(x: x1 - c, y: -1))
            p.addLine(to: CGPoint(x: x1 - c, y: -c))
            p.addLine(to: CGPoint(x: x1, y: -c))
            p.addLine(to: CGPoint(x: x1, y: h - r))
        } else {
            p.addLine(to: CGPoint(x: x1 + f, y: -1))
            p.addLine(to: CGPoint(x: x1 + f, y: 0))
            p.addQuadCurve(to: CGPoint(x: x1, y: f), control: CGPoint(x: x1, y: 0))
            p.addLine(to: CGPoint(x: x1, y: h - r))
        }
        p.addArc(tangent1End: CGPoint(x: x1, y: h), tangent2End: CGPoint(x: x1 - r, y: h), radius: r)
        p.addLine(to: CGPoint(x: x0 + r, y: h))
        p.addArc(tangent1End: CGPoint(x: x0, y: h), tangent2End: CGPoint(x: x0, y: h - r), radius: r)
        p.addLine(to: CGPoint(x: x0, y: f))
        p.addQuadCurve(to: CGPoint(x: x0 - f, y: 0), control: CGPoint(x: x0, y: 0))
        p.closeSubpath()
        guard !down else { return p.offsetBy(dx: 0, dy: rect.minY) }
        return p.applying(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.minY + h))
    }
}

/// A launch's countdown, read from the counted clock about 30 times a second on its own timeline: the 4 Hz one the pads
/// and blocks draw on put the count up to a quarter of a second behind the beat, half a beat at 120 (Scott, 2026-11-10:
/// "the countdown… isn't very accurate"). Only this text redraws that often.
struct LaunchCountdown: View {
    let session: DeviceSession
    let track: Int
    var prefix = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30)) { _ in
            Text(prefix + LaneMarks.countdown(session.ticksToLaunch(track), session.launchMode))
        }
    }
}

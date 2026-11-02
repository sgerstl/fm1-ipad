import SloopKit
import SwiftUI

/// The track selector: one component on every page, in one place. Its box of chips and names never
/// changes (top left, the left column's width, 44 pt rows). The timeline, each track's 64 steps, is
/// attached to its right, shut unless pulled open with the pill inside the box's right edge (drag, or tap);
/// open, it slides over whatever is beside the box. Only the visible width moves; the rows keep their
/// full layout, so nothing reflows. A tap on a row selects the track on the FM-1.
struct Overview: View {
    let session: SloopSession
    let ui: EditorUI
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
    @State private var pressAt = CGPoint.zero
    /// The row just long-pressed: its release opens the menu only, never also a tap (which would mute or select).
    @State private var held: Int?
    @State private var dragX: CGFloat = 0          // the handle's drag, following the finger

    private var visible: CGFloat {
        min(max((expanded ? Self.fullWidth : Self.boxWidth) + dragX, Self.boxWidth), Self.fullWidth)
    }
    /// 0 shut … 1 open: the timeline fades in as it slides out.
    private var progress: CGFloat { (visible - Self.boxWidth) / (Self.fullWidth - Self.boxWidth) }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { t in row(t) }
        }
        .frame(width: visible - 8, alignment: .leading)
        .clipped()
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: visible, height: Self.height, alignment: .leading)
        .panel()
        .overlay(alignment: .trailing) { handle }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: expanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tracks")
    }

    /// The pull: a light grey pill inside the box's right edge (the open timeline ends 16 pt short of
    /// it, so it never covers a step). Drag it out to open the timeline, back to shut it; a tap toggles.
    private var handle: some View {
        // measured on the screen, not on the handle: the handle moves with the panel as it opens
        let drag = DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { dragX = $0.translation.width }
            .onEnded { v in
                // a pull of 80 pt, or a flick, either way is enough
                let dx = max(v.translation.width, v.predictedEndTranslation.width * 0.5)
                let dxClose = min(v.translation.width, v.predictedEndTranslation.width * 0.5)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    ui.timelineOpen = expanded ? dxClose > -80 : dx > 80
                    dragX = 0
                }
            }
        let tap = TapGesture().onEnded {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { ui.timelineOpen.toggle() }
        }
        return Capsule()
            .fill(dragX != 0 ? Theme.text : Theme.textSecondary)       // brightens while held
            .frame(width: 5, height: 40)
            .padding(.trailing, 6)
            .frame(width: 28, height: 72, alignment: .trailing)    // a 28 × 72 pt target, inside the box
            .contentShape(Rectangle())
        .gesture(drag.exclusively(before: tap))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(expanded ? "Hide the timeline" : "Show the timeline")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { ui.timelineOpen.toggle() }
    }

    private func row(_ t: Int) -> some View {
        let track = session.tracks[t]
        // On the Song page a section is all four tracks, so picking one means nothing there: the box
        // shows no selection and every tap mutes, a live move while sections play.
        let muteOnly = ui.page == .song
        let selected = session.selectedTrack == t && !muteOnly
        let hitWidth = expanded ? Self.rowWidth : Self.boxWidth - 8
        return HStack(spacing: 0) {
            // The chip is its own key: on the selected track it mutes and unmutes; on another track it
            // selects, so a stray tap can't mute a track you weren't on.
            Button {
                if held == t { held = nil; return }
                selected || muteOnly ? session.toggleMute(track: t) : session.select(track: t)
            } label: {
                TrackChip(track: t, muted: track.mute)
                    .frame(width: 44, height: Self.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel(selected || muteOnly ? (track.mute ? "Unmute track \(t + 1)" : "Mute track \(t + 1)") : "Track \(t + 1)")
            .accessibilityValue(track.mute ? "muted" : "")
            Button {
                if held == t { held = nil; return }
                muteOnly ? session.toggleMute(track: t) : session.select(track: t)
            } label: { rowBody(t, track: track, selected: selected, hitWidth: hitWidth) }
                .buttonStyle(.plain)
                .accessibilityLabel("Track \(t + 1), \(track.displayName)\(track.mute ? ", muted" : "")")
                .accessibilityValue(expanded ? "\((0..<track.length).filter(track.isOn).count) of \(track.length) steps on" : "")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityHint(muteOnly ? (track.mute ? "Unmutes it" : "Mutes it") : selected ? "" : "Selects the track on the FM-1")
        }
        .frame(width: Self.rowWidth, height: Self.rowHeight, alignment: .leading)
        .background(alignment: .leading) {
            let raised = ui.trackMenu?.track == t
            RoundedRectangle(cornerRadius: 10)
                .fill(raised ? Color.white.opacity(0.10) : selected ? Theme.track[t].opacity(0.16) : .clear)
                .shadow(color: .black.opacity(raised ? 0.5 : 0), radius: raised ? 8 : 0, y: raised ? 4 : 0)
                .frame(width: hitWidth)
        }
        .animation(.easeOut(duration: 0.15), value: ui.trackMenu?.track)
        .onChange(of: ui.trackMenu?.track) { _, open in if open == nil { held = nil } }   // (a press that slid off)
        // long press: the track's menu by the finger (only Clear all for now; no confirm, it offers Undo)
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
            .onChanged { pressAt = $0.location })
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            held = t
            ui.trackMenu = TrackMenu(track: t, at: pressAt)
        })
        .accessibilityAction(named: "Track menu") { ui.trackMenu = TrackMenu(track: t, at: CGPoint(x: 200, y: 160 + CGFloat(t) * 48)) }
    }

    private func rowBody(_ t: Int, track: TrackState, selected: Bool, hitWidth: CGFloat) -> some View {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(track.displayName)
                        .font(.system(size: 15, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .layoutPriority(-1)                 // the name gives way to the tags
                    if track.mute {
                        Text("muted").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                    // CHORD and ARP, by SLOOP's names, on every page; a tag opens its Sound page
                    if t < 3, track.chord > 0 { modeTag(Music.chordNames[safe: track.chord] ?? "CHORD", track: t, family: .sel) }
                    if t < 3, track.arpMode > 0 { modeTag("ARP " + (Music.arpModes[safe: track.arpMode] ?? ""), track: t, family: .arp) }
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 14)                     // clear of the timeline's pull
                .frame(width: Self.boxWidth - 8 - 44 - 4, alignment: .leading)
                .padding(.leading, 4)
                // the playhead is taller than the cells: as an overlay it can't shift them off centre
                Canvas { ctx, _ in draw(ctx, track) }
                .frame(width: Self.timelineWidth - 6, height: Self.cell.height)
                .overlay(alignment: .leading) { OverviewPlayhead(session: session, track: t, running: progress > 0) }
                .padding(3)
                // a flat, even well: the deep inset shadow of the bigger wells made the cells read high on
                // a strip this thin; read-only, so nothing here looks raised
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.well)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.5), lineWidth: 1)))
                .opacity(Double(progress) * (track.mute ? 0.45 : 1))
            }
            .frame(width: Self.rowWidth - 44, height: Self.rowHeight, alignment: .leading)
            // collapsed, the hidden timeline catches no taps (clipping alone doesn't stop hit-testing)
            .contentShape(Path(CGRect(x: 0, y: 0, width: hitWidth - 44, height: Self.rowHeight)))
    }

    /// A small tag after the name: what the track's notes become (a chord, an arpeggio).
    private func modeTag(_ text: String, track t: Int, family: SoundFamily) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(Capsule().fill(Theme.track[t].opacity(0.28)))
            .contentShape(Rectangle().inset(by: -8))
            .highPriorityGesture(TapGesture().onEnded {
                session.select(track: t)
                ui.page = .sound
                ui.soundFamily = family
                if session.screenLinked, ui.followDevice, let p = SoundPage.shown(session, family).first {
                    session.showOnDevice(page: p.fw)
                }
            })
            .accessibilityLabel(family == .arp ? "Arpeggio \(text.dropFirst(4))" : "Chord \(text)")
            .accessibilityHint("Opens its Shape page")
            .accessibilityAddTraits(.isButton)
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
struct TrackMenu: Equatable {
    var track: Int
    var at: CGPoint
}

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

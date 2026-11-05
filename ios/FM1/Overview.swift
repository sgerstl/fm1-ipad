import SloopKit
import SwiftUI

/// The track selector: one component on every page, in one place. Its box of chips and names never
/// changes (top left, the left column's width, 44 pt rows). The timeline, each track's 64 steps, is
/// attached to its right: always open on Sequence, and on the other tabs shut unless pulled open with the
/// pill inside the box's right edge (drag, or tap), sliding over whatever is beside the box. Only the
/// visible width moves; the rows keep their full layout, so nothing reflows. A tap on a name selects the
/// track on the FM-1. On Sequence the selected track's row carries the view box, the bar the grid shows:
/// touch or drag a row's timeline to show that bar (2026-11-02).
struct Overview: View {
    let session: DeviceSession
    let ui: EditorUI
    var expanded = true
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let height: CGFloat = 204                     // 8 + 4 × 44 + 3 × 4 + 8
    /// Rows share the box's height: four at 44 pt; more (Skiff's six) thinner, in the same space, since the
    /// box is for reading and a tap on a row selects its track (Scott, 2026-11-05). Six: about 30 pt.
    static func rowGap(_ n: Int) -> CGFloat { n <= 4 ? 4 : 2 }
    static func rowHeight(_ n: Int) -> CGFloat {
        n <= 4 ? 44 : (height - 16 - CGFloat(n - 1) * rowGap(n)) / CGFloat(n)
    }
    /// A timeline cell's height: 20 pt in a 44 pt row, 16 in the thinner ones.
    static func cellHeight(_ n: Int) -> CGFloat { n <= 4 ? cell.height : 16 }
    private var rowHeight: CGFloat { Self.rowHeight(session.trackCount) }
    private var cellHeight: CGFloat { Self.cellHeight(session.trackCount) }
    static let boxWidth: CGFloat = 320                   // the chips-and-names box = the left column
    static let fullWidth: CGFloat = Theme.canvas.width - 48
    static let gap: CGFloat = 2
    /// The timeline starts at the box's edge: 64 cells fill what is left of the row (SLOOP and Skiff both
    /// have 64 steps; a firmware with another count would need its own cell width).
    static let timelineWidth: CGFloat = fullWidth - boxWidth - 4 - 8
    static let cell = CGSize(width: (timelineWidth - 6 - 63 * gap) / 64, height: 20)
    static var rowWidth: CGFloat { fullWidth - 8 }
    @State private var pressAt = CGPoint.zero
    /// The row just long-pressed: its release opens the menu only, never also a tap (which would mute or select).
    @State private var held: Int?
    @State private var dragX: CGFloat = 0          // the handle's drag, following the finger
    @State private var dragBar: Int?               // the bar a drag along a timeline last asked for

    private var visible: CGFloat {
        min(max((expanded ? Self.fullWidth : Self.boxWidth) + dragX, Self.boxWidth), Self.fullWidth)
    }
    /// 0 shut … 1 open: the timeline fades in as it slides out.
    private var progress: CGFloat { (visible - Self.boxWidth) / (Self.fullWidth - Self.boxWidth) }

    var body: some View {
        VStack(spacing: Self.rowGap(session.trackCount)) {
            ForEach(session.trackIndices, id: \.self) { t in row(t) }
        }
        .frame(width: visible - 8, alignment: .leading)
        .clipped()
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: visible, height: Self.height, alignment: .leading)
        .panel()
        .overlay(alignment: .trailing) { if ui.page != .sequencer { handle } }
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
            HStack(spacing: 0) {
            // The chip is its own key: on the selected track it mutes and unmutes; on another track it
            // selects, so a stray tap can't mute a track you weren't on.
            Button {
                if held == t { held = nil; return }
                selected || muteOnly ? session.toggleMute(track: t) : session.select(track: t)
            } label: {
                TrackChip(track: t, muted: track.mute, selected: selected)
                    .frame(width: 44, height: rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink(latched: track.mute))
            .accessibilityLabel(selected || muteOnly ? (track.mute ? "Unmute track \(t + 1)" : "Mute track \(t + 1)") : "Track \(t + 1)")
            .accessibilityValue(track.mute ? "muted" : "")
            Button {
                if held == t { held = nil; return }
                muteOnly ? session.toggleMute(track: t) : session.select(track: t)
            } label: { nameBody(t, track: track, selected: selected) }
                .buttonStyle(.plain)
                .accessibilityLabel("Track \(t + 1), \(track.displayName)\(track.mute ? ", muted" : "")")
                .accessibilityValue(expanded ? "\((0..<track.length).filter(track.isOn).count) of \(track.length) steps on" : "")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityHint(muteOnly ? (track.mute ? "Unmutes it" : "Mutes it") : selected ? "" : "Selects the track on the FM-1")
            }
            // long press: the track's menu by the finger (only on the chip and name: on the timeline a
            // slow drag of the view box would open it)
            .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
                .onChanged { pressAt = $0.location })
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                held = t
                ui.trackMenu = TrackMenu(track: t, at: pressAt)
            })
            timeline(t, track: track, selected: selected, muteOnly: muteOnly)
        }
        .frame(width: Self.rowWidth, height: rowHeight, alignment: .leading)
        .background(alignment: .leading) {
            let raised = ui.trackMenu?.track == t
            RoundedRectangle(cornerRadius: 10)
                // flat: no colour wash; the selected track shows by its lifted chip and its bold name
                .fill(raised ? Color.white.opacity(0.10) : selected && !look.flat ? Theme.track[t].opacity(0.16) : .clear)
                .shadow(color: .black.opacity(raised ? 0.5 : 0), radius: raised ? 8 : 0, y: raised ? 4 : 0)
                .frame(width: hitWidth)
        }
        .animation(.easeOut(duration: 0.15), value: ui.trackMenu?.track)
        .onChange(of: ui.trackMenu?.track) { _, open in if open == nil { held = nil } }   // (a press that slid off)
        .accessibilityAction(named: "Track menu") { ui.trackMenu = TrackMenu(track: t, at: CGPoint(x: 200, y: 160 + CGFloat(t) * 48)) }
    }

    private func nameBody(_ t: Int, track: TrackState, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(track.displayName)
                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .layoutPriority(-1)                 // the name gives way to the tags
            if track.mute {
                Text("muted").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            // CHORD and ARP, by SLOOP's names, on every page; a tag opens its Sound page
            if !session.isDrums(t), track.chord > 0 { modeTag(Music.chordNames[safe: track.chord] ?? "CHORD", track: t, family: .sel) }
            if !session.isDrums(t), track.arpMode > 0 { modeTag("ARP " + (Music.arpModes[safe: track.arpMode] ?? ""), track: t, family: .arp) }
            Spacer(minLength: 0)
        }
        .padding(.trailing, 14)                     // clear of the timeline's pull
        .frame(width: Self.boxWidth - 8 - 44 - 4, height: rowHeight, alignment: .leading)
        .padding(.leading, 4)
        .contentShape(Rectangle())
    }

    /// A track's 64 steps. On Sequence, touching or dragging it shows the bar under the finger in the
    /// grid (selecting the track first), and the selected track's row frames the bar in view.
    @ViewBuilder
    private func timeline(_ t: Int, track: TrackState, selected: Bool, muteOnly: Bool) -> some View {
        let onSequence = ui.page == .sequencer
        let strip = Canvas { ctx, _ in draw(ctx, track) }
            .frame(width: Self.timelineWidth - 6, height: cellHeight)
            // the playhead is taller than the cells: as an overlay it can't shift them off centre
            .overlay(alignment: .leading) { OverviewPlayhead(session: session, track: t, running: progress > 0, height: cellHeight) }
            .overlay(alignment: .leading) { if onSequence && selected { ViewBox(ui: ui, height: cellHeight) } }
            .padding(3)
            // a flat, even well: the deep inset shadow of the bigger wells made the cells read high on
            // a strip this thin; read-only, so nothing here looks raised
            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.well)
                .overlay { if !look.flat { RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.5), lineWidth: 1) } })
            .opacity(Double(progress) * (track.mute ? 0.45 : 1))
            .frame(height: rowHeight)
        if !expanded {
            strip.allowsHitTesting(false).accessibilityHidden(true)
        } else if onSequence {
            strip
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { e in
                        if session.selectedTrack != t { session.select(track: t) }
                        // one request per bar the finger enters, so the grid's scroll isn't restarted on every move
                        let bar = max(0, min(3, Int((e.location.x - 3) / (16 * (Self.cell.width + Self.gap)))))
                        if bar != dragBar { dragBar = bar; show(bar: bar) }
                    }
                    .onEnded { _ in dragBar = nil })
                // a quick tap can end before the drag reports a move: it picks the bar too
                .simultaneousGesture(SpatialTapGesture().onEnded { e in
                    if session.selectedTrack != t { session.select(track: t) }
                    show(bar: Int((e.location.x - 3) / (16 * (Self.cell.width + Self.gap))))
                })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Track \(t + 1) bars")
                .accessibilityValue(selected ? "Showing bar \(viewBar + 1) of 4" : "")
                .accessibilityHint(selected ? "Swipe up or down to show another bar" : "Selects the track")
                .accessibilityAdjustableAction { dir in
                    if session.selectedTrack != t { session.select(track: t) }
                    show(bar: viewBar + (dir == .increment ? 1 : -1))
                }
                .accessibilityAction { if session.selectedTrack != t { session.select(track: t) } }
        } else {
            // the other tabs: a tap selects (or mutes, on Arrange), as the name does
            strip
                .contentShape(Rectangle())
                .onTapGesture { muteOnly ? session.toggleMute(track: t) : session.select(track: t) }
                .accessibilityHidden(true)
        }
    }

    private var viewBar: Int { max(0, min(3, Int((ui.viewStep / 16).rounded()))) }

    private func show(bar: Int) {
        ui.viewJump = ViewJump(bar: max(0, min(3, bar)), id: (ui.viewJump?.id ?? 0) + 1)
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
        let w = Self.cell.width, h = cellHeight
        for i in track.steps.indices {
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

/// The bar the grid shows, framed on the selected track's timeline row. It follows the grid while it
/// pans, so it can sit between bars mid-pan.
private struct ViewBox: View {
    let ui: EditorUI
    var height = Overview.cell.height
    var body: some View {
        let pitch = Overview.cell.width + Overview.gap
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(Theme.text, lineWidth: 2)
            .frame(width: 16 * pitch + 4, height: height + 10)
            .offset(x: max(0, min(48, ui.viewStep)) * pitch - 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The playhead in one overview row; it redraws on its own so the rows don't.
private struct OverviewPlayhead: View {
    let session: DeviceSession
    let track: Int
    var running = true
    var height = Overview.cell.height
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !session.playing || !running)) { tl in
            let pos = session.playhead(track: track, at: tl.date, interpolate: !reduceMotion)
            let pitch = Overview.cell.width + Overview.gap
            Capsule()
                .fill(Theme.text)
                .frame(width: 2, height: height + 10)
                .glow(Theme.text.opacity(0.5), radius: 3)
                .offset(x: CGFloat(pos) * pitch - 1)
                .opacity(session.playing ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A track's number on its colour, raised. Muted, it sinks into the panel and greys, as a pressed
/// toggle does (the brief's physical rule), with the colour kept as a thin underline.
/// Flat look (2026-11-05): as a key (`selected` given, the track box), a grey chiclet at rest and, on
/// the selected track, its colour, lifted to elevation 2 with the ring; as a label (`selected` nil, a
/// panel's heading), its colour, flat. Muted, it sits down on its edge, grey, with the underline.
struct TrackMenu: Equatable {
    var track: Int
    var at: CGPoint
}

struct TrackChip: View {
    let track: Int
    var size: CGFloat = 28
    var muted = false
    var selected: Bool?
    @Environment(\.look) private var look
    @Environment(\.keyPressed) private var pressed

    var body: some View {
        if look.flat { flatChip } else { physicalChip }
    }

    private var flatChip: some View {
        let lit = !muted && selected != false
        return Text("\(track + 1)")
            .font(.system(size: size > 28 ? 15 : 13, weight: .semibold))
            .foregroundStyle(muted ? Theme.textSecondary : lit ? Theme.onColour : Theme.text)
            .frame(width: size, height: size)
            .background {
                if muted {
                    Chiclet(radius: 7, down: pressed, edge: false, top: Theme.control)
                        .overlay(alignment: .bottom) { Capsule().fill(Theme.track[track]).frame(width: size - 12, height: 2).padding(.bottom, 4) }
                } else if selected == true {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.track[track])
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.text, lineWidth: 2))
                        .elevationShadow(.selected, look)
                } else if selected == false {
                    Chiclet(radius: 7, down: pressed, edge: !pressed)
                } else {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.track[track])
                }
            }
            .accessibilityHidden(true)
    }

    private var physicalChip: some View {
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

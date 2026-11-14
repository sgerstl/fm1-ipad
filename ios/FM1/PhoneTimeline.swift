import SloopKit
import SwiftUI

// The phone's Timeline tab (vault decisions 28, 33; board 76; Android's TimelinePage is the reference): time runs
// across. Six rows in Pads' order and height, each a compact head (its number on a strip of its colour, the sound's
// name; a tap selects the track, a hold opens its menu) and a lane of its song's blocks. A bar ruler runs along the top;
// about twelve bars show to begin with, − and + show more or fewer (8 to 24), the lanes pan sideways. The selected
// track's colour, muted, runs under its whole row, as on Pads. Blocks are the track's colour at 45 % with the pattern's
// number and its passes; a REST is a dashed outline. A tap picks a block for the editor (white ring); a hold opens the
// iPad's block menu (as the radial menu); a hold on the empty lane after the last block adds to the song. The iPad's
// arrange code supplies the blocks, the menus and the playhead (SongBlock, ArrangeMenus, SongPlayhead). iPhone only.

struct PhoneTimeline: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    @State private var barsShown: Double = 12
    @State private var pressAt: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let head: CGFloat = 72, ruler: CGFloat = 28, gap: CGFloat = 4
    private var menus: ArrangeMenus { ArrangeMenus(session: session, store: store, ui: ui) { r in ui.pinnedEntry = r } }

    var body: some View {
        let tracks = Array(session.trackIndices)
        GeometryReader { g in
            let laneW = g.size.width - Self.head - Self.gap
            let barW = max(12, laneW / barsShown)
            let total = max(1, (store.laneEnds.max() ?? 0).rounded(.up))
            let contentBars = max(total + 2, barsShown)
            let rowH = max(28, (g.size.height - Self.ruler - Self.gap - CGFloat(tracks.count - 1) * Self.gap) / CGFloat(max(1, tracks.count)))
            let selRow = tracks.firstIndex(of: session.selectedTrack)
            VStack(alignment: .leading, spacing: Self.gap) {
                HStack(spacing: Self.gap) {
                    zoomKeys.frame(width: Self.head)
                    Color.clear.frame(height: Self.ruler)
                }
                Color.clear
            }
            // the selected track: its colour muted under the whole row, head and lane; it glides to a new row
            .background(alignment: .topLeading) {
                if let k = selRow {
                    RoundedRectangle(cornerRadius: 10).fill(SelectionTint.fill(session.selectedTrack))
                        .frame(height: rowH + 4)
                        .offset(y: Self.ruler + Self.gap + CGFloat(k) * (rowH + Self.gap) - 2)
                        .phoneTrackAnchor()
                        .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.2), value: k)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(alignment: .top, spacing: Self.gap) {
                    VStack(spacing: Self.gap) {
                        Color.clear.frame(height: Self.ruler)
                        ForEach(tracks, id: \.self) { t in head(t).frame(height: rowH) }
                    }
                    .frame(width: Self.head)
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: Self.gap) {
                            ruler(bars: Int(contentBars), barW: barW, songBars: Int(total))
                            ForEach(tracks, id: \.self) { t in lane(t, barW: barW).frame(height: rowH) }
                        }
                        .frame(width: CGFloat(contentBars) * barW, alignment: .leading)
                        .overlay(alignment: .topLeading) {
                            SongPlayhead(session: session, store: store, barWidth: barW,
                                         height: Self.ruler + CGFloat(tracks.count) * (rowH + Self.gap))
                        }
                    }
                    .scrollIndicators(.hidden)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .animation(.easeOut(duration: reduceMotion ? 0 : 0.3), value: barsShown)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityAction(named: "Show more bars") { zoom(4) }
        .accessibilityAction(named: "Show fewer bars") { zoom(-4) }
    }

    private func zoom(_ by: Double) { barsShown = min(24, max(8, barsShown + by)) }

    private var zoomKeys: some View {
        HStack(spacing: 4) {
            key("minus", "Show more bars", enabled: barsShown < 24) { zoom(4) }
            key("plus", "Show fewer bars", enabled: barsShown > 8) { zoom(-4) }
        }
    }

    private func key(_ icon: String, _ label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: Self.ruler)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.control))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(label)
    }

    private func ruler(bars: Int, barW: CGFloat, songBars: Int) -> some View {
        let step = barW >= 40 ? 1 : barW >= 20 ? 2 : 4
        return Canvas { ctx, size in
            for b in 0...bars {
                let x = CGFloat(b) * barW
                let tall = b % 4 == 0
                ctx.fill(Path(CGRect(x: x, y: size.height - (tall ? 10 : 6), width: 1, height: tall ? 10 : 6)),
                         with: .color(tall ? Theme.textTertiary : Theme.control))
                if b % step == 0, b < bars {
                    ctx.draw(Text("\(b + 1)").font(.lupe(12)).foregroundStyle(b >= songBars ? Theme.textSecondary : Theme.textSecondaryRaised),
                             at: CGPoint(x: x + 4, y: 2), anchor: .topLeading)
                }
            }
        }
        .frame(height: Self.ruler)
        .accessibilityHidden(true)
    }

    private func head(_ t: Int) -> some View {
        let selected = session.selectedTrack == t
        return Button { session.select(track: t) } label: {
            HStack(spacing: 0) {
                Text("\(t + 1)").font(.lupeNumber(15, .bold)).foregroundStyle(Theme.onColour)
                    .frame(width: 22).frame(maxHeight: .infinity).background(Theme.track[t])
                Text(Entries.trackName(t, session: session)).font(.lupe(12, .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                Spacer(minLength: 0)
            }
            .background(selected ? Color.clear : Theme.control)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeOut(duration: 0.15), value: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .trackMenuPress(session: session, ui: ui, track: t)
        .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Selects the track. Actions: its menu")
    }

    private func lane(_ t: Int, barW: CGFloat) -> some View {
        let blocks = store.blocks(t)
        let end = (blocks.last?.end ?? 0) / SongPlacement.ticksPerBar
        let selected = session.selectedTrack == t
        return ZStack(alignment: .topLeading) {
            // the lane's well; on the selected row the band shows through
            RoundedRectangle(cornerRadius: 6).fill(Theme.well).opacity(selected ? 0 : 1)
                .animation(.easeOut(duration: 0.15), value: selected)
                // held after the last block: add to the track's song
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { pressAt = $0.location }.onEnded { _ in HoldFinger.shared.down = false })
                .simultaneousGesture(LongPressGesture(minimumDuration: holdToMenu).onEnded { _ in
                    HoldFinger.shared.down = true
                    session.select(track: t)
                    ui.menu = AppMenu(title: "T\(t + 1) · after the last entry", groups: { menus.add(t) }, at: pressAt, fan: true, tint: t)
                })
                .accessibilityHidden(true)
            ForEach(blocks.filter { $0.kind != .gap }) { b in
                block(t, b, barW: barW)
                    .offset(x: CGFloat(b.start / SongPlacement.ticksPerBar) * barW)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(t + 1) lane, \(Int(end.rounded(.up))) bars")
        .accessibilityAction(named: "Add after the last entry") {
            ui.menu = AppMenu(title: "T\(t + 1) · after the last entry", groups: { menus.add(t) }, at: CGPoint(x: 400, y: 200), fan: true, tint: t)
        }
    }

    private func block(_ t: Int, _ b: SongBlock, barW: CGFloat) -> some View {
        let list = store.song?.tracks[safe: t]
        let e = list?.entries[safe: b.entries.lowerBound] ?? .empty
        let w = max(10, CGFloat(b.length / SongPlacement.ticksPerBar) * barW - 2)
        let picked = ui.pinnedEntry.map { $0.track == t && b.entries.contains($0.entry) } ?? false
        let rest = b.kind == .rest
        let ref = EntryRef(track: t, entry: b.entries.lowerBound)
        return Button {
            session.select(track: t)
            ui.pinnedEntry = picked ? nil : ref
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(rest ? "REST" : e.label).font(.lupeNumber(rest ? 12 : 17, .bold)).monospacedDigit()
                    .foregroundStyle(rest ? Theme.textSecondary : Theme.text)
                if b.reps > 1, w > 34 { Text("×\(b.reps)").font(.lupe(11)).foregroundStyle(Theme.textSecondaryRaised) }
            }
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(width: w, alignment: .leading).frame(maxHeight: .infinity)
            .background {
                if rest {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.restDash, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                } else {
                    RoundedRectangle(cornerRadius: 6).fill(SelectionTint.fill(t, percent: 45))
                }
            }
            .overlay { if picked { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.text, lineWidth: 2) } }
            .animation(.easeOut(duration: 0.15), value: picked)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { pressAt = $0.location }.onEnded { _ in HoldFinger.shared.down = false })
        .simultaneousGesture(LongPressGesture(minimumDuration: holdToMenu).onEnded { _ in HoldFinger.shared.down = true; openBlockMenu(t, b, at: pressAt) })
        .accessibilityLabel("Track \(t + 1), entr\(b.entries.count > 1 ? "ies" : "y") \(Entries.letters(b.entries)), "
                            + (rest ? "rest" : "pattern \(e.label)") + (b.reps > 1 ? ", \(b.reps) times" : ""))
        .accessibilityAddTraits(picked ? .isSelected : [])
        .accessibilityAction(named: "Block menu") { openBlockMenu(t, b, at: CGPoint(x: 400, y: 200)) }
    }

    private func openBlockMenu(_ t: Int, _ b: SongBlock, at: CGPoint) {
        session.select(track: t)
        ui.menu = AppMenu(title: "T\(t + 1) · entr\(b.entries.count > 1 ? "ies" : "y") \(Entries.letters(b.entries))",
                          groups: { menus.block(t, b) }, at: at, fan: true, tint: t)
    }
}

import SloopKit
import SwiftUI

// The phone's track heads and MUTE column on Pads (vault decisions 29, 31; Android's RowHead and MuteColumn): a wide
// head with the track's number on a strip of its colour, the sound's name and the engine under it. A tap selects the
// track and does nothing else; a hold opens its menu (Sounds, mute, solo and the rest). MUTE carries the word, white when
// muted; a swipe up or down the column sets every key it crosses to the state the first one changed to. A change that
// waits for the launch point draws its outline as that comes (LaunchTrace), as the pads do. iPhone only.

enum PhoneHeads {
    /// Board 76 at the iPhone's 874 pt: a head 118 wide, MUTE 48, 4 between them, so eight slots fit beside them.
    static let head: CGFloat = 118, mute: CGFloat = 48, gap: CGFloat = 4
    static var width: CGFloat { head + gap + mute }
}

struct PhonePadHead: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let track: Int
    let preview: SkiffSongStore.SceneTrack?

    var body: some View {
        let t = track
        let selected = session.selectedTrack == t
        let list = store.song?.tracks[safe: t]
        let m = store.marks(t, launchIn: nil)
        let lines = TrackStripCard.lines(list, m, playing: session.playing, launch: session.launchMode)
        let solo = store.soloed.contains(t)
        let waits = store.soloWaiting[t] ?? []
        let engine = session.tracks[t].engineName
        Button { session.select(track: t) } label: {
            HStack(spacing: 0) {
                Text("\(t + 1)").font(.lupeNumber(17, .bold)).monospacedDigit()
                    .foregroundStyle(Theme.onColour)
                    .frame(width: 30).frame(maxHeight: .infinity)
                    .background(Theme.track[t])
                VStack(alignment: .leading, spacing: 0) {
                    Text(Entries.trackName(t, session: session)).font(.lupe(15, .semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    HStack(spacing: 6) {
                        if !engine.isEmpty { Text(engine).font(.lupe(12)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1) }
                        // solo: a lit pill with the word, never the colour alone
                        if solo {
                            Text("SOLO").font(.lupe(10, .semibold)).foregroundStyle(Theme.onColour)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.text))
                        }
                    }
                }
                .padding(.leading, 8).padding(.trailing, 4)
                Spacer(minLength: 0)
            }
            // selected: the lane's muted colour shows through (PadsPage.lanes); otherwise the control grey
            .background(selected ? Color.clear : Theme.control)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                // a solo that waits for the launch point: the head's outline drawn as it comes, in the track's colour
                if !waits.isEmpty {
                    LaunchTrace(left: { waits.compactMap { session.ticksToLaunch($0) }.max() }, colour: Theme.track[t], radius: 8, width: 2, base: 0.6)
                        .transition(.opacity)
                }
            }
            .overlay { if preview != nil { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) } }
            .animation(.easeOut(duration: 0.15), value: selected)
            .animation(.easeOut(duration: 0.2), value: waits.isEmpty)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .phoneHoldMenu(session: session, ui: ui, track: t)
        .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))" + (engine.isEmpty ? "" : ", \(engine)") + (solo ? ", solo" : ""))
        .accessibilityValue(lines.plays + (preview.map { ", the scene would: " + TrackStripCard.previewText($0, list) } ?? ""))
        .accessibilityHint("Selects the track. Actions: its menu")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityAction(named: "Choose a sound") { ui.chooseSound(session, track: t) }
        .accessibilityAction(named: solo ? "Solo off" : "Solo") { Task { await store.toggleSolo(t) } }
    }
}

/// MUTE, one key a row, 54 wide with the word on it, white when muted. A tap toggles one; press one and slide up or down
/// the column, and every key the finger crosses takes the state the first one changed to (paint mutes, decision 29),
/// each sent as it is crossed with a tick.
struct PhoneMuteColumn: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let tracks: [Int]
    let rowHeight: CGFloat
    let rowGap: CGFloat
    @State private var painted: Set<Int> = []
    @State private var target: Bool?
    @State private var ticks = 0

    private func muted(_ t: Int) -> Bool { store.perform?.muted[safe: t] ?? session.tracks[t].mute }
    private func toggle(_ t: Int) { ticks += 1; Task { await store.performOp(.mute(track: t)) } }

    var body: some View {
        VStack(spacing: rowGap) {
            ForEach(tracks, id: \.self) { t in key(t).frame(height: rowHeight) }
        }
        .frame(width: PhoneHeads.mute)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            guard !store.offline else { return }
            let row = Int((v.location.y / (rowHeight + rowGap)).rounded(.down))
            guard let t = tracks[safe: max(0, min(tracks.count - 1, row))] else { return }
            if target == nil {
                target = !muted(t); painted = [t]; toggle(t)
            } else if !painted.contains(t) {
                painted.insert(t)
                if muted(t) != target { toggle(t) }
            }
        }.onEnded { _ in target = nil; painted = [] })
        .sensoryFeedback(.selection, trigger: ticks)
    }

    private func key(_ t: Int) -> some View {
        let on = muted(t)
        let staged = store.perform?.staged[safe: t] ?? PerformState.Staged.none
        return Text("MUTE").font(.lupe(13, .semibold))
            .foregroundStyle(on ? Theme.onColour : Theme.textSecondaryRaised)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? Theme.text : Theme.control))
            .overlay {
                // a mute that waits for the launch point: the key's outline drawn as it comes, in the track's colour (dark
                // on the lit white key)
                if staged != .none {
                    LaunchTrace(left: { session.ticksToLaunch(t) }, colour: on ? Theme.onColour : Theme.track[t], radius: 8, width: 2, base: 0.6)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: on)
            .animation(.easeOut(duration: 0.2), value: staged)
            .accessibilityElement()
            .accessibilityLabel("Mute track \(t + 1), \(Entries.trackName(t, session: session))")
            .accessibilityValue((on ? "muted" : "not muted") + (staged != .none ? ", changing at the launch point" : ""))
            .accessibilityAddTraits([.isButton, .isToggle])
            .accessibilityAction { toggle(t) }
    }
}

extension View {
    /// The phone's hold menu on a track head: the track menu, drawn radial on the phone (RadialMenu via FanMenu).
    func phoneHoldMenu(session: DeviceSession, ui: EditorUI, track: Int) -> some View {
        trackMenuPress(session: session, ui: ui, track: track)
    }
}

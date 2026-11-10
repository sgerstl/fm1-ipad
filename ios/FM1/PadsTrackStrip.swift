import SloopKit
import SwiftUI

// The track strip beside the Pads: a card per track (or a row when the editor is open), with its pass bar.

/// One track in the strip: tap to put its entries on the pads; what it plays and how far, what's waiting, and its mute
/// (PERFORM's: staged to the launch point while playing).
struct TrackStripCard: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let track: Int
    /// A scene held: where this track would go and its mute (nil: no scene held, or one not seen yet).
    var preview: SkiffSongStore.SceneTrack? = nil

    var body: some View {
        let t = track
        let selected = session.selectedTrack == t
        let list = store.song?.tracks[safe: t]
        let perf = store.perform
        let muted = perf?.muted[safe: t] ?? session.tracks[t].mute
        let staged = perf?.staged[safe: t] ?? PerformState.Staged.none
        return TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let m = store.marks(t, launchIn: session.ticksToLaunch(t))
            let lines = Self.lines(list, m, playing: session.playing, launch: session.launchMode)
            let parts = lines.plays.components(separatedBy: "  ")
            // H1 (Scott, 2026-11-09, board 43): the number big, top left, the entry it's on beside it, big; the name
            // under; the pass bar and what's next; Mute over Solo down the right
            HStack(alignment: .top, spacing: 8) {
                Button { session.select(track: t) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 10) {
                            BigTrackChip(track: t, muted: muted, side: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                EntryTitle(list: list)
                                if parts.count > 1 {
                                    Text(parts.dropFirst().joined(separator: " ")).font(.lupe(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                                }
                            }
                        }
                        // the instrument: under the entry, quieter (Scott, 2026-11-09: "too bold")
                        Text(Entries.trackName(t, session: session)).font(.lupe(15))
                            .padding(.top, 4)
                            .foregroundStyle(muted ? Theme.textSecondary : Theme.textSecondaryRaised).lineLimit(1)
                        if session.playing, m.playing != nil {
                            SmoothBar(track: Theme.well, ink: Theme.track[t]) { session.passProgress(t) ?? 0 }
                                .frame(height: 4).padding(.top, 4)
                        }
                        if let p = preview {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                                Text(Self.previewText(p, list)).font(.lupe(12, .semibold)).lineLimit(1)
                            }
                            .foregroundStyle(Theme.text).padding(.top, 4)
                        }
                        // (no "Then B" line: the head stops at the tag's 100 pt, and the pads mark the next entry)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .trackMenuPress(session: session, ui: ui, track: t)
                .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))\(selected ? ", selected" : "")")
                .accessibilityValue([lines.plays, lines.next].filter { !$0.isEmpty }.joined(separator: ", "))
                .accessibilityHint(selected ? "" : "Selects it: the editor and the FM-1's knobs follow")
                VStack(spacing: 6) {
                    muteKey(muted: muted, staged: staged).frame(height: 32)
                    SoloKey(store: store, track: t, session: session).frame(height: 32)
                }
                .frame(width: 64)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)      // (8 top and bottom: the tag's even inset)
            .frame(maxWidth: .infinity, minHeight: 86, maxHeight: .infinity, alignment: .topLeading)   // (as tall as its row of pads)
            // (no tint of its own: its lane runs behind it, the selected track's in its colour; PadsPage.lanes)
            // the whole head selects, its padding too (Scott, 2026-11-09: a dead spot at its foot); its keys keep their own
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { session.select(track: t) }
            .overlay {
                if preview != nil {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.text.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
            }
        }
    }

    private func muteKey(muted: Bool, staged: PerformState.Staged) -> some View {
        let cd = LaneMarks.countdown(session.ticksToLaunch(track), session.launchMode)
        return Button { Task { await store.performOp(.mute(track: track)) } } label: {
            VStack(spacing: 2) {
                Image(systemName: muted != (staged != .none) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(muted && staged == .none ? Theme.onColour : Theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { HeadKeySurface(on: muted && staged == .none, onColour: Theme.text, staged: staged != .none,
                                         left: { session.ticksToLaunch(track) }) }
            .animation(.easeOut(duration: 0.15), value: muted)
            .animation(.easeOut(duration: 0.2), value: staged)
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        .accessibilityLabel("Mute track \(track + 1)")
        .accessibilityValue(staged == .mute ? "mutes \(cd)" : staged == .unmute ? "unmutes \(cd)" : muted ? "muted" : "playing")
        .accessibilityHint(staged != .none ? "Takes the waiting change back" : session.playing ? "At the launch point" : "")
    }

    /// A held scene's line: "B · 05 · muted", "stays on B", "unmutes".
    static func previewText(_ p: SkiffSongStore.SceneTrack, _ l: SongList?) -> String {
        guard let e = p.entry else { return p.muted ? "no entry · muted" : "no entry" }
        let x = l?.entries[safe: e] ?? .empty
        let name = "\(Entries.letter(e)) · " + x.label
        let stays = l?.entryOn == e ? "stays on " : ""
        return stays + name + (p.muted ? " · muted" : "")
    }

    /// What the card says: what it plays (entry, pattern, pass), and what comes (a launch waiting, the song's next).
    static func lines(_ l: SongList?, _ m: SongPlayback.Marks, playing: Bool, launch: SongPlayback.Launch) -> (plays: String, next: String) {
        guard let l else { return ("—", "") }
        func name(_ i: Int) -> String {
            let e = l.entries[safe: i] ?? .empty
            return "\(Entries.letter(i)) · " + e.label
        }
        guard let on = l.entryOn else { return (playing ? "Quiet" : "On no entry", "") }
        var plays = name(on)
        if playing { plays += m.loops ? "  looping" : m.pass.map { "  pass \($0) of \(m.reps)" } ?? "" }
        var next = ""
        if m.queued != nil, let s = l.staged { next = "\(name(s)) waiting, \(LaneMarks.countdown(m.launchIn, launch))" }
        else if playing, m.ends { next = "Ends after this" }
        else if playing, m.next != nil, let s = l.staged { next = "Then \(name(s))" }
        return (plays, next)
    }
}

/// A track in the compact strip (over the editor): as the Timeline's lane heads, its chip, name, what it plays and a
/// smooth pass bar, M to mute (PERFORM's, staged at the launch point while playing). The selected row lit in its colour,
/// as on the Timeline. Tap selects it; a scene held shows where that scene would send it.
struct TrackStripRow: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    let track: Int
    let preview: SkiffSongStore.SceneTrack?

    var body: some View {
        let t = track
        let selected = session.selectedTrack == t
        let list = store.song?.tracks[safe: t]
        let perf = store.perform
        let muted = perf?.muted[safe: t] ?? session.tracks[t].mute
        let staged = perf?.staged[safe: t] ?? PerformState.Staged.none
        return TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let m = store.marks(t, launchIn: session.ticksToLaunch(t))
            let lines = TrackStripCard.lines(list, m, playing: session.playing, launch: session.launchMode)
            HStack(spacing: 8) {
                Button { session.select(track: t) } label: {
                    HStack(spacing: 8) {
                        BigTrackChip(track: t, muted: muted, side: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(Entries.trackName(t, session: session)).font(.lupe(15, selected ? .semibold : .regular)).layoutPriority(1)
                                    .foregroundStyle(selected ? Theme.text : Theme.textSecondaryRaised).lineLimit(1)
                                Spacer(minLength: 4)
                                // (what it's on; the bar under it is the pass)
                                Text(preview.map { "→ " + TrackStripCard.previewText($0, list) } ?? lines.plays.components(separatedBy: "  ").first ?? lines.plays)
                                    .font(.lupe(12, preview == nil ? .regular : .semibold)).monospacedDigit()
                                    .minimumScaleFactor(0.8)   // (Half: two keys and a 15 pt name leave no room for a big entry; the pads show it)
                                    .foregroundStyle(preview == nil ? Theme.textSecondaryRaised : Theme.text).lineLimit(1)
                            }
                            if session.playing, m.playing != nil {
                                SmoothBar(track: Theme.well, ink: Theme.track[t]) { session.passProgress(t) ?? 0 }.frame(height: 3)
                            } else {
                                Color.clear.frame(height: 3)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .trackMenuPress(session: session, ui: ui, track: t)
                .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))")
                .accessibilityValue(lines.plays + (preview.map { ", the scene would: " + TrackStripCard.previewText($0, list) } ?? ""))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                HStack(spacing: 2) {
                    Button { Task { await store.performOp(.mute(track: t)) } } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(muted ? Theme.onColour : Theme.text)
                            .frame(width: 30, height: 34)
                            .background { HeadKeySurface(on: muted && staged == .none, onColour: Theme.text, staged: staged != .none,
                                                         left: { session.ticksToLaunch(t) }) }
                            .animation(.easeOut(duration: 0.2), value: staged)
                    }
                    .buttonStyle(PressSink())
                    .disabled(store.offline)
                    .accessibilityLabel(muted ? "Unmute" : "Mute")
                    .accessibilityValue(staged == .none ? "" : staged == .mute ? "mutes at the launch point" : "unmutes at the launch point")
                    SoloKey(store: store, track: t, compact: true, session: session).frame(width: 30, height: 34)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)            // (as tall as its slot: the Pads' 42, or a Timeline lane)
            // (no tint of its own: its lane runs behind it; PadsPage.lanes)
            .overlay { if preview != nil { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) } }
        }
    }
}

/// A pass bar redrawn every frame (30 a second) from the counted clock, alone in its own view: the card's and the pads'
/// slower refreshes (2 and 4 a second) made it step (Scott, 2026-11-07: "low frame rate"). Only this redraws.
struct SmoothBar: View {
    let track: Color
    let ink: Color
    let fraction: () -> Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let f = min(1, max(0, fraction()))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule().fill(ink).frame(width: g.size.width * f)
                }
            }
        }
        .accessibilityHidden(true)
    }
}


/// A track's number, big (board 43): its colour filled; muted, the colour as an outline and the number in it, so the
/// number still says which track.
struct BigTrackChip: View {
    let track: Int
    let muted: Bool
    var side: CGFloat = 44

    var body: some View {
        let r = side * 0.25, c = Theme.track[track]
        Text("\(track + 1)").font(.lupeNumber(side * 0.56, .bold)).monospacedDigit()
            .foregroundStyle(muted ? c : Theme.onColour)
            .frame(width: side, height: side)
            .background {
                if muted { RoundedRectangle(cornerRadius: r).strokeBorder(c, lineWidth: 2.5) }
                else { RoundedRectangle(cornerRadius: r).fill(c) }
            }
            .animation(.easeOut(duration: 0.15), value: muted)
            .accessibilityHidden(true)
    }
}

/// Mute's and Solo's surface (board 43): flat when off (the control grey, no base edge: the page is flat); pressed in
/// when on (an inner shadow); a change waiting at the launch point, the pads' waiting line round it (LaunchTrace:
/// Scott, 2026-11-10), light on the flat key, dark on a lit one, so it reads either way.
struct HeadKeySurface: View {
    let on: Bool
    let onColour: Color
    var staged = false
    var left: () -> Double? = { nil }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(on ? AnyShapeStyle(onColour.shadow(.inner(color: .black.opacity(0.45), radius: 3, y: 2))) : AnyShapeStyle(Theme.control))
            .overlay { if staged { LaunchTrace(left: left, colour: on ? Theme.onColour : Theme.text, radius: 8, width: 2, base: 0.6).transition(.opacity) } }
    }
}

/// Solo (board 43): Lupe's, through PERFORM's mutes (SkiffSongStore.toggleSolo); amber when on.
struct SoloKey: View {
    let store: SkiffSongStore
    let track: Int
    var compact = false
    var session: DeviceSession? = nil

    var body: some View {
        let on = store.soloed.contains(track)
        // the mutes it staged, until the last of them lands
        let waits = store.soloWaiting[track] ?? []
        Button { Task { await store.toggleSolo(track) } } label: {
            Text("S").font(.lupe(compact ? 13 : 18, .bold))
                .foregroundStyle(on ? Theme.onColour : Theme.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { HeadKeySurface(on: on, onColour: Theme.caution, staged: !waits.isEmpty,
                                             left: { session.flatMap { s in waits.compactMap { s.ticksToLaunch($0) }.max() } }) }
                .animation(.easeOut(duration: 0.15), value: on)
                .animation(.easeOut(duration: 0.2), value: waits.isEmpty)
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        .accessibilityLabel("Solo track \(track + 1)")
        .accessibilityValue(on ? "on" : "off")
        .accessibilityHint("Mutes every other track; again, the mutes come back as they were")
    }
}


/// The entry a track is on, written as a pad writes it (Scott, 2026-11-09): its letter small and grey, then its pattern
/// number bold in even figures; a REST says so, smaller.
struct EntryTitle: View {
    let list: SongList?
    var size: CGFloat = 22

    var body: some View {
        if let l = list, let on = l.entryOn, let e = l.entries[safe: on] {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Entries.letter(on)).font(.lupe(size * 0.68, .semibold)).foregroundStyle(Theme.textSecondary)
                Text(e.isRest ? "REST" : e.label).font(.lupeNumber(e.isRest ? size * 0.72 : size * 1.12, .bold)).monospacedDigit()
                    .foregroundStyle(e.isRest ? Theme.textSecondary : Theme.text)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        } else {
            Text("–").font(.lupe(size, .bold)).foregroundStyle(Theme.textSecondary)
        }
    }
}

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
                                Text(parts.first ?? lines.plays).font(.system(size: 22, weight: .semibold)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.6)
                                if parts.count > 1 {
                                    Text(parts.dropFirst().joined(separator: " ")).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                                }
                            }
                        }
                        Text(Entries.trackName(t, session: session)).font(.system(size: 17, weight: .semibold))
                            .padding(.top, 8)
                            .foregroundStyle(muted ? Theme.textSecondary : Theme.text).lineLimit(1)
                        if session.playing, m.playing != nil {
                            SmoothBar(track: Theme.well, ink: Theme.track[t]) { session.passProgress(t) ?? 0 }
                                .frame(height: 4).padding(.top, 6)
                        }
                        if let p = preview {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                                Text(Self.previewText(p, list)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
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
                    muteKey(muted: muted, staged: staged).frame(height: 40)
                    SoloKey(store: store, track: t).frame(height: 40)
                }
                .frame(width: 64)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: .infinity, alignment: .topLeading)   // (as tall as its row of pads)
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
                if staged != .none { Text(cd).font(.system(size: 11, weight: .semibold)).monospacedDigit().lineLimit(1) }
            }
            .foregroundStyle(muted && staged == .none ? Theme.onColour : Theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { HeadKeySurface(on: muted && staged == .none, onColour: Theme.text, staged: staged != .none) }
            .animation(.easeOut(duration: 0.15), value: muted)
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
                                Text(Entries.trackName(t, session: session)).font(.system(size: 15, weight: selected ? .semibold : .regular)).layoutPriority(1)
                                    .foregroundStyle(selected ? Theme.text : Theme.textSecondaryRaised).lineLimit(1)
                                Spacer(minLength: 4)
                                // (what it's on; the bar under it is the pass)
                                Text(preview.map { "→ " + TrackStripCard.previewText($0, list) } ?? lines.plays.components(separatedBy: "  ").first ?? lines.plays)
                                    .font(.system(size: 12, weight: preview == nil ? .regular : .semibold)).monospacedDigit()
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
                            .background { HeadKeySurface(on: muted && staged == .none, onColour: Theme.text, staged: staged != .none) }
                    }
                    .buttonStyle(PressSink())
                    .disabled(store.offline)
                    .accessibilityLabel(muted ? "Unmute" : "Mute")
                    .accessibilityValue(staged == .none ? "" : staged == .mute ? "mutes at the launch point" : "unmutes at the launch point")
                    SoloKey(store: store, track: t, compact: true).frame(width: 30, height: 34)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: PadsPage.rowHeight)
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
        Text("\(track + 1)").font(.system(size: side * 0.5, weight: .bold)).monospacedDigit()
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
/// when on (an inner shadow); a change waiting at the launch point, a dashed white edge.
struct HeadKeySurface: View {
    let on: Bool
    let onColour: Color
    var staged = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(on ? AnyShapeStyle(onColour.shadow(.inner(color: .black.opacity(0.45), radius: 3, y: 2))) : AnyShapeStyle(Theme.control))
            .overlay { if staged { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [5, 3])) } }
    }
}

/// Solo (board 43): Lupe's, through PERFORM's mutes (SkiffSongStore.toggleSolo); amber when on.
struct SoloKey: View {
    let store: SkiffSongStore
    let track: Int
    var compact = false

    var body: some View {
        let on = store.soloed.contains(track)
        Button { Task { await store.toggleSolo(track) } } label: {
            Text("S").font(.system(size: compact ? 13 : 18, weight: .bold))
                .foregroundStyle(on ? Theme.onColour : Theme.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { HeadKeySurface(on: on, onColour: Theme.caution) }
                .animation(.easeOut(duration: 0.15), value: on)
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        .accessibilityLabel("Solo track \(track + 1)")
        .accessibilityValue(on ? "on" : "off")
        .accessibilityHint("Mutes every other track; again, the mutes come back as they were")
    }
}

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
    @AppStorage(SelectionTint.key) private var selectionTint = SelectionTint.standard
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
            HStack(alignment: .top, spacing: 8) {
                Button { session.select(track: t) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            TrackChip(track: t, size: 26, muted: muted)
                            Text(Entries.trackName(t, session: session)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        }
                        Text(lines.plays).font(.system(size: 13)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1)
                        if session.playing, m.playing != nil {
                            SmoothBar(track: Theme.well, ink: Theme.track[t]) { session.passProgress(t) ?? 0 }
                                .frame(height: 4)
                        }
                        if let p = preview {
                            // the scene held: an arrow line in full white, a second channel to the dashed outline
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                                Text(Self.previewText(p, list)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            }
                            .foregroundStyle(Theme.text)
                        } else if !lines.next.isEmpty {
                            Text(lines.next).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .trackMenuPress(session: session, ui: ui, track: t)
                .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))\(selected ? ", on the pads" : "")")
                .accessibilityValue([lines.plays, lines.next].filter { !$0.isEmpty }.joined(separator: ", "))
                .accessibilityHint(selected ? "" : "Puts its entries on the pads")
                muteKey(muted: muted, staged: staged)
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 8))
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            // no background but the selected track's tint, as the lane heads (Scott, 2026-11-07: grey cards at full
            // size and nothing when compact was "one or the other")
            .background { RoundedRectangle(cornerRadius: 12).fill(selected ? SelectionTint.fill(track, selectionTint) : .clear) }
            .overlay {
                if preview != nil {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.text.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .padding(selected ? 4 : 0)
                }
            }
        }
    }

    private func muteKey(muted: Bool, staged: PerformState.Staged) -> some View {
        let cd = LaneMarks.countdown(session.ticksToLaunch(track), session.launchMode)
        let label = staged == .mute ? "Mutes\n\(cd)" : staged == .unmute ? "Unmutes\n\(cd)" : muted ? "Muted" : "Mute"
        return Button { Task { await store.performOp(.mute(track: track)) } } label: {
            Text(label).font(.system(size: 12, weight: muted || staged != .none ? .semibold : .regular)).multilineTextAlignment(.center)
                .foregroundStyle(muted && staged == .none ? Theme.onColour : Theme.text)
                .frame(width: 72, height: 52)
                .background {
                    if muted && staged == .none { RoundedRectangle(cornerRadius: 8).fill(Theme.text) }
                    else if staged != .none {
                        RoundedRectangle(cornerRadius: 8).fill(Theme.control)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
                    } else { Chiclet(radius: 8, down: false, edge: true) }
                }
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
    @AppStorage(SelectionTint.key) private var selectionTint = SelectionTint.standard

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
                        TrackChip(track: t, size: 26, muted: muted)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(Entries.trackName(t, session: session)).font(.system(size: 13, weight: selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Theme.text : Theme.textSecondaryRaised).lineLimit(1)
                                Spacer(minLength: 4)
                                // (what it's on; the bar under it is the pass)
                                Text(preview.map { "→ " + TrackStripCard.previewText($0, list) } ?? lines.plays.components(separatedBy: "  ").first ?? lines.plays)
                                    .font(.system(size: 12, weight: preview == nil ? .regular : .semibold))
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
                Button { Task { await store.performOp(.mute(track: t)) } } label: {
                    Text("M").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(muted ? Theme.onColour : Theme.textSecondaryRaised)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(muted ? Theme.text : Theme.control))
                        .overlay { if staged != .none { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) } }
                }
                .buttonStyle(PressSink())
                .disabled(store.offline)
                .accessibilityLabel(muted ? "Unmute" : "Mute")
                .accessibilityValue(staged == .none ? "" : staged == .mute ? "mutes at the launch point" : "unmutes at the launch point")
            }
            .padding(.horizontal, 8)
            .frame(height: PadsPage.rowHeight)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? SelectionTint.fill(t, selectionTint) : .clear))
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

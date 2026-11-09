import SloopKit
import SwiftUI
import UIKit

// SLOOP's song mode and sections panel, and a section's menu.

/// Left column, under the track box: loop or song mode.
struct SongModePanel: View {
    let session: DeviceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            SegmentedKeys(label: "Mode", options: ["Loop", "Song"], selected: session.song.songMode ? 1 : 0) { k in
                // song mode keeps the loop: PLAY puts it aside, STOP brings it back (arranger_scene.c)
                if (k == 1) != session.song.songMode { session.toggleSongMode() }
            }
            Text(session.song.songMode ? "PLAY runs the song. STOP brings your loop back."
                                       : "The tracks loop. A section you tap replaces them.")
                .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}

/// A section's menu, by the finger: held, replace it or clear it (clearing asked again); tapped over
/// edited tracks, whether to load it over them.
struct SectionMenu: Equatable {
    enum Mode { case manage, confirmClear, confirmLoad }
    var section: Int
    var at: CGPoint
    var mode = Mode.manage
}

/// Above the song: the four sections as keys in a row, and SONG REC, which records what they play.
struct SectionsPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    /// Where the finger is on a key: a held stored section opens its menu there.
    @State private var pressAt = CGPoint.zero
    @State private var confirmRec = false
    /// The key just held: its release isn't a tap (a tap loads the section, over the tracks being saved).
    @State private var held: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Sections").font(.lupe(17, .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(session.playing ? "Tap: plays from the next bar, over the tracks. Hold: save the tracks here."
                                     : "Tap: loads it over the tracks. Hold: save the tracks here.")
                    .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                ToggleKey(name: session.song.songRecording ? "SONG REC: recording" : "SONG REC", on: session.song.songRecording) {
                    // what SONG REC records replaces the whole order: ask when there is one
                    if !session.song.songRecording, !(session.songOrder?.steps.isEmpty ?? true) { confirmRec = true } else { session.toggleSongRec() }
                }
                .accessibilityHint("From the next bar, every section you play, and how long, becomes the song")
            }
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { k in sectionKey(k) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .confirmationDialog("SONG REC replaces the song", isPresented: $confirmRec, titleVisibility: .visible) {
            Button("Record over the song", role: .destructive) { session.toggleSongRec() }
            Button("Keep the song", role: .cancel) {}
        } message: {
            Text("The sections you play, and for how long, become the song's order. Its \(session.songOrder?.steps.count ?? 0) steps now are replaced, and the FM-1 keeps no copy.")
        }
    }

    /// What a section key shows: one state per key, each with a look and a word (never colour alone).
    /// Only one section is in the tracks at a time, so loaded, playing, edited, song and recording are
    /// one key's; next bar is another's.
    enum KeyState: Equatable {
        case empty, stored, loaded, playing, edited, nextBar, song, recording

        var label: String {
            switch self {
            case .empty: "empty · hold to save"
            case .stored: "stored"
            case .loaded: "loaded"
            case .playing: "playing"
            case .edited: "edited · hold to save"
            case .nextBar: "next bar"
            case .song: "song"
            case .recording: "recording"
            }
        }
        /// In the tracks now: the key is lit in its colour.
        var inTracks: Bool { [.loaded, .playing, .edited, .song, .recording].contains(self) }
        /// Sounding: a pill along the bottom fills through the bar.
        var sounding: Bool { [.playing, .song, .recording].contains(self) }
    }

    private func keyState(_ k: Int) -> KeyState {
        let s = session.song
        if s.sectionPlaying == k {
            if s.songRecording, session.playing { return .recording }
            if s.songPlaying { return .song }
            // the tracks changed since this section came in: picking another would lose that
            if session.tracksEdited { return .edited }
            return session.playing ? .playing : .loaded
        }
        if s.sectionQueued == k { return .nextBar }
        return s.stored(k) ? .stored : .empty
    }

    /// How far through the bar the FM-1 is, from track 1's playhead at 4 beats a bar (as the top bar's
    /// bar · step). SLOOP reports the song's bar only while a song plays, so this is the bar line in loop mode too.
    private func barFraction(_ date: Date) -> Double {
        let div = session.tracks[0].division
        let beats = Music.divisionBeats.indices.contains(div) ? Music.divisionBeats[div] : 0.25
        let perBar = max(1, 4 / beats)
        let p = session.playhead(track: 0, at: date, interpolate: !reduceMotion)
        return p.truncatingRemainder(dividingBy: perBar) / perBar
    }

    private func sectionKey(_ k: Int) -> some View {
        let state = keyState(k)
        let stored = session.song.stored(k)
        let colour = Theme.track[k]
        return Button {
            if held == k { held = nil; return }
            // a section picked in loop mode replaces the tracks (now, or on the next bar)
            // in loop mode a section replaces the tracks and SLOOP keeps no copy: with edits, ask by the finger
            if session.tracksEdited, stored, !session.song.songMode {
                ui.sectionMenu = SectionMenu(section: k, at: pressAt, mode: .confirmLoad)
            } else {
                session.playSection(k)
            }
        } label: {
            VStack(spacing: 2) {
                Text(DeviceSession.sectionName(k)).font(.lupe(30, .semibold))
                Text(state.label).font(.lupe(12, .semibold))
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(state.inTracks ? Theme.onColour : state == .empty ? Theme.textTertiary : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background { keyFace(state, colour: colour) }
            .overlay(alignment: .topTrailing) { keyBadge(state) }
            .overlay { if state == .nextBar { nextBarOutline(colour) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(AppView.space))
            .onChanged { pressAt = $0.location })
        // hold: an empty section takes the tracks at once; a stored one offers replace or clear, by the finger
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            held = k
            if stored { ui.sectionMenu = SectionMenu(section: k, at: pressAt) } else { session.storeLoop(in: k) }
        })
        .accessibilityLabel("Section \(DeviceSession.sectionName(k))")
        .accessibilityValue(state == .nextBar ? "starts on the next bar" : state.label)
        .accessibilityHint(stored ? (session.playing ? "Plays from the next bar" : "Loads it as the loop") : "Empty: hold to store the loop here")
        .accessibilityAction(named: stored ? "Replace or clear" : "Store the loop here") {
            if stored { ui.sectionMenu = SectionMenu(section: k, at: CGPoint(x: 560 + CGFloat(k) * 220, y: 140)) } else { session.storeLoop(in: k) }
        }
    }

    @ViewBuilder
    private func keyFace(_ state: KeyState, colour: Color) -> some View {
        if state.inTracks {
            RoundedRectangle(cornerRadius: 12)
                .fill(colour)
                .overlay(alignment: .bottom) {
                    if state.sounding || (state == .edited && session.playing) {
                        // the bar passing, as the song blocks' pills
                        TimelineView(.animation(paused: !session.playing || reduceMotion)) { tl in
                            GeometryReader { g in
                                Capsule().fill(Theme.onColour.opacity(0.22))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Theme.onColour.opacity(0.8))
                                            .frame(width: max(6, g.size.width * barFraction(tl.date)))
                                    }
                            }
                            .frame(height: 6)
                        }
                        .padding(.horizontal, 18).padding(.bottom, 8)
                    }
                }
        } else if state == .empty {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        } else {
            // stored (and next bar, which is stored): the colour dim, its line along the bottom
            RoundedRectangle(cornerRadius: 12).fill(colour.opacity(0.22))
                .overlay(alignment: .bottom) { Capsule().fill(colour).frame(height: 3).padding(.horizontal, 18).padding(.bottom, 8) }
        }
    }

    @ViewBuilder
    private func keyBadge(_ state: KeyState) -> some View {
        switch state {
        case .edited:
            Circle().fill(Theme.onColour).frame(width: 8, height: 8).padding(10)
        case .song:
            Text("SONG").font(.lupe(10, .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Theme.onColour.opacity(0.85)))
                .padding(8)
        case .recording:
            HStack(spacing: 4) {
                Circle().fill(Color(hex: 0xFF2C34)).frame(width: 8, height: 8)
                Text("REC").font(.lupe(10, .semibold)).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Theme.onColour.opacity(0.85)))
            .padding(8)
        default:
            EmptyView()
        }
    }

    /// Next bar: an outline in the section's own colour, drawn round as the bar runs out.
    private func nextBarOutline(_ colour: Color) -> some View {
        TimelineView(.animation(paused: !session.playing || reduceMotion)) { tl in
            let f = session.playing ? barFraction(tl.date) : 1
            ZStack {
                RoundedRectangle(cornerRadius: 15).stroke(colour.opacity(0.3), lineWidth: 2)
                RoundedRectangle(cornerRadius: 15).trim(from: 0, to: reduceMotion ? 1 : f).stroke(colour, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .padding(-4)
        }
    }
}

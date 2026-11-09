import SloopKit
import SwiftUI

/// Sound selection without leaving the page: opened from a track's long-press menu, it slides in from
/// the right over the page, laid out as the Sounds tab (engines, then the presets as keys); the track
/// box stays in view beside it to show and switch the track. Done, or a tap on the page, closes it. Another way in to the
/// same choice as the Sounds tab: SLOOP keeps the pattern, the mix and the key when a preset loads.
struct PresetsPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    /// A pad or block without a sound of its own, its check just cleared: the browser opens to pick one.
    @State private var choosing = false

    static let width: CGFloat = 780

    var body: some View {
        let t = session.selectedTrack
        let entry = ui.soundEntry.flatMap { $0.ref.track == t ? $0 : nil }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                TrackChip(track: t, size: 28)
                Text(Self.header(session, track: t, entry: entry)).font(.lupe(22, .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { ui.presetsPanel = false } label: {
                    Text("Done").fontWeight(.semibold).padding(.horizontal, 18).frame(height: 44).raisedKey()
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Closes the sound panel")
            }
            if let entry { EntrySoundNone(session: session, entry: entry, choosing: $choosing) }
            // an entry that keeps the sound playing, unchecked to choose: the browser waits until then (Scott, 2026-11-09)
            let resting = entry != nil && !choosing && entryHasNoSound(entry)
            HStack(alignment: .top, spacing: 16) {
                if !session.isDrums(t) || entry != nil { LibraryEngines(session: session, ui: ui, entry: entry != nil).frame(width: 260) }
                LibraryPage(session: session, ui: ui, columns: 2, entry: entry)
            }
            .disabled(resting)
            .opacity(resting ? 0.4 : 1)
            .accessibilityHint(resting ? "Uncheck Uses the sound already playing to choose one" : "")
        }
        .padding(16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.well)
            .shadow(color: .black.opacity(0.5), radius: 14, x: -6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.header(session, track: t, entry: ui.soundEntry.flatMap { $0.ref.track == t ? $0 : nil }))
        .onChange(of: ui.soundEntry) { _, _ in choosing = false }
    }

    private func entryHasNoSound(_ entry: SoundEntryTarget?) -> Bool {
        guard let entry else { return false }
        return session.skiffSong?.song?.tracks[safe: entry.ref.track]?.entries[safe: entry.ref.entry]?.sound == nil
    }

    /// What the panel chooses for, in plain words (Scott, 2026-11-08): "Choose a sound for Track 5", "Choose a sound for
    /// Pad A on Track 5", a Timeline block's "Choose a sound for entry B on Track 5" (the Timeline's own word for a block,
    /// as its menus and inspector say); a drum track's "Choose a kit".
    static func header(_ session: DeviceSession, track t: Int, entry: SoundEntryTarget?) -> String {
        let what = session.isDrums(t) && entry == nil ? "a kit" : "a sound"
        guard let entry else { return "Choose \(what) for Track \(t + 1)" }
        let letter = Entries.letter(entry.ref.entry)
        return "Choose \(what) for \(entry.pad ? "Pad \(letter)" : "entry \(letter)") on Track \(t + 1)"
    }
}

/// An entry's panel: first, whether starting it changes the sound (Scott, 2026-11-09: the banner, a check mark at its
/// end, the wording accurate). An entry with no sound of its own doesn't change the track's sound when it starts: the
/// track keeps the sound it has, its own or one an earlier entry switched to (an entry's sound carries on after it).
/// Checked: that, and the browser below waits. Unchecked: the browser opens to pick one; with one picked it says what
/// the entry switches to, and checking drops it. The check is disabled when the change can't be made now.
private struct EntrySoundNone: View {
    let session: DeviceSession
    let entry: SoundEntryTarget
    @Binding var choosing: Bool

    var body: some View {
        let store = session.skiffSong
        let t = entry.ref.track, e = entry.ref.entry
        let current = store?.song?.tracks[safe: t]?.entries[safe: e]?.sound
        let checked = current == nil && !choosing
        let what = entry.pad ? "pad" : "entry"
        // dropping a sound goes to the FM-1 and may be refused; unchecking only opens the browser
        let why: String? = {
            guard let store else { return "No song yet" }
            if store.offline { return "The FM-1 is disconnected" }
            guard current != nil, var es = store.song?.tracks[safe: t]?.entries else { return nil }
            es[e].sound = nil
            return store.blocked(track: t, to: es)
        }()
        let canTap = why == nil && !(store?.busy ?? true)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Uses the sound already playing").fontWeight(checked ? .semibold : .regular)
                Group {
                    if let s = current {
                        Text("This \(what) switches the track to \(Entries.soundName(s, session: session).capitalized) when it starts. Check to drop it.")
                    } else if choosing {
                        Text("Pick a sound below for this \(what).")
                    } else {
                        Text("Starting this \(what) doesn't change the track's sound: the track keeps the one it has, its own or an earlier \(what)'s. Uncheck to give it a sound.")
                    }
                }
                .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                if let why { Text(why).font(.lupe(12)).foregroundStyle(Theme.text) }
            }
            Spacer(minLength: 0)
            Button {
                if current != nil, let store, let b = store.blocks(t).first(where: { $0.entries.contains(e) }) {
                    choosing = false
                    ArrangeEdits(session: session, store: store).setSound(t, b, nil)
                } else {
                    choosing.toggle()
                }
            } label: {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(canTap ? Theme.track[t] : Theme.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(!canTap)
            .accessibilityLabel("Uses the sound already playing")
            .accessibilityValue(checked ? "on" : "off")
            .accessibilityAddTraits(.isToggle)
            .accessibilityHint(current != nil ? "Drops the \(what)'s own sound" : checked ? "Opens the sounds to give the \(what) one" : "Closes the sounds")
        }
        .padding(.leading, 14).padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tones[2]))       // a raised surface, as the keys below
    }
}

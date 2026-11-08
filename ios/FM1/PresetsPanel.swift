import SloopKit
import SwiftUI

/// Sound selection without leaving the page: opened from a track's long-press menu, it slides in from
/// the right over the page, laid out as the Sounds tab (engines, then the presets as keys); the track
/// box stays in view beside it to show and switch the track. Done, or a tap on the page, closes it. Another way in to the
/// same choice as the Sounds tab: SLOOP keeps the pattern, the mix and the key when a preset loads.
struct PresetsPanel: View {
    let session: DeviceSession
    let ui: EditorUI

    static let width: CGFloat = 780

    var body: some View {
        let t = session.selectedTrack
        let entry = ui.soundEntry.flatMap { $0.ref.track == t ? $0 : nil }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                TrackChip(track: t, size: 28)
                Text(Self.header(session, track: t, entry: entry)).font(.system(size: 22, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { ui.presetsPanel = false } label: {
                    Text("Done").fontWeight(.semibold).padding(.horizontal, 18).frame(height: 44).raisedKey()
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Closes the sound panel")
            }
            if let entry { EntrySoundNone(session: session, entry: entry) }
            HStack(alignment: .top, spacing: 16) {
                if !session.isDrums(t) || entry != nil { LibraryEngines(session: session, ui: ui).frame(width: 260) }
                LibraryPage(session: session, ui: ui, columns: 2, entry: entry)
            }
        }
        .padding(16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.well)
            .shadow(color: .black.opacity(0.5), radius: 14, x: -6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.header(session, track: t, entry: ui.soundEntry.flatMap { $0.ref.track == t ? $0 : nil }))
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

/// An entry's panel: first, whether starting it changes the sound (Scott, 2026-11-09: the banner stays, with a check
/// mark at its end that's tapped to change it, disabled when the change can't be made). Checked: the entry has no sound
/// of its own, so the sound playing carries on when it starts (the track's, or an earlier entry's). Unchecked: it brings
/// its own, named here. Checking it drops that sound; unchecking puts back the one it just dropped (a sound picked
/// below unchecks it too).
private struct EntrySoundNone: View {
    let session: DeviceSession
    let entry: SoundEntryTarget
    /// The sound the check last dropped, so unchecking can bring it back.
    @State private var dropped: EntrySound?

    var body: some View {
        let store = session.skiffSong
        let t = entry.ref.track, e = entry.ref.entry
        let current = store?.song?.tracks[safe: t]?.entries[safe: e]?.sound
        let keeps = current == nil
        let what = entry.pad ? "pad" : "entry"
        // what checking or unchecking would do, and whether the FM-1 would take it now
        let target: EntrySound?? = keeps ? (dropped.map { .some($0) }) : .some(nil)
        let why: String? = {
            guard let store else { return "No song yet" }
            if store.busy || store.offline { return store.offline ? "The FM-1 is disconnected" : nil }
            guard let next = target, var es = store.song?.tracks[safe: t]?.entries else { return nil }
            es[e].sound = next
            return store.blocked(track: t, to: es)
        }()
        let canTap = target != nil && why == nil && !(store?.busy ?? true)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep the current sound").fontWeight(keeps ? .semibold : .regular)
                Text(keeps ? "Starting this \(what) doesn't change the sound." + (dropped == nil ? "" : " Uncheck to bring back \(Entries.soundName(dropped!, session: session).capitalized).")
                           : "This \(what) brings its own sound: \(Entries.soundName(current!, session: session).capitalized).")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let why, target != nil {
                    Text(why).font(.system(size: 12)).foregroundStyle(Theme.text)
                }
            }
            Spacer(minLength: 0)
            Button {
                guard let store, let b = store.blocks(t).first(where: { $0.entries.contains(e) }), let next = target else { return }
                if next == nil { dropped = current }
                ArrangeEdits(session: session, store: store).setSound(t, b, next)
            } label: {
                Image(systemName: keeps ? "checkmark.square.fill" : "square")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(canTap || keeps ? Theme.track[t] : Theme.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(!canTap)
            .accessibilityLabel("Keep the current sound")
            .accessibilityValue(keeps ? "on" : "off")
            .accessibilityAddTraits(.isToggle)
            .accessibilityHint(keeps ? (dropped == nil ? "Pick a sound below to give the \(what) its own" : "Brings its sound back")
                                     : "Drops the \(what)'s own sound")
        }
        .padding(.leading, 14).padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tones[2]))       // a raised surface, as the keys below
    }
}

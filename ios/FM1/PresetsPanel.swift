import SloopKit
import SwiftUI

/// Sound selection without leaving the page: opened from a track's long-press menu, it slides in from
/// the right over the page, laid out as the Library tab (engines, then the presets as keys); the track
/// box stays in view beside it to show and switch the track. Done, or a tap on the page, closes it. Another way in to the
/// same choice as the Library tab: SLOOP keeps the pattern, the mix and the key when a preset loads.
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

/// An entry's panel: its first choice, no sound of its own (the track's carries on), lit while that's what it has.
private struct EntrySoundNone: View {
    let session: DeviceSession
    let entry: SoundEntryTarget

    var body: some View {
        let store = session.skiffSong
        let current = store?.song?.tracks[safe: entry.ref.track]?.entries[safe: entry.ref.entry]?.sound
        Button {
            guard let store, let b = store.blocks(entry.ref.track).first(where: { $0.entries.contains(entry.ref.entry) }) else { return }
            ArrangeEdits(session: session, store: store).setSound(entry.ref.track, b, nil)
        } label: {
            HStack(spacing: 10) {
                LED(on: current == nil, colour: Theme.track[entry.ref.track])
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use the track's sound").fontWeight(current == nil ? .semibold : .regular)
                    Text(current == nil ? "This \(entry.pad ? "pad" : "entry") plays whatever the track has"
                         : "Drops \(entry.pad ? "the pad" : "the entry")'s own sound: the track's carries on").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .latchedKey(current == nil, 10)
        }
        .buttonStyle(PressSink(latched: current == nil))
        .disabled(store?.busy ?? true)
        .accessibilityAddTraits(current == nil ? .isSelected : [])
    }
}

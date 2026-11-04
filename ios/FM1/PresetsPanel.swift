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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                TrackChip(track: t, size: 28)
                Text(session.isDrums(t) ? "Kits" : "Presets for track \(t + 1)").font(.system(size: 22, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { ui.presetsPanel = false } label: {
                    Text("Done").fontWeight(.semibold).padding(.horizontal, 18).frame(height: 44).raisedKey()
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Closes the presets")
            }
            HStack(alignment: .top, spacing: 16) {
                if !session.isDrums(t) { LibraryEngines(session: session, ui: ui).frame(width: 260) }
                LibraryPage(session: session, ui: ui, columns: 2)
            }
        }
        .padding(16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.well)
            .shadow(color: .black.opacity(0.5), radius: 14, x: -6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.isDrums(t) ? "Kits for the drum track" : "Presets for track \(t + 1)")
    }
}

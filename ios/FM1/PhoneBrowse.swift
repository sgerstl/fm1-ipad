import SloopKit
import SwiftUI

/// Browse on the iPhone (2026-11-04): the engines listed on the left, the selected engine's presets on
/// the right, as the iPad's Browse tab (the same two views, fewer columns). A tap loads a preset onto
/// the selected track at once; its pattern, mix and key stay.
struct PhoneBrowse: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if session.selectedTrack < 3 { LibraryEngines(session: session, ui: ui).frame(width: 210) }
            LibraryPage(session: session, ui: ui, columns: 3)
        }
    }
}

/// A track's sound without leaving the page (from its chip's long-press menu): slides in from the right
/// over the page, engines on the left and the presets as one list on the right (Scott's call on the
/// mockups, 2026-11-04). Done, or a tap on the page beside it, closes it.
struct PhonePresetsPopover: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        let t = session.selectedTrack
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TrackChip(track: t, size: 28)
                Text(t == 3 ? "Kits" : "Track \(t + 1) sound").font(.system(size: 17, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { ui.presetsPanel = false } label: {
                    Text("Done").font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 44).raisedKey()
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Closes the presets")
            }
            HStack(alignment: .top, spacing: 8) {
                if t < 3 { LibraryEngines(session: session, ui: ui).frame(width: 180) }
                LibraryPage(session: session, ui: ui, columns: 1)
            }
        }
        .padding(10)
        .frame(width: 470)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.well)
            .shadow(color: .black.opacity(0.55), radius: 14, x: -6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t == 3 ? "Kits for the drum track" : "Sound for track \(t + 1)")
    }
}

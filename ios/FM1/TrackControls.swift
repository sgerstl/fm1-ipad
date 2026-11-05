import SloopKit
import SwiftUI

// The Song tab's whole-track controls (Scott, 2026-11-05): SWING, LEVEL, STEPS and PAN moved from the foot of the
// inspector into a small popover under the right end of the selected track's lane header. The menus' surface
// (MenuPanel), the white knobs with hold-to-drag and a tap for the big control (Done or Cancel), as elsewhere.

/// The key at the right end of the selected lane's header: opens and closes the popover, and keeps its frame for it.
struct TrackControlsKey: View {
    let ui: EditorUI
    let height: CGFloat

    var body: some View {
        Button { ui.trackControlsOpen.toggle() } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ui.trackControlsOpen ? Theme.onColour : Theme.text)
                .frame(width: 36, height: max(28, height - 4))
                .background(RoundedRectangle(cornerRadius: 8).fill(ui.trackControlsOpen ? Theme.text : Theme.control))
                .frame(width: 44, height: max(height, 28))          // the target: 44 wide, the lane's height
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { ui.trackControlsAnchor = $0 }
        .accessibilityLabel("Whole track controls")
        .accessibilityValue(ui.trackControlsOpen ? "open" : "closed")
        .accessibilityHint("Swing, level, steps and pan")
    }
}

/// The popover, under the key with their right edges lined up (above it where it wouldn't fit); a tap anywhere
/// else or Escape closes it, and so does another track picked or the tab left.
struct TrackControlsLayer: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var frame: CGRect = .zero
    @Environment(\.look) private var look

    var body: some View {
        GeometryReader { g in
            if ui.trackControlsOpen, ui.page == .song, ui.trackControlsAnchor != .zero {
                let a = ui.trackControlsAnchor.offsetBy(dx: -frame.minX, dy: -frame.minY)
                ZStack(alignment: .topLeading) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { ui.trackControlsOpen = false }
                        .accessibilityHidden(true)
                    panel
                        .fixedSize()
                        .alignmentGuide(.leading) { d in -min(max(12, a.maxX - d.width), g.size.width - d.width - 12) }
                        .alignmentGuide(.top) { d in -(a.maxY + 8 + d.height <= g.size.height ? a.maxY + 8 : max(12, a.minY - 8 - d.height)) }
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .onChange(of: session.selectedTrack) { _, _ in ui.trackControlsOpen = false }
        .onChange(of: ui.page) { _, _ in ui.trackControlsOpen = false }
    }

    private var panel: some View {
        let t = session.selectedTrack
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TrackChip(track: t, muted: session.tracks[t].mute)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Whole track").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Text(session.isDrums(t) ? "Drums" : session.tracks[t].displayName)
                        .font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            KnobRow(session: session, ui: ui)
            Text("Swing sets every track.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Whole track, track \(t + 1)")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { ui.trackControlsOpen = false }
        .onKeyPress(.escape) { ui.trackControlsOpen = false; return .handled }
    }
}

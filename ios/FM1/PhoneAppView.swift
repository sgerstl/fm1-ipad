import SloopKit
import SwiftUI

/// The iPhone layout (landscape, 2026-11-04): one 44 pt top bar, then one job at a time. Designed in the
/// mockups (vault: Projects/Dev/fm1-ipad/iphone-adaptation.md); built screen by screen. Until a screen
/// exists, this says so plainly instead of shrinking the iPad's canvas onto the phone.
struct PhoneAppView: View {
    let session: SloopSession
    let ui: EditorUI
    @Binding var useDemo: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Jib on iPhone").font(.system(size: 28, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text(status)
                .font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
            Text("The iPhone layout is being built. Use Jib on an iPad for now.")
                .font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var status: String {
        switch session.status {
        case .connected(let version): "Connected: \(version)"
        case .wrongFirmware(let found, _): "This FM-1 runs other firmware (\(found))"
        default: "No FM-1 connected"
        }
    }
}

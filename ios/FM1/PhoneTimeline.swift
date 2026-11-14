import SloopKit
import SwiftUI

/// The phone's Timeline tab (decision 33; Android's TimelinePage is the reference). First cut: the iPad's arrange page.
struct PhoneTimeline: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI

    var body: some View {
        SkiffArrangePage(session: session, store: store, ui: ui)
    }
}

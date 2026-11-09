import CoreAudioKit
import SwiftUI

/// "Connect over Bluetooth…" (bluetooth-poc, 2026-11-10): Apple's Bluetooth MIDI view, which lists the BLE-MIDI devices
/// nearby and connects one. Once the FM-1 (FM1-XXXX, MENU > SYSTEM > BLUETOOTH ON) is connected there, iOS shows it to
/// CoreMIDI and the session finds it as it finds the USB port (MIDITransport). Apple's view does its own VoiceOver; the
/// bar around it is Lupe's: a title and Done.
struct BluetoothConnectSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("On the FM-1, switch MENU › SYSTEM › BLUETOOTH on, then choose FM1-… below.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                BluetoothMIDIPicker()
            }
            .navigationTitle("Connect over Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes the Bluetooth list. A connected FM-1 stays connected.")
                }
            }
        }
    }
}

/// CABTMIDICentralViewController in SwiftUI. It's a table view controller: it needs a navigation controller around it
/// for its own bar items, which stay hidden here (the SwiftUI bar has the title and Done).
private struct BluetoothMIDIPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let nav = UINavigationController(rootViewController: CABTMIDICentralViewController())
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

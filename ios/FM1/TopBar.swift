import SloopKit
import SwiftUI

struct TopBar: View {
    let session: SloopSession
    let ui: EditorUI
    @Binding var useDemo: Bool

    var body: some View {
        HStack {
            connection.frame(width: 420, alignment: .leading)
            Spacer()
            tabs
            Spacer()
            transport.frame(width: 420, alignment: .trailing)
        }
        .frame(height: 64)
    }

    // MARK: Connection: tap for the device / demo choice

    private var connection: some View {
        Menu {
            Picker("Source", selection: $useDemo) {
                Text("FM-1 over USB").tag(false)
                Text("Demo FM-1 (no device)").tag(true)
            }
            if session.screenLinked {
                Toggle("Follow the FM-1's screen", isOn: Binding(get: { ui.followDevice }, set: { ui.followDevice = $0 }))
            }
            if isConnected {
                // Diagnostics for the feel test: are pushes arriving, or is the re-sync doing the work?
                let s = session.stats
                Section("Since connecting") {
                    Text("Step pushes \(s.stepPushes) · all pushes \(s.pushes)")
                    Text("Steps fixed by re-sync \(s.resyncFixes)")
                    Text(String(format: "LIVE %.1f a second · timeouts %d", s.pollsPerSecond, s.timeouts))
                }
            }
        } label: {
            HStack(spacing: 10) {
                LED(on: isConnected, colour: Theme.text)
                    .frame(width: 8, height: 8)
                Text(statusLine).font(.system(size: 15, weight: .semibold))
                Text(versionLine).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(statusLine), \(versionLine)")
        .accessibilityHint("Choose the FM-1 or the demo")
    }

    private var isConnected: Bool { if case .connected = session.status { true } else { false } }

    private var statusLine: String {
        switch session.status {
        case .searching: "No FM-1"
        case .connecting: "Connecting…"
        case .connected: session.isDemo ? "Demo FM-1" : "FM-1 connected"
        case .wrongFirmware: "Wrong firmware"
        case .lost: "FM-1 disconnected"
        }
    }

    private var versionLine: String {
        switch session.status {
        case .connected(let v): session.screenLinked ? "\(v) · screen link" : v
        case .wrongFirmware(let found, _): found.replacingOccurrences(of: "FELUCCA ", with: "")
        default: "needs SLOOP 2.8.4"
        }
    }

    // MARK: Tabs: tap only (two fingers pan the grid on this page)

    // MARK: Tabs (three raised keys were tried 2026-11-01 and didn't work: back to the tabs)

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(Page.allCases) { p in
                let current = ui.page == p
                Button {
                    ui.page = p
                    driveDevice(to: p)
                } label: {
                    Text(p.rawValue)
                        .fontWeight(current ? .semibold : .regular)
                        .foregroundStyle(current ? Theme.text : Theme.textSecondary)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background { if current { Color.clear.raisedKey() } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(current ? [.isSelected] : [])
            }
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pages")
    }

    /// A tab tapped on the iPad: the FM-1's screen goes to the same place (HOME, the preset browser,
    /// or the Sound tab's button), when linked and following.
    private func driveDevice(to p: Page) {
        guard session.screenLinked, ui.followDevice else { return }
        if let s = session.deviceScreen, SoundPage.tab(for: s) == p { return }    // already there
        switch p {
        case .sequencer: session.showOnDevice(page: SoundPage.home)
        case .library: session.showOnDevice(page: SoundPage.presets)
        case .song: session.showOnDevice(page: SoundPage.section)
        case .sound:
            if let first = SoundPage.shown(session, ui.soundFamily).first { session.showOnDevice(page: first.fw) }
        }
    }

    // MARK: Position, tempo, play / stop

    private var transport: some View {
        let pos = session.positions[session.selectedTrack]
        return HStack(spacing: 20) {
            ToggleKey(name: "Keys", on: ui.keyboardOpen, enabled: isConnected) { ui.keyboardOpen.toggle() }
                .accessibilityHint("Shows the FM-1's keyboard")
            if session.song.songMode { songMarker }
            readout(session.playing ? "\(pos.step / 16 + 1) · \(pos.step % 16 + 1)" : "– · –", "bar · step")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(session.playing ? "Bar \(pos.step / 16 + 1), step \(pos.step % 16 + 1)" : "Stopped")
                .frame(width: 72, alignment: .trailing)     // "4 · 16" at its widest: nothing beside it moves
            readout("\(session.bpm)", "BPM")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(session.bpm) BPM")
            Button { session.setPlaying(!session.playing) } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0xF7F7F9), Color(hex: 0xCFCFD4)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.6), radius: 1.5, y: 2)
                        .shadow(color: .black.opacity(0.4), radius: 7, y: 6)
                    if session.playing {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.onColour).frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(Theme.onColour).offset(x: 1.5)
                    }
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .disabled(!isConnected)
            .opacity(isConnected ? 1 : 0.4)
            .accessibilityLabel(session.playing ? "Stop" : session.song.songMode ? "Play the song" : "Play")
        }
        .fixedSize()            // the controls keep their size; the connection label gives way
    }

    /// Song mode is on: PLAY plays the song order and loads sections over the tracks. Shown on every
    /// page, since it changes what PLAY does to the grid; tap for the Song tab.
    private var songMarker: some View {
        Button {
            ui.page = .song
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: SoundPage.section) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "music.note.list").font(.system(size: 13, weight: .semibold))
                Text(session.song.songRecording ? "SONG REC" : "SONG").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.onColour)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(Theme.text))
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(session.song.songRecording ? "Song recording is on" : "Song mode is on")
        .accessibilityHint("PLAY plays the song order. Opens the Song tab")
    }

    private func readout(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.system(size: 22, weight: .semibold)).lineLimit(1)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        }
    }
}

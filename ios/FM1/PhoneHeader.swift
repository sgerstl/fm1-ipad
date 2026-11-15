import SloopKit
import SwiftUI

// The phone's header (vault decisions 23, 29, 31, 33; Android's TopBar is the reference): the song's name with ⌄ as the
// app menu, the tabs Pads · Edit · Timeline as words with a white underline that glides, then at the right the launch
// timing beside the readout, and Record and Play round like the FM-1's buttons. DESIGN.md: the header is chrome, not
// content, so words and rounds here, square keys stay the content's. 48 pt with a hairline under it. iPhone only.

/// The phone's three tabs, laid over the app's pages: Pads and the Timeline are the Song page's two views, Edit is
/// Sequence, Mix the GLO MIXER page (batch item 10, 2026-11-15: the tab is back; DELAY, REVERB, CHORUS and GLOBAL open
/// the Mix pop-up). Sounds is a sheet (decision 33).
enum PhoneTab: Int, CaseIterable, Identifiable {
    case pads, edit, timeline, mix
    var id: Int { rawValue }
    var title: String { ["Pads", "Edit", "Timeline", "Mix"][rawValue] }
}

extension EditorUI {
    /// The tab showing, read from the page and the Song page's view.
    var phoneTab: PhoneTab {
        if page == .sequencer { return .edit }
        if page == .mixer { return .mix }
        return songView == .timeline ? .timeline : .pads
    }
    func setPhoneTab(_ t: PhoneTab) {
        switch t {
        case .pads: songView = .pads; page = .song
        case .edit: page = .sequencer
        case .timeline: songView = .timeline; page = .song
        case .mix: page = .mixer          // (batch item 10: the Mix tab is back; GLO's shared pages still open the pop-up)
        }
    }
}

struct PhoneHeader: View {
    let session: DeviceSession
    let ui: EditorUI
    @Binding var useDemo: Bool
    @Environment(AudioThrough.self) private var through
    @Environment(FirmwareCentre.self) private var firmware
    @Environment(ProjectStore.self) private var projects
    @State private var nameFrame: CGRect = .zero
    @State private var readoutFrame: CGRect = .zero

    private var recording: Bool { session.isRecordingAnything }

    var body: some View {
        HStack(spacing: 0) {
            songWord
            if session.isConnected {
                PhoneTabs(ui: ui) { t in
                    ui.setPhoneTab(t)
                    TopBar.driveDevice(session: session, ui: ui, to: ui.page)
                }
                .padding(.leading, 16)
            }
            Spacer(minLength: 8)
            if session.isConnected, ui.songTab, let store = session.skiffSong {
                PhoneLaunchKey(session: session, store: store, ui: ui)
                    .padding(.trailing, 4)
            }
            readout.padding(.trailing, 4)
            HeaderRound(lit: recording, litColour: Theme.rec, label: "Record",
                        value: session.song.songRecording ? "song recording" : session.recording ? "recording" : "off") {
                session.toggleRec()
            } content: { lit in
                Circle().fill(lit ? Theme.onColour : Theme.rec).frame(width: 14, height: 14)
            }
            .padding(.trailing, 4)
            HeaderRound(lit: session.playing, litColour: Theme.text, label: session.playing ? "Stop" : "Play", value: nil) {
                session.setPlaying(!session.playing)
            } content: { lit in
                Image(systemName: lit ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(lit ? Theme.onColour : Theme.text)
                    .offset(x: lit ? 0 : 1)        // (the triangle's optical centre)
            }
            .disabled(!session.isConnected)
            .opacity(session.isConnected ? 1 : 0.45)
        }
        .frame(height: 48)
    }

    // MARK: The song's name: the app menu

    private var songName: String {
        switch projects.state {
        case .project(let n): n
        case .untitled: "Untitled"
        case .unknown: session.isDemo ? "Demo" : "FM-1"
        case .offline(let n): n ?? "Lupe"
        }
    }

    private var songWord: some View {
        HeaderWord(text: songName, size: 17, primary: true, maxWidth: 130) { openMenu() }
            .globalFrame($nameFrame)
            .accessibilityLabel("Lupe menu, \(songName)")
            .accessibilityHint("Projects, Mix, the FM-1's firmware, Settings, the iPhone's audio and the demo")
    }

    /// Android's song-name menu, carrying what the iPhone's ⋯ held (decision 33): Projects, Mix, Settings, then the
    /// iPhone's audio, the source and Developer.
    private func openMenu() {
        guard !OutsideTouch.justClosed else { return }
        ui.menu = AppMenu(title: songName, groups: {
            var g: [[MenuItem]] = []
            var main: [MenuItem] = []
            if session.isConnected, session.dialect == .skiff || session.capabilities.contains(.projects) {
                main.append(MenuItem(title: "Projects…", icon: "folder") { ui.projectsOpen = true })
            }
            if session.isConnected, ui.songTab {
                main.append(MenuItem(title: "Patterns…", icon: "square.grid.2x2") { ui.patternsSheet = .manage })
                main.append(MenuItem(title: "Mix…", icon: "slider.vertical.3") { ui.mixPopup = true })
            }
            // decision 42: what the FM-1 runs, Skiff-Lupe, and stock V15 back (it was Developer › Install firmware…, debug only)
            main.append(MenuItem(title: "FM-1 firmware…", icon: "arrow.down.circle") {
                firmware.pickerNote = nil; firmware.target = .skiff251; firmware.showPicker = true
            })
            main.append(MenuItem(title: "Settings…", icon: "gearshape") { ui.phoneSettingsOpen = true })
            g.append(main)
            var audio = [MenuItem(title: "Play through the iPhone", icon: "speaker.wave.2", checked: through.enabled) { through.enabled.toggle() }]
            if through.enabled { audio.append(.note(through.summary)) }
            g.append(audio)
            g.append([MenuItem(title: "FM-1 over USB", icon: "cable.connector", checked: !useDemo) { useDemo = false },
                      MenuItem(title: "Skiff demo", icon: "play.rectangle", checked: useDemo && ui.demoSkiff) { ui.demoSkiff = true; useDemo = true },
                      MenuItem(title: "SLOOP demo", icon: "play.rectangle", checked: useDemo && !ui.demoSkiff) { ui.demoSkiff = false; useDemo = true }])
            return g
        }, at: CGPoint(x: nameFrame.minX, y: nameFrame.maxY), fromKey: true)
    }

    // MARK: The readout: bar · beat over the tempo; a tap opens the tempo

    private var readout: some View {
        let pos = session.positions[session.selectedTrack]
        return Button { if !OutsideTouch.justClosed { ui.tempoAt = CGPoint(x: readoutFrame.minX, y: readoutFrame.maxY) } } label: {
            VStack(alignment: .trailing, spacing: 1) {
                Text(session.playing ? "\(pos.step / 16 + 1)·\(pos.step % 16 / 4 + 1)" : "–")
                    .font(.lupeNumber(17, .semibold))
                    .foregroundStyle(recording ? Theme.recText : Theme.text)
                Text(recording ? "REC" : "\(session.bpm) BPM").font(.lupe(11)).foregroundStyle(Theme.textSecondary)
            }
            .lineLimit(1)
            .frame(width: 60, alignment: .trailing)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .globalFrame($readoutFrame)
        .disabled(!session.isConnected)
        .opacity(session.isConnected ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the tempo")
        .accessibilityAddTraits(.isButton)
    }
}

/// A word with a ⌄ that opens a menu: no box (Android's HeaderWord). The target is the header's 48 pt and at least 48
/// wide; a press lays a soft well behind the word.
struct HeaderWord: View {
    let text: String
    let size: CGFloat
    var primary = true
    var sub: String? = nil
    var maxWidth: CGFloat = 110
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(text).font(.lupe(size, .semibold)).lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: maxWidth, alignment: .leading).fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(primary ? Theme.text : Theme.textSecondaryRaised)
                    Image(systemName: "chevron.down").font(.system(size: size * 0.55, weight: .bold))
                        .foregroundStyle(Theme.textSecondaryRaised)
                }
                if let sub { Text(sub).font(.lupe(11)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1) }
            }
            .padding(.horizontal, 8)
            .frame(minWidth: 48, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(HeaderWordStyle())
    }
}

/// The word's press: a soft well behind it, in quickly, out a little slower.
struct HeaderWordStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 8).fill(Theme.control)
                    .padding(.vertical, 4)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .animation(.easeOut(duration: configuration.isPressed ? 0.06 : 0.15), value: configuration.isPressed)
            }
    }
}

/// Record and Play: round, as the FM-1's buttons (Android's RoundButton). 40 pt across in a 48 pt target; lit, the
/// circle fills in its colour; otherwise a ring in the outline grey. The change blends (150 ms).
struct HeaderRound<Content: View>: View {
    let lit: Bool
    let litColour: Color
    let label: String
    let value: String?
    let action: () -> Void
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(litColour).opacity(lit ? 1 : 0)
                Circle().strokeBorder(Theme.disabledOutline, lineWidth: 2).opacity(lit ? 0 : 1)
                content(lit)
            }
            .frame(width: 40, height: 40)
            .animation(.easeOut(duration: 0.15), value: lit)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(RoundPress())
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
    }
}

/// A round key's press: a soft white wash over the circle.
struct RoundPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Circle().fill(Theme.text.opacity(0.14)).frame(width: 40, height: 40)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .animation(.easeOut(duration: configuration.isPressed ? 0.06 : 0.1), value: configuration.isPressed)
                    .allowsHitTesting(false)
            }
    }
}

/// Pads · Edit · Timeline: Barlow 17 semibold, 24 pt apart; the tab showing in the text white with a 3 pt underline the
/// width of its word that glides to the new tab (200 ms, ease-out). Reduce Motion: the underlines cross-fade in place.
struct PhoneTabs: View {
    let ui: EditorUI
    let pick: (PhoneTab) -> Void
    @Namespace private var line
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = ui.phoneTab
        HStack(spacing: 24) {
            ForEach(PhoneTab.allCases) { t in
                let on = t == current
                Button { if !on { pick(t) } } label: {
                    Text(t.title).font(.lupe(17, .semibold))
                        .foregroundStyle(on ? Theme.text : Theme.textSecondary)
                        .lineLimit(1).fixedSize()
                        .frame(height: 48)
                        .overlay(alignment: .bottom) {
                            if reduceMotion {
                                Rectangle().fill(Theme.text).frame(height: 3).padding(.bottom, 4).opacity(on ? 1 : 0)
                            } else if on {
                                Rectangle().fill(Theme.text).frame(height: 3).padding(.bottom, 4)
                                    .matchedGeometryEffect(id: "underline", in: line)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isHeader] : [])
                .accessibilityHint(on ? "" : "Shows \(t.title)")
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.2), value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }
}

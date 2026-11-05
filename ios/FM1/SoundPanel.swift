import SloopKit
import SwiftUI

// The sound panel (Scott, 2026-11-05; canvas boards 21 and 22, design/boards/panel.py): on the Song tab, ENV, LFO,
// FX, SEL, EDIT and ARP (the rail down the right edge, or the FM-1's own buttons) bring in the selected track's
// sound from the right, at level 3 over the song and the pattern: the sound and its Sounds browser on top, that
// button's Shape cards below (ShapeSection, the Shape tab's own). Another button switches it; the same one again,
// HOME, ✕ or a tap outside closes it, and Pin keeps it open. Built to drop into the Mixer tab later as it is.

/// What the panel shows: a button's pages, and whether it stays open on a tap outside.
struct SoundPanelState: Equatable {
    var family: SoundFamily
    var pinned = false
}

enum SoundPanelControl {
    static let families: [SoundFamily] = [.env, .lfo, .fx, .sel, .edit, .arp]

    /// A button pressed (on the rail, or on the FM-1 while the Song tab is up): its pages, or closed if they were up.
    /// `fromDevice`: the FM-1 is already on that page; a press on the FM-1 never closes (it steps the button's pages).
    @MainActor static func press(_ f: SoundFamily, session: DeviceSession, ui: EditorUI, fromDevice: Bool = false) {
        if ui.soundPanel?.family == f {
            if !fromDevice { ui.soundPanel = nil }
            return
        }
        ui.soundPanel = SoundPanelState(family: f, pinned: ui.soundPanel?.pinned ?? false)
        ui.soundFamily = f
        guard !fromDevice, session.screenLinked, ui.followDevice, let first = SoundPage.reached(session, f).first else { return }
        session.showOnDevice(page: first.fw)
    }

    /// The FM-1's screen moved while the Song tab is up: ENV LFO FX SEL EDIT ARP bring in the panel (the tab stays);
    /// HOME closes it. true: handled here; false: the button map's (SkiffNavigator) to follow.
    @MainActor static func follow(_ s: UIState, session: DeviceSession, ui: EditorUI) -> Bool {
        guard ui.followDevice, session.screenLinked, ui.songTab, ui.page == .song || ui.page == .mixer else { return false }
        if s.home { ui.soundPanel = nil; return false }
        guard s.layer == 0, s.menu == 0, let page = SoundPage.page(session, fw: s.page), families.contains(page.family) else { return false }
        press(page.family, session: session, ui: ui, fromDevice: true)
        return true
    }

    /// Closed (✕, HOME, a tap outside unless pinned, another tab).
    @MainActor static func close(_ ui: EditorUI, unlessPinned: Bool = false) {
        guard let p = ui.soundPanel, !(unlessPinned && p.pinned) else { return }
        ui.soundPanel = nil
    }
}

/// The rail: the six buttons with pages, as the FM-1's keys; the one whose pages are open is lit.
struct SoundRail: View {
    let session: DeviceSession
    let ui: EditorUI
    static let width: CGFloat = 56

    var body: some View {
        VStack(spacing: 8) {
            ForEach(SoundPanelControl.families) { f in
                let on = ui.soundPanel?.family == f
                let none = SoundPage.shown(session, f).isEmpty
                Button { SoundPanelControl.press(f, session: session, ui: ui) } label: {
                    Text(f.rawValue).font(.system(size: 12, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(on ? Theme.text : none ? Theme.textTertiary : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background { if on { Color.clear.selectedKey(8) } else { Color.clear.raisedKey(8) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel("\(f.rawValue) pages")
                .accessibilityValue(on ? "open" : none ? "none for this track" : "")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sound pages")
    }
}

/// The panel itself: the track's sound, then the button's cards in one column.
struct SoundPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    let state: SoundPanelState
    @State private var marks = ShapeMarks()
    @Environment(\.look) private var look
    static let width: CGFloat = 430

    var body: some View {
        let t = session.selectedTrack, track = session.tracks[t]
        let pages = SoundPage.shown(session, state.family)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(state.family.rawValue).font(.system(size: 20, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text("T\(t + 1) \(Entries.trackName(t, session: session)) · \(pages.count) page\(pages.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                Spacer(minLength: 0)
                Button { ui.soundPanel?.pinned.toggle() } label: {
                    Label(state.pinned ? "Pinned" : "Pin", systemImage: state.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                        .background { if state.pinned { Color.clear.selectedKey(8) } else { Color.clear.raisedKey(8) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Keeps the panel open when you tap outside it")
                .accessibilityAddTraits(state.pinned ? .isSelected : [])
                Button { SoundPanelControl.close(ui) } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44).raisedKey(8).contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close the \(state.family.rawValue) pages")
            }
            // the track's sound, and the browser for another
            HStack(spacing: 10) {
                TrackChip(track: t, muted: track.mute)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.presetName.isEmpty ? track.displayName : track.presetName.capitalized).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(track.engineName).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button { ui.presetsPanel = true } label: {
                    HStack(spacing: 4) {
                        Text("Sounds").font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12).frame(minHeight: 44).raisedKey(8).contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityHint("Opens the presets for this track")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
            ScrollView {
                if pages.isEmpty {
                    Text("T\(t + 1)'s engine has no \(state.family.rawValue) pages.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                } else {
                    ShapeSection(session: session, ui: ui, marks: marks, family: state.family, columns: 1, showsHeader: false)
                        .padding(.bottom, 8)
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .background { TouchFollower(session: session) { if let k = session.lastTouched { marks.mark("s\(k.scope).\(k.id)") } } }
        .onChange(of: session.deviceScreen) { _, s in SoundTab.adoptCursor(session, marks, s) }
        .onAppear { SoundTab.adoptCursor(session, marks, session.deviceScreen) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sound panel, \(state.family.rawValue)")
        .accessibilityAction(.escape) { SoundPanelControl.close(ui) }
    }
}

/// The rail beside a page and the panel over it (the Song tab now; the Mixer tab once its redesign merges): a tap on
/// the page outside the panel closes it unless pinned.
struct SoundPanelHost<Content: View>: View {
    let session: DeviceSession
    let ui: EditorUI
    /// The Mixer tab: the page makes way for the panel (its soundPanelRoom hook) instead of being covered, so a tap
    /// on it is the page's own (a fader) and doesn't close the panel; ✕, the key again, HOME or a tab do.
    var makesRoom = false
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.grid) private var grid

    var body: some View {
        // the page gives the rail its width: a step narrower, so a bar of the grid still fits across
        var narrowed = grid
        narrowed.stepWidth = grid.stepWidth - (SoundRail.width + 12) / 16
        return HStack(alignment: .top, spacing: 12) {
            content()
                .environment(\.grid, narrowed)
                .environment(\.soundPanelRoom, makesRoom && ui.soundPanel != nil ? SoundPanel.width + 12 : 0)
                .overlay {
                    if let s = ui.soundPanel, !s.pinned, !makesRoom {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { SoundPanelControl.close(ui, unlessPinned: true) }
                            .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let s = ui.soundPanel {
                        SoundPanel(session: session, ui: ui, state: s)
                            .id(s.family)
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: ui.soundPanel?.family)
            SoundRail(session: session, ui: ui)
        }
    }
}

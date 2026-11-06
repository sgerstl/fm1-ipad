import SloopKit
import SwiftUI

// The sound panel (Scott, 2026-11-05; canvas boards 21 and 22, design/boards/panel.py): on the Song tab, ENV, LFO,
// FX, SEL, EDIT and ARP (the rail down the right edge, or the FM-1's own buttons) bring in the selected track's
// sound from the right, at level 3 over the song and the pattern: the sound and its Sounds browser on top, that
// button's Shape cards below (ShapeSection, the Shape tab's own). Another button switches it; the same one again
// steps its pages, as on the FM-1 (the page's card scrolls to the top and lights); HOME, ✕, Escape or a tap outside
// closes it, and Pin keeps it open. Built to drop into the Mixer tab later as it is.

/// What the panel shows: a button's pages, and whether it stays open on a tap outside.
struct SoundPanelState: Equatable {
    var family: SoundFamily
    var pinned = false
}

enum SoundPanelControl {
    /// The rail's order is the FM-1's, top to bottom (then SEQ, its own key: SeqKey).
    static let families: [SoundFamily] = [.fx, .sel, .env, .lfo, .edit, .arp]

    /// A button pressed (on the rail, the pads, or on the FM-1 while the Song or Mixer tab is up): its pages; pressed
    /// again, its next page (Scott, 2026-11-05: the same key steps and reveals, as the FM-1's does; it no longer
    /// closes). `fromDevice`: the FM-1 has already moved; AppView focused that page.
    @MainActor static func press(_ f: SoundFamily, session: DeviceSession, ui: EditorUI, fromDevice: Bool = false) {
        guard !SoundPage.shown(session, f).isEmpty else { return }        // a disabled button: nothing, no empty panel
        if ui.soundPanel?.family == f {
            if !fromDevice { step(f, session: session, ui: ui) }
            return
        }
        ui.soundPanel = SoundPanelState(family: f, pinned: ui.soundPanel?.pinned ?? false)
        ui.soundFamily = f
        guard !fromDevice, let first = SoundPage.reached(session, f).first else { return }
        ui.focus(first)
        if session.screenLinked, ui.followDevice { session.showOnDevice(page: first.fw) }
    }

    /// The button's next page, round and round: from the FM-1's page when linked, else from the one focused here. It
    /// goes to the FM-1 too; its card comes forward at once.
    @MainActor static func step(_ f: SoundFamily, session: DeviceSession, ui: EditorUI) {
        let pages = SoundPage.reached(session, f)
        guard !pages.isEmpty else { return }
        let linked = session.screenLinked && ui.followDevice
        let at = linked ? session.deviceScreen.flatMap { s in pages.firstIndex { $0.fw == s.page } }
                        : ui.focusedPage.flatMap { fp in pages.firstIndex { $0.id == fp.id } }
        let next = pages[at.map { ($0 + 1) % pages.count } ?? 0]
        ui.focus(next)
        if linked { session.showOnDevice(page: next.fw) }
    }

    /// The FM-1's screen moved while the Song tab is up: ENV LFO FX SEL EDIT ARP bring in the panel (the tab stays);
    /// HOME closes it. true: handled here; false: the button map's (SkiffNavigator) to follow.
    @MainActor static func follow(_ s: UIState, session: DeviceSession, ui: EditorUI) -> Bool {
        // a button the track's engine has no pages for, pressed on the FM-1: nothing in Lupe, on any tab (the FM-1
        // shows what it shows)
        if ui.songTab, !s.home, s.layer == 0, let page = SoundPage.page(session, fw: s.page), families.contains(page.family),
           SoundPage.shown(session, page.family).isEmpty { return true }
        guard ui.followDevice, session.screenLinked, ui.songTab else { return false }
        if s.home { ui.soundPanel = nil; return false }
        guard s.layer == 0, s.menu == 0, let page = SoundPage.page(session, fw: s.page), families.contains(page.family) else { return false }
        press(page.family, session: session, ui: ui, fromDevice: true)
        return true
    }

    /// Why a button is disabled, for VoiceOver: "No ENV pages on DRUM".
    @MainActor static func noPages(_ f: SoundFamily?, _ session: DeviceSession) -> String {
        guard let f else { return "" }
        let t = session.tracks[session.selectedTrack]
        return "No \(f.rawValue) pages on \(t.engineName.isEmpty ? "this engine" : t.engineName)"
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
                        .background {
                            // disabled: no raised edge, dimmed
                            if on { Color.clear.selectedKey(8) } else if none { RoundedRectangle(cornerRadius: 8).fill(Theme.control.opacity(0.5)) }
                            else { Color.clear.raisedKey(8) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(none)
                .accessibilityLabel("\(f.rawValue) pages")
                .accessibilityValue(on ? "open" : none ? SoundPanelControl.noPages(f, session) : "")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            SeqKey(session: session, ui: ui)
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
    @State private var settled = false          // slid in: the cards' graphs draw from then (not while it moves)
    @Environment(\.look) private var look
    static let width: CGFloat = 430
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The button's pages as chips: tap one to bring it forward (and onto the FM-1), as pressing the key again steps
    /// them. The one on the FM-1 (or focused here) is lit.
    /// The panel's pages as the FM-1 labels its buttons (Scott, 2026-11-06): plain words that light when theirs is the
    /// page, no pill. Unlit in the secondary grey; lit in the primary text with a soft glow and the heavier weight
    /// (its width held by the heavier word, so nothing shifts). 44 pt high to tap.
    private func pageChips(_ pages: [SoundPage]) -> some View {
        let current = session.screenLinked ? pages.first { SoundCard.onDevice(session, $0) }?.id : ui.focusedPage?.id
        // (the track's colour was tried: it reads more like an LED, but its orange is 3.4:1 on the panel; text is 9:1)
        let lit = Theme.text
        return ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(pages) { p in
                    let on = current == p.id
                    let title = p.title(session)
                    Button {
                        ui.focus(p)
                        if session.screenLinked, ui.followDevice { session.showOnDevice(page: p.fw) }
                    } label: {
                        Text(title).font(.system(size: 13, weight: .semibold)).tracking(0.4).lineLimit(1).hidden()
                            .overlay {
                                Text(title).font(.system(size: 13, weight: on ? .semibold : .regular)).tracking(0.4).lineLimit(1)
                                    .foregroundStyle(on ? lit : Theme.textSecondaryRaised)
                                    .shadow(color: on ? lit.opacity(0.55) : .clear, radius: 6)
                            }
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) page")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.leading, -12)          // the first word on the panel's edge; its target reaches past it
        }
        .scrollIndicators(.hidden)
    }

    private func reveal(_ f: FocusedPage?, _ proxy: ScrollViewProxy, animated: Bool) {
        guard let f, let card = SoundPage.cardID(of: f.id, session), card.hasPrefix(state.family.rawValue + ".") else { return }
        withAnimation(animated && !reduceMotion ? .easeOut(duration: 0.2) : nil) { proxy.scrollTo(card, anchor: .top) }
    }

    var body: some View {
        let _ = BodyCounter.tick("SoundPanel")
        let t = session.selectedTrack, track = session.tracks[t]
        let pages = SoundPage.shown(session, state.family)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(state.family.rawValue).font(.system(size: 20, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text("T\(t + 1) \(Entries.trackName(t, session: session)) · \(pages.count) page\(pages.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1)
                Spacer(minLength: 0)
                // SAVE > USER: the track's sound to a user slot, its name asked
                if session.dialect == .skiff { SaveSoundKey(session: session, ui: ui) }
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
            if pages.count > 1 { pageChips(pages) }
            // the track's sound, and the browser for another
            HStack(spacing: 10) {
                TrackChip(track: t, muted: track.mute)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.presetName.isEmpty ? track.displayName : track.presetName.capitalized).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(track.engineName).font(.system(size: 12)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1)
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
            ScrollViewReader { proxy in
            ScrollView {
                if pages.isEmpty {
                    Text("T\(t + 1)'s engine has no \(state.family.rawValue) pages.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textSecondaryRaised)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                } else {
                    ShapeSection(session: session, ui: ui, marks: marks, family: state.family, columns: 1, showsHeader: false)
                        .padding(.bottom, 8)
                }
            }
            .scrollIndicators(.hidden)
            // the focused page's card to the top (as far as the scroll goes for the last ones)
            .onChange(of: ui.focusedPage) { _, f in reveal(f, proxy, animated: true) }
            .onAppear { reveal(ui.focusedPage, proxy, animated: false) }
            }
        }
        .padding(16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .background { TouchFollower(session: session) { if let k = session.lastTouched { marks.mark("s\(k.scope).\(k.id)") } } }
        .onChange(of: session.deviceScreen) { _, s in SoundTab.adoptCursor(session, marks, s) }
        .environment(\.graphsDeferred, !settled)
        .task { try? await Task.sleep(for: .milliseconds(250)); settled = true }
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
                // the push lands at once (one layout), never animated: re-laying out the strips and the carousel every
                // frame of the slide dropped frames (2026-11-06); only the panel moves
                .environment(\.soundPanelRoom, makesRoom && ui.soundPanel != nil ? SoundPanel.width + 12 : 0)
                .animation(nil, value: ui.soundPanel != nil)
                .overlay {
                    if let s = ui.soundPanel, !s.pinned, !makesRoom {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { SoundPanelControl.close(ui, unlessPinned: true) }
                            .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    ZStack(alignment: .topTrailing) {
                        if let s = ui.soundPanel {
                            SoundPanel(session: session, ui: ui, state: s)
                                .id(s.family)
                                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: ui.soundPanel?.family)
                }
                // another track whose engine has none of the open button's pages: closed, never an empty panel
                .onChange(of: session.selectedTrack) { _, _ in
                    if let f = ui.soundPanel?.family, SoundPage.shown(session, f).isEmpty { ui.soundPanel = nil }
                }
            SoundRail(session: session, ui: ui)
        }
    }
}


/// SEQ on the rail (as the FM-1's): on the Song tab it steps SEQ's pages as the tab's own places, the same as an FM-1
/// SEQ press: NOTES and FEEL the step inspector, PATTERN the whole-track popover, AUTOMATION the motion lanes, SONG the
/// lanes. From Mix or Sounds it goes to the Song tab first, on NOTES. Linked, the FM-1 goes there too (and its screen
/// coming back is what lights the place); not linked, the place is lit here.
struct SeqKey: View {
    let session: DeviceSession
    let ui: EditorUI
    /// Skiff's SEQ pages (PAGES 41–45): NOTES, FEEL, PATTERN, AUTOMATION, SONG.
    static let pages = [41, 42, 43, 44, 45]
    @State private var last: Int?

    var body: some View {
        Button { press() } label: {
            Text("SEQ").font(.system(size: 12, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background { Color.clear.raisedKey(8) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel("SEQ pages")
        .accessibilityHint("Steps the Song tab through NOTES, FEEL, PATTERN, AUTOMATION and SONG")
    }

    private func press() {
        ui.soundPanel = nil
        let onSong = ui.page == .song
        let now = session.screenLinked ? session.deviceScreen.flatMap { s in s.home ? nil : Self.pages.firstIndex(of: s.page) } : last
        let k = onSong ? (now.map { ($0 + 1) % Self.pages.count } ?? 0) : 0
        last = k
        if !onSong { ui.page = .song }
        if session.screenLinked, ui.followDevice { session.showOnDevice(page: Self.pages[k]) }
        Self.focus(Self.pages[k], ui)
    }

    /// A SEQ page's place on the Song tab.
    @MainActor static func focus(_ page: Int, _ ui: EditorUI) {
        switch page {
        case 41, 42: SkiffNavigator.flash(.stepPanel, ui)
        case 43: ui.trackControlsOpen = true
        case 44: ui.motionHidden = false; SkiffNavigator.flash(.grid, ui)
        default: break                                   // SONG: the lanes, the tab's own top half
        }
    }
}

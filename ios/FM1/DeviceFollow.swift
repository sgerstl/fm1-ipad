import SloopKit
import SwiftUI

// Following the FM-1's own screen over the screen link: which page is which, where a button pressed on the FM-1
// lands in the app, and the SEQ step cursor.

/// SEQ › NOTES and FEEL on the FM-1 (pages 1 and 2 of 5): KNOB 1 moves the step cursor there, and the screen link says
/// where (SCREEN's cursor: the selection's first step, its second the last). The app's selected step follows it and the
/// grid pages to keep it in view; a selection of several steps on the FM-1 is picked here too (Scott, 2026-11-08:
/// "the app should highlight said steps and make sure that the selected one is always on screen").
@MainActor
enum SeqCursor {
    static let pages: Set<Int> = [41, 42]               // NOTES, FEEL (Skiff 2.2 params.c)
    /// The steps last picked from the FM-1's selection, so a later single-step cursor takes back only those.
    private static var mirrored: Set<Int> = []

    static func follow(_ s: UIState?, session: DeviceSession, ui: EditorUI) {
        guard session.screenLinked, session.screenCursor, let s, !s.home, pages.contains(s.page), let c = s.cursor else { return }
        let t = session.selectedTrack
        let top = max(0, session.stepCount - 1)
        let first = min(max(0, c), top), last = min(max(first, s.cursor2 ?? first), top)
        if ui.selectedStep[t] != first { ui.selectedStep[t] = first }
        if last > first {
            let range = Set(first...last)
            if ui.stepSel != range { ui.stepSel = range; ui.noteSel = [] }
            mirrored = range
        } else if !mirrored.isEmpty {
            if ui.stepSel == mirrored { ui.stepSel = [] }
            mirrored = []
        }
        // the step on screen: page the grid to its bar when it's off the bar in view
        let bar = first / 16
        if Int((ui.viewStep / 16).rounded()) != bar {
            ui.viewJump = ViewJump(bar: bar, id: (ui.viewJump?.id ?? 0) + 1)
        }
    }
}

enum SkiffNavigator {
    /// The FM-1 changed screen: go where its button lands in Lupe (linked only; on stock Skiff nothing moves).
    @MainActor static func follow(_ s: UIState, session: DeviceSession, ui: EditorUI) {
        guard ui.followDevice, session.screenLinked else { return }
        // the FM-1 left SAVE > PROJECT (the next SAVE page, DONE, any other button): the Projects sheet goes with it
        // (Scott, 2026-11-07: "as it is the modal just sits there"). Not for a menu or a held layer: PROJECT's own
        // load and save menus open over page 38.
        if ui.projectsOpen, s.menu == 0, s.layer == 0, s.home || s.page != 38 { ui.projectsOpen = false }
        guard let place = SkiffButtonMap.place(for: s) else { return }
        if case .mixer(let t) = place { if ui.mixerSection != t { ui.mixerSection = t }; go(.mixer, ui); return }
        switch place {
        case .home: go(.sequencer, ui)
        case .shape(let p):
            if s.layer == SkiffButtonMap.keysLayer { ui.soundFamily = .sel }
            else if let page = SoundPage.page(session, fw: p) { ui.soundFamily = page.family }
            ui.pageFromDevice = true
            go(.sound, ui)
        case .sequence(let f):
            go(.sequencer, ui)
            flash(f == .pattern ? .trackPanel : f == .automation ? .grid : .stepPanel, ui)
        case .arrange(let patterns):
            go(.song, ui)
            // SAVE > PATTERNS: the Song tab's Patterns drawer, open
            if patterns { if ui.songTab { ui.poolOpen = true }; flash(.patternBin, ui) }
        case .browse: browse(user: s.page == 36, session: session, ui: ui)
        case .projects:
            // the Projects sheet: SLOOP's backups, or Skiff's 4 slots on the FM-1 beside the iPad's projects
            if session.capabilities.contains(.projects) || session.dialect == .skiff { ui.projectsOpen = true }
        case .mixer: break
        }
    }

    /// SAVE's PRESETS (35) and USER (36) pages: the Sounds tab, on the factory sounds or the user slots.
    @MainActor private static func browse(user: Bool, session: DeviceSession, ui: EditorUI) {
        go(.library, ui)
        if user { ui.librarySection = .user }
        else if ui.librarySection == .user, !session.selectedIsDrums { ui.librarySection = .engine(session.tracks[session.selectedTrack].engine) }
    }

    /// The SAVE pad on Skiff: PRESETS, USER, PATTERNS, PROJECT in turn, as the FM-1's SAVE steps its pages. From the
    /// FM-1's screen when linked; otherwise from where Lupe is.
    @MainActor static func save(session: DeviceSession, ui: EditorUI) {
        let now: Int? = if session.screenLinked, let s = session.deviceScreen, !s.home, (35...38).contains(s.page) { s.page }
            else if ui.page == .song && ui.poolOpen { 37 }
            else if ui.page == .library { ui.librarySection == .user ? 36 : 35 }
            else { nil }
        let next = now.map { $0 == 38 ? 35 : $0 + 1 } ?? 35
        if session.screenLinked, ui.followDevice { session.showOnDevice(page: next) }
        if next != 37 { ui.poolOpen = false }
        if next != 38 { ui.projectsOpen = false }
        switch next {
        case 35, 36: browse(user: next == 36, session: session, ui: ui)
        case 37: go(.song, ui); ui.poolOpen = true
        default: ui.projectsOpen = true
        }
    }

    @MainActor private static func go(_ p: Page, _ ui: EditorUI) { if ui.page != p { ui.pageFromDevice = true; ui.page = p } }

    @MainActor static func flash(_ t: FlashTarget, _ ui: EditorUI) {
        // (the Song tab's whole-track knobs sit in the timeline now, TrackKnobBox, and PATTERN lights them like the rest)
        ui.flash = Flash(target: t, id: (ui.flash?.id ?? 0) + 1)
    }
}

/// Where the screen link points, per firmware: the pages Lupe's tabs open on the FM-1, and the layer that
/// is the keys' (SLOOP: SEL held, LY_SCALE; Skiff: SCL held). SLOOP's PAGES, or Skiff's (127: HOME).
struct ScreenMap {
    let home, presets, song, notes, pattern, selLayer: Int
    static let sloop = ScreenMap(home: 37, presets: 28, song: 30, notes: 34, pattern: 35, selLayer: 5)
    static let skiff = ScreenMap(home: 127, presets: 35, song: 45, notes: 41, pattern: 43, selLayer: 3)
    @MainActor static func of(_ s: DeviceSession) -> ScreenMap { s.dialect == .skiff ? .skiff : .sloop }
}

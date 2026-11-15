import SloopKit
import SwiftUI

// The app's shared UI state (EditorUI): the open tab, what's selected, the open menus and panels, and the small
// value types they use.

enum Page: String, CaseIterable, Identifiable {
    // labels name what each tab is for (2026-11-02): sequence a pattern, shape its sound, arrange the song, browse sounds
    case sequencer = "Sequence", sound = "Shape", song = "Arrange", library = "Browse"
    /// Skiff's GLO pages (its Song tab's firmware only): the strips and the shared effects.
    case mixer = "Mixer"
    var id: String { rawValue }
    /// The tabs on SLOOP (no Mixer: its GLO pages are Shape's).
    static let sloopTabs: [Page] = [.sequencer, .sound, .song, .library]
    /// The tabs on Skiff: Song · Mix · Sounds.
    static let skiffTabs: [Page] = [.song, .mixer, .library]
    /// The iPad's tabs on Skiff since 2026-11-10 (Scott): Song · Mix. The Sounds tab's browser is the sounds panel
    /// (PresetsPanel), opened from SAVE, the track controls' sound key, the sound panel and the menus. The phone keeps
    /// Sounds (skiffTabs) until its Song tab exists.
    static let skiffPadTabs: [Page] = [.song, .mixer]
    /// SLOOP on the iPad, in the same tabs (2026-11-10, proposed): Song · Mix.
    static let sloopPadTabs: [Page] = [.song, .mixer]
    /// Whether this is the iPad, where Skiff has no Sounds tab.
    @MainActor static var padHasNoSoundsTab: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    /// The phone's tabs on Skiff: Song split into Pads and Edit (the pattern and its step panel), then Mix and Sounds
    /// (design/structure-map.md › "The phone with a Skiff FM-1", Scott 2026-11-10).
    static let phoneSkiffTabs: [Page] = [.song, .sequencer, .mixer, .library]
    /// A tab's name: Skiff's are Song · Mix · Sounds (2026-11-06).
    func title(skiff: Bool, phone: Bool = false) -> String {
        guard skiff else { return rawValue }
        switch self {
        case .song: return phone ? "Pads" : "Song"
        case .sequencer where phone: return "Edit"
        case .mixer: return "Mix"
        case .library: return "Sounds"
        default: return rawValue
        }
    }
}

struct ViewJump: Equatable {
    var bar: Int
    var id: Int
}

/// What the iPad alone decides: which step is selected (per track), which drum lane, which page.
@MainActor @Observable
final class EditorUI {
    /// -page sound|song|library|sequencer opens on that page (screenshots and layout checks, 2026-11-04)
    var page: Page = {
        let a = LaunchArgs.all
        guard let i = a.firstIndex(of: "-page"), i + 1 < a.count else { return .sequencer }
        return ["sound": .sound, "song": .song, "library": .library, "mixer": .mixer, "edit": .sequencer][a[i + 1]] ?? .sequencer
    }() {
        // Skiff: Sequence and Arrange are one Song tab; whatever asks for Sequence (HOME, SEQ, a tab) lands there.
        // And there's no Shape tab (Scott, 2026-11-06): whatever asks for Shape brings the button's pages in on the
        // sound panel, over the tab that was up
        didSet {
            // (the phone keeps Sequence: it's the phone's Edit tab)
            if shell, page == .sequencer, !phone { page = .song }
            // the iPad has no Sounds tab on Skiff: whatever asks for it (the FM-1's SAVE, a launch flag) gets the sounds
            // panel over the tab that was up
            // the phone: Sounds is a sheet, never a tab (decision 33); Mix is a tab again (batch item 10, 2026-11-15)
            if shell, page == .library, Page.padHasNoSoundsTab || phone {
                page = oldValue == .library ? .song : oldValue
                presetsPanel = true
            }
            if shell, page == .sound {
                page = oldValue == .sound ? .song : oldValue
                if SoundPanelControl.families.contains(soundFamily) { soundPanel = SoundPanelState(family: soundFamily) }
            }
        }
    }
    /// Skiff: the Song tab (Arrange's lanes over the pattern editor) stands for Sequence and Arrange.
    var songTab = false {
        didSet { if songTab { enterShell() } }
    }
    /// SLOOP on the iPad in the Skiff tabs (the SLOOP design pass, 2026-11-10, boards S1–S5): Song · Mix, the sound panel
    /// for Shape, the sounds panel for Browse, the Song tab holding SLOOP's sections, its order and the editor.
    var sloopShell = false {
        didSet { if sloopShell { enterShell() } }
    }
    /// The Song · Mix layout, whichever firmware: Skiff's Song tab, or SLOOP's in the same tabs. (`songTab` stays Skiff's
    /// own: its song store, the pool, its playback mode.)
    var shell: Bool { songTab || sloopShell }
    private func enterShell() {
        // (turning on, the phone too opens on Pads, unless -page edit asked for Edit)
        if (page == .sequencer && !(phone && LaunchArgs.all.contains("edit"))) || page == .sound
            || (page == .library && Page.padHasNoSoundsTab) { page = .song }
    }
    /// The phone layout (FM1App): on Skiff its Song is two tabs, Pads (`.song`) and Edit (`.sequencer`).
    var phone = false {
        didSet { if !phone, songTab, page == .sequencer { page = .song } }
    }
    /// The Song tab as pads (PadsPage.swift) or a timeline. Pads first (Scott, 2026-11-09: the pads are how a song is
    /// built; the timeline is where it's cut). -song-timeline opens on the timeline (screenshots).
    var songView: SongView = LaunchArgs.all.contains("-song-timeline") ? .timeline : .pads
    /// The Song tab: the entry the editor is pinned to (a block tapped); nil follows what each track plays.
    var pinnedEntry: EntryRef?
    /// Each pattern's drawing for the pads (PadThumb), as seen while a track was on it: kept for the session.
    var padThumbs: [Int: PadThumb] = [:]
    /// The Song tab's Timeline: bars across the lanes, set by the top bar's zoom (nil: fitted to the song).
    var timelineZoom: Int?
    /// The Pads: a stored scene held, its preview on the pads (and, when Lupe hasn't seen it, a line under the top bar).
    var previewScene: Int?
    /// The Song tab: the pattern pool's drawer is open.
    var poolOpen = LaunchArgs.all.contains("-pool-open")      // (-pool-open: the Patterns drawer up, for captures)
    /// A pattern being dragged from the pool (set as the drag starts), shared by the drawer and the lanes.
    var dragPattern: Int?
    /// Step editing: the notes picked (a tap, or a lasso) and the steps picked (along the step numbers), on this
    /// track; what was copied; the last change that can be undone, and what it said.
    var noteSel: Set<NoteRef> = []
    var stepSel: Set<Int> = []
    var clip: [SynthStep]?
    var patternUndo: PatternUndo?
    var selectedStep = Array(repeating: 0, count: 8)      // per track: room for every firmware's tracks
    /// The tempo panel, open under this point (global), from the top bar's BPM.
    var tempoAt: CGPoint?
    /// A Lupe menu open over the app (the connection menu, the phone's ⋯, the sound slots).
    var menu: AppMenu?
    /// A sound waiting on its name before it goes to a user slot (Skiff's SAVE > USER).
    var saveSound: SaveSoundRequest?
    /// A name asked for in place (TextPromptLayer at the root).
    var textPrompt: TextPrompt?
    var selectedLane = 0
    var keptRows: [Int: Set<Int>] = [:]
    var knobGrab: KnobGrab?
    /// The value being slid, magnified above the finger (ValueLoupe.swift); only the loupe reads it.
    let loupe = LoupeState()
    /// A knob's big control, open under this point (global; .zero: VoiceOver's "Open", centred).
    var knobPanelAt: CGPoint?
    @ObservationIgnored var knobPanelSpec: (() -> KnobSpec)?
    /// -family EDIT (a button's name) opens Shape on that button (screenshots)
    var soundFamily: SoundFamily = {
        let a = LaunchArgs.all
        guard let i = a.firstIndex(of: "-family"), i + 1 < a.count else { return .fx }
        return SoundFamily(rawValue: a[i + 1]) ?? .fx
    }()
    var keyboardOpen = false
    /// The tabs follow the FM-1's screen (and tapping a tab moves it), when the screen link is there. Always, since
    /// Scott took the switch out of the menu (2026-11-06); kept as a property so what reads it stays as it was.
    var followDevice: Bool { true }
    /// Which firmware the demo FM-1 pretends to run: Skiff, or SLOOP (the menu's "Skiff demo" / "SLOOP demo",
    /// 2026-11-06). Starts from the launch flag (-demo-skiff) so screenshots and tests open where they did.
    var demoSkiff = DeviceSession.launchedSkiffDemo
    /// The track box's timeline, pulled open with its handle on the other tabs; shut again on a page change.
    /// On Sequence it is always open.
    var timelineOpen = false
    /// The grid's first step in view (fractional while panning): the view box on the timeline follows it.
    var viewStep: CGFloat = 0
    /// A bar picked on the timeline: the grid scrolls there.
    var viewJump: ViewJump?
    var trackMenu: TrackMenu?                    // a long-pressed track's menu, where the finger was
    var trackPicker: CGPoint?                    // the phone's one chip tapped (more than four tracks): the tracks, there
    var sectionMenu: SectionMenu?                // a held stored section's menu, where the finger was
    var lastClear: DeviceSession.ClearedTrack?   // offered for undo for a few seconds
    var librarySection: LibrarySection = LaunchArgs.all.contains("-library-user") ? .user
        : LaunchArgs.all.contains("-library-samples") ? .samples : .engine(0)
    /// The Presets panel is up on the Sequencer, in place of the step panel and knobs. Closed, it chooses for the track
    /// again next time.
    /// -presets-panel opens it at launch (the before/after screenshots, qa/top-row-2026-11-10).
    var presetsPanel = LaunchArgs.all.contains("-presets-panel") { didSet { if !presetsPanel { soundEntry = nil } } }
    /// The sound panel choosing an entry's own sound (a pad's, a Timeline block's) instead of the track's (Scott,
    /// 2026-11-08: "Select sound" opens the panel; its header says what it's choosing for). Nil: the track.
    var soundEntry: SoundEntryTarget?
    /// The panel for a track (entry nil) or an entry's own sound, the track selected.
    func chooseSound(_ session: DeviceSession, track: Int, entry: SoundEntryTarget? = nil) {
        session.select(track: track)
        timelineOpen = false                     // the open timeline would run under the panel
        soundEntry = entry
        presetsPanel = true
    }
    /// The sampler is open: flipped in place of the grid (from a track's menu) or up from the bottom (Browse).
    /// (-sampler-file PATH: the sampler open from the sound panel with that file imported, for captures and tests of
    /// Import file… past the Files picker the simulator can't drive)
    var sampler: SamplerRequest? = LaunchArgs.all.contains("-sampler-file") ? SamplerRequest(track: 0, slot: 0, fromBrowse: true) : nil
    /// The last page change came from the FM-1 (its button pressed), not from a tab or pad here.
    var pageFromDevice = false
    /// Skiff's GLO pages: the Mixer tab's section (the strips, Delay, Reverb, Chorus, Global), as GLO steps them.
    var mixerSection: SkiffButtonMap.MixerTab = .mixer
    /// The Song tab's whole-track controls (SWING LEVEL STEPS PAN): open under the selected lane's control.
    var trackControlsOpen = false
    /// Motion lanes added with + Lane, per track (parameters with no records yet).
    var addedLanes: [Int: [Int]] = [:]
    /// The motion lanes hidden from the pattern header's chip (they show whenever there's motion otherwise).
    var motionHidden = false
    /// The motion lane opened into its editor (one at a time): its track and parameter. -motion-lane 36 opens that
    /// lane on the selected track (screenshots).
    var openLane: OpenLane? = {
        let a = LaunchArgs.all
        guard let i = a.firstIndex(of: "-motion-lane"), i + 1 < a.count, let id = Int(a[i + 1]) else { return nil }
        return OpenLane(track: 0, id: id)
    }()
    struct OpenLane: Equatable { var track: Int, id: Int }
    /// What a touch on the open lane writes: false a recorded change that holds, true a lock on that step only.
    var motionWritesLocks = false
    /// The page last brought forward (FocusedPage).
    var focusedPage: FocusedPage?
    func focus(_ p: SoundPage) { focusedPage = FocusedPage(id: p.id, n: (focusedPage?.n ?? 0) + 1) }
    /// The Song tab's sound panel (a button's Shape cards from the right); nil: closed. -sound-panel LFO opens it.
    var soundPanel: SoundPanelState? = {
        let a = LaunchArgs.all
        guard let i = a.firstIndex(of: "-sound-panel"), i + 1 < a.count, let f = SoundFamily(rawValue: a[i + 1]) else { return nil }
        return SoundPanelState(family: f)
    }()
    var projectsOpen = false
    /// The pad last cleared (batch item 13: no confirm, an Undo strip instead), offered for undo until the next change:
    /// valid while the song store's undo stack is as deep as it was right after the clear.
    var padClear: PadClear?
    /// The pad being dragged (Pads), for the edge wells (EdgeWells): its centre and track; nil when none is.
    var padDrag: PadDragShow?
    /// The lifted pad's face and size, drawn by the wells' layer over everything (not observed: padDrag drives redraws).
    @ObservationIgnored var padDragFace: AnyView?
    var padDragSize: CGSize = .zero
    /// The phone's Mix pop-up (GLO's pages, board 77), and its Settings sheet (from the song-name menu).
    var mixPopup = LaunchArgs.all.contains("-mix-popup")      // (-mix-popup: open on it, for captures)
    var phoneSettingsOpen = LaunchArgs.all.contains("-settings")
    /// The phone's Patterns sheet (board 79): to manage the pool, or to pick a kept pattern for a pad. (-patterns opens it)
    var patternsSheet: PatternsSheetMode? = LaunchArgs.all.contains("-patterns") ? .manage : nil
    /// When a swipe up from the foot of the Song tab last moved the divider: the pad or scene key the swipe began on
    /// drops the tap its lift makes (Scott, 2026-11-07: the zone is the scene row's own keys).
    var pulledAt = Date.distantPast
    /// Bumped to ask the Song tab to open its editor when it's shut (Edit pattern on a pad).
    var openEditor = 0
    var justPulled: Bool { Date().timeIntervalSince(pulledAt) < 0.4 }
    /// A place the FM-1 sent Lupe to, lit for a moment (the whole-track controls for PATTERN, and so on).
    var flash: Flash?
}

enum FlashTarget: Equatable { case stepPanel, trackPanel, grid, patternBin }

/// The page a button's press (here or on the FM-1) last brought forward: its card scrolls to the top of the panel or
/// the Shape tab and is lit. `n` makes a press of the same page again count.
struct FocusedPage: Equatable {
    var id: String
    var n: Int
}

struct Flash: Equatable {
    var target: FlashTarget
    var id: Int
}

/// A pattern change that can be undone: the steps and LENGTH before it, and what it said ("steps 9–16 added, length
/// 8 → 16").
struct PatternUndo: Equatable {
    var track: Int
    var steps: [SynthStep]
    var length: Int
    var said: String
}

/// An entry whose own sound the panel is choosing: from a pad (Pads) or a block (the Timeline), which the header names.
struct SoundEntryTarget: Equatable {
    var ref: EntryRef
    var pad: Bool
}

/// A pad cleared, for its Undo strip and its menu's Undo clear.
struct PadClear: Equatable {
    var track: Int
    var entry: Int
    var what: String           // "pattern 02", "REST"
    var depth: Int             // the store's undo stack right after the clear
    var stripGone = false      // the strip has left (8 s); Undo clear stays in the pad's menu until the next change
    var id = UUID()
}

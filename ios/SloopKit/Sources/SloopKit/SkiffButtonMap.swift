import Foundation

/// Where each FM-1 button and page lands in Jib, and back (vault skiff-arrange-spec.md, "Lupe and the FM-1's
/// buttons", decided 2026-11-05). Skiff 2.2's PAGES indices (firmware params.c), as the screen link reports and opens
/// them. Pure, so the app, the fake and the patched skiff-sim are tested against one table.
public enum SkiffButtonMap {
    /// GLO's pages, the mixer panel's tabs, in the FM-1's order: MIXER is page 30, then DELAY REVERB CHORUS GLOBAL.
    public enum MixerTab: Int, CaseIterable, Sendable, Identifiable {
        case mixer, delay, reverb, chorus, global
        public var id: Int { rawValue }
        public var page: Int { 30 + rawValue }
        public var title: String { ["Mixer", "Delay", "Reverb", "Chorus", "Global"][rawValue] }
        /// Skiff's page title (PAGES), for the pages Jib lays out (SkiffPages).
        public var pageTitle: String { ["MIXER", "DELAY", "REVERB", "CHORUS", "GLOBAL"][rawValue] }
    }

    public enum SequenceFocus: Equatable, Sendable { case notes, feel, pattern, automation }

    public enum Place: Equatable, Sendable {
        /// HOME: Sequence, nothing focused.
        case home
        /// ENV LFO FX SCL EDIT ARP: Shape, the section of that page's button, the page (or its row) focused.
        case shape(page: Int)
        /// GLO: the mixer panel on that tab.
        case mixer(MixerTab)
        /// SEQ's NOTES, FEEL (the step inspector), PATTERN (the whole-track controls), AUTOMATION (motion).
        case sequence(SequenceFocus)
        /// SEQ's SONG: Arrange. SAVE's PATTERNS: Arrange's pattern bin.
        case arrange(patterns: Bool)
        /// SAVE's PRESETS and USER: Browse.
        case browse
        /// SAVE's PROJECT: the Projects sheet.
        case projects
    }

    public static let home = 127
    /// The Shape pages: ENV … VOICE 2 (0–29) and ARP, ARP 2 (39, 40).
    public static func isShape(_ page: Int) -> Bool { (0...29).contains(page) || page == 39 || page == 40 }
    /// SCL held: the keys' layer (Skiff LY_SCALE).
    public static let keysLayer = 3
    /// ARP held: PERFORM, the list's entries or the scenes on the keys (Skiff LAYER_PERF); Lupe shows its Pads.
    public static let performLayer = 7

    /// Where the FM-1's screen lands in Jib; nil for a screen with no place (a MENU, another layer held).
    public static func place(for s: UIState) -> Place? {
        if s.menu != 0 { return nil }
        if s.layer == keysLayer { return .shape(page: 11) }           // SCL held: SCALE, the keys' map
        if s.layer != 0 { return nil }
        if s.home { return .home }
        switch s.page {
        case let p where isShape(p): return .shape(page: p)
        case 30...34: return .mixer(MixerTab(rawValue: s.page - 30)!)
        case 35, 36: return .browse
        case 37: return .arrange(patterns: true)
        case 38: return .projects
        case 41: return .sequence(.notes)
        case 42: return .sequence(.feel)
        case 43: return .sequence(.pattern)
        case 44: return .sequence(.automation)
        case 45: return .arrange(patterns: false)
        default: return nil
        }
    }

    /// The page Jib's navigation sends the FM-1 to (SCREEN_GOTO); 127 is HOME.
    public static func page(for place: Place) -> Int {
        switch place {
        case .home: return home
        case .shape(let p): return p
        case .mixer(let t): return t.page
        case .sequence(.notes): return 41
        case .sequence(.feel): return 42
        case .sequence(.pattern): return 43
        case .sequence(.automation): return 44
        case .arrange(let patterns): return patterns ? 37 : 45
        case .browse: return 35
        case .projects: return 38
        }
    }
}

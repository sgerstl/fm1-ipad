// The phone's FM-1 button block (decision 24, board 72): which of the FM-1's keys has its screen up, so the phone lights
// that key, and the screenGoto intent for the keys that have no sound pages (GLO, SAVE, SEQ). Where a screen lands is
// SloopKit's SkiffButtonMap.place, the iPad's own table (Skiff 2.2's PAGES numbers, which the driver translates for
// 2.5.1), plus 2.5.1's FX › DELAY and REVERB. Mirrored by android/app/.../core/ScreenState.kt.
import Foundation
import SloopKit

public struct Fm1ScreenArea: Codable, Equatable, Sendable {
    /// The FM-1 key whose screen is up: "HOME", "FX", "SEL", "ENV", "LFO", "EDIT", "ARP", "GLO", "SAVE", "SEQ"; "" when
    /// a MENU or a held layer covers the screen (or a screen Lupe has no place for).
    public var key: String
    /// The page (Lupe's number, as pickPage and screenGoto take it), -1 on HOME or none.
    public var page: Int
    /// The FM-1's title for it: "MIXER", "PRESETS", "USER", "PATTERNS", "PROJECT", "NOTES", "SONG", "CUTOFF"'s "EDIT 2"…
    public var title: String
    /// The FM-1's MENU is open (its settings over the screen).
    public var menu: Bool
    /// A layer held on the FM-1 (0 none; 3 SCL's keys, which shows as SEL › SCALE; 7 ARP's PERFORM).
    public var layer: Int
    /// SEQ › NOTES and FEEL only: the FM-1's step cursor (the selection's first step, 0-based) and, for a selection of several, its last;
    /// the PRESETS encoder moves it (Skiff 2.5.1 ui_input.c cursor_turn). The phone's picked step follows it (the iPad's SeqCursor).
    public var cursor: Int? = nil
    public var cursor2: Int? = nil
}

extension PhoneCore {
    /// Each key's pages after the first press's: GLO MIXER…GLOBAL, SAVE PRESETS…PROJECT, SEQ NOTES…SONG (Lupe's numbers).
    static let screenPages: [String: [(page: Int, title: String)]] = [
        "GLO": [(30, "MIXER"), (31, "DELAY"), (32, "REVERB"), (33, "CHORUS"), (34, "GLOBAL")],
        "SAVE": [(35, "PRESETS"), (36, "USER"), (37, "PATTERNS"), (38, "PROJECT")],
        "SEQ": [(41, "NOTES"), (42, "FEEL"), (43, "PATTERN"), (44, "AUTOMATION"), (45, "SONG")],
    ]

    /// nil until the screen link has reported (Skiff with the link only).
    public func fm1ScreenArea() -> Fm1ScreenArea? {
        let s = session
        guard s.isConnected, s.dialect == .skiff, s.screenLinked, let sc = s.deviceScreen else { return nil }
        let menu = sc.menu != 0, layer = sc.layer
        func area(_ key: String, _ page: Int, _ title: String) -> Fm1ScreenArea {
            var a = Fm1ScreenArea(key: key, page: page, title: title, menu: menu, layer: layer)
            // the step cursor, on the two pages whose knobs edit the selection (NOTES 41, FEEL 42)
            if key == "SEQ", page == 41 || page == 42, !menu, layer == 0 { a.cursor = sc.cursor; a.cursor2 = sc.cursor2 }
            return a
        }
        // a sound page (2.5.1's FX › DELAY and REVERB too, and SCL held: SCALE): its family's key
        if let fw = Self.soundPage(of: sc), let p = SoundPage.page(s, fw: fw) { return area(p.family.rawValue, fw, p.title) }
        switch SkiffButtonMap.place(for: sc) {
        case .home?: return area("HOME", -1, "")
        case .mixer?, .browse?, .projects?, .sequence?, .arrange?:
            for (key, pages) in Self.screenPages { if let p = pages.first(where: { $0.page == sc.page }) { return area(key, p.page, p.title) } }
            return area("", sc.page, "")
        default: return area("", menu || layer != 0 ? -1 : sc.page, "")
        }
    }

    private struct ScreenWire: Decodable { let intent: String; let screen: String?; let page: Int?; let cursor: Int? }

    /// `{"intent":"screenGoto","screen":"GLO"|"SAVE"|"SEQ"[,"page":n]}`: the FM-1 to that key's screen, its first page
    /// (GLO MIXER, SAVE PRESETS, SEQ NOTES, as the key itself lands) or `page`, one of that key's; `cursor` (SEQ › NOTES and FEEL)
    /// puts the FM-1's step cursor on that step, so its knobs edit it (the phone's Edit step panel, 2026-11-17). A write
    /// (SCREEN_GOTO): refused while read-only. True when `json` was it.
    func handleScreenJSON(_ json: String) -> Bool {
        guard let w = try? JSONDecoder().decode(ScreenWire.self, from: Data(json.utf8)), w.intent == "screenGoto" else { return false }
        guard canWrite() else { refuseReadOnly("screenGoto"); return true }
        guard session.isConnected, session.dialect == .skiff else { refuse("No FM-1 is connected."); return true }
        guard let key = w.screen, let pages = Self.screenPages[key] else { log("screenGoto: no screen \(w.screen ?? "") (GLO, SAVE or SEQ)"); return true }
        let target = w.page.flatMap { p in pages.first { $0.page == p }?.page } ?? pages[0].page
        if let p = w.page, p != target { log("screenGoto: page \(p) isn't one of \(key)'s, its first instead") }
        lag.start("screenGoto \(key) \(target)")
        session.showOnDevice(page: target, cursor: key == "SEQ" && (target == 41 || target == 42) ? w.cursor.map { max(0, $0) } : nil)
        publishNow(["shell", "page", "fm1Screen"])
        return true
    }
}

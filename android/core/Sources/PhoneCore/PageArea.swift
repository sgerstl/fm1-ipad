// The `page` area (P4's schema, android/app/.../core/PageState.kt): the sound page the FM-1 is on, built from the
// screen link (DeviceSession.deviceScreen) → SkiffButtonMap.place → SloopKit's SoundPage → PageSpec, the way the
// iPad's Sound tab reads the same state. Kept in a file of its own (P1 wires the Pads and editor intents into
// PhoneCore.swift and State.swift at the same time).
//
// Page numbers are Lupe's (Skiff 2.2's; FX › DELAY 46, REVERB 47): SkiffDriver translates them to the firmware's own
// at the wire, in both directions, so `deviceScreen.page` and `showOnDevice(page:)` already speak them.
import Foundation
import SloopKit

// MARK: area (mirrors PageState.kt field for field)

public struct PageArea: Codable, Equatable, Sendable {
    public struct Ref: Codable, Equatable, Sendable { public var index: Int; public var title: String }

    public struct Control: Codable, Equatable, Sendable {
        public var label: String
        /// As the FM-1 shows it ("72", "-3", "710 Hz", "SAW").
        public var value: String
        public var raw: Int
        public var min: Int
        public var max: Int
        public var list: Bool
        public var ringless: Bool
        public var fixed: Bool
        public var locked: Bool
        /// A list's names, indexed by `raw` (the DESC's names; absent for a number). The phone's fake steps through them.
        public var names: [String]?
    }

    public struct Route: Codable, Equatable, Sendable { public var group: String; public var label: String; public var amount: Int; public var empty: Bool }

    /// Where a knob picks from a list of names instead of setting a value (decision 25: tiles above the dials). "routes":
    /// MOD's eleven (knob 1, pickRoute); "pick": LANES' and LANE MIX's lanes, SOUND's eight sounds, OPERATOR's six
    /// operators (pickTile moves the FM-1's cursor).
    public struct Tiles: Codable, Equatable, Sendable {
        public var kind: String
        public var labels: [String]
        public var routes: [Route]
        public var picked: Int
    }

    /// A sheet's window (OPERATOR, ALL OPS, SOUND): the row of the table the four knobs turn, which SELECT on the
    /// FM-1 moves (the screen link's second cursor; the phone can't move it).
    public struct Window: Codable, Equatable, Sendable {
        public var index: Int
        public var count: Int
        public var title: String
    }

    public struct Lock: Codable, Equatable, Sendable { public var text: String; public var note: String?; public var locking: Bool }

    public var family: String
    public var pages: [Ref]
    public var page: Int
    public var track: Int
    public var trackName: String
    /// The header: the page's title, or a sheet's as the FM-1 writes it ("OPERATOR 3", "SOUND SD").
    public var title: String
    /// Always four; nil (JSON null) is an empty well, the FM-1's 0xFF knob. On a sheet: the window's four.
    public var controls: [Control?]
    public var tiles: Tiles?
    public var window: Window?
    /// What the page's picture is drawn from (PagePictures.swift; decision 30: the pictures are a setting).
    public var graph: Graph = Graph()
    public var turned: Int
    public var turnSeq: Int
    public var lock: Lock?
}

/// `shell`'s part Swift owns: what the bottom half shows. Only `bottom` is sent; tab and divider stay the screens' own
/// (BridgedLupeCore merges it in). The bottom half always follows the FM-1 (decision 3): a sound page while the FM-1
/// shows one, the editor for everything else (HOME, SEQ, GLO, SAVE, a layer, a menu).
public struct ShellArea: Codable, Equatable, Sendable {
    public struct Bottom: Codable, Equatable, Sendable {
        /// "editor" or "page"
        public var kind: String
        public var family: String?
        /// The page's title (what the page row underlines), only for "page".
        public var page: String?
    }
    public var bottom: Bottom
}

// MARK: building it

let pageLaneShort = ["BD", "SD", "CP", "CH", "OH", "TM", "RS", "CB"]
let pageLaneNames = ["KICK", "SNARE", "CLAP", "CL HAT", "OP HAT", "TOM", "RIM", "BELL"]
let pageModFixed: [(group: String, label: String)] =
    [("LFO", "PITCH"), ("LFO", "CUTOFF"), ("LFO", "SHAPE"), ("LFO", "AMP"), ("ENV", "PITCH"), ("ENV", "CUTOFF"), ("ENV", "SHAPE")]

extension PhoneCore {
    /// The Lupe page number of the sound page the screen shows, if any. SkiffButtonMap.place knows the pages 0…29, ARP
    /// and ARP 2, and SCL held; Skiff 2.5.1's FX › DELAY and FX › REVERB (46, 47) are sound pages too, which it doesn't
    /// list (it never counted them: ios/SloopKit/SkiffButtonMap.isShape), so they are added here.
    @MainActor static func soundPage(of screen: UIState) -> Int? {
        if screen.menu == 0, screen.layer == 0, !screen.home, [SkiffPageMap.fxDelay, SkiffPageMap.fxReverb].contains(screen.page) { return screen.page }
        if case .shape(let fw)? = SkiffButtonMap.place(for: screen) { return fw }
        return nil
    }

    /// nil until the FM-1 is read and its screen reports (before that the shell keeps its own default, the editor).
    public func shellArea() -> ShellArea? {
        let s = session
        guard s.isConnected, s.dialect == .skiff, s.screenLinked, let screen = s.deviceScreen else { return nil }
        // the FM-1's FREE TAKE picker open: it takes the editor's place (the bottom half follows the FM-1)
        if s.takePicker?.open == true { return ShellArea(bottom: .init(kind: "freetake", family: nil, page: nil)) }
        if let fw = Self.soundPage(of: screen), let page = SoundPage.page(s, fw: fw) {
            return ShellArea(bottom: .init(kind: "page", family: page.family.rawValue, page: page.title))
        }
        return ShellArea(bottom: .init(kind: "editor", family: nil, page: nil))
    }

    /// Asks for what the dense pages draw (FM6_GET, KIT_GET: reads) whenever the FM-1's screen moves onto or within one.
    /// Run as an area watch's builder so Observation re-runs it on a screen or track change; it publishes nothing.
    func readDenseData() -> String? {
        let s = session
        guard s.isConnected, s.dialect == .skiff, s.screenLinked, let screen = s.deviceScreen, let fw = Self.soundPage(of: screen),
              let page = SoundPage.page(s, fw: fw), let store = s.skiffEdit else { return nil }
        let t = s.selectedTrack
        switch page.title {
        case "OPERATOR", "ALL OPS": Task { await store.readPatch(track: t) }
        case "SOUND": Task { await store.readKit(lane: min(max(screen.cursor ?? 0, 0), 7)) }
        default: break
        }
        return nil
    }

    /// The sound page the FM-1 shows, or nil when it shows none (HOME, the sequencer, GLO, a layer), when the firmware
    /// isn't Skiff, or before the screen link has reported.
    public func pageArea() -> PageArea? {
        let s = session
        guard s.isConnected, s.dialect == .skiff, s.screenLinked, let screen = s.deviceScreen,
              let fw = Self.soundPage(of: screen),
              let page = SoundPage.page(s, fw: fw) else { return nil }
        let t = s.selectedTrack
        var row = SoundPage.counted(SoundPage.reached(s, page.family), s).map { PageArea.Ref(index: $0.fw, title: $0.title) }
        if !row.contains(where: { $0.index == page.fw }) { row.append(PageArea.Ref(index: page.fw, title: page.title)) }
        let ctx = PageContext(session: s, page: page, cursor: screen.cursor)
        var area = PageArea(family: page.family.rawValue, pages: row, page: page.fw, track: t + 1, trackName: s.tracks[t].displayName,
                            title: ctx.isSheet ? ctx.sheetTitle : page.title, controls: ctx.controls(), tiles: ctx.tiles(),
                            window: ctx.isSheet ? PageArea.Window(index: ctx.window, count: ctx.windowCount, title: ctx.windowTitle) : nil,
                            graph: ctx.graph(), turned: -1, turnSeq: 0, lock: nil)
        // the knob the FM-1 last turned, if it is one of this page's (Session.lastTouched, filtered for a sound loading)
        if let touched = s.lastTouched {
            for k in 0..<4 {
                if let id = page.ids[safe: k] ?? nil, page.scope(of: k) == touched.scope, id == touched.id { area.turned = k; break }
            }
            area.turnSeq = Int(touched.at.timeIntervalSinceReferenceDate * 1000) % 1_000_000_000
        }
        if let step = s.lockStep {
            area.lock = PageArea.Lock(text: "Locking to step \(step + 1)", note: "held on the FM-1", locking: true)
        }
        return area
    }
}

/// What one page's controls and graph are drawn from. Built fresh each time; reads only Session's observed state.
@MainActor struct PageContext {
    let session: DeviceSession
    let page: SoundPage
    /// The screen link's cursor on this page (MOD's route, the lane); nil where it carries none.
    let cursor: Int?
    var track: Int { session.selectedTrack }

    var isMod: Bool { page.title == "MOD" && page.routes.count == 11 }
    var isLanes: Bool { ["LANES", "LANE MIX"].contains(page.title) && !page.picks.isEmpty }
    var route: Int { min(max(cursor ?? 0, 0), 10) }
    var lane: Int { min(max(cursor ?? 0, 0), 7) }

    func control(scope: Int, id: Int, label: String? = nil, fixed: Bool = false) -> PageArea.Control {
        PageArea.control(session, track: track, scope: scope, id: id, label: label, fixed: fixed)
    }

    /// The control on knob k of the page's own ids. A parameter the FM-1 labels "-" (an engine's unused knob: SAMPLE's
    /// EDIT 2) is a blank column there (ui_draw.c), so it is none here.
    func knob(_ k: Int) -> PageArea.Control? {
        guard let id = page.ids[safe: k] ?? nil else { return nil }
        let c = control(scope: page.scope(of: k), id: id, label: page.knobLabels[safe: k] ?? nil)
        return c.label.isEmpty || c.label.hasPrefix("-") ? nil : c
    }

    func controls() -> [PageArea.Control?] {
        if isSheet { return sheetControls() }
        if page.title == "SLICES" { return [nil, nil, nil, nil] }     // its markers: no command reaches them
        if isMod {
            let r = route
            let ids = page.routes[r]
            var out: [PageArea.Control?] = [PageArea.Control(label: "ROUTE", value: routeName(r), raw: r, min: 0, max: 10, list: false,
                                                             ringless: true, fixed: false, locked: false, names: nil)]
            if r < 7 {
                let f = pageModFixed[r]
                out.append(fixedControl("SRC", f.group)); out.append(fixedControl("DEST", f.label))
                out.append(ids.first.flatMap { $0 }.map { control(scope: 0, id: $0, label: "AMT") })
            } else {
                for (i, l) in ["SRC", "DEST", "AMT"].enumerated() {
                    out.append((ids[safe: i] ?? nil).map { control(scope: 0, id: $0, label: l) })
                }
            }
            return out
        }
        if isLanes {
            let l = lane
            var out: [PageArea.Control?] = [PageArea.Control(label: "LANE", value: pageLaneNames[l], raw: l, min: 0, max: 7, list: true,
                                                             ringless: true, fixed: false, locked: false, names: nil)]
            let labels: [String?] = page.title == "LANES" ? ["LEVEL", "TUNE", "DECAY"] : ["LEVEL", "PAN", nil]
            let ids = page.picks[safe: l] ?? []
            for k in 0..<3 {
                if let id = ids[safe: k] ?? nil, let label = labels[k] { out.append(control(scope: 0, id: id, label: label)) } else { out.append(nil) }
            }
            return out
        }
        return (0..<4).map { knob($0) }
    }

    func fixedControl(_ label: String, _ value: String) -> PageArea.Control {
        PageArea.Control(label: label, value: value, raw: 0, min: 0, max: 0, list: false, ringless: false, fixed: true, locked: false, names: nil)
    }

    func routeName(_ r: Int) -> String {
        if r < 7 { let f = pageModFixed[r]; return "\(f.group)→\(f.label.prefix(3))" }
        return "SLOT \(r - 6)"
    }

    // MARK: graphs

    /// The raw value of a page's knob k, on any page of this track found by title.
    func raw(_ title: String, _ k: Int) -> Int? {
        guard let p = SoundPage.pages(session).first(where: { $0.title == title }),
              let id = p.ids[safe: k] ?? nil else { return nil }
        return p.scope(of: k) == 0 ? session.cell(id).value : session.globalCell(id).value
    }
    func shown(_ title: String, _ k: Int) -> String? {
        guard let p = SoundPage.pages(session).first(where: { $0.title == title }), let id = p.ids[safe: k] ?? nil else { return nil }
        return control(scope: p.scope(of: k), id: id).value
    }

    /// The tiles above the dials, where a knob picks from names (nil elsewhere).
    func tiles() -> PageArea.Tiles? {
        switch page.title {
        case "MOD":
            guard isMod else { return nil }
            let routes = (0..<11).map { r -> PageArea.Route in
                let ids = page.routes[r]
                if r < 7 {
                    let f = pageModFixed[r]
                    return PageArea.Route(group: f.group, label: f.label, amount: (ids.first.flatMap { $0 }).map { session.cell($0).value } ?? 0, empty: false)
                }
                // a matrix slot: its SOURCE's name, AMOUNT as the bar; no source set is an empty slot
                let src = ids[safe: 0] ?? nil, amt = ids[safe: 2] ?? nil
                let empty = (src.map { session.cell($0).value } ?? 0) == 0
                let label = empty ? "\(r - 6) —" : "\(r - 6) \(src.map { control(scope: 0, id: $0).value } ?? "")"
                return PageArea.Route(group: "SLOTS", label: label, amount: amt.map { session.cell($0).value } ?? 0, empty: empty)
            }
            return PageArea.Tiles(kind: "routes", labels: [], routes: routes, picked: route)
        case "LANES", "LANE MIX":
            guard isLanes else { return nil }
            return PageArea.Tiles(kind: "pick", labels: pageLaneNames, routes: [], picked: lane)
        case "SOUND": return PageArea.Tiles(kind: "pick", labels: Sheets.soundNames, routes: [], picked: lane)
        case "OPERATOR": return PageArea.Tiles(kind: "pick", labels: (1...6).map { "OP\($0)" }, routes: [], picked: operatorPicked - 1)
        default: return nil
        }
    }

    var windowTitle: String {
        let w = min(max(window, 0), windowCount - 1)
        switch page.title {
        case "OPERATOR": return Sheets.fm6WindowNames[0][w]
        case "ALL OPS": return Sheets.fm6WindowNames[1][w]
        default: return Sheets.soundWindowNames[w]
        }
    }
}

// MARK: intents (P4)

extension PhoneCore {
    private struct PageWire: Decodable {
        let intent: String
        let slot: Int?, value: Int?, family: String?, page: Int?, route: Int?, tile: Int?
    }

    /// The page intents (setParam, pickPage, pickRoute, pickTile, goHome). True when `json` was one of them. All are
    /// writes to the FM-1 (SET, SCREEN_GOTO): AndroidLink's ReadOnlyGuard drops and logs them while the phone build is
    /// read-only, so nothing else gates them here.
    func handlePageJSON(_ json: String) -> Bool {
        guard let w = try? JSONDecoder().decode(PageWire.self, from: Data(json.utf8)),
              ["setParam", "pickPage", "pickRoute", "pickTile", "goHome"].contains(w.intent) else { return false }
        guard session.isConnected, session.dialect == .skiff else { log("\(w.intent): no Skiff FM-1 connected"); return true }
        // All four are writes: refused up front while read-only, so Session's optimistic copy never shows what the guard then drops
        guard canWrite() else { log("read-only: \(w.intent) not sent (allow writes to send it)"); return true }
        // goHome (decision 19: Android's back gesture): SCREEN_GOTO 127, a HOME tap, as the iPad's HOME key sends it. The
        // screen is set to HOME at once and then to the FM-1's reply; the shell and page areas follow `deviceScreen`, so
        // the bottom half is the editor again without waiting for the reply.
        if w.intent == "goHome" {
            lag.start("goHome")
            session.showOnDevice(page: 127)
            publishNow(["shell", "page", "fm1Screen"])
            return true
        }
        // pickPage works from anywhere (HOME too); the rest act on the sound page showing
        let screen = session.deviceScreen
        var shape: SoundPage?
        if let screen, let fw = Self.soundPage(of: screen) { shape = SoundPage.page(session, fw: fw) }
        if w.intent != "pickPage" && shape == nil { log("\(w.intent): no sound page showing"); return true }
        switch w.intent {
        case "setParam":
            guard let slot = w.slot, let value = w.value, (0..<4).contains(slot) else { log("setParam: missing slot or value"); break }
            guard let page = shape else { break }
            let ctx = PageContext(session: session, page: page, cursor: screen?.cursor)
            if ctx.isSheet { setSheet(ctx, slot: slot, value: value); break }
            if let (scope, id) = ctx.target(slot: slot) {
                if scope == 0 { session.set(track: session.selectedTrack, param: id, to: value) } else { session.set(global: id, to: value) }
            }
        case "pickPage":
            guard let family = w.family.flatMap(SoundFamily.init(rawValue:)) else { log("pickPage: unknown family"); break }
            let target = w.page ?? SoundPage.reached(session, family).first?.fw
            if let target {
                lag.start("pickPage \(family.rawValue) \(target)")
                session.showOnDevice(page: target)
                publishNow(["shell", "page", "fm1Screen"])      // the page as Session's optimistic screen has it, in this same call
            }
        case "pickRoute":
            if let r = w.route, let page = shape { session.showOnDevice(page: page.fw, cursor: min(max(r, 0), 10)); publishNow(["page"]) }
        default: // pickTile: a lane (LANES, LANE MIX)
            if let t = w.tile, let page = shape { session.showOnDevice(page: page.fw, cursor: min(max(t, 0), 7)); publishNow(["page"]) }
        }
        return true
    }
}

extension PageArea {
    /// One control as the FM-1 shows it: the label (track_desc's), the value text (param_format's), the range, a held
    /// step's lock. The sound pages' columns and HOME's four (HomeKnobs.swift) both come from here.
    @MainActor static func control(_ session: DeviceSession, track: Int, scope: Int, id: Int, label: String? = nil, fixed: Bool = false) -> PageArea.Control {
        let d = scope == 0 ? session.trackDesc(id) : session.globalDescs[id]
        let locked = scope == 0 && session.lockStep.map { step in
            session.motion[track]?.events.contains { $0.lock && $0.step == step && $0.id == id } ?? false } ?? false
        let lockedValue = scope == 0 ? session.lockStep.flatMap { step in
            session.motion[track]?.events.first { $0.lock && $0.step == step && $0.id == id }?.value } : nil
        let v = lockedValue ?? (scope == 0 ? session.cell(id).value : session.globalCell(id).value)
        let lo = d?.min ?? 0, hi = max(d?.max ?? 127, lo)
        return PageArea.Control(label: label ?? d?.label ?? "", value: formatValue(d, v, skiff: true).shown, raw: v, min: lo, max: hi,
                                list: d.map { $0.format == 8 || !$0.names.isEmpty } ?? false, ringless: false, fixed: fixed, locked: locked,
                                names: d.flatMap { $0.names.isEmpty ? nil : Array(repeating: "", count: max(0, $0.min)) + $0.names })
    }
}

@MainActor extension PageContext {
    /// Which parameter a control slot writes: the page's own knob, or MOD's / the lanes' row for the picked route or lane.
    func target(slot: Int) -> (scope: Int, id: Int)? {
        if isMod, slot > 0 {
            let ids = page.routes[route]
            let i = route < 7 ? (slot == 3 ? 0 : -1) : slot - 1     // a fixed route: only AMOUNT (knob 4) turns
            guard let id = ids[safe: i] ?? nil else { return nil }
            return (0, id)
        }
        if isLanes, slot > 0, let id = page.picks[safe: lane]?[safe: slot - 1] ?? nil { return (0, id) }
        guard !isMod, !isLanes, let id = page.ids[safe: slot] ?? nil else { return nil }
        return (page.scope(of: slot), id)
    }
}

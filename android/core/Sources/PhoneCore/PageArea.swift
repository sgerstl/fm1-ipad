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

    public enum Kind: String, Codable, Sendable { case none, env, lfo, drive, fx, scale, arp, analog, mod, tiles, card }
    public struct Tile: Codable, Equatable, Sendable { public var label: String }
    public struct Route: Codable, Equatable, Sendable { public var group: String; public var label: String; public var amount: Int; public var empty: Bool }

    public struct Graph: Codable, Equatable, Sendable {
        public var kind: Kind = .none
        public var values: [Int] = []
        public var root = 0
        public var notes: [Int] = []
        public var caption: String?
        public var side: String?
        public var routes: [Route] = []
        public var tiles: [Tile] = []
        public var picked = 0
        public var title: String?
    }

    public struct Lock: Codable, Equatable, Sendable { public var text: String; public var note: String?; public var locking: Bool }

    public var family: String
    public var pages: [Ref]
    public var page: Int
    public var track: Int
    public var trackName: String
    /// Always four; nil (JSON null) is an empty well, the FM-1's 0xFF knob.
    public var controls: [Control?]
    public var graph: Graph
    public var turned: Int
    public var turnSeq: Int
    public var lock: Lock?
}

// MARK: building it

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

    /// The sound page the FM-1 shows, or nil when it shows none (HOME, the sequencer, GLO, a layer), when the firmware
    /// isn't Skiff, or before the screen link has reported.
    public func pageArea() -> PageArea? {
        let s = session
        guard s.isConnected, s.dialect == .skiff, s.screenLinked, let screen = s.deviceScreen,
              let fw = Self.soundPage(of: screen),
              let page = SoundPage.page(s, fw: fw) else { return nil }
        let t = s.selectedTrack
        var row = SoundPage.reached(s, page.family).map { PageArea.Ref(index: $0.fw, title: $0.title) }
        if !row.contains(where: { $0.index == page.fw }) { row.append(PageArea.Ref(index: page.fw, title: page.title)) }
        let ctx = PageContext(session: s, page: page, cursor: screen.cursor)
        var area = PageArea(family: page.family.rawValue, pages: row, page: page.fw, track: t + 1, trackName: s.tracks[t].displayName,
                            controls: ctx.controls(), graph: ctx.graph(), turned: -1, turnSeq: 0, lock: nil)
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
    var isDense: Bool { ["OPERATOR", "ALL OPS", "SLICES", "SOUND"].contains(page.title) }
    var route: Int { min(max(cursor ?? 0, 0), 10) }
    var lane: Int { min(max(cursor ?? 0, 0), 7) }

    func control(scope: Int, id: Int, label: String? = nil, fixed: Bool = false) -> PageArea.Control {
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

    /// The control on knob k of the page's own ids.
    func knob(_ k: Int) -> PageArea.Control? {
        guard let id = page.ids[safe: k] ?? nil else { return nil }
        return control(scope: page.scope(of: k), id: id, label: page.knobLabels[safe: k] ?? nil)
    }

    func controls() -> [PageArea.Control?] {
        if isDense { return [nil, nil, nil, nil] }
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

    func graph() -> PageArea.Graph {
        var g = PageArea.Graph()
        switch page.title {
        case "ENV", "ENV 2":
            g.kind = .env; g.values = (0..<4).map { raw(page.title, $0) ?? 0 }
        case "LFO", "LFO 2":
            g.kind = .lfo; g.values = (0..<4).map { raw("LFO", $0) ?? 0 }; g.caption = shown("LFO", 0)
        case "MOD":
            guard isMod else { break }
            g.kind = .mod; g.picked = route
            g.routes = (0..<11).map { r in
                let ids = page.routes[r]
                if r < 7 {
                    let f = pageModFixed[r]
                    return PageArea.Route(group: f.group, label: f.label, amount: (ids.first.flatMap { $0 }).map { session.cell($0).value } ?? 0, empty: false)
                }
                // a matrix slot: its SOURCE and DEST names, AMOUNT as the bar; no source set is an empty slot
                let src = ids[safe: 0] ?? nil, dst = ids[safe: 1] ?? nil, amt = ids[safe: 2] ?? nil
                let srcV = src.map { session.cell($0).value } ?? 0
                let empty = srcV == 0
                let label = empty ? "\(r - 6) —" : "\(r - 6) \(src.map { control(scope: 0, id: $0).value } ?? "")"
                _ = dst
                return PageArea.Route(group: "SLOTS", label: label, amount: amt.map { session.cell($0).value } ?? 0, empty: empty)
            }
        case "FX":
            g.kind = .fx; g.values = (0..<4).map { raw("FX", $0) ?? 0 }
        case "DRIVE":
            g.kind = .drive; g.values = [raw("DRIVE", 0) ?? 0, raw("DRIVE", 1) ?? 0, raw("DRIVE", 2) ?? 0]
            g.caption = shown("DRIVE", 1); g.side = "drive \(raw("DRIVE", 0) ?? 0) · tone \(raw("DRIVE", 2) ?? 0)"
        case "SCALE":
            let root = raw("SCALE", 0) ?? 0, sc = raw("SCALE", 1) ?? 2
            g.kind = .scale; g.root = ((root % 12) + 12) % 12
            let scale = Music.scales[safe: sc]
            g.notes = scale?.intervals ?? []
            g.side = "\(Music.noteNames[g.root]) \(scale?.name.lowercased() ?? "") · ● root"
        case "ARP", "ARP 2":
            g.kind = .arp
            g.values = (0..<4).map { raw("ARP", $0) ?? 0 } + (0..<4).map { raw("ARP 2", $0) ?? 0 }
            g.side = [shown("ARP", 0), shown("ARP", 2).map { "\($0) oct" }, shown("ARP", 1), shown("ARP", 3).map { "gate \($0)" }]
                .compactMap { $0 }.joined(separator: " · ")
        case "EDIT 1", "EDIT 2":
            // ANALOG's OSC and filter pictures; the other engines' pictures aren't ported (the panel stays empty)
            guard !session.selectedIsDrums, session.tracks[track].engine == 0 else { break }
            g.kind = .analog
            g.values = (0..<4).map { raw("EDIT 1", $0) ?? 0 } + (0..<2).map { raw("EDIT 2", $0) ?? 0 }
            g.caption = "OSC · \(shown("EDIT 1", 0) ?? "")"; g.side = "FILTER · \(shown("EDIT 2", 0) ?? "")"
        case "LANES", "LANE MIX":
            guard isLanes else { break }
            g.kind = .tiles; g.tiles = pageLaneNames.map { PageArea.Tile(label: $0) }; g.picked = lane
        case "OPERATOR", "ALL OPS", "SLICES", "SOUND":
            g.kind = .card
            g.title = cursor.map { "\(page.title) · \($0 + 1)" } ?? page.title
        default: break
        }
        return g
    }
}

// MARK: intents (P4)

extension PhoneCore {
    private struct PageWire: Decodable {
        let intent: String
        let slot: Int?, value: Int?, family: String?, page: Int?, route: Int?, tile: Int?
    }

    /// The four page intents (setParam, pickPage, pickRoute, pickTile). True when `json` was one of them. All four are
    /// writes to the FM-1 (SET, SCREEN_GOTO): AndroidLink's ReadOnlyGuard drops and logs them while the phone build is
    /// read-only, so nothing else gates them here.
    func handlePageJSON(_ json: String) -> Bool {
        guard let w = try? JSONDecoder().decode(PageWire.self, from: Data(json.utf8)),
              ["setParam", "pickPage", "pickRoute", "pickTile"].contains(w.intent) else { return false }
        guard session.isConnected, session.dialect == .skiff else { log("\(w.intent): no Skiff FM-1 connected"); return true }
        // All four are writes: refused up front while read-only, so Session's optimistic copy never shows what the guard then drops
        guard canWrite() else { log("read-only: \(w.intent) not sent (allow writes to send it)"); return true }
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
            if let (scope, id) = ctx.target(slot: slot) {
                if scope == 0 { session.set(track: session.selectedTrack, param: id, to: value) } else { session.set(global: id, to: value) }
            }
        case "pickPage":
            guard let family = w.family.flatMap(SoundFamily.init(rawValue:)) else { log("pickPage: unknown family"); break }
            let target = w.page ?? SoundPage.reached(session, family).first?.fw
            if let target { session.showOnDevice(page: target) }
        case "pickRoute":
            if let r = w.route, let page = shape { session.showOnDevice(page: page.fw, cursor: min(max(r, 0), 10)) }
        default: // pickTile: a lane (LANES, LANE MIX)
            if let t = w.tile, let page = shape { session.showOnDevice(page: page.fw, cursor: min(max(t, 0), 7)) }
        }
        return true
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

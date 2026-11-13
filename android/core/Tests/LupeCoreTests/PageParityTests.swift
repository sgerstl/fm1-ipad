import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Decision 22, "match first": every Skiff 2.5.1 sound page as PhoneCore's page area gives it, against what the FM-1
/// draws, printed by Skiff's own code (android/fixtures/skiff/skiff-2.5.1-pages.json, made by
/// android/scripts/skiff-page-dump.sh from the v2.5.1 sources: PAGES, page_visible, page_desc, param_format).
/// For each engine at its first preset (loaded through the phone's pickPreset, as an engine change on the FM-1 loads
/// it), on FakeSkiff 2.5.1:
/// - which pages each family's key reaches (the FM-1's page_visible against SoundPage.reached);
/// - each page reached: the four labels (the page area's controls);
/// - HOME's four knobs (decision 21): which parameters, their labels and text, as on a page;
/// - each control's value text, at the dump's spread of raw values (every value of a list, the ends and steps between
///   for a number), as the page area formats it (formatValue with the session's descriptor), against param_format's
///   value and unit ("%" joined, any other unit after a space: the phone's way of writing the FM-1's two lines).
/// INSERT under every TYPE and ENV with ENV SYNC on are checked the same way. What the dump can't decide (pictures,
/// columns drawn rather than printed, pages the phone shows differently by design) is in android/notes/page-parity.md.
@MainActor extension FixtureRecordingTests {
    struct SkiffDump: Decodable {
        struct Slot: Decodable {
            var label: String
            var action: Bool?
            var drawnAbove: Bool?
            var values: [Value]?
        }
        struct Value: Decodable {
            var raw: Int, text: String, unit: String
            init(from d: Decoder) throws {
                var c = try d.unkeyedContainer()
                raw = try c.decode(Int.self); text = try c.decode(String.self); unit = try c.decode(String.self)
            }
            var shown: String { unit.isEmpty ? text : unit == "%" ? "\(text)%" : "\(text) \(unit)" }
        }
        struct Page: Decodable { var index: Int; var title: String; var family: String; var graph: Int; var visible: Bool; var slots: [Slot] }
        struct Home: Decodable { var id: Int; var label: String; var values: [Value] }
        struct Engine: Decodable { var engine: Int; var name: String; var preset: String; var home: [Home]; var pages: [Page] }
        struct Insert: Decodable { var type: Int; var pages: [Page] }
        var engines: [Engine]
        var insert: [Insert]
        var envSync: [Page]

        static func load() throws -> SkiffDump {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../fixtures/skiff/skiff-2.5.1-pages.json")
            return try JSONDecoder().decode(SkiffDump.self, from: Data(contentsOf: url))
        }
    }

    /// Pages whose columns the FM-1 doesn't draw as four plain knobs: a picture or a sheet takes their place, or the
    /// phone lays them out its own way by design (page-parity.md says which and why). Their reach is still checked.
    static let parityByDesign: Set<String> = ["MOD", "LANES", "LANE MIX", "OPERATOR", "ALL OPS", "SOUND", "SLICES", "SAMPLES"]

    /// The phone's descriptor for a knob of the page showing, as PageContext.control reads it.
    func phoneDesc(_ s: DeviceSession, _ page: SoundPage, _ k: Int) -> ParamDesc? {
        guard k < page.ids.count, let id = page.ids[k] else { return nil }
        return page.scope(of: k) == 0 ? s.trackDesc(id) : s.globalDescs[id]
    }

    /// One page of the dump against the page area showing it. Mismatches go into `out`.
    func compare(_ core: PhoneCore, _ want: SkiffDump.Page, _ ctx: String, _ out: inout [String]) {
        let s = core.session
        guard let area = core.pageArea(), let page = SoundPage.page(s, fw: area.page) else { out.append("\(ctx): no page area"); return }
        for (k, slot) in want.slots.enumerated() {
            let c = k < area.controls.count ? area.controls[k] : nil
            let label = c?.label ?? ""
            if slot.drawnAbove == true { continue }
            if label != slot.label { out.append("\(ctx) knob \(k + 1): label \"\(label)\", the FM-1 \"\(slot.label)\"") }
            guard let values = slot.values, let d = phoneDesc(s, page, k) else {
                if slot.values != nil, c != nil { out.append("\(ctx) knob \(k + 1) \(slot.label): no descriptor on the phone") }
                continue
            }
            var bad: [String] = []
            for v in values {
                // the one difference kept on purpose, open for Scott (page-parity.md): the phone writes the sharp sign
                // where the FM-1's font has "#"
                let shown = formatValue(d, v.raw, skiff: true).shown.replacingOccurrences(of: "♯", with: "#")
                if shown != v.shown { bad.append("\(v.raw): \"\(shown)\" ≠ \"\(v.shown)\"") }
            }
            if !bad.isEmpty {
                out.append("\(ctx) knob \(k + 1) \(slot.label) (fmt \(d.format), \(d.min)…\(d.max)): " + bad.prefix(6).joined(separator: ", ")
                           + (bad.count > 6 ? " … (\(bad.count) of \(values.count))" : ""))
            }
        }
    }

    func showPage(_ core: PhoneCore, family: String, page lupe: Int) async -> Bool {
        core.handle(json: #"{"intent":"pickPage","family":"\#(family)","page":\#(lupe)}"#)
        let end = Date().addingTimeInterval(2)
        while Date() < end {
            if core.pageArea()?.page == lupe, core.session.deviceScreen?.page == lupe { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    @Test func everySoundPageMatchesTheFM1() async throws {
        let dump = try SkiffDump.load()
        let map = SkiffFirmware.v2_5_1.pageMap
        var out: [String] = []
        var checked = 0
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        for eng in dump.engines {
            core.handle(json: #"{"intent":"pickPreset","engine":\#(eng.engine),"preset":0}"#)
            try await waitFor(4, "\(eng.name) loaded") { core.session.tracks[0].engine == eng.engine && fake.engines[0].engine == eng.engine }
            let e0 = core.session.info?.firstEngineParam ?? 0
            try await waitFor(4, "\(eng.name)'s descriptors") { core.session.trackDescs[e0]?.label == eng.pages.first { $0.title == "EDIT 1" }?.slots.first?.label || eng.engine == 0 }
            try await Task.sleep(for: .milliseconds(150))
            let s = core.session
            // HOME's four (decision 21): which parameters (SkiffHomeKnobs against the engine's .knob), their labels and text
            if let area = core.homeKnobsArea() {
                let ids = s.homeKnobIDs ?? []
                for (k, want) in eng.home.enumerated() {
                    let ctx = "\(eng.name) HOME knob \(k + 1)"
                    if ids.dropFirst(k).first != want.id { out.append("\(ctx): parameter \(ids.dropFirst(k).first ?? -1), the FM-1's \(want.id)"); continue }
                    let label = area.controls.dropFirst(k).first?.label ?? ""
                    if label != want.label { out.append("\(ctx): label \"\(label)\", the FM-1 \"\(want.label)\"") }
                    let d = s.trackDesc(want.id)
                    let bad = want.values.filter { formatValue(d, $0.raw, skiff: true).shown.replacingOccurrences(of: "♯", with: "#") != $0.shown }
                    if !bad.isEmpty {
                        out.append("\(ctx) \(want.label): " + bad.prefix(6).map { "\($0.raw): \"\(formatValue(d, $0.raw, skiff: true).shown)\" ≠ \"\($0.shown)\"" }.joined(separator: ", "))
                    }
                }
                checked += 1
            } else {
                out.append("\(eng.name): no homeKnobs area")
            }
            // reach: per family, the pages the FM-1's key steps through against the phone's
            for fam in Set(eng.pages.map(\.family)) {
                guard let family = SoundFamily(rawValue: fam) else { continue }
                let fm1 = eng.pages.filter { $0.family == fam && $0.visible }.map { map.lupe($0.index) }
                let phone = SoundPage.counted(SoundPage.reached(s, family), s).map(\.fw)    // the page area's row
                if Set(fm1) != Set(phone) {
                    let name = { (l: Int) in eng.pages.first { map.lupe($0.index) == l }?.title ?? "page \(l)" }
                    out.append("\(eng.name) \(fam): the FM-1 reaches \(fm1.map(name)), the phone \(phone.map(name))")
                }
            }
            // each page the FM-1 shows this engine
            for want in eng.pages where want.visible && !Self.parityByDesign.contains(want.title) {
                let lupe = map.lupe(want.index)
                guard await showPage(core, family: want.family, page: lupe) else {
                    if PageArea.isSoundPageFamily(want.family) { out.append("\(eng.name) \(want.family) › \(want.title): not shown on the phone") }
                    continue
                }
                compare(core, want, "\(eng.name) \(want.family) › \(want.title)", &out)
                checked += 1
            }
            if eng.engine == 0 {
                // INSERT under every TYPE, ENV with ENV SYNC on (track_desc's rules): the ids as Skiff 2.5.1 numbers them
                // (INSERT's TYPE its knob 1, ENV SYNC LFO 2's knob 4)
                let typeID = try #require(s.pageLayout?.first { $0.title == "INSERT" }?.ids.first ?? nil)
                let syncID = try #require(s.pageLayout?.first { $0.title == "LFO 2" }?.ids.last ?? nil)
                for ins in dump.insert {
                    s.set(track: 0, param: typeID, to: ins.type)
                    try await waitFor(2, "TYPE \(ins.type)") { fake.params[0][typeID] == ins.type }
                    if let want = ins.pages.first, await showPage(core, family: "FX", page: map.lupe(want.index)) {
                        compare(core, want, "INSERT TYPE \(ins.type)", &out); checked += 1
                    }
                }
                s.set(track: 0, param: typeID, to: 0)
                s.set(track: 0, param: syncID, to: 1)
                try await waitFor(2, "ENV SYNC on") { fake.params[0][syncID] == 1 }
                if let want = dump.envSync.first, await showPage(core, family: "ENV", page: map.lupe(want.index)) {
                    compare(core, want, "ENV with ENV SYNC on", &out); checked += 1
                }
                s.set(track: 0, param: syncID, to: 0)
            }
        }
        print("PARITY: \(checked) pages checked, \(out.count) mismatches")
        for l in out { print("PARITY  \(l)") }
        #expect(out.isEmpty, "\(out.count) mismatches with the FM-1 (printed above)")
    }
}

extension PageArea {
    /// The families whose pages the phone's page area shows (GLO's are Mix's cards, P5).
    static func isSoundPageFamily(_ f: String) -> Bool { ["ENV", "LFO", "FX", "SEL", "EDIT", "ARP"].contains(f) }
}

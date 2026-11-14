import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The FX family's pictures (decision 30's sweep) on FakeSkiff 2.5.1: DELAY, REVERB, INSERT, SLICER and DUCK each
/// send a graph, with what their own four knobs don't hold: the delay bus's MIX, INSERT's MIX, DUCK's source hits.
@MainActor extension FixtureRecordingTests {
    func fxPage(_ core: PhoneCore, _ title: String) async throws -> PageArea {
        try await pick(core, family: "FX")
        let ref = try #require(core.pageArea()?.pages.first { $0.title == title }, "no FX › \(title)")
        try await pick(core, family: "FX", page: ref.index)
        return try #require(core.pageArea())
    }

    @Test func theFxPagesSendTheirPictures() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let s = core.session
        // DELAY: the send apart, the bus's three, and the bus's MIX from GLO › DELAY
        var a = try await fxPage(core, "DELAY")
        let glo = try #require(SoundPage.pages(s).first { $0.title == "DELAY" && $0.family != .fx && $0.scope == 1 })
        let mixID = try #require(glo.ids[3])
        #expect(a.graph.kind == .fxdelay && a.graph.send == a.controls[0]?.raw)
        #expect(a.graph.values == [a.controls[1]!.raw, a.controls[2]!.raw, a.controls[3]!.raw, s.globalCell(mixID).value])
        #expect(a.graph.caption == a.controls[1]?.value)
        s.set(global: mixID, to: 33)
        try await waitFor(3, "the bus's MIX in the picture") { core.pageArea()?.graph.values.last == 33 }
        // REVERB
        a = try await fxPage(core, "REVERB")
        #expect(a.graph.kind == .fxreverb && a.graph.send == a.controls[0]?.raw && a.graph.values.count == 3 && a.graph.caption == a.controls[1]?.value)
        // INSERT: TYPE A B C, then its MIX (INSERT 2's knob)
        a = try await fxPage(core, "INSERT")
        let insMix = try #require(SoundPage.pages(s).first { $0.title == "INSERT 2" }?.ids.first ?? nil)
        #expect(a.graph.kind == .insert && a.graph.values == a.controls.map { $0?.raw ?? 0 } + [s.cell(insMix).value])
        s.set(track: 0, param: insMix, to: 64)
        try await waitFor(3, "INSERT's MIX in the picture") { core.pageArea()?.graph.values.last == 64 }
        // SLICER
        a = try await fxPage(core, "SLICER")
        #expect(a.graph.kind == .slicer && a.graph.values == a.controls.map { $0?.raw ?? 0 })
        // DUCK: no source, no hits; a source track's steps over a bar, and RELEASE as a part of the bar
        a = try await fxPage(core, "DUCK")
        #expect(a.graph.kind == .duck && a.graph.values.count == 2)
        let page = try #require(SoundPage.page(s, fw: a.page))
        let by = try #require(page.ids[0])
        s.set(track: 0, param: by, to: 0)
        try await waitFor(3, "no source") { core.pageArea()?.graph.notes.isEmpty == true && core.pageArea()?.graph.values.last == 0 }
        s.set(track: 0, param: by, to: 3)                                         // ducked by track 3
        let src = s.tracks[2]
        let on = (0..<min(16, src.length)).filter { src.isOn($0) }
        try await waitFor(3, "the source's hits") { !(core.pageArea()?.graph.notes.isEmpty ?? true) }
        a = try #require(core.pageArea())
        #expect(a.graph.notes.count >= on.count && a.graph.notes.allSatisfy { (0..<1000).contains($0) }, "\(a.graph.notes) for steps \(on)")
        #expect(a.graph.values[1] > 0)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

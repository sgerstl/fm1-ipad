import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// SEL › CHORD and SEL › FOLLOW's pictures on FakeSkiff 2.5.1, against what the iPad draws (ios/FM1/PageGraphs.swift
/// chordDrawing and followDrawing): the chord resolved to its notes by SkiffChord, the strum, and the followed track.
@MainActor extension FixtureRecordingTests {
    func selPage(_ core: PhoneCore, _ title: String) async throws -> PageArea {
        try await pick(core, family: "SEL")
        let ref = try #require(core.pageArea()?.pages.first { $0.title == title }, "no SEL › \(title)")
        try await pick(core, family: "SEL", page: ref.index)
        return try #require(core.pageArea())
    }
    func knob(_ s: DeviceSession, _ title: String, _ k: Int) throws -> Int {
        try #require(SoundPage.pages(s).first { $0.title == title }?.ids[k], "no \(title) knob \(k + 1)")
    }

    @Test func chordSendsTheNotesAKeyPlays() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let s = core.session
        var a = try await selPage(core, "CHORD")
        let chord = try knob(s, "CHORD", 0), voicing = try knob(s, "CHORD", 1), strum = try knob(s, "CHORD", 2), dir = try knob(s, "CHORD", 3)
        let root = try knob(s, "SCALE", 0), scale = try knob(s, "SCALE", 1), voice = try knob(s, "VOICE", 0), arp = try knob(s, "ARP", 0)
        func g() -> PageArea.Graph? { core.pageArea()?.graph }
        for (id, v) in [(strum, 0), (voice, 0), (arp, 0), (root, 0), (voicing, 0)] { s.set(track: 0, param: id, to: v) }
        // off: two lines, no keys
        s.set(track: 0, param: chord, to: 0)
        try await waitFor(3, "CHORD off") { g()?.title == "CHORD KEYS OFF" }
        a = try #require(core.pageArea())
        #expect(a.graph.kind == .chord && a.graph.notes.isEmpty && a.graph.caption == "K1 DIA3: IN-KEY CHORDS" && a.graph.values.isEmpty)
        // every mode and voicing: SkiffChord's notes on ROOT from C4, its name, its root
        for mode in 1...9 {
            for v in 0...4 {
                s.set(track: 0, param: chord, to: mode); s.set(track: 0, param: voicing, to: v)
                let want = try #require(SkiffChord.make(note: 60, mode: mode, voicing: v, root: 0, scale: s.cell(scale).value))
                try await waitFor(3, "mode \(mode) voicing \(v)") { g()?.notes == want.notes }
                let gr = try #require(g())
                #expect(gr.title == SkiffChord.name(root: want.root, mask: want.mask) && gr.root == want.root % 12 && gr.caption == "ON ROOT" && gr.values.isEmpty)
                #expect(gr.notes.count <= SkiffChord.maxNotes && gr.notes == gr.notes.sorted())
            }
        }
        // MAJ, CLOSE on ROOT D: D F# A from D4
        s.set(track: 0, param: chord, to: 3); s.set(track: 0, param: voicing, to: 0); s.set(track: 0, param: root, to: 2)
        try await waitFor(3, "the chord on ROOT D") { g()?.notes == [62, 66, 69] }
        #expect(g()?.title == "D" && g()?.root == 2)
        // STRUM on a POLY track: the time and the direction, the notes as they were
        s.set(track: 0, param: strum, to: 30); s.set(track: 0, param: dir, to: 1)
        try await waitFor(3, "the strum") { g()?.values == [30, 1] }
        #expect(g()?.caption == "UP 30 ms" && g()?.notes == [62, 66, 69])
        s.set(track: 0, param: dir, to: 2)
        try await waitFor(3, "ALT") { g()?.caption == "ALT: DOWN, THEN UP" }
        // one voice (not POLY, ARP off): the root alone, no strum
        s.set(track: 0, param: voice, to: 1)
        try await waitFor(3, "ROOT ONLY") { g()?.caption == "ROOT ONLY" }
        #expect(g()?.notes == [62] && g()?.values.isEmpty == true)
        // the ARP on plays the whole chord again
        s.set(track: 0, param: arp, to: 1)
        try await waitFor(3, "the ARP's chord") { g()?.notes == [62, 66, 69] && g()?.caption == "ON ROOT" }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func followSendsTheTrackAndHow() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let s = core.session
        _ = try await selPage(core, "FOLLOW")
        let follow = try knob(s, "FOLLOW", 0), mode = try knob(s, "FOLLOW", 1), note = try knob(s, "FOLLOW", 2)
        func g() -> PageArea.Graph? { core.pageArea()?.graph }
        s.set(track: 0, param: follow, to: 0)
        try await waitFor(3, "FOLLOW off") { g()?.title == "FOLLOW OFF" }
        #expect(g()?.kind == .follow && g()?.follow == nil && g()?.caption == "K1 A TRACK TO FOLLOW")
        // itself: off, as on the iPad
        s.set(track: 0, param: follow, to: 1)
        try await Task.sleep(for: .milliseconds(150))
        #expect(g()?.follow == nil && g()?.title == "FOLLOW OFF")
        // a track that plays notes, and one that plays a kit
        let kits = PageContext.kitEngines
        let tonal = try #require(s.tracks.indices.first { $0 != 0 && !kits.contains(s.tracks[$0].engine) }, "no second tonal track")
        s.set(track: 0, param: mode, to: 1); s.set(track: 0, param: note, to: 2); s.set(track: 0, param: follow, to: tonal + 1)
        try await waitFor(3, "the followed track") { g()?.follow?.track == tonal && g()?.follow?.by == "HIGH" }
        var f = try #require(g()?.follow)
        #expect(f == PageArea.Follow(track: tonal, trackName: "T\(tonal + 1)", mode: "SCALE", by: "HIGH", kit: false))
        #expect(g()?.title == "FOLLOWS T\(tonal + 1) · SCALE BY ITS HIGH" && g()?.caption == "ITS LIVE CHORD SHOWS ON THE FM-1")
        s.set(track: 0, param: mode, to: 2)                                       // FIT goes by the root, whatever NOTE says
        try await waitFor(3, "FIT") { g()?.follow?.mode == "FIT" }
        #expect(g()?.follow?.by == "ROOT")
        if let kit = s.tracks.indices.first(where: { $0 != 0 && kits.contains(s.tracks[$0].engine) }) {
            s.set(track: 0, param: follow, to: kit + 1)
            try await waitFor(3, "a kit followed") { g()?.follow?.kit == true }
            f = try #require(g()?.follow)
            #expect(f.track == kit && g()?.title == "T\(kit + 1) PLAYS A KIT" && g()?.caption == "NO CHORDS TO FOLLOW")
        } else {
            Issue.record("the fake has no kit track to follow")
        }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

import Foundation
import Testing
@testable import SloopKit

/// Traffic captured from the FM-1 on SLOOP 2.8.4 with tools/sloopcapture.swift (2026-10-31): snapshot-0, every read
/// the first SLOOP driver made, the device stopped. Lupe speaks Skiff only now (decision 43); the capture stays as the
/// evidence of what SLOOP's INFO looks like, so an FM-1 on SLOOP is recognised and offered Skiff-Lupe.
struct Capture {
    struct Line: Decodable { let t: Double; let dir: String; let hex: String }
    let frames: [(dir: String, bytes: [UInt8])]

    init(_ name: String) throws {
        let url = Bundle.module.url(forResource: name, withExtension: "jsonl", subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        frames = try text.split(separator: "\n").map {
            let l = try JSONDecoder().decode(Line.self, from: Data($0.utf8))
            return (l.dir, l.hex.split(separator: " ").map { UInt8($0, radix: 16)! })
        }
    }

    var rx: [(cmd: UInt8, body: [UInt8])] { frames.filter { $0.dir == "rx" }.compactMap { Frame.decode($0.bytes) } }
    func replies(_ cmd: UInt8) -> [[UInt8]] { rx.filter { $0.cmd == cmd }.map(\.body) }
}

/// An FM-1 on SLOOP doesn't connect any more (decision 43): its INFO, as captured, is firmware Lupe doesn't speak, and
/// it's recognised as SLOOP so the app can offer Skiff-Lupe in its place.
@Suite(.serialized) @MainActor struct SloopRefusalTests {
    /// Answers INFO with SLOOP's captured reply, and nothing else.
    final class SloopInfo: SysExTransport, @unchecked Sendable {
        let frames: AsyncStream<[UInt8]>
        let notes = AsyncStream<NoteEvent> { $0.finish() }
        private let sink: AsyncStream<[UInt8]>.Continuation
        private let info: [UInt8]
        private(set) var unanswered: [UInt8] = []
        init() throws {
            (frames, sink) = AsyncStream.makeStream(of: [UInt8].self)
            info = try Capture("snapshot-0").replies(Cmd.info)[0]
        }
        func send(_ frame: [UInt8]) {
            guard let (cmd, _) = Frame.decode(frame) else { return }
            if cmd == Cmd.info { sink.yield(Frame.encode(Cmd.info, info)) } else { unanswered.append(cmd) }
        }
    }

    @Test func sloopsInfoIsRecognisedButNotSpoken() throws {
        let info = try DeviceInfo(Capture("snapshot-0").replies(Cmd.info)[0])
        #expect(info.version == "FELUCCA SLOOP 2.8.4" && info.protocolVersion == 12)
        #expect(FirmwareDialect.detect(info) == nil)
        #expect(FirmwareDialect.isSLOOP(info.version))
        #expect(!FirmwareDialect.isSLOOP("FELUCCA v2.5.1") && !FirmwareDialect.isSLOOP("FELUCCA v1.1.5"))
    }

    @Test func theDetectorReportsSLOOPAsUnknown() async throws {
        let t = try SloopInfo()
        guard case .unknown(let i) = try await FirmwareDetector.connect(t) else { Issue.record("connected"); return }
        #expect(i.version == "FELUCCA SLOOP 2.8.4")
        #expect(t.unanswered.isEmpty)
    }

    @Test func theSessionSaysWrongFirmware() async throws {
        let session = DeviceSession(transport: { try? SloopInfo() })
        let run = Task { await session.run() }
        try await waitFor { if case .wrongFirmware = session.status { true } else { false } }
        #expect(session.status == .wrongFirmware(found: "FELUCCA SLOOP 2.8.4", protocolVersion: 12))
        run.cancel()
    }
}

@Suite struct ChordTests {
    @Test func chordsAreBuiltOnTheScaleAsSLOOPDoes() {
        // C minor (root C, scale MIN)
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 1) == [60, 63, 67])          // TRIAD on C: C Eb G
        #expect(Music.chordNotes(on: 67, root: 0, scale: 2, type: 2) == [67, 70, 74, 77])      // 7TH on G: G Bb D F
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 3) == [60, 63, 70, 74])      // 9TH: 1 3 7 9
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 4) == [60, 65, 67])          // SUS4: C F G
        #expect(Music.chordNotes(on: 60, root: 0, scale: 2, type: 5) == [60, 67, 72])          // POWER
        // C major: TRIAD on D is D F A; chromatic builds on minor
        #expect(Music.chordNotes(on: 62, root: 0, scale: 1, type: 1) == [62, 65, 69])
        #expect(Music.chordNotes(on: 60, root: 0, scale: 0, type: 1) == [60, 63, 67])
    }

    @Test func blackKeysAreChordModifiers() {
        // key 0 is F3; F# is key 1, G# key 3, A# key 5, C# key 8, D# key 10
        #expect(Music.chordModifier(ofKey: 1) == "maj/min")
        #expect(Music.chordModifier(ofKey: 3) == "+7")
        #expect(Music.chordModifier(ofKey: 5) == "sus4")
        #expect(Music.chordModifier(ofKey: 8) == "+9")
        #expect(Music.chordModifier(ofKey: 10) == "inv")
        #expect(Music.chordModifier(ofKey: 0) == nil)
    }
}

import Foundation
import Testing
@testable import SloopKit

/// The pads' pictures from the pattern pool (SkiffPoolRead, SkiffPatternSketch), against a pretend bank that refuses
/// as editor_backup.c does: GET rc 5 until a LIST this connection, rc 3 while playing.
struct SkiffPoolReadTests {
    final class Bank: @unchecked Sendable {
        var records: [Int: [UInt8]] = [:]
        var listed = false, playing = false
        var lists = 0, gets = 0

        func chunk(_ c: Int) -> [UInt8] {
            let recs = (0..<4).map { records[4 * c + $0] }
            guard recs.contains(where: { $0 != nil }) else { return [] }
            return recs.flatMap { $0 ?? [UInt8](repeating: 0, count: 888) }
        }

        var request: BackupRequest {
            { cmd, a, _ in
                switch cmd {
                case 65:
                    self.lists += 1; self.listed = true; self.playing = false
                    let ids = Array(16...31)
                    return [1, 0, UInt8(ids.count)] + ids.flatMap { id -> [UInt8] in
                        let b = self.chunk(id - 16)
                        return [UInt8(id)] + Pack7.u35(UInt32(b.count)) + Pack7.u35(CRC32.of(b))
                    }
                default:
                    self.gets += 1
                    let id = Int(a[0]), off = Int(Pack7.readU35(a[1...])), n = Int(a[6]) | Int(a[7]) << 7
                    if !self.listed { return [a[0], 5] + Pack7.u35(0) + [0, 0] }
                    if self.playing { return [a[0], 3] + Pack7.u35(0) + [0, 0] }
                    let b = self.chunk(id - 16)
                    guard off + n <= b.count else { return [a[0], 1] + Pack7.u35(UInt32(off)) + [0, 0] }
                    return [a[0], 0] + Pack7.u35(UInt32(off)) + [a[6], a[7]] + Pack7.encode(Array(b[off..<(off + n)]))
                }
            }
        }
    }

    /// A record: version 1, LEN `len`, a note step (C4 and E4) on step 0, two lane hits on step 4.
    static func record(len: Int) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: 888)
        r[0] = 1; r[2] = UInt8(64 + len)
        r[8] = 60; r[9] = 64; r[12] = 2                        // step 0: two notes, time NOTE
        r[8 + 36 + 6] = 0b101                                  // step 4: lanes 1 and 3
        return r
    }

    @Test func refusedGetListsOnceThenReads() async throws {
        let bank = Bank()
        bank.records = [5: Self.record(len: 16), 9: Self.record(len: 32)]
        let got = try await SkiffPoolRead.records(chunks: [1, 2, 3], request: bank.request)
        #expect(Set(got.keys) == [5, 9])
        #expect(bank.lists == 1)                               // GET asked for it once; chunk 3 (empty) skipped from the list
        let again = try await SkiffPoolRead.records(chunks: [1], request: bank.request)
        #expect(again.keys.contains(5))
        #expect(bank.lists == 1)                               // listed this connection: no second LIST
    }

    @Test func playingIsRefused() async {
        let bank = Bank()
        bank.records = [0: Self.record(len: 16)]
        bank.listed = true; bank.playing = true
        await #expect(throws: SkiffProjectError.playing) {
            _ = try await SkiffPoolRead.records(chunks: [0], request: bank.request)
        }
    }

    @Test func sketchReadsLenNotesAndHits() throws {
        let s = try #require(SkiffPatternSketch(record: Self.record(len: 16)))
        #expect(s.length == 16)
        #expect(s.steps[0].note && s.steps[0].notes == [60, 64])
        #expect(s.steps[4].hits == 2 && s.drums)
        #expect(!s.steps[1].note)
        #expect(SkiffPatternSketch(record: [UInt8](repeating: 0, count: 888)) == nil)   // empty record
    }
}

/// The FM-1's THEME track colours (SkiffTheme).
struct SkiffThemeTests {
    @Test func builtInsAndCustomAndTheGuard() throws {
        #expect(SkiffTheme.tracks(palette: 0)?.first == 0xFF5A36)        // SKIFF: Lupe's own
        #expect(SkiffTheme.tracks(palette: 1) == nil && SkiffTheme.tracks(palette: 2) == nil)   // HI-CON, PAPER: none
        #expect(SkiffTheme.tracks(palette: 4)?[1] == 0x30E0FF)          // NEON's cyan
        // CUSTOM: T1 pure red (RGB565 0xF800), the rest pure green (0x07E0)
        let c: [UInt16] = Array(repeating: 0, count: 5) + [0xF800] + Array(repeating: 0x07E0, count: 5)
        let reply: [UInt8] = [0, 3, 0] + Pack7.encode(c.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
        let t = try #require(SkiffTheme.customTracks(reply))
        #expect(t[0] == 0xFF0000 && t[1] == 0x00FF00)
        #expect(SkiffTheme.customTracks([0, 0, 0] + Pack7.encode([UInt8](repeating: 0, count: 22))) == nil)   // none stored
        // the guard: a navy (too dark on the page) and a mid red (too dark for the numbers on it) fall back
        let fb: [UInt32] = [1, 2, 3]
        #expect(SkiffTheme.guarded([0x10205A, 0xC03030, 0xFFDE5A], fallback: fb) == [1, 2, 0xFFDE5A])
    }
}

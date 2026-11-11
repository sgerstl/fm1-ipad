import Foundation

/// A Standard MIDI File (SMF, format 1) writer: a tempo track, then one track per part. Only what Lupe's exports need:
/// note on and off, controllers, track names, tempo, time signature, end of track.
public struct MIDIFile: Equatable, Sendable {
    public struct Event: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case note(note: Int, velocity: Int, length: Int)
            case controller(number: Int, value: Int)
        }
        public var tick: Int
        public var channel: Int          // 0…15
        public var kind: Kind
        public init(tick: Int, channel: Int, kind: Kind) { self.tick = tick; self.channel = channel; self.kind = kind }
    }

    public struct Track: Equatable, Sendable {
        public var name: String
        public var events: [Event]
        public init(name: String, events: [Event]) { self.name = name; self.events = events }
    }

    /// Ticks a quarter note.
    public var ppq: Int
    public var tempo: Double              // BPM
    public var name: String
    public var tracks: [Track]
    /// Where every track ends (the song's end), in ticks; nil: each at its last event.
    public var end: Int?

    public init(ppq: Int, tempo: Double, name: String, tracks: [Track], end: Int? = nil) {
        self.ppq = ppq; self.tempo = tempo; self.name = name; self.tracks = tracks; self.end = end
    }

    public var data: Data {
        var out: [UInt8] = Array("MThd".utf8) + Self.u32(6) + Self.u16(1) + Self.u16(tracks.count + 1) + Self.u16(ppq)
        // the tempo track: name, 4/4, tempo
        var t0: [UInt8] = []
        t0 += [0] + Self.meta(0x03, Array(Self.ascii(name).utf8))
        t0 += [0] + Self.meta(0x58, [4, 2, 24, 8])
        let us = Int((60_000_000 / max(1, tempo)).rounded())
        t0 += [0] + Self.meta(0x51, [UInt8(us >> 16 & 0xFF), UInt8(us >> 8 & 0xFF), UInt8(us & 0xFF)])
        t0 += Self.vlq(max(0, end ?? 0)) + Self.meta(0x2F, [])
        out += Array("MTrk".utf8) + Self.u32(t0.count) + t0
        for t in tracks { out += Self.chunk(t, end: end) }
        return Data(out)
    }

    /// A track's chunk: its name, then its events in time order (at one tick: note-offs first, then controllers, then
    /// note-ons, so a note retriggered on the tick it ends sounds again), then the end.
    static func chunk(_ t: Track, end: Int?) -> [UInt8] {
        struct Raw { var tick: Int; var order: Int; var bytes: [UInt8] }
        var raw: [Raw] = []
        for e in t.events {
            let ch = UInt8(max(0, min(15, e.channel)))
            switch e.kind {
            case .note(let n, let v, let len):
                let note = UInt8(max(0, min(127, n)))
                raw.append(Raw(tick: e.tick, order: 2, bytes: [0x90 | ch, note, UInt8(max(1, min(127, v)))]))
                raw.append(Raw(tick: e.tick + max(1, len), order: 0, bytes: [0x80 | ch, note, 0]))
            case .controller(let c, let v):
                raw.append(Raw(tick: e.tick, order: 1, bytes: [0xB0 | ch, UInt8(max(0, min(127, c))), UInt8(max(0, min(127, v)))]))
            }
        }
        raw = raw.enumerated().sorted { a, b in
            (a.element.tick, a.element.order, a.offset) < (b.element.tick, b.element.order, b.offset)
        }.map(\.element)
        var body: [UInt8] = [0] + meta(0x03, Array(ascii(t.name).utf8))
        var at = 0
        for r in raw {
            let tick = max(0, r.tick)
            body += vlq(tick - at) + r.bytes
            at = tick
        }
        body += vlq(max(0, (end ?? at) - at)) + meta(0x2F, [])
        return Array("MTrk".utf8) + u32(body.count) + body
    }

    static func meta(_ type: UInt8, _ data: [UInt8]) -> [UInt8] { [0xFF, type] + vlq(data.count) + data }

    /// A variable-length quantity: 7 bits a byte, the high bit set on all but the last.
    static func vlq(_ v: Int) -> [UInt8] {
        var v = max(0, v), out = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 { out.insert(UInt8(v & 0x7F) | 0x80, at: 0); v >>= 7 }
        return out
    }
    static func u16(_ v: Int) -> [UInt8] { [UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
    static func u32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
    /// Names as plain ASCII (what every DAW reads).
    static func ascii(_ s: String) -> String { String(s.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 }.map(Character.init)) }
}

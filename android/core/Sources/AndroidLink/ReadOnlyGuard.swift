// A transport that lets only reads reach the FM-1 (added 2026-11-13 for unattended runs on the Pixel: Scott
// approved read-only testing against the real FM-1 overnight: version requests, Session reaching ready,
// reads, the screen link, clock; nothing that changes the device).
//
// The allowlist is Skiff's own command table (skiff-src web/EDITOR_PROTOCOL.md): most commands are a query
// with no or few arguments and a write with more, so each read is allowed only in its query form. Anything
// not listed (SET, STEP writes, PRESET, the sample and user-slot writes, MENU_SET, SCREEN_GOTO, TRANSPORT ops,
// LIST/POOL/PERFORM ops, BACKUP_PUT, plain MIDI notes or clock) is dropped and reported.
import Foundation
import SloopKit

public enum ReadOnlyGuard {
    /// Skiff command → the argument counts that make it a read.
    static let reads: [UInt8: Set<Int>] = [
        1: [0],        // INFO
        2: [2],        // GET scope, id
        4: [0],        // DUMP
        5: [2],        // DESC scope, id
        9: [2],        // PROJECT: only op 2 (query) is let through, checked below
        10: [1],       // NAMES engine
        15: [0],       // SMP_INFO
        16: [2],       // UP_LIST start, count
        17: [1],       // UP_GET slot
        22: [1],       // WATCH on: a subscription to pushes, nothing stored
        25: [0],       // PING
        27: [0],       // TRACK query (one argument selects a track: refused)
        28: [1],       // TRACK_MIX get
        29: [1],       // TRACK_DUMP
        30: [2],       // TRACK_STEP get track, index
        31: [2],       // TRACK_PARAM get track, id
        34: [0],       // UI_STATE (the look: palette, font; SkiffTheme reads it on connect). SLOOP: BACKUP_LIST, also a read
        36: [0],       // UI_PALETTES
        39: [0],       // COLORS state (its ops carry arguments: refused)
        64: [1, 2],    // MOTION query, or track, 7 (query with kinds), checked below
        65: [0],       // BACKUP_LIST
        66: [8],       // BACKUP_GET id, offset u32, count lo, hi
        68: [2],       // FM6_GET
        70: [0],       // FM6_LIST
        72: [1],       // MENU_DESC index
        74: [1],       // KIT_GET lane
        76: [0],       // TRANSPORT state (ops play, stop, restart, rec: refused)
        77: [0],       // PROJ_NAME names (SLOOP's LIVE shares 77: its ops carry arguments, refused)
        78: [0],       // POOL
        79: [0],       // LIST
        80: [0],       // PERFORM state
        81: [1],       // SMP_MIX get
        82: [0],       // LIST2
        90: [0],       // SCREEN
        92: [0],       // METER
        93: [0],       // SCOPE
    ]

    /// Whether `frame` only reads. False for anything else, plain MIDI included.
    public static func isRead(_ frame: [UInt8]) -> Bool {
        guard let (cmd, args) = Frame.decode(frame), let counts = reads[cmd], counts.contains(args.count) else { return false }
        switch cmd {
        case 9: return args.first == 2                       // PROJECT query only
        case 64: return args.count == 1 || args[1] == 7      // MOTION query, query with kinds
        default: return true
        }
    }

    /// A short name for the log.
    public static func describe(_ frame: [UInt8]) -> String {
        guard let (cmd, args) = Frame.decode(frame) else {
            return "plain MIDI " + frame.prefix(6).map { String(format: "%02X", $0) }.joined(separator: " ")
        }
        return "cmd \(cmd) with \(args.count) argument byte(s)"
    }
}

/// Wraps a transport so only reads go out; the rest is dropped and reported through `onBlocked`.
public final class GuardedTransport: SysExTransport, @unchecked Sendable {
    public let inner: SysExTransport
    private let onBlocked: @Sendable ([UInt8]) -> Void
    private let lock = NSLock()
    private var _blocked = 0
    public var blockedCount: Int { lock.withLock { _blocked } }

    public init(_ inner: SysExTransport, onBlocked: @escaping @Sendable ([UInt8]) -> Void = { _ in }) {
        self.inner = inner; self.onBlocked = onBlocked
    }
    public var frames: AsyncStream<[UInt8]> { inner.frames }
    public var notes: AsyncStream<NoteEvent> { inner.notes }
    public var clock: AsyncStream<ClockEvent> { inner.clock }
    public func send(_ frame: [UInt8]) {
        if ReadOnlyGuard.isRead(frame) { inner.send(frame); return }
        lock.withLock { _blocked += 1 }
        onBlocked(frame)
    }
}

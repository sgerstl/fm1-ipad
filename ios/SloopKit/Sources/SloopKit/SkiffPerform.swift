import Foundation

// Skiff's PERFORM (80; EDITOR_PROTOCOL.md "Pool, lists, PERFORM", INFO `57 01` bit 4): the 16 scenes (each the entry
// every track is on, and its mute), the mutes staged for the launch point, and LAUNCH. The Song tab's Pads view
// (canvas board 25; Scott, 2026-11-07: "the most live playing friendly") reads it about once a second and sends its ops.

/// PERFORM's state, after `op, rc`: LAUNCH, the scene recalled or stored last (127 none), the scenes kept (16 bits,
/// 7 a byte, low first), then for each track: muted 0/1, its mute staged (0 none, 1 to unmute, 2 to mute).
public struct PerformState: Equatable, Sendable {
    public enum Staged: Int, Sendable { case none = 0, unmute = 1, mute = 2 }
    public static let scenes = 16

    public var launch: SongPlayback.Launch
    public var lastScene: Int?
    public var kept: [Bool]
    public var muted: [Bool]
    public var staged: [Staged]

    public init(launch: SongPlayback.Launch = .loop, lastScene: Int? = nil, kept: [Bool] = Array(repeating: false, count: 16),
                muted: [Bool], staged: [Staged]) {
        self.launch = launch; self.lastScene = lastScene; self.kept = kept; self.muted = muted; self.staged = staged
    }

    init<C: Collection>(_ b: C, tracks: Int) throws where C.Element == UInt8 {
        var r = ByteReader(Array(b), cmd: 80)
        launch = SongPlayback.Launch(rawValue: Int(try r.u8())) ?? .loop
        let s = Int(try r.u8())
        lastScene = s < Self.scenes ? s : nil
        let bits = Int(try r.u8()) | Int(try r.u8()) << 7 | Int(try r.u8()) << 14
        kept = (0..<Self.scenes).map { bits >> $0 & 1 != 0 }
        muted = []; staged = []
        for _ in 0..<tracks {
            muted.append(try r.u8() != 0)
            staged.append(Staged(rawValue: Int(try r.u8())) ?? .none)
        }
    }

    /// Something is waiting for the launch point: a mute (the lists' staged entries are LIST's).
    public var anyStaged: Bool { staged.contains { $0 != .none } }
}

/// One PERFORM change, as the FM-1's PERFORM layer makes it.
public enum PerformOp: Equatable, Sendable {
    case store(scene: Int)                  // the entry each track is on, and its mute; over a kept one without asking
    case recall(scene: Int)                 // at once stopped, staged to the launch point playing
    case mute(track: Int)                   // the other way; staged while playing, a staged one taken back
    case cancel                             // all that is staged: entries, mutes (the song's next stays)
    case launch(SongPlayback.Launch)        // saved with the settings

    var bytes: [UInt8] {
        switch self {
        case .store(let s): [1, UInt8(s & 15)]
        case .recall(let s): [2, UInt8(s & 15)]
        case .mute(let t): [3, UInt8(t)]
        case .cancel: [4]
        case .launch(let l): [5, UInt8(l.rawValue)]
        }
    }
}

/// RECALL's answer (the others always say 0).
public enum PerformRC: Int, Sendable {
    case done = 0, empty = 1, withoutAutomation = 2, patternsFull = 4, failed = 5

    public var isDone: Bool { self == .done || self == .withoutAutomation }
    public var reason: String {
        switch self {
        case .done: "Done"
        case .empty: "That scene is empty: store one there first"
        case .withoutAutomation: "Recalled, without some automation (no room for it)"
        case .patternsFull: "All 64 patterns are taken, so the scene couldn't load. Clear unused ones to free a number"
        case .failed: "Skiff couldn't do it"
        }
    }
}

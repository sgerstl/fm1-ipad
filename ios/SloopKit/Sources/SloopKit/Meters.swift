import Foundation
import Observation

/// Each track's level for the Mixer's lines beside its faders, as the FM-1 draws them on MIXER (ui_graph.c
/// draw_tracks: a thin line by the fader, 60 dB over its height, falling about 2 dB a 16 ms frame). Two sources:
/// - measured: Skiff's METER push (the screen link's `56 01 03`, editor.c ed_met_tick), 0…127 on the meter's own
///   scale (60 dB: 0 = −54 dB or quieter, 127 = +6 dB), already zero while muted and with the device's own ballistics
///   (peak since the last reading, falling about 125 dB/s): drawn as it comes, held between pushes. A push goes out
///   only when a level changes (and once a second as a keep-alive), so nothing for 1.5 s means watching lapsed: stale,
///   and the notes' estimate takes over until METER comes back;
/// - estimated: the notes each track sends over USB MIDI (NOTES OUT, a channel a track), a note-on rising to its
///   velocity, held while notes sound, then falling at the meter's own rate. Note activity, not audio.
/// A muted track's line comes from its notes either way (METER says 0 for it), drawn dimmed by the Mixer, so a
/// track that's playing but silent shows it.
/// Only `active` and `measured` are observed; the levels are read at the display's rate by whoever draws them.
@MainActor @Observable
public final class TrackMeters {
    /// Something to draw: a level above 0, or a note held, in the last moment. The lines' display link runs only then.
    public private(set) var active = false
    /// The levels come from the FM-1 (METER), not from the notes.
    public private(set) var measured = false

    @ObservationIgnored private var level = [Double](repeating: 0, count: 8)       // 0…1 at `at`
    @ObservationIgnored private var at = [Date](repeating: .distantPast, count: 8)
    @ObservationIgnored private var noteLevel = [Double](repeating: 0, count: 8)   // the estimate, for every track
    @ObservationIgnored private var noteAt = [Date](repeating: .distantPast, count: 8)
    @ObservationIgnored private var held = [Set<Int>](repeating: [], count: 8)
    @ObservationIgnored private var heldVelocity = [Double](repeating: 0, count: 8)
    @ObservationIgnored private var idleCheck: Task<Void, Never>?

    /// The meter's fall: its 30 px a 16 ms frame on the FM-1, so the whole scale in about half a second.
    public static let fallPerSecond = 1.0 / 30 / 0.016
    /// METER silent this long: stale (its keep-alive comes once a second).
    public static let stale: TimeInterval = 1.5

    public init() {}

    /// A METER push: each track's level, 0…127.
    public func measure(_ v: [Int]) {
        let now = Date.now
        if !measured { measured = true }
        for (t, x) in v.enumerated() where t < level.count {
            level[t] = Double(min(max(x, 0), 127)) / 127
            at[t] = now
        }
        if v.contains(where: { $0 > 0 }) { wake() }
    }

    /// A note from the FM-1 on track t's channel.
    public func note(track t: Int, note n: Int, on: Bool, velocity: Int) {
        guard t < held.count else { return }
        let now = Date.now
        let current = Self.fallen(noteLevel[t], since: noteAt[t], now)
        if on {
            held[t].insert(n)
            let v = Double(min(max(velocity, 1), 127)) / 127
            heldVelocity[t] = max(held[t].count > 1 ? heldVelocity[t] : 0, v)
            noteLevel[t] = max(current, v)
            wake()
        } else {
            held[t].remove(n)
            noteLevel[t] = held[t].isEmpty ? max(current, heldVelocity[t]) : current
            if held[t].isEmpty { heldVelocity[t] = 0 }
        }
        noteAt[t] = now
    }

    /// Track t's level now, 0…1. `muted`: the notes' estimate (the FM-1's METER reads 0 for a muted track).
    public func level(track t: Int, muted: Bool = false, at now: Date = .now) -> Double {
        guard t < level.count else { return 0 }
        if measured && !muted && now.timeIntervalSince(at[t]) < Self.stale { return level[t] }
        if !held[t].isEmpty { return max(heldVelocity[t], Self.fallen(noteLevel[t], since: noteAt[t], now)) }
        return Self.fallen(noteLevel[t], since: noteAt[t], now)
    }

    /// Whether track t has notes sounding now (the Mixer's steady lit state under Reduce Motion).
    public func sounding(track t: Int) -> Bool { t < held.count && !held[t].isEmpty }

    /// The device went away: nothing measured, nothing held.
    public func reset() {
        measured = false
        for t in level.indices { level[t] = 0; noteLevel[t] = 0; held[t] = []; heldVelocity[t] = 0 }
        active = false
    }

    static func fallen(_ v: Double, since t: Date, _ now: Date) -> Double {
        max(0, v - fallPerSecond * max(0, now.timeIntervalSince(t)))
    }

    /// Active now; idle again once every line has fallen and no note is held (checked twice a second).
    private func wake() {
        if !active { active = true }
        guard idleCheck == nil else { return }
        idleCheck = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                let now = Date.now
                let quiet = self.held.allSatisfy(\.isEmpty)
                    && self.level.indices.allSatisfy { self.level(track: $0, at: now) == 0 && self.level(track: $0, muted: true, at: now) == 0 }
                if quiet { self.active = false; self.idleCheck = nil; return }
            }
        }
    }
}

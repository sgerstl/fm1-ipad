// P6's areas from DeviceSession as the iPad's Timeline and motion lanes read the same state: the song store's blocks
// (SongPlacement: start and length in ticks from the patterns' lengths and divisions), its marks, and MOTION.
import Foundation
import SloopKit

extension PhoneCore {
    // MARK: timeline

    public func timelineArea() -> TimelineArea {
        let s = session
        let store = s.skiffSong
        let song = store?.song
        let perBar = SongPlacement.ticksPerBar
        let mode: String = switch song?.mode ?? .off { case .off: "off"; case .on: "on"; case .once: "once" }
        let perf = store?.perform
        var tracks: [TimelineArea.Track] = []
        for t in s.trackIndices {
            let list = song?.tracks[safe: t]
            let blocks = store?.blocks(t) ?? []
            let marks = store?.marks(t, launchIn: nil) ?? SongPlayback.Marks()
            let out = blocks.map { b -> TimelineArea.Block in
                let pats = b.entries.compactMap { i -> Int? in
                    guard let e = list?.entries[safe: i], e.pattern >= 1, e.pattern <= 64 else { return nil }
                    return e.pattern
                }
                let kind: String = switch b.kind { case .pattern: "pattern"; case .rest: "rest"; case .gap: "gap" }
                let hasSound = list?.entries[safe: b.entries.lowerBound]?.sound != nil
                return TimelineArea.Block(id: b.id, first: b.entries.lowerBound, last: b.entries.upperBound, kind: kind,
                                          pattern: pats.first, patterns: pats, reps: b.reps,
                                          startBar: (b.start / perBar * 1000).rounded() / 1000,
                                          lengthBars: (b.length / perBar * 1000).rounded() / 1000,
                                          passBars: (b.pass / perBar * 1000).rounded() / 1000,
                                          hasSound: hasSound, playing: marks.playing == b.id, pass: marks.playing == b.id ? marks.pass : nil,
                                          next: marks.next == b.id, queued: marks.queued == b.id)
            }
            let used = list?.span.map { $0.upperBound + 1 } ?? 0
            tracks.append(TimelineArea.Track(track: t + 1, name: s.tracks[t].displayName, muted: perf?.muted[safe: t] ?? s.tracks[t].mute,
                                             blocks: out, endBar: ((blocks.last?.end ?? 0) / perBar * 1000).rounded() / 1000, entriesUsed: used))
        }
        let bars = tracks.map(\.endBar).max() ?? 0
        // to the beat only (it was a hundredth of a bar: the whole area 19 times a second while playing). The smooth
        // playhead is the clock's: ticksNow / ticksPerBar (ClockArea.swift)
        let head: Double? = s.playing && s.clockTicks >= 0 ? Double(s.clockTicks / 24) * 24 / perBar : nil
        let kept = (0..<64).filter { (store?.pool?.patterns[safe: $0]?.length ?? 0) > 0 }.map { $0 + 1 }
        return TimelineArea(mode: mode, tracks: tracks, bars: bars, playheadBar: head, ticksPerBar: perBar, playing: s.playing, kept: kept, patternsFree: store?.pool?.free, clearUndo: clearUndos())
    }

    // MARK: automation

    func paramID(_ label: String) -> Int? { session.trackDescs.first { $0.value.label == label }?.key }

    public func automationArea() -> AutomationArea {
        let s = session, t = editorTrack()
        let m = s.motion[t] ?? TrackMotion()
        func label(_ id: Int) -> String { s.trackDescs[id]?.label ?? "P\(id)" }
        let ids = Array(Set(m.events.map(\.id))).sorted { label($0) < label($1) }
        let lanes = ids.map { id in
            AutomationArea.Lane(param: label(id), id: id, recorded: m.events.filter { $0.id == id && !$0.lock }.count,
                                locks: m.events.filter { $0.id == id && $0.lock }.count)
        }
        // the lane shown: the one picked (here or in the editor), else the first recorded; a picked one with nothing
        // on it yet stays shown, so a first stroke can go on it
        let lane = pickedLane.flatMap { paramID($0) != nil ? $0 : nil } ?? lanes.first?.param ?? ""
        let steps = max(1, min(64, s.tracks[t].length))
        var lo = 0, hi = 127, base = 0
        var points: [AutomationArea.Point] = []
        if let id = paramID(lane) {
            let d = s.trackDescs[id]
            lo = d?.min ?? 0; hi = max(lo, d?.max ?? 127)
            base = t == s.selectedTrack ? s.cell(id).value : (s.everyTrack[id]?[t] ?? d?.defaultValue ?? lo)
            points = (0..<steps).map { k in
                let r = m.value(of: id, at: k, base: base)
                let src: String = switch r.source { case .lock: "lock"; case .recorded: "recorded"; case .sound: "sound" }
                return AutomationArea.Point(step: k, value: r.value, source: src, text: formatValue(d, r.value, skiff: true).shown)
            }
        }
        let pattern = s.skiffSong?.song?.tracks[safe: t].flatMap { l in l.entryOn.flatMap { l.entries[safe: $0]?.pattern } } ?? 0
        return AutomationArea(track: t + 1, pattern: pattern, steps: steps, lanes: lanes, lane: lane, min: lo, max: hi, base: base,
                              points: points, used: s.motionUsed, capacity: DeviceSession.motionMax)
    }
}

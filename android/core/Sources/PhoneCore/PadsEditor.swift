// The pads and editor areas (P3), built the way the iPad's Pads page reads the same state
// (ios/FM1/PadsTrackStrip.swift: LIST2's lists, PERFORM's mutes and scenes, SkiffSongStore.marks, the counted clock).
import Foundation
import SloopKit

extension PhoneCore {
    /// The trig conditions by COND number (ios/FM1/StepInspector.swift's table; 0 is "ALWAYS" on the phone).
    static let conditions = ["ALWAYS", "FILL", "!FILL", "1:2", "2:2", "1:3", "2:3", "3:3", "1:4", "2:4", "3:4", "4:4"]
    /// The kit lanes' short names (ios/FM1/SkiffEditPages.swift laneShort).
    static let laneShort = ["BD", "SD", "CP", "CH", "OH", "TM", "RS", "CB"]

    public func padsArea() -> PadsArea {
        let s = session
        let store = s.skiffSong
        let song = store?.song
        let perf = store?.perform
        let tracks = s.trackIndices
        // Columns: entries A… up to the last any track uses, plus one empty (at most 16).
        let lastUsed = tracks.compactMap { t in song?.tracks[safe: t]?.entries.lastIndex { !$0.isEmpty } }.max() ?? -1
        let columns = max(1, min(16, lastUsed + 2))
        var rows: [PadsArea.Row] = []
        for t in tracks {
            let list = song?.tracks[safe: t]
            let marks = store?.marks(t, launchIn: s.ticksToLaunch(t)) ?? SongPlayback.Marks()
            var entries: [PadsArea.Entry] = []
            for e in 0..<columns {
                var p = PadsArea.Entry()
                let se = list?.entries[safe: e] ?? .empty
                p.kind = se.isEmpty ? .empty : se.isRest ? .rest : .pattern
                if p.kind == .pattern { p.pattern = se.pattern }
                p.hasSound = se.sound != nil
                if list?.entryOn == e {
                    // The entry the track is on: lit stopped too (where it starts); progress only while playing.
                    p.play = .playing
                    if marks.reps > 1 { p.passes = marks.reps; p.pass = marks.pass }
                    if s.playing, let prog = s.passProgress(t) { p.progress = (prog * 100).rounded() / 100 }
                } else if list?.staged == e {
                    if marks.queued != nil {
                        p.play = .waiting
                        if let left = s.ticksToLaunch(t), s.clockTicks >= 0 { p.bar = (s.clockTicks + Int(left)) / 96 + 1 }
                        p.launchTick = launchTick(t)
                    } else {
                        p.play = .next
                    }
                } else if list?.staged == nil, marks.next == e {
                    p.play = .next
                }
                entries.append(p)
            }
            let muted = perf?.muted[safe: t] ?? s.tracks[t].mute
            var row = PadsArea.Row(track: t + 1, name: s.tracks[t].displayName, muted: muted, entries: entries)
            if let pc = passClock(t) { row.passTicks = pc.ticks; row.passStartTick = pc.start }
            switch perf?.staged[safe: t] ?? PerformState.Staged.none { case .mute: row.mutePending = "mute"; case .unmute: row.mutePending = "unmute"; case .none: break }
            row.soloPending = store?.soloWaiting[t] != nil
            let waits = row.mutePending != "none" || row.soloPending || entries.contains { $0.play == .waiting }
            if waits { row.launchTick = launchTick(t) }
            rows.append(row)
        }
        let scenes = (0..<16).map { i -> PadsArea.Scene in
            var sc = PadsArea.Scene(stored: perf?.kept[safe: i] ?? false, current: perf?.lastScene == i)
            if let w = store?.recallWaiting, w.scene == i { sc.waiting = true; sc.launchTick = w.tracks.compactMap { launchTick($0) }.max() }
            return sc
        }
        let kept = (0..<64).filter { (store?.pool?.patterns[safe: $0]?.length ?? 0) > 0 }.map { $0 + 1 }
        let pool = store?.pool
        let unused = (0..<64).filter { pool?.patterns[safe: $0].map { $0.length > 0 && $0.uses == 0 } ?? false }.map { $0 + 1 }
        return PadsArea(rows: rows, scenes: scenes, selected: selectedPad(), kept: kept, patternsFree: pool?.free, unused: unused, clearUndo: clearUndos())
    }

    /// The pad the editor shows: the one the screen picked (padSelect), else the selected track's current entry.
    func selectedPad() -> PadsArea.Ref {
        if let p = pickedPad, pickedOnTrack == session.selectedTrack { return p }
        let t = session.selectedTrack
        return PadsArea.Ref(track: t + 1, entry: session.skiffSong?.song?.tracks[safe: t]?.entryOn ?? 0)
    }

    /// How many steps the editor carries for track `t`: its LENGTH rounded up to whole chunks of 16, at least one
    /// chunk and at most the FM-1's NSTEP. The steps past LENGTH in the last chunk are there (the FM-1 holds them)
    /// but don't play.
    func editorStepCount(_ t: Int) -> Int {
        let s = session
        guard s.tracks.indices.contains(t) else { return 16 }
        let len = max(1, min(s.stepCount, s.tracks[t].length))
        return max(16, min(s.stepCount, (len + 15) / 16 * 16))
    }

    public func editorArea() -> EditorArea {
        let s = session
        let ref = selectedPad()
        let t = max(0, min(s.tracks.count - 1, ref.track - 1))
        let tr = s.tracks[t]
        let list = s.skiffSong?.song?.tracks[safe: t]
        let on = list?.entryOn
        let entry = on ?? ref.entry
        let kit = s.isKit(t)
        // every step of the pattern, in whole 16-step chunks (the Edit grid scrolls by chunk): 16, 32, 48 or 64
        let count = editorStepCount(t)
        let src = Array(tr.steps.prefix(count))
        var steps: [EditorArea.Step] = []
        for (i, st) in src.enumerated() {
            var e = EditorArea.Step()
            if kit {
                let lanes = (0..<8).filter { st.kitLanes.has($0) }
                e.on = !lanes.isEmpty
                e.hits = lanes.map { EditorArea.Hit(lane: $0, accent: st.kitLanes.level($0) != 0) }
                e.note = lanes.map { Self.laneShort[$0] }.joined(separator: " ")
                e.pitchText = e.note
            } else {
                e.on = st.isOn
                if e.on {
                    e.notes = st.notes
                    e.note = Music.noteName(st.notes[0])
                    e.extra = st.notes.count - 1
                    e.pitchText = st.notes.map(Music.noteName).joined(separator: " ")
                    var len = 1
                    while i + len < src.count, src[i + len].time == .tie { len += 1 }
                    e.length = len
                    var cap = 1
                    while i + cap < tr.steps.count, tr.steps[i + cap].time != .note { cap += 1 }
                    e.maxLength = min(16, cap)
                }
            }
            if !kit, st.time == .tie, let start = (0..<i).last(where: { src[$0].time != .tie }), src[start].isOn { e.heldFrom = start }
            e.velocity = st.velocity == 0 ? 96 : st.velocity       // 0 plays as 96 (seq.c seq_step)
            // Skiff's bytes after the velocity: hits (3), chance, ratchet, FLAM, COND, NUDGE + 32, ties.
            let x = st.extra
            if x.count > 3 { e.chance = Int(x[3]) }
            if x.count > 4 { e.ratchet = max(1, Int(x[4])) }
            if x.count > 6 { e.cond = Self.conditions[safe: Int(x[6])] ?? "C\(x[6])" }
            if x.count > 7 { e.nudge = Int(x[7]) - 32 }
            steps.append(e)
        }
        while steps.count < count { steps.append(EditorArea.Step()) }
        // MOTION (read every few seconds): a step's locks and recorded changes as its values; the lanes the track has
        let m = s.motion[t] ?? TrackMotion()
        func label(_ id: Int) -> String { s.trackDescs[id]?.label ?? "P\(id)" }
        for (k, _) in steps.enumerated() {
            steps[k].values = m.events.filter { $0.step == k }.sorted { ($0.lock ? 0 : 1, label($0.id)) < ($1.lock ? 0 : 1, label($1.id)) }
                .map { EditorArea.Value(param: label($0.id), value: $0.value, locked: $0.lock) }
            steps[k].locked = steps[k].values.contains { $0.locked }
        }
        let laneIDs = Array(Set(m.events.map(\.id))).sorted { label($0) < label($1) }
        let lanes = laneIDs.map(label)
        let lane = pickedLane.flatMap { l in lanes.contains(l) ? l : nil } ?? lanes.first ?? ""
        var laneValues: [Int] = []
        if let id = laneIDs.first(where: { label($0) == lane }) {
            let d = s.trackDescs[id], lo = d?.min ?? 0, hi = max(lo + 1, d?.max ?? 127)
            let base = t == s.selectedTrack ? s.cell(id).value : lo
            laneValues = (0..<count).map { k in ((m.value(of: id, at: k, base: base).value - lo) * 100 / (hi - lo)).clamped(0, 100) }
        }
        var playhead = -1
        if s.playing, let prog = s.passProgress(t) {
            let i = Int(prog * Double(max(1, tr.length)))
            if i < count { playhead = i }
        }
        let scaleName = Music.scales[safe: tr.scale]?.name.lowercased() ?? ""
        return EditorArea(
            track: t + 1, trackName: tr.displayName,
            entry: String(UnicodeScalar(UInt8(65 + max(0, min(25, entry))))),
            pattern: list?.entries[safe: entry]?.pattern ?? 0,
            scale: kit ? "" : "\(Music.noteNames[((tr.root % 12) + 12) % 12]) \(scaleName)",
            kind: kit ? .drum : .roll, steps: steps, selected: selectedStep, playhead: playhead,
            chord: false, lock: heldStep != nil ? .held : lockLatched ? .latched : .off,
            lanes: lanes, lane: lane, laneValues: laneValues,
            maxNotes: kit ? 0 : Self.maxStepNotes, kitLanes: kit ? Self.laneShort : [], kitNotes: kit ? Music.skiffLaneNotes : [],
            patternSteps: max(1, min(s.stepCount, tr.length)), patternStepsMax: s.stepCount)
    }
}

extension Int { func clamped(_ lo: Int, _ hi: Int) -> Int { Swift.max(lo, Swift.min(hi, self)) } }

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

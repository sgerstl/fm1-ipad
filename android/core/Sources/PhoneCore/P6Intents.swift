// P6's intents on the real FM-1. The timeline's block edits are a port of the iPad's ArrangeEdits
// (ios/FM1/SkiffArrangeParts.swift), the same SloopKit pieces in the same order: the track's entries, a change, the song
// store's rewrite. (A follow-up: move ArrangeEdits itself into SloopKit so both share one copy; that touches the
// iPad and needs its device check.) Automation draws through MotionPaint.plan and Session.paintMotion as the iPad's lane
// (ios/FM1/MotionLanes.swift), and clears with clearMotionLane. Writes are refused while read-only; drawing over
// recorded changes (decision 16), clearing a lane, and an edit that would erase a pattern wait for the confirm.
import Foundation
import SloopKit

extension PhoneCore {
    func handle(_ i: P6Intent) {
        if i.writes && !canWrite() {
            log("read-only: \(i) not sent (allow writes to send it)")
            return
        }
        let s = session
        switch i {
        case .automationLane(let lane):
            pickedLane = lane
            pokeAreas(["automation", "editor"])
        case .drawLane(let param, let from, let values, let lock, let confirmed):
            drawLane(param: param, from: from, values: values, lock: lock, confirmed: confirmed)
        case .clearLane(let param, let confirmed):
            let t = editorTrack()
            guard let id = paramID(param) else { log("no parameter named \(param)"); return }
            guard confirmed else { log("clearing the \(param) lane removes its records: the screen must confirm"); return }
            Task { await s.clearMotionLane(track: t, id: id); self.pokeAreas(["automation", "editor"]) }
        default:
            blockEdit(i)
        }
    }

    // MARK: automation

    func drawLane(param: String, from: Int, values: [Int], lock: Bool, confirmed: Bool) {
        let s = session, t = editorTrack()
        guard let id = paramID(param) else { log("no parameter named \(param)"); return }
        guard s.dialect == .skiff else { return }
        let steps = max(1, min(64, s.tracks[t].length))
        let d = s.trackDescs[id], lo = d?.min ?? 0, hi = max(lo, d?.max ?? 127)
        var painted: [Int: Int] = [:]
        for (k, v) in values.enumerated() where (0..<steps).contains(from + k) { painted[from + k] = max(lo, min(hi, v)) }
        guard !painted.isEmpty else { log("drawLane: no step of the pattern in \(from)…\(from + values.count - 1)"); return }
        let m = s.motion[t] ?? TrackMotion()
        let base = t == s.selectedTrack ? s.cell(id).value : (s.everyTrack[id]?[t] ?? d?.defaultValue ?? lo)
        // decision 16: where the lane shows recorded data (a change on the step, or one held from before it, as the
        // lane draws it) the screen asks first, in place
        if !confirmed, painted.keys.contains(where: { m.value(of: id, at: $0, base: base).source == .recorded }) {
            log("drawing over the recorded \(param): the screen must confirm first (decision 16)"); return
        }
        let plan = MotionPaint.plan(events: m.events, id: id, base: base, painted: painted, lock: lock, steps: steps, restore: values.count > 1)
        guard !plan.writes.isEmpty || !plan.deletes.isEmpty else { return }
        if s.motionUsed + plan.cost > DeviceSession.motionMax {
            log("MOTION holds \(DeviceSession.motionMax) records across all tracks: this stroke needs \(plan.cost), \(DeviceSession.motionMax - s.motionUsed) are free")
        }
        Task {
            if let rc = await s.paintMotion(track: t, id: id, plan: plan) {
                self.log(rc == .full ? "the FM-1's 64 motion records are full: part of the stroke went in"
                         : rc == .songPlaying ? "the FM-1 refused the stroke while the song plays"
                         : "the FM-1 refused that change: \(param) can't be recorded as motion, or the value is out of range")
            }
            self.pokeAreas(["automation", "editor"])
        }
    }

    // MARK: timeline (ArrangeEdits)

    /// The track's entries, dangling CHAIN flags off (anything moved in after one would join it).
    func arrangeEntries(_ t: Int) -> [SongEntry]? {
        session.skiffSong?.song?.tracks[safe: t].map { SongSections.unchainDangling($0.entries) }
    }

    /// Whether `n` more entries fit (16 a track); refused with the iPad's words when not.
    func arrangeFull(_ t: Int, adding n: Int = 1) -> Bool {
        guard let store = session.skiffSong, let l = store.song?.tracks[safe: t] else { return true }
        let span = l.span.map { $0.upperBound + 1 } ?? 0
        if span + n > 16 {
            log("T\(t + 1) has all 16 entries. Play one entry more times, or chain two, to free a slot"); return true
        }
        return false
    }

    /// The rewrite, after the iPad's checks: a list the FM-1 can't take is refused with the store's reason; one that
    /// would erase a pattern nothing else uses waits for the screen's confirm.
    func arrangeRewrite(_ t: Int, _ es: [SongEntry], focus: Int, confirmed: Bool, what: String) {
        guard let store = session.skiffSong else { return }
        if let why = store.blocked(track: t, to: es) { log("\(what): \(why)"); return }
        let gone = store.erased([t: es])
        if !gone.isEmpty, !confirmed {
            log("\(what) erases pattern \(gone.map { String($0 + 1) }.joined(separator: ", ")) (used nowhere else): the screen must confirm"); return
        }
        Task { if !(await store.rewrite(track: t, to: es, focus: focus, confirmed: true)) { self.reportRefusal(store) } }
    }

    func blockEdit(_ i: P6Intent) {
        let s = session
        guard let store = s.skiffSong else { log("no song read yet"); return }
        func block(_ t: Int, _ id: Int) -> SongBlock? {
            let b = store.blocks(t).first { $0.id == id }
            if b == nil { log("no block at T\(t + 1) entry \(id + 1)") }
            return b
        }
        switch i {
        case .blockInsert(let t1, let at, let p):
            guard let t = track(t1), var es = arrangeEntries(t), !arrangeFull(t) else { return }
            guard p == SongEntry.rest || (store.pool?.patterns[safe: p - 1]?.length ?? 0) > 0 else {
                log("pattern \(p) holds nothing on the FM-1: insert a kept one, or New pattern"); return
            }
            let k = max(0, min(at, es.count))
            es.insert(SongEntry(pattern: p), at: k)
            arrangeRewrite(t, Array(es.prefix(16)), focus: k, confirmed: true, what: "Insert")
        case .blockNew(let t1):
            guard let t = track(t1), let l = store.song?.tracks[safe: t], !arrangeFull(t) else { return }
            let at = l.span.map { $0.upperBound + 1 } ?? 0
            Task { if !(await store.send(.new(track: t, entry: at))) { self.reportRefusal(store) } }
        case .blockMove(let t1, let id, let by):
            guard let t = track(t1), let l = store.song?.tracks[safe: t], let b = block(t, id) else { return }
            let blocks = store.blocks(t)
            guard let k = blocks.firstIndex(where: { $0.id == b.id }), blocks.indices.contains(k + by) else { log("Move: no place there"); return }
            let mv = SongSections.move(list: l, blocks: blocks, block: k, to: k + by)
            guard !mv.unchanged, let es = mv.result else { return }
            arrangeRewrite(t, es, focus: mv.index, confirmed: true, what: "Move")
        case .blockStretch(let t1, let id, let reps):
            guard let t = track(t1), var es = arrangeEntries(t), let b = block(t, id) else { return }
            es[b.entries.upperBound].reps = max(1, min(16, reps))      // a chain repeats whole on its last entry's
            arrangeRewrite(t, es, focus: b.entries.lowerBound, confirmed: true, what: "Stretch")
        case .blockDelete(let t1, let id, let confirmed):
            guard let t = track(t1), var es = arrangeEntries(t), let b = block(t, id), let sp = store.song?.tracks[safe: t]?.span else { return }
            es.removeSubrange(b.entries)
            es += Array(repeating: .empty, count: 16 - es.count)
            // a rest left at the start or end would be passed over: it stays a rest
            es = SongSections.restsAtEdges(es, range: sp.lowerBound..<(sp.upperBound + 1 - b.entries.count))
            arrangeRewrite(t, es, focus: b.entries.lowerBound, confirmed: confirmed, what: "Delete")
        case .blockSetPattern(let t1, let id, let p, let confirmed):
            guard let t = track(t1), var es = arrangeEntries(t), let b = block(t, id) else { return }
            guard p == SongEntry.rest || (store.pool?.patterns[safe: p - 1]?.length ?? 0) > 0 else {
                log("pattern \(p) holds nothing on the FM-1: Set pattern takes a kept one"); return
            }
            es[b.entries.lowerBound].pattern = p
            arrangeRewrite(t, es, focus: b.entries.lowerBound, confirmed: confirmed, what: "Set pattern")
        case .blockDuplicate(let t1, let id):
            guard let t = track(t1), var es = arrangeEntries(t), let b = block(t, id), !arrangeFull(t, adding: b.entries.count) else { return }
            es.insert(contentsOf: Array(es[b.entries]), at: b.entries.upperBound + 1)
            arrangeRewrite(t, Array(es.prefix(16)), focus: b.entries.upperBound + 1, confirmed: true, what: "Duplicate")
        case .blockChain(let t1, let id):
            guard let t = track(t1), var es = arrangeEntries(t), let b = block(t, id) else { return }
            guard b.kind != .gap, b.entries.upperBound < 15, !es[b.entries.upperBound + 1].isEmpty else { log("Nothing after it to chain into"); return }
            es[b.entries.upperBound].chained = true
            arrangeRewrite(t, es, focus: b.entries.lowerBound, confirmed: true, what: "Chain")
        case .blockSplit(let t1, let id):
            guard let t = track(t1), var es = arrangeEntries(t), let b = block(t, id) else { return }
            for k in b.entries { es[k].chained = false; es[k].reps = 1 }
            arrangeRewrite(t, es, focus: b.entries.lowerBound, confirmed: true, what: "Split")
        default: break
        }
    }
}

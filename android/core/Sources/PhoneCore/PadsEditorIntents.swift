// P3's pads and editor intents on the real FM-1, each through the call the iPad uses for the same thing
// (ios/FM1/PadsPage.swift, PadsTrackStrip.swift, StepInspector.swift). Writes are refused up front while the link is
// read-only (`canWrite`), so Session's optimistic copy never shows a change the FM-1 didn't get; ReadOnlyGuard stays
// the second layer underneath.
import Foundation
import SloopKit

/// What Compose sends from the Pads tab and the editor (P3's Intent.kt), decoded.
public enum PadEditIntent: Equatable, Sendable {
    case padTap(track: Int, entry: Int)          // track 1-based, entry 0-based
    case padNew(track: Int, entry: Int)
    case padSet(track: Int, entry: Int, pattern: Int)
    case padClear(track: Int, entry: Int)
    case padSelectSound(track: Int, entry: Int)
    case trackSelect(Int)
    case trackMute(Int)
    case sceneStore(Int, confirmed: Bool)        // 0-based; over a kept scene only when confirmed (Scott, 2026-11-14)
    case sceneRecall(Int)
    case stepHold(step: Int, down: Bool)
    case stepAdjust(field: String, delta: Int)
    case lockToggle
    case lockClear(step: Int, param: String)
    case locksClearAll(step: Int)
    case stepAction(step: Int, action: String)   // copy, paste, clear
    case lanePick(String)

    private struct Wire: Decodable {
        let intent: String
        let track: Int?, entry: Int?, pattern: Int?, scene: Int?, step: Int?, down: Bool?
        let field: String?, delta: Int?, param: String?, action: String?, lane: String?, confirmed: Bool?
    }

    /// nil: not one of these.
    static func decode(_ json: String) throws -> PadEditIntent? {
        let w = try JSONDecoder().decode(Wire.self, from: Data(json.utf8))
        func need<T>(_ v: T?, _ f: String) throws -> T { guard let v else { throw PhoneIntent.DecodeError.missing("\(w.intent).\(f)") }; return v }
        switch w.intent {
        case "padTap": return .padTap(track: try need(w.track, "track"), entry: try need(w.entry, "entry"))
        case "padNew": return .padNew(track: try need(w.track, "track"), entry: try need(w.entry, "entry"))
        case "padSet": return .padSet(track: try need(w.track, "track"), entry: try need(w.entry, "entry"), pattern: try need(w.pattern, "pattern"))
        case "padClear": return .padClear(track: try need(w.track, "track"), entry: try need(w.entry, "entry"))
        case "padSelectSound": return .padSelectSound(track: try need(w.track, "track"), entry: try need(w.entry, "entry"))
        case "trackSelect": return .trackSelect(try need(w.track, "track"))
        case "trackMute": return .trackMute(try need(w.track, "track"))
        case "sceneStore": return .sceneStore(try need(w.scene, "scene"), confirmed: w.confirmed ?? false)
        case "sceneRecall": return .sceneRecall(try need(w.scene, "scene"))
        case "stepHold": return .stepHold(step: try need(w.step, "step"), down: try need(w.down, "down"))
        case "stepAdjust": return .stepAdjust(field: try need(w.field, "field"), delta: try need(w.delta, "delta"))
        case "lockToggle": return .lockToggle
        case "lockClear": return .lockClear(step: try need(w.step, "step"), param: try need(w.param, "param"))
        case "locksClearAll": return .locksClearAll(step: try need(w.step, "step"))
        case "stepAction": return .stepAction(step: try need(w.step, "step"), action: try need(w.action, "action"))
        case "lanePick": return .lanePick(try need(w.lane, "lane"))
        default: return nil
        }
    }

    /// Whether it changes the FM-1 (refused while read-only). Select, hold, Chord and the lane are the screen's own.
    var writes: Bool {
        switch self {
        case .lanePick, .stepHold, .lockToggle: false
        case .stepAction(_, let a): a != "copy"
        default: true
        }
    }
}

extension PhoneCore {
    /// The store's word on an op it turned down (one op at a time, stopped only, patterns full…), into the log;
    /// the screens show it once there's an area for it.
    func reportRefusal(_ store: SkiffSongStore) {
        if let r = store.refusal { log("FM-1 refused: \(r.text)") }
    }

    /// The panel's step for one StepAdjust unit, as the − / + keys step (P3's fake: VELOCITY 4, CHANCE 5, the rest 1).
    static let unit: [String: Int] = ["velocity": 4, "chance": 5]

    func handle(_ i: PadEditIntent) {
        if i.writes && !canWrite() {
            log("read-only: \(i) not sent (allow writes to send it)")
            return
        }
        let s = session
        let store = s.skiffSong
        switch i {
        // MARK: pads (PadsPage.swift)
        case .padTap(let t1, let e):
            let t = t1 - 1
            guard let store, let list = store.song?.tracks[safe: t] else { return }
            guard !(list.entries[safe: e]?.isEmpty ?? true) else { return }       // an empty pad: the screen's menu
            // a waiting pad tapped again takes its launch back: the entry playing is relaunched in its place
            if list.staged == e, s.playing, let on = list.entryOn { store.launch(track: t, entry: on); return }
            store.launch(track: t, entry: e)
        case .padNew(let t1, let e):
            let t = t1 - 1
            guard let store else { return }
            Task {
                guard await store.send(.new(track: t, entry: e)) else { self.reportRefusal(store); return }
                if s.playing { await store.send(.play(track: t, entry: e)) }
                self.pickedPad = PadsArea.Ref(track: t1, entry: e)
                self.pokeAreas(["pads", "editor"])
            }
        case .padSet(let t1, let e, let p):
            guard let store else { return }
            // LIST SET names a kept pattern (or 65, a REST): an empty number is refused by the FM-1 (rc 1)
            if p != SongEntry.rest, (store.pool?.patterns[safe: p - 1]?.length ?? 0) == 0 {
                log("pattern \(p) holds nothing on the FM-1: Set pattern takes a kept one (New pattern makes a new one)")
                return
            }
            Task { if !(await store.send(.set(track: t1 - 1, entry: e, pattern: p))) { reportRefusal(store) } }
        case .padClear(let t1, let e):
            guard let store else { return }
            Task { if !(await store.send(.clear(track: t1 - 1, entry: e))) { reportRefusal(store) } }
        case .padSelectSound:
            log("padSelectSound not wired: the entry's sound picker is a later phase")
        case .trackSelect(let t1):
            // the track head: the selection moves and any pad pick goes with it (the editor shows the track's own entry)
            pickedPad = nil
            s.select(track: t1 - 1)
            pokeAreas(["pads", "editor"])
        case .trackMute(let t1):
            guard let store else { return }
            Task { if !(await store.performOp(.mute(track: t1 - 1))) { reportRefusal(store) } }
        case .sceneStore(let k, let confirmed):
            guard let store else { return }
            // Over a kept scene the screen confirms in place first, like Clear (Scott, 2026-11-14) and sends
            // confirmed; an empty scene stores at once. An unconfirmed store over a kept one is refused here.
            if store.perform?.kept[safe: k] == true, !confirmed {
                log("scene \(k + 1) is kept: the screen must confirm before replacing it (sceneStore confirmed)")
                return
            }
            Task { if !(await store.performOp(.store(scene: k), confirmed: true)) { reportRefusal(store) } }
        case .sceneRecall(let k):
            guard let store else { return }
            Task { if !(await store.performOp(.recall(scene: k))) { reportRefusal(store) } }

        // MARK: editor (StepInspector.swift)
        case .stepHold(let step, let down):
            if down { heldStep = step } else { heldStep = nil }
            syncLockStep()
        case .lockToggle:
            lockLatched.toggle()
            syncLockStep()
        case .lanePick(let lane):
            pickedLane = lane
            pokeAreas(["editor"])
        case .stepAdjust(let field, let delta):
            adjust(field: field, delta: delta)
        case .lockClear(let step, let param):
            let t = editorTrack()
            guard let id = s.trackDescs.first(where: { $0.value.label == param })?.key else { log("no parameter named \(param)"); return }
            Task { await s.deleteMotion(track: t, step: step, id: id) }
        case .locksClearAll(let step):
            let t = editorTrack()
            Task { await s.clearLocks(track: t, step: step) }
        case .stepAction(let step, let action):
            let t = editorTrack()
            guard s.tracks.indices.contains(t), s.tracks[t].steps.indices.contains(step) else { return }
            switch action {
            case "copy": copiedStep = s.tracks[t].steps[step]
            case "paste": if let c = copiedStep { s.write(track: t, index: step, c) }
            case "clear":
                s.write(track: t, index: step, .empty)
                Task { await s.clearLocks(track: t, step: step) }
            default: log("unknown step action \(action)")
            }
        }
    }

    /// The track the editor shows: the picked pad's, else the selected one.
    func editorTrack() -> Int { max(0, min(session.tracks.count - 1, selectedPad().track - 1)) }

    /// Lock held (a step pressed) or latched (the Lock key): knob turns sent from Lupe lock to the step
    /// (Session.lockStep, as the iPad's Lock does). The FM-1's own knobs keep changing the sound.
    func syncLockStep() {
        session.lockStep = heldStep ?? (lockLatched ? selectedStep : nil)
        pokeAreas(["editor"])
    }

    /// One − / + unit on a field of the selected step, as the iPad's step panel writes it.
    func adjust(field: String, delta d: Int) {
        let s = session, t = editorTrack(), i = selectedStep
        guard s.tracks.indices.contains(t), s.tracks[t].steps.indices.contains(i) else { return }
        var st = s.tracks[t].steps[i]
        let n = d * (Self.unit[field] ?? 1)
        switch field {
        case "pitch":
            if s.isKit(t) {
                // LANE: each hit moves to the next lane
                let lanes = st.kitLanes
                var moved = DrumStep.empty
                for l in 0..<8 where lanes.has(l) { moved = moved.setting(((l + n) % 8 + 8) % 8, on: true, level: lanes.level(l)) }
                s.write(track: t, index: i, st.withHits(moved))
            } else {
                guard st.isOn else { return }
                st.notes = st.notes.map { min(127, max(0, $0 + n)) }   // the chord moves together
                s.write(track: t, index: i, st)
            }
        case "move":
            // swapped with what's there, the selection with it
            let j = i + n
            guard s.tracks[t].steps.indices.contains(j) else { return }
            let a = s.tracks[t].steps[i], b = s.tracks[t].steps[j]
            s.write(track: t, index: j, a)
            s.write(track: t, index: i, b)
            selectedStep = j
            if lockLatched { syncLockStep() }
            pokeAreas(["editor"])
        case "length":
            var len = 1
            while i + len < s.tracks[t].steps.count, s.tracks[t].steps[i + len].time == .tie { len += 1 }
            var cap = 1
            while i + cap < s.tracks[t].steps.count, s.tracks[t].steps[i + cap].time != .note { cap += 1 }
            if len + n > cap { log("LENGTH can't grow past \(cap): step \(i + cap + 1) holds a note") }
            s.setLength(track: t, start: i, steps: max(1, min(16, s.tracks[t].steps.count - i, len + n)))
        case "velocity":
            st.velocity = max(1, min(127, (st.velocity == 0 ? 96 : st.velocity) + n))
            s.write(track: t, index: i, st)
        case "ratchet":
            let r = max(0, min(3, (st.ratchets.first ?? 0) + n))
            st.ratchets = Array(repeating: r, count: max(1, st.notes.count))
            s.write(track: t, index: i, st)
        case "chance", "cond", "nudge":
            // Skiff's bytes after the velocity: hits ×3, chance, ratchet, FLAM, COND, NUDGE + 32, ties
            let (k, lo, hi, base) = field == "chance" ? (3, 0, 100, 0) : field == "cond" ? (6, 0, 11, 0) : (7, -32, 31, 32)
            guard st.extra.count > k else { log("this step has no \(field) on this firmware"); return }
            let now = Int(st.extra[k]) - base
            st.extra[k] = UInt8(max(lo, min(hi, now + n)) + base)
            s.write(track: t, index: i, st)
        default:
            log("unknown step field \(field)")
        }
    }
}

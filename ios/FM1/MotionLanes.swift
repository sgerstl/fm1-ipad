import SloopKit
import SwiftUI

// Skiff's motion under the grid (canvas boards 15 and 16, design/boards/steps.py, stepstates.py; 2026-11-05): one
// lane per recorded parameter. A recorded change draws as a step-and-hold line in the track's colour (it holds
// until the next change; each pass starts from the sound, motion.c motion_restore), a lock as a diamond on its step
// (that step only), the sound's own value as a dashed baseline. The selected step's column runs through every
// lane. The 64 records are shared by all tracks.
//
// Touch editing, approach A (Scott's pick, 2026-11-06; canvas "Lupe motion lane editing", qa/motion-design-2026-11-06):
// a closed lane is a button the full width; tapped, it opens in place into a 140 pt editor. There you draw across
// steps to paint (MotionPaint: a change only where the value changes, what played after the stroke put back), drag a
// point up or down, or tap a step to set it there. The header says the selected step's value and what it is, with
// − / + (the path without dragging), Hold or Lock (what a touch writes), ⋯ and Done. Edited with the song stopped:
// playing, the editor dims and offers Stop.

/// The header and the lanes, for the selected track; `offsetX` is the grid's pan (one bar in view).
struct MotionLanes: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let offsetX: CGFloat
    let width: CGFloat
    @Environment(\.grid) private var grid
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A closed lane (28 before the editor; 36 so it's a fair target the full width).
    static let laneHeight: CGFloat = 36
    /// Closed lanes shown at once; more scroll.
    static let visibleLanes = 4
    /// Closed lanes kept in view beside an open one.
    static let besideOpen = 2

    /// The parameters with a lane: those with records, then any added with + Lane.
    static func laneIDs(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> [Int] {
        var ids = session.motion[track]?.ids ?? []
        for id in ui.addedLanes[track] ?? [] where !ids.contains(id) && recordable(session, id) { ids.append(id) }
        return ids
    }

    /// A parameter the firmware records as motion: on Skiff only motion_param's (SkiffMotion), else any.
    static func recordable(_ session: DeviceSession, _ id: Int) -> Bool { session.dialect != .skiff || SkiffMotion.recordable(id) }

    /// Skiff refused a write on this track in the last few seconds: what to say on the lanes.
    static func refusal(_ session: DeviceSession, track: Int) -> String? {
        guard let r = session.motionRefusal, r.track == track, Date.now.timeIntervalSince(r.at) < 6 else { return nil }
        let label = session.trackDesc(r.id)?.label ?? "This parameter"
        switch r.rc {
        case .invalid: return "The FM-1 refused that change: \(label) can't be recorded as motion, or the value is out of its range."
        case .full: return "All 64 motion records are used, so the stroke stopped there. Clear a lane or a lock to make room."
        case .songPlaying: return "Stop the song to edit motion."
        case .done: return nil
        }
    }

    /// Motion waits for STOP: an entry that starts loads its pattern with its own motion (bank.c), so an edit made
    /// while the song moves through its entries wouldn't last. SLOOP says so in LIVE; Skiff, whose firmware takes the
    /// write regardless (editor.c ED_MOTION, checked on skiff-sim 2026-11-06), when it plays with SONG ON or ONCE. Loop
    /// entry keeps one entry going, so its motion can be edited while it plays.
    static func songPlays(_ session: DeviceSession) -> Bool {
        if session.song.songPlaying { return true }
        guard session.dialect == .skiff, session.playing, let mode = session.skiffSong?.song?.mode else { return false }
        return mode != .off
    }

    /// The lane open on this track, if it's one of its shown lanes.
    static func openID(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> Int? {
        guard let o = ui.openLane, o.track == track, shownIDs(session, ui, track: track).contains(o.id) else { return nil }
        return o.id
    }

    /// The lanes' own height: an open editor and the closed lanes beside it, or the closed lanes alone.
    static func lanesHeight(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> CGFloat {
        let n = shownIDs(session, ui, track: track).count
        guard n > 0 else { return 0 }
        if openID(session, ui, track: track) != nil {
            return MotionLaneEditor.height + CGFloat(min(n - 1, besideOpen)) * (laneHeight + 4)
        }
        return CGFloat(min(n, visibleLanes)) * (laneHeight + 4)
    }

    /// How tall the motion area is: its notes (song playing, a refusal), then the lanes; 0 with neither.
    static func height(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> CGFloat {
        let n = shownIDs(session, ui, track: track).count
        var h = lanesHeight(session, ui, track: track)
        // the playing note is the editor's own header when a lane is open
        if n > 0, MotionLanes.songPlays(session), openID(session, ui, track: track) == nil { h += 56 }
        if refusal(session, track: track) != nil { h += 48 }
        return h
    }

    var body: some View {
        let ids = Self.shownIDs(session, ui, track: track)
        let playing = MotionLanes.songPlays(session)
        let open = Self.openID(session, ui, track: track)
        VStack(alignment: .leading, spacing: 4) {
            if playing, !ids.isEmpty, open == nil {
                // Lupe's rule: an entry that starts loads its pattern with its own motion (bank.c), so an edit made
                // while the song plays wouldn't last; the lanes wait for STOP. Said before a touch, not after
                HStack(spacing: 10) {
                    Image(systemName: "lock").accessibilityHidden(true)
                    Text("Stop the song to edit motion. Each entry brings its own motion when it starts, so a change now wouldn't last.")
                        .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { session.setPlaying(false) } label: {
                        Label("Stop", systemImage: "stop.fill").font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44).raisedKey()
                    }
                    .buttonStyle(PressSink())
                }
                .padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
                .padding(.leading, 88)
            }
            if let said = Self.refusal(session, track: track) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
                    Text(said).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { session.dismissMotionRefusal() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
                .padding(.leading, 12).frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
                .padding(.leading, 88)
                .task(id: session.motionRefusal?.at) {
                    try? await Task.sleep(for: .seconds(6))
                    if session.motionRefusal.map({ Date.now.timeIntervalSince($0.at) >= 6 }) == true { session.dismissMotionRefusal() }
                }
                .accessibilityElement(children: .combine)
            }
            if !ids.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(ids, id: \.self) { id in
                                if id == open {
                                    MotionLaneEditor(session: session, ui: ui, track: track, id: id, offsetX: offsetX, width: width)
                                } else {
                                    closedLane(id, dim: playing)
                                }
                            }
                        }
                    }
                    .scrollIndicators(ids.count > (open == nil ? Self.visibleLanes : Self.besideOpen + 1) ? .visible : .hidden)
                    .frame(height: Self.lanesHeight(session, ui, track: track))
                    .onChange(of: open) { _, o in if let o { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { proxy.scrollTo(o, anchor: .center) } } }
                }
            }
        }
    }

    /// The lanes drawn: none while hidden from the chip, or when the track has no motion and none was added.
    static func shownIDs(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> [Int] {
        ui.motionHidden ? [] : laneIDs(session, ui, track: track)
    }

    /// Which tracks use the shared 64, to jump to one.
    static func usage(_ session: DeviceSession) -> [[MenuItem]] {
        [session.trackIndices.compactMap { t in
            let n = session.motion[t]?.events.count ?? 0
            return n == 0 ? nil : MenuItem(title: "T\(t + 1) · \(session.tracks[t].displayName): \(n)", chip: ("\(t + 1)", Theme.track[t])) {
                session.select(track: t)
            }
        }]
    }

    /// + Lane's choices: the track's pages, its engine's EDIT 1 and 2 included; on Skiff only what it records (a lane
    /// of anything else took no points: the FM-1 refused every one, 2026-11-05). The new lane opens.
    static func addLaneGroups(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> [[MenuItem]] {
        let have = Set(laneIDs(session, ui, track: track))
        let pages = SoundPage.shown(session, .edit).filter { $0.engineEdit != 0 }
            + SoundPage.pages(session).filter { $0.scope == 0 && $0.engineEdit == 0 }
        return [pages.compactMap { p in
            var seen = Set<Int>()
            let ids = (p.ids.compactMap { $0 } + p.picks.flatMap { $0.compactMap { $0 } })
                .filter { !have.contains($0) && recordable(session, $0) && seen.insert($0).inserted }
            guard !ids.isEmpty else { return nil }
            return MenuItem(title: p.title(session), children: {
                [ids.map { id in
                    MenuItem(title: session.trackDesc(id)?.label ?? "\(id)") {
                        ui.addedLanes[track, default: []].append(id)
                        ui.motionHidden = false
                        ui.openLane = .init(track: track, id: id)
                    }
                }]
            })
        }]
    }

    // MARK: A closed lane

    /// The whole lane is one button: its name, a chevron, the drawing. A tap opens it (and closes any other).
    private func closedLane(_ id: Int, dim: Bool) -> some View {
        let m = session.motion[track] ?? TrackMotion()
        let label = session.trackDesc(id)?.label ?? "\(id)"
        let changes = m.events.filter { $0.id == id && !$0.lock }.count, locks = m.events.filter { $0.id == id && $0.lock }.count
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { ui.openLane = .init(track: track, id: id) }
        } label: {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(label).font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.trailing, 8).frame(width: 80, alignment: .trailing)
                MotionLaneDrawing(session: session, track: track, id: id, offsetX: offsetX, selected: ui.selectedStep[track], detail: false)
                    .frame(width: width, height: Self.laneHeight)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.well))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(dim ? 0.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(id)
        .accessibilityLabel("\(label) motion, \(Self.count(changes, "change"))" + (locks > 0 ? " and \(Self.count(locks, "lock"))" : ""))
        .accessibilityHint("Opens the lane editor")
    }

    static func count(_ n: Int, _ word: String) -> String { n == 1 ? "1 \(word)" : "\(n) \(word)s" }
}

/// A lock's mark: a diamond, white with the track's colour round it.
struct Diamond: View {
    let colour: Color
    var body: some View {
        Rectangle().fill(Theme.text).overlay(Rectangle().strokeBorder(colour, lineWidth: 2)).rotationEffect(.degrees(45)).scaleEffect(0.75)
            .accessibilityHidden(true)
    }
}

/// One parameter's records drawn: the selected column, the sound's value dashed, the held line (filled under it in
/// the editor), its points and the locks. `motion` overrides the session's (a stroke or drag in progress); `old`, a
/// line drawn faint under it (what was there before the stroke); `painted`, the steps under the finger.
struct MotionLaneDrawing: View {
    let session: DeviceSession
    let track: Int
    let id: Int
    let offsetX: CGFloat
    let selected: Int
    let detail: Bool
    var motion: TrackMotion? = nil
    var old: TrackMotion? = nil
    var painted: [Int: Int] = [:]
    var held: Int? = nil                    // a point being dragged: drawn larger
    @Environment(\.grid) private var grid

    static func range(_ session: DeviceSession, _ id: Int) -> ClosedRange<Int> {
        let d = session.trackDesc(id)
        return (d?.min ?? 0)...max(d?.max ?? 127, (d?.min ?? 0) + 1)
    }
    /// The inset the line keeps from the top and bottom (more in the editor, for the points and bubble).
    static func inset(_ detail: Bool) -> CGFloat { detail ? 10 : 5 }
    static func y(_ v: Int, _ h: CGFloat, _ r: ClosedRange<Int>, detail: Bool) -> CGFloat {
        let i = inset(detail), lo = Double(r.lowerBound), hi = Double(r.upperBound)
        return i + CGFloat(1 - (Double(v) - lo) / (hi - lo)) * (h - 2 * i)
    }

    var body: some View {
        let m = motion ?? session.motion[track] ?? TrackMotion()
        let colour = Theme.track[track]
        Canvas { ctx, sz in draw(ctx, sz, m, colour) }
            .accessibilityHidden(true)
    }

    private func draw(_ ctx: GraphicsContext, _ sz: CGSize, _ m: TrackMotion, _ colour: Color) {
        let w = grid.stepWidth, h = sz.height, steps = session.stepCount
        let r = Self.range(session, id), base = session.cell(id).value
        func y(_ v: Int) -> CGFloat { Self.y(v, h, r, detail: detail) }
        func x(_ s: Int) -> CGFloat { CGFloat(s) * w - offsetX }
        if detail {
            // steps faint, bars stronger, quarter lines across
            for s in 1..<steps where x(s) > 0 && x(s) < sz.width {
                ctx.stroke(Path { $0.move(to: CGPoint(x: x(s), y: 0)); $0.addLine(to: CGPoint(x: x(s), y: h)) },
                           with: .color(Theme.text.opacity(s % 4 == 0 ? 0.12 : 0.05)), lineWidth: 1)
            }
            for f in [0.25, 0.5, 0.75] {
                let v = r.lowerBound + Int(Double(r.upperBound - r.lowerBound) * f)
                ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y(v))); $0.addLine(to: CGPoint(x: sz.width, y: y(v))) },
                           with: .color(Theme.text.opacity(0.06)), lineWidth: 1)
            }
        }
        // the selected step's column
        ctx.fill(Path(CGRect(x: x(selected), y: 0, width: w, height: h)), with: .color(Theme.text.opacity(0.07)))
        ctx.stroke(Path(CGRect(x: x(selected) + 0.5, y: 0, width: w - 1, height: h)), with: .color(Theme.text.opacity(0.25)), lineWidth: 1)
        // the sound's own: dashed
        ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y(base))); $0.addLine(to: CGPoint(x: sz.width, y: y(base))) },
                   with: .color(Theme.textSecondary.opacity(detail ? 0.5 : 0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        // before the stroke: faint
        if let old {
            ctx.stroke(heldPath(old, base, steps, y, x), with: .color(Theme.textSecondary.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
        // under the finger: a bar per painted step
        for (s, v) in painted {
            ctx.fill(Path(CGRect(x: x(s) + 2, y: y(v), width: w - 4, height: h - Self.inset(detail) - y(v))), with: .color(colour.opacity(0.28)))
        }
        // the recorded changes, step and hold, from the sound at step 0
        let line = heldPath(m, base, steps, y, x)
        if detail {
            var area = line
            area.addLine(to: CGPoint(x: x(steps), y: h - Self.inset(detail)))
            area.addLine(to: CGPoint(x: x(0), y: h - Self.inset(detail)))
            area.closeSubpath()
            ctx.fill(area, with: .color(colour.opacity(0.12)))
        }
        ctx.stroke(line, with: .color(colour), style: StrokeStyle(lineWidth: detail ? 2.5 : 2, lineJoin: .round))
        // its points: on the change's step, in the editor mid-step on the held line (a 44 pt grab round each)
        for e in m.events where e.id == id && !e.lock {
            let p = CGPoint(x: x(e.step) + (detail ? w / 2 : 4), y: y(e.value))
            let big = held == e.step || (detail && e.step == selected)
            let rad: CGFloat = detail ? (big ? 9 : 7) : 4
            let c = CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2)
            ctx.fill(Path(ellipseIn: c), with: .color(colour))
            ctx.stroke(Path(ellipseIn: c), with: .color(big ? Theme.text : Theme.page), lineWidth: big ? 2.5 : (detail ? 2 : 1.5))
        }
        // the locks: diamonds on their step
        let d: CGFloat = detail ? 8 : 6
        for e in m.events where e.id == id && e.lock {
            let c = CGPoint(x: x(e.step) + w / 2, y: y(e.value))
            let path = Path { p in
                p.move(to: CGPoint(x: c.x, y: c.y - d)); p.addLine(to: CGPoint(x: c.x + d, y: c.y))
                p.addLine(to: CGPoint(x: c.x, y: c.y + d)); p.addLine(to: CGPoint(x: c.x - d, y: c.y)); p.closeSubpath()
            }
            ctx.fill(path, with: .color(Theme.text))
            ctx.stroke(path, with: .color(colour), lineWidth: held == e.step ? 3 : 2)
        }
    }

    private func heldPath(_ m: TrackMotion, _ base: Int, _ steps: Int, _ y: (Int) -> CGFloat, _ x: (Int) -> CGFloat) -> Path {
        let rec = m.events.filter { $0.id == id && !$0.lock }
        var path = Path(), cur = base
        for i in 0...steps {
            if let e = rec.first(where: { $0.step == i }) { cur = e.value }
            let p = CGPoint(x: x(i), y: y(cur))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            if i < steps { path.addLine(to: CGPoint(x: x(i + 1), y: y(cur))) }
        }
        return path
    }
}

/// One lane opened: the header (the selected step's value and what it is, Hold / Lock, − / +, ⋯, Done), a 140 pt
/// plot to paint, drag and tap, and a line saying the gestures and the cost in the shared 64.
struct MotionLaneEditor: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let id: Int
    let offsetX: CGFloat
    let width: CGFloat
    @Environment(\.grid) private var grid
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let plotHeight: CGFloat = 140
    static let headerHeight: CGFloat = 48
    static let hintHeight: CGFloat = 22
    /// The whole editor: its padding, header, plot and hint line.
    static var height: CGFloat { 8 + headerHeight + 6 + plotHeight + 6 + hintHeight + 8 }

    private enum Touch: Equatable { case point(step: Int, lock: Bool), paint }
    @State private var touch: Touch?
    @State private var moved = false
    @State private var dragValue: Int?
    @State private var painted: [Int: Int] = [:]
    @State private var lastPainted: Int?
    @State private var moreFrame: CGRect = .zero

    private var desc: ParamDesc? { session.trackDesc(id) }
    private var label: String { desc?.label ?? "\(id)" }
    private var range: ClosedRange<Int> { MotionLaneDrawing.range(session, id) }
    private var base: Int { session.cell(id).value }
    private var steps: Int { session.stepCount }
    private var motion: TrackMotion { session.motion[track] ?? TrackMotion() }
    private var selected: Int { ui.selectedStep[track] }
    private var playing: Bool { MotionLanes.songPlays(session) }
    private var locks: Bool { ui.motionWritesLocks }
    private func shown(_ v: Int) -> String { formatValue(desc, v).shown }
    private func spoken(_ v: Int) -> String { formatValue(desc, v).spoken }

    /// The stroke in progress as MOTION writes, or none. A tap (no move) puts nothing back after it: the change holds.
    private var plan: MotionPaint.Plan {
        painted.isEmpty ? .none : MotionPaint.plan(events: motion.events, id: id, base: base, painted: painted, lock: locks, steps: steps,
                                                    restore: moved)
    }

    /// What the lane would hold with the stroke or drag in progress.
    private var preview: TrackMotion? {
        var m = motion
        if case .point(let s, let lock) = touch, let v = dragValue, moved {
            m.events.removeAll { $0.id == id && $0.step == s }
            m.events.append(.init(step: s, id: id, value: v, lock: lock))
            return m
        }
        guard !painted.isEmpty else { return nil }
        let p = plan
        m.events.removeAll { $0.id == id && p.deletes.contains($0.step) }
        for w in p.writes {
            m.events.removeAll { $0.id == id && $0.step == w.step }
            m.events.append(.init(step: w.step, id: id, value: w.value, lock: w.lock))
        }
        return m
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .top, spacing: 8) {
                axis.frame(width: 80, height: Self.plotHeight)
                plot
            }
            hints.padding(.leading, 88).frame(height: Self.hintHeight)
        }
        .padding(.vertical, 8).padding(.trailing, 10)
        .frame(height: Self.height)
        .elevated(.selected, radius: 10)
        .padding(.horizontal, 2)
        .id(id)
        #if DEBUG
        // -motion-paint 1:20,2:28,…: a stroke held mid-draw, for screenshots (nothing is written); -motion-locks: Lock
        .onAppear {
            let a = ProcessInfo.processInfo.arguments
            if a.contains("-motion-locks") { ui.motionWritesLocks = true }
            guard let i = a.firstIndex(of: "-motion-paint"), i + 1 < a.count else { return }
            for pair in a[i + 1].split(separator: ",") {
                let kv = pair.split(separator: ":").compactMap { Int($0) }
                if kv.count == 2 { painted[kv[0]] = kv[1]; lastPainted = kv[0] }
            }
            moved = true
        }
        #endif
    }

    // MARK: Header

    private var header: some View {
        let r = motion.value(of: id, at: selected, base: base)
        return HStack(spacing: 8) {
            Button { close() } label: {
                HStack(spacing: 4) {
                    Text(label).font(.system(size: 13, weight: .semibold)).lineLimit(2).multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
                }
                .padding(.trailing, 8).frame(width: 88, height: 44, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label) lane, open")
            .accessibilityHint("Closes the editor")

            VStack(alignment: .leading, spacing: 2) {
                Text(playing ? "Playing · \(shown(r.value)) at step \(selected + 1)" : "Step \(selected + 1) · \(shown(dragValue ?? r.value))")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit().lineLimit(1)
                Text(playing ? "Stop to edit. The song keeps its own motion while it plays." : status(r))
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if playing {
                Button { session.setPlaying(false) } label: {
                    Label("Stop", systemImage: "stop.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 14).frame(height: 44).raisedKey(primary: true)
                }
                .buttonStyle(PressSink())
            } else {
                writesSwitch
                stepper("minus", "Lower \(label) at step \(selected + 1)", -1)
                stepper("plus", "Raise \(label) at step \(selected + 1)", 1)
                Button { more() } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold)).frame(width: 48, height: 44).raisedKey()
                }
                .buttonStyle(PressSink())
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { moreFrame = $0 }
                .accessibilityLabel("More: lock or hold, delete this change, clear the lane")
            }
            Button { close() } label: {
                Text("Done").font(.system(size: 14, weight: .semibold)).foregroundStyle(playing ? Theme.text : Theme.onColour)
                    .padding(.horizontal, 16).frame(height: 44).raisedKey(primary: !playing)
            }
            .buttonStyle(PressSink())
        }
        .frame(height: Self.headerHeight)
    }

    /// What the selected step's value is: a lock, a recorded change and how long it holds, or the sound's own.
    private func status(_ r: (value: Int, source: TrackMotion.Source)) -> String {
        switch r.source {
        case .lock: return "locked on this step only · the sound's own is \(shown(base))"
        case .sound: return "the sound's own · tap or draw to record a change"
        case .recorded:
            let rec = motion.events.filter { $0.id == id && !$0.lock }
            let from = rec.filter { $0.step <= selected }.map(\.step).max() ?? selected
            let next = rec.filter { $0.step > selected }.map(\.step).min()
            let at = from == selected ? "recorded" : "recorded at step \(from + 1)"
            let until = next.map { $0 - 1 == selected ? "this step only" : "holds to step \($0)" } ?? "holds to the end"
            return "\(at), \(until) · the sound's own is \(shown(base))"
        }
    }

    /// Hold or Lock: what a tap, stroke or − / + on an empty step writes.
    private var writesSwitch: some View {
        HStack(spacing: 4) {
            ForEach([false, true], id: \.self) { lock in
                let on = locks == lock
                Button { ui.motionWritesLocks = lock } label: {
                    HStack(spacing: 6) {
                        if lock { Diamond(colour: Theme.text).frame(width: 12, height: 12) }
                        else { Image(systemName: "chart.line.flattrend.xyaxis").font(.system(size: 12, weight: .semibold)).accessibilityHidden(true) }
                        Text(lock ? "Lock" : "Hold").font(.system(size: 14, weight: on ? .semibold : .regular))
                    }
                    .padding(.horizontal, 12).frame(height: 40)
                    .background { if on { RoundedRectangle(cornerRadius: 8).fill(Theme.tones[2]).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, lineWidth: 2)) } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lock ? "Lock: a touch locks that step only" : "Hold: a touch records a change that holds")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.controlPressed))
    }

    private func stepper(_ icon: String, _ spoken: String, _ dir: Int) -> some View {
        Button { nudge(dir) } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).frame(width: 48, height: 44).raisedKey()
        }
        .buttonStyle(PressSink())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(spoken)
    }

    /// − / +: the selected step's value by one, as its record's kind (or what the switch writes, on an empty step).
    private func nudge(_ dir: Int) {
        let s = selected, m = motion
        let cur = m.value(of: id, at: s, base: base).value
        let n = min(max(cur + dir, range.lowerBound), range.upperBound)
        guard n != cur else { return }
        Task { await session.setMotion(track: track, step: s, id: id, value: n, lock: m.record(id, at: s)?.lock ?? locks) }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { ui.openLane = nil }
    }

    private func more() {
        let s = selected, r = motion.record(id, at: s)
        ui.menu = JibMenu(title: "\(label) · step \(s + 1)", groups: {
            var first: [MenuItem] = []
            if let r {
                first.append(r.lock
                    ? MenuItem(title: "Make it hold from here") { Task { await session.setMotion(track: track, step: s, id: id, value: r.value, lock: false) } }
                    : MenuItem(title: "Lock step \(s + 1) only") { Task { await session.setMotion(track: track, step: s, id: id, value: r.value, lock: true) } })
                first.append(MenuItem(title: "Delete this change") { Task { await session.deleteMotion(track: track, step: s, id: id) } })
            } else {
                first.append(.note("Nothing recorded on step \(s + 1)."))
            }
            return [first, [MenuItem(title: "Clear the \(label) lane") {
                Task { await session.clearMotionLane(track: track, id: id) }
                ui.addedLanes[track]?.removeAll { $0 == id }
                ui.openLane = nil
            }]]
        }, at: CGPoint(x: moreFrame.minX, y: moreFrame.maxY))
    }

    // MARK: Axis and hints

    private var axis: some View {
        GeometryReader { g in
            let h = g.size.height
            let mid = range.lowerBound + (range.upperBound - range.lowerBound) / 2
            ZStack(alignment: .topTrailing) {
                tick(shown(range.upperBound), y: MotionLaneDrawing.y(range.upperBound, h, range, detail: true))
                tick(shown(mid), y: MotionLaneDrawing.y(mid, h, range, detail: true))
                if abs(base - mid) > (range.upperBound - range.lowerBound) / 8 && base != range.upperBound {
                    tick("sound \(shown(base))", y: MotionLaneDrawing.y(base, h, range, detail: true))
                }
            }
            .frame(width: g.size.width, height: h, alignment: .topTrailing)
        }
        .accessibilityHidden(true)
    }

    private func tick(_ s: String, y: CGFloat) -> some View {
        Text(s).font(.system(size: 11)).foregroundStyle(Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
            .padding(.trailing, 8)
            .offset(y: max(0, y - 7))
    }

    private var hints: some View {
        let used = motion.events.filter { $0.id == id }.count
        let free = DeviceSession.motionMax - session.motionUsed
        let p = plan
        return HStack(spacing: 18) {
            if !painted.isEmpty {
                Text("Painting · \(MotionLanes.count(p.writes.count, "change")) · \(max(0, free - p.cost)) of 64 free after")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(free - p.cost < 0 ? Theme.caution : Theme.text)
            } else if playing {
                Text("Read only while the song plays").font(.system(size: 12)).foregroundStyle(Theme.textSecondaryRaised)
            } else {
                hint("scribble", "Draw across steps to paint")
                hint("arrow.up.and.down", "Drag a point up or down")
                hint("hand.tap", "Tap a step to set it there")
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if free < 8 { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).accessibilityHidden(true) }
                Text("\(label) uses \(used) · ").foregroundStyle(Theme.textSecondaryRaised)
                Text("\(free) of 64 free").fontWeight(.semibold).foregroundStyle(free < 8 ? Theme.caution : Theme.text)
            }
            .font(.system(size: 12))
            .accessibilityElement(children: .combine)
        }
    }

    private func hint(_ icon: String, _ s: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).accessibilityHidden(true)
            Text(s)
        }
        .font(.system(size: 12)).foregroundStyle(Theme.textSecondaryRaised)
    }

    // MARK: The plot: paint, drag a point, tap a step

    private var plot: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                MotionLaneDrawing(session: session, track: track, id: id, offsetX: offsetX, selected: selected, detail: true,
                                  motion: preview, old: painted.isEmpty ? nil : motion, painted: painted,
                                  held: { if case .point(let s, _) = touch { s } else { nil } }())
                bubble(g.size)
                EditorPlayhead(session: session, track: track, offsetX: offsetX, height: g.size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { e in changed(e, g.size) }.onEnded { e in ended(e, g.size) },
                     including: playing ? .none : .all)
            .opacity(playing ? 0.45 : 1)
        }
        .frame(width: width, height: Self.plotHeight)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.well))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement()
        .accessibilityLabel("\(label) motion")
        .accessibilityValue(spokenValue)
        .accessibilityHint(playing ? "Stop the song to edit" : "Swipe up or down to change the value")
        .accessibilityAdjustableAction { dir in if !playing { nudge(dir == .increment ? 1 : -1) } }
        .accessibilityAction(named: "Next step") { ui.selectedStep[track] = min(steps - 1, selected + 1) }
        .accessibilityAction(named: "Previous step") { ui.selectedStep[track] = max(0, selected - 1) }
        .accessibilityAction(named: motion.record(id, at: selected)?.lock == true ? "Hold from this step" : "Lock this step") { toggleKind() }
        .accessibilityAction(named: "Delete this change") { Task { await session.deleteMotion(track: track, step: selected, id: id) } }
        .accessibilityAction(named: "Close the editor") { close() }
    }

    private var spokenValue: String {
        let r = motion.value(of: id, at: selected, base: base)
        return "step \(selected + 1), \(spoken(r.value)), \(status(r))"
    }

    private func toggleKind() {
        guard !playing else { return }
        let s = selected, r = motion.value(of: id, at: s, base: base)
        let lock = motion.record(id, at: s)?.lock != true
        Task { await session.setMotion(track: track, step: s, id: id, value: r.value, lock: lock) }
    }

    @ViewBuilder private func bubble(_ size: CGSize) -> some View {
        let at: (step: Int, value: Int)? = {
            if case .point(let s, _) = touch, let v = dragValue, moved { return (s, v) }
            if let s = lastPainted, let v = painted[s] { return (s, v) }
            return nil
        }()
        if let at {
            let y = MotionLaneDrawing.y(at.value, size.height, range, detail: true)
            let x = CGFloat(at.step + 1) * grid.stepWidth - offsetX + 6
            Text("step \(at.step + 1) · \(shown(at.value))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.onColour)
                .padding(.horizontal, 8).frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.text))
                .fixedSize()
                .offset(x: min(x, size.width - 120), y: max(2, y - 30))
                .allowsHitTesting(false)
        }
    }

    private func value(atY py: CGFloat, _ h: CGFloat) -> Int {
        let i = MotionLaneDrawing.inset(true)
        let f = 1 - Double(min(max((py - i) / max(1, h - 2 * i), 0), 1))
        return range.lowerBound + Int((Double(range.upperBound - range.lowerBound) * f).rounded())
    }
    private func step(atX px: CGFloat) -> Int { min(steps - 1, max(0, Int((px + offsetX) / grid.stepWidth))) }

    /// The record a touch starts on: its step's, within 22 pt of where it's drawn (a 44 pt grab).
    private func record(near p: CGPoint, _ h: CGFloat) -> TrackMotion.Event? {
        guard let e = motion.record(id, at: step(atX: p.x)) else { return nil }
        return abs(MotionLaneDrawing.y(e.value, h, range, detail: true) - p.y) < 22 ? e : nil
    }

    private func changed(_ e: DragGesture.Value, _ size: CGSize) {
        if touch == nil {
            if let r = record(near: e.startLocation, size.height) {
                touch = .point(step: r.step, lock: r.lock)
                dragValue = r.value
            } else {
                touch = .paint
            }
        }
        if hypot(e.translation.width, e.translation.height) > 6 { moved = true }
        switch touch {
        case .point:
            if moved { dragValue = value(atY: e.location.y, size.height) }
        case .paint:
            // every step crossed takes the finger's height, those skipped by a fast finger filled in between
            let s = step(atX: e.location.x), v = value(atY: e.location.y, size.height)
            if let l = lastPainted, abs(s - l) > 1, let lv = painted[l] {
                let dir = s > l ? 1 : -1
                for k in stride(from: l + dir, to: s, by: dir) {
                    let f = Double(k - l) / Double(s - l)
                    painted[k] = lv + Int((Double(v - lv) * f).rounded())
                }
            }
            painted[s] = v
            lastPainted = s
        case nil: break
        }
    }

    private func ended(_ e: DragGesture.Value, _ size: CGSize) {
        defer { touch = nil; moved = false; dragValue = nil; painted = [:]; lastPainted = nil }
        switch touch {
        case .point(let s, let lock):
            ui.selectedStep[track] = s
            if moved, let v = dragValue {
                Task { await session.setMotion(track: track, step: s, id: id, value: v, lock: lock) }
            }
        case .paint:
            // a tap paints one step: a change (or lock) there at the tapped height
            let p = plan
            ui.selectedStep[track] = lastPainted ?? step(atX: e.location.x)
            if !p.writes.isEmpty || !p.deletes.isEmpty {
                Task { await session.paintMotion(track: track, id: id, plan: p) }
            }
        case nil: break
        }
    }
}

/// The pattern header's motion chip: the shared 64 as "Motion 9/64", amber when fewer than 8 are free. It opens a
/// menu: the lanes shown or hidden, + Lane, clearing the track's motion, what uses the 64, and the key.
struct MotionChip: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    @State private var frame: CGRect = .zero

    var body: some View {
        let used = session.motionUsed, free = DeviceSession.motionMax - used
        let low = free < 8
        Button { open() } label: {
            HStack(spacing: 4) {
                if low { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)) }
                Text("Motion").font(.system(size: 13)).foregroundStyle(low ? Theme.caution : Theme.textSecondary)
                Text("\(used)/\(DeviceSession.motionMax)").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(low ? Theme.caution : Theme.text)
            .padding(.horizontal, 10).frame(height: 36).raisedKey()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel("Motion, \(used) of 64 records used by all tracks" + (low ? ", \(free) free" : ""))
        .accessibilityHint("Shows or hides the lanes, adds a lane, clears the track's motion")
    }

    private func open() {
        let lanes = MotionLanes.laneIDs(session, ui, track: track)
        let n = session.motion[track]?.events.count ?? 0
        let stopped = !MotionLanes.songPlays(session)
        ui.menu = JibMenu(title: "Motion · T\(track + 1)", groups: {
            [[MenuItem(title: ui.motionHidden ? "Show the lanes" : "Hide the lanes", enabled: !lanes.isEmpty) { ui.motionHidden.toggle() },
              MenuItem(title: "+ Lane", enabled: stopped, children: { MotionLanes.addLaneGroups(session, ui, track: track) }),
              MenuItem(title: "Clear T\(track + 1)'s motion", enabled: n > 0 && stopped) {
                  session.clearMotion(track: track)
                  ui.addedLanes[track] = nil
              }],
             [MenuItem(title: "What uses the 64", enabled: session.motionUsed > 0, children: { MotionLanes.usage(session) })],
             [.note("Line: a recorded change, held until the next one."), .note("Diamond: a lock, this step only.")]]
        }, at: CGPoint(x: frame.minX, y: frame.maxY))
    }
}

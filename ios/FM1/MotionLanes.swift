import SloopKit
import SwiftUI

// Skiff's motion under the grid (canvas boards 15 and 16, design/boards/steps.py, stepstates.py; 2026-11-05): one
// lane per recorded parameter. A recorded change draws as a step-and-hold line in the track's colour (it holds
// until the next change; each pass starts from the sound, motion.c motion_restore), a lock as a diamond on its step
// (that step only), the sound's own value as a dashed baseline. The selected step's column runs through every
// lane. Edited with the song stopped: drag a point for its value, tap an empty step to add a change, hold a point
// for its menu. The 64 records are shared by all tracks.

/// The header and the lanes, for the selected track; `offsetX` is the grid's pan (one bar in view).
struct MotionLanes: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let offsetX: CGFloat
    let width: CGFloat
    @Environment(\.grid) private var grid
    @State private var frame: CGRect = .zero          // global, for the menus' anchors
    private var menuAt: CGPoint { CGPoint(x: frame.maxX - 260, y: frame.minY + Self.headerHeight) }

    static let laneHeight: CGFloat = 52
    static let headerHeight: CGFloat = 36
    /// Lanes shown at once; more scroll.
    static let visibleLanes = 3

    /// The parameters with a lane: those with records, then any added with + Lane.
    static func laneIDs(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> [Int] {
        var ids = session.motion[track]?.ids ?? []
        for id in ui.addedLanes[track] ?? [] where !ids.contains(id) { ids.append(id) }
        return ids
    }

    /// How tall the motion area is: the header, then the lanes (or the empty or full note).
    static func height(_ session: DeviceSession, _ ui: EditorUI, track: Int) -> CGFloat {
        let n = laneIDs(session, ui, track: track).count
        let note: CGFloat = session.motionUsed >= DeviceSession.motionMax || session.song.songPlaying ? 52 : 0
        return headerHeight + 8 + note + (n == 0 ? 64 : CGFloat(min(n, visibleLanes)) * (laneHeight + 4))
    }

    var body: some View {
        let ids = Self.laneIDs(session, ui, track: track)
        let used = session.motionUsed, full = used >= DeviceSession.motionMax
        let playing = session.song.songPlaying
        VStack(alignment: .leading, spacing: 8) {
            header(used: used)
            if playing {
                // Jib's rule: an entry that starts loads its pattern with its own motion (bank.c), so an edit made
                // while the song plays wouldn't last; the lanes wait for STOP
                HStack(spacing: 10) {
                    Image(systemName: "lock").accessibilityHidden(true)
                    Text("Motion can't be edited while the song plays: the next entry brings its own.")
                        .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { session.setPlaying(false) } label: {
                        Text("Stop").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).frame(minHeight: 36).raisedKey()
                    }
                    .buttonStyle(PressSink())
                }
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
                .padding(.leading, 88)
            } else if full {
                HStack(spacing: 10) {
                    Text("Full: 64 of 64.").font(.system(size: 13, weight: .semibold))
                    Text("All tracks share 64; new moves aren't recorded until some are deleted.").font(.system(size: 13))
                        .foregroundStyle(Theme.text).lineLimit(2)
                    Spacer(minLength: 0)
                    Button { ui.menu = JibMenu(title: "Motion records", groups: { usage }, at: menuAt) } label: {
                        Text("Show what uses them").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).frame(minHeight: 36).raisedKey()
                    }
                    .buttonStyle(PressSink())
                }
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
                .padding(.leading, 88)
            }
            if ids.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No motion on T\(track + 1) yet").font(.system(size: 15, weight: .semibold))
                    Text("Arm REC and play to record knob moves, or lock a step's knobs from the step panel.")
                        .font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.85))
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
                .padding(.leading, 88)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(ids, id: \.self) { id in lane(id, readOnly: playing) }
                    }
                }
                .scrollIndicators(ids.count > Self.visibleLanes ? .visible : .hidden)
                .frame(height: CGFloat(min(ids.count, Self.visibleLanes)) * (Self.laneHeight + 4))
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }

    // MARK: The header: the shared 64, the legend, + Lane

    private func header(used: Int) -> some View {
        let colour = Theme.track[track]
        return HStack(spacing: 12) {
            Text("Motion").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 2) {
                ForEach(0..<32, id: \.self) { k in
                    RoundedRectangle(cornerRadius: 1).fill(k < (used + 1) / 2 ? colour : Theme.stepEmpty).frame(width: 4, height: 12)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(used) of 64 motion records used, shared by all tracks")
            Text("\(used) of 64 records · shared by all tracks").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 10, height: 3)
                Text("recorded, holds").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Diamond(colour: colour).frame(width: 10, height: 10).padding(.leading, 6)
                Text("lock, this step only").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Button { openAddLane() } label: {
                Text("+ Lane").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).frame(minHeight: 36).raisedKey()
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(session.song.songPlaying)
            .accessibilityHint("Adds a lane for another of the track's parameters")
        }
        .padding(.leading, 88)
        .frame(height: Self.headerHeight)
    }

    private var usage: [[MenuItem]] {
        [session.trackIndices.compactMap { t in
            let n = session.motion[t]?.events.count ?? 0
            return n == 0 ? nil : MenuItem(title: "T\(t + 1) · \(session.tracks[t].displayName): \(n)", chip: ("\(t + 1)", Theme.track[t])) {
                session.select(track: t)
            }
        }]
    }

    /// + Lane: the track's parameters on its Shape pages, by page.
    private func openAddLane() {
        let have = Set(Self.laneIDs(session, ui, track: track))
        let pages = SoundPage.pages(session).filter { $0.scope == 0 && $0.engineEdit == 0 }
        ui.menu = JibMenu(title: "Add a lane", groups: {
            [pages.compactMap { p in
                let ids = p.ids.compactMap { $0 }.filter { !have.contains($0) }
                guard !ids.isEmpty else { return nil }
                return MenuItem(title: p.title, children: {
                    [ids.map { id in
                        MenuItem(title: session.trackDesc(id)?.label ?? "\(id)") { ui.addedLanes[track, default: []].append(id) }
                    }]
                })
            }]
        }, at: menuAt)
    }

    // MARK: One lane

    private func lane(_ id: Int, readOnly: Bool) -> some View {
        let d = session.trackDesc(id)
        return HStack(spacing: 8) {
            Text(d?.label ?? "\(id)").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                .lineLimit(2).multilineTextAlignment(.trailing)
                .padding(.trailing, 8).frame(width: 80, alignment: .trailing)
            MotionLane(session: session, ui: ui, track: track, id: id, offsetX: offsetX, readOnly: readOnly)
                .frame(width: width, height: Self.laneHeight)
                .opacity(readOnly ? 0.5 : 1)
        }
    }
}

/// A lock's mark: a diamond, white with the track's colour round it.
struct Diamond: View {
    let colour: Color
    var body: some View {
        Rectangle().fill(Theme.text).overlay(Rectangle().strokeBorder(colour, lineWidth: 2)).rotationEffect(.degrees(45)).scaleEffect(0.75)
            .accessibilityHidden(true)
    }
}

/// One parameter's lane: drawn from the track's records, edited by touch.
struct MotionLane: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let id: Int
    let offsetX: CGFloat
    let readOnly: Bool
    @Environment(\.grid) private var grid
    @State private var dragging: (step: Int, value: Int, lock: Bool)?
    @State private var press: Task<Void, Never>?
    @State private var moved = false
    @State private var frame: CGRect = .zero          // global, for the menu's anchor

    private var range: ClosedRange<Int> {
        let d = session.trackDesc(id)
        return (d?.min ?? 0)...max(d?.max ?? 127, (d?.min ?? 0) + 1)
    }
    private var base: Int { session.cell(id).value }
    private var steps: Int { session.stepCount }

    private func y(_ v: Int, _ h: CGFloat) -> CGFloat {
        let lo = Double(range.lowerBound), hi = Double(range.upperBound)
        return 6 + CGFloat(1 - (Double(v) - lo) / (hi - lo)) * (h - 12)
    }
    private func value(atY py: CGFloat, _ h: CGFloat) -> Int {
        let f = 1 - Double(min(max((py - 6) / max(1, h - 12), 0), 1))
        return range.lowerBound + Int((Double(range.upperBound - range.lowerBound) * f).rounded())
    }
    private func step(atX px: CGFloat) -> Int { min(steps - 1, max(0, Int((px + offsetX) / grid.stepWidth))) }

    var body: some View {
        let m = shown
        let colour = Theme.track[track]
        GeometryReader { g in
            Canvas { ctx, sz in draw(ctx, sz, m, colour) }
                .overlay(alignment: .topLeading) { bubble(g.size) }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { e in changed(e, g.size) }.onEnded { e in ended(e, g.size) },
                         including: readOnly ? .none : .all)
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.well))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityElement()
        .accessibilityLabel("\(session.trackDesc(id)?.label ?? "Parameter") motion")
        .accessibilityValue(spoken(m))
        .accessibilityAdjustableAction { dir in
            // VoiceOver: the selected step's value, up or down, as a recorded change
            let s = ui.selectedStep[track], cur = m.value(of: id, at: s, base: base).value
            let n = min(max(cur + (dir == .increment ? 1 : -1) * max(1, (range.upperBound - range.lowerBound) / 16), range.lowerBound), range.upperBound)
            Task { await session.setMotion(track: track, step: s, id: id, value: n, lock: m.record(id, at: s)?.lock ?? false) }
        }
    }

    /// The records with the point being dragged in its new place.
    private var shown: TrackMotion {
        var m = session.motion[track] ?? TrackMotion()
        if let d = dragging {
            m.events.removeAll { $0.id == id && $0.step == d.step }
            m.events.append(.init(step: d.step, id: id, value: d.value, lock: d.lock))
        }
        return m
    }

    private func spoken(_ m: TrackMotion) -> String {
        let s = ui.selectedStep[track], r = m.value(of: id, at: s, base: base)
        let word = r.source == .lock ? "locked on this step" : r.source == .recorded ? "recorded" : "the sound's own"
        return "step \(s + 1): \(r.value), \(word); \(m.events.filter { $0.id == id }.count) changes"
    }

    private func draw(_ ctx: GraphicsContext, _ sz: CGSize, _ m: TrackMotion, _ colour: Color) {
        let w = grid.stepWidth, h = sz.height
        let sel = ui.selectedStep[track]
        // the selected step's column
        let cx = CGFloat(sel) * w - offsetX
        ctx.fill(Path(CGRect(x: cx, y: 0, width: w, height: h)), with: .color(Theme.text.opacity(0.07)))
        ctx.stroke(Path(CGRect(x: cx + 0.5, y: 0, width: w - 1, height: h)), with: .color(Theme.text.opacity(0.25)), lineWidth: 1)
        // the sound's own: dashed
        let by = y(base, h)
        ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: by)); $0.addLine(to: CGPoint(x: sz.width, y: by)) },
                   with: .color(Theme.textSecondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        // the recorded changes, step and hold, from the sound at step 0
        let rec = m.events.filter { $0.id == id && !$0.lock }
        var path = Path(), cur = base
        for i in 0...steps {
            if let e = rec.first(where: { $0.step == i }) { cur = e.value }
            let x = CGFloat(i) * w - offsetX, py = y(cur, h)
            if i == 0 { path.move(to: CGPoint(x: x, y: py)) } else { path.addLine(to: CGPoint(x: x, y: py)) }
            if i < steps { path.addLine(to: CGPoint(x: x + w, y: py)) }
        }
        ctx.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        for e in rec {
            let p = CGPoint(x: CGFloat(e.step) * w - offsetX + 4, y: y(e.value, h))
            let big = dragging?.step == e.step
            let r: CGFloat = big ? 6 : 4
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(colour))
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(big ? Theme.text : Theme.page), lineWidth: big ? 2 : 1.5)
        }
        // the locks: diamonds on their step
        for e in m.events where e.id == id && e.lock {
            let c = CGPoint(x: CGFloat(e.step) * w - offsetX + w / 2, y: y(e.value, h))
            let d = Path { p in
                p.move(to: CGPoint(x: c.x, y: c.y - 7)); p.addLine(to: CGPoint(x: c.x + 7, y: c.y))
                p.addLine(to: CGPoint(x: c.x, y: c.y + 7)); p.addLine(to: CGPoint(x: c.x - 7, y: c.y)); p.closeSubpath()
            }
            ctx.fill(d, with: .color(Theme.text))
            ctx.stroke(d, with: .color(colour), lineWidth: 2)
        }
    }

    @ViewBuilder private func bubble(_ size: CGSize) -> some View {
        if let d = dragging {
            let f = formatValue(session.trackDesc(id), d.value).shown
            Text(f).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.onColour)
                .padding(.horizontal, 8).frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.text))
                .fixedSize()
                .offset(x: CGFloat(d.step) * grid.stepWidth - offsetX + 12, y: max(0, y(d.value, size.height) - 30))
                .allowsHitTesting(false)
        }
    }

    // MARK: Touch: drag a point, tap an empty step, hold a point

    private func record(near p: CGPoint, _ h: CGFloat) -> TrackMotion.Event? {
        let s = step(atX: p.x)
        guard let e = session.motion[track]?.record(id, at: s) else { return nil }
        return abs(y(e.value, h) - p.y) < 22 ? e : nil
    }

    private func changed(_ e: DragGesture.Value, _ size: CGSize) {
        if press == nil, dragging == nil, !moved {
            // a touch: on a point it can be dragged, or held for the menu
            if let r = record(near: e.startLocation, size.height) {
                dragging = (r.step, r.value, r.lock)
                let at = e.startLocation
                press = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled, !moved else { return }
                    dragging = nil
                    openMenu(r, at: at)
                }
            }
        }
        if hypot(e.translation.width, e.translation.height) > 6 { moved = true; press?.cancel() }
        if moved, let d = dragging { dragging = (d.step, value(atY: e.location.y, size.height), d.lock) }
    }

    private func ended(_ e: DragGesture.Value, _ size: CGSize) {
        press?.cancel(); press = nil
        defer { moved = false; dragging = nil }
        if let d = dragging, moved {
            Task { await session.setMotion(track: track, step: d.step, id: id, value: d.value, lock: d.lock) }
            return
        }
        guard !moved, dragging == nil || session.motion[track]?.record(id, at: step(atX: e.location.x)) == nil else {
            ui.selectedStep[track] = step(atX: e.location.x)
            return
        }
        // a tap on an empty step: a recorded change there, at the value the step sounds now
        let s = step(atX: e.location.x)
        ui.selectedStep[track] = s
        let v = (session.motion[track] ?? TrackMotion()).value(of: id, at: s, base: base).value
        Task { await session.setMotion(track: track, step: s, id: id, value: v, lock: false) }
    }

    private func openMenu(_ r: TrackMotion.Event, at p: CGPoint) {
        let label = session.trackDesc(id)?.label ?? "\(id)"
        let n = r.step + 1
        ui.menu = JibMenu(title: "\(label) · step \(n)", groups: {
            [[r.lock
                ? MenuItem(title: "Make it hold from here") {
                    Task { await session.setMotion(track: track, step: r.step, id: id, value: r.value, lock: false) }
                }
                : MenuItem(title: "Lock step \(n) only") {
                    Task { await session.setMotion(track: track, step: r.step, id: id, value: r.value, lock: true) }
                },
              MenuItem(title: "Delete this change") { Task { await session.deleteMotion(track: track, step: r.step, id: id) } }],
             [MenuItem(title: "Clear the \(label) lane") {
                Task { await session.clearMotionLane(track: track, id: id) }
                ui.addedLanes[track]?.removeAll { $0 == id }
             }]]
        }, at: CGPoint(x: frame.minX + p.x, y: frame.minY + p.y))
    }
}

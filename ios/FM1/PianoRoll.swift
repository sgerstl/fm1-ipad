import SloopKit
import SwiftUI

/// The selected synth track as a piano roll folded to its scale: one bar in view, two fingers pan (it
/// settles on a bar), or move the view box on the track's timeline row.
struct PianoRoll: View {
    @Environment(\.grid) private var grid
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    @State private var offset = CGPoint.zero
    @State private var request: TwoFingerScrollView<PianoRollContent>.ScrollRequest?

    static let gridHeight: CGFloat = 534        // 11 note rows and a bit; one bar wide (grid.barWidth)
    /// Both editors are this tall, so switching to the drum track moves nothing below them.
    static let panelHeight: CGFloat = 684
    /// The panel's height where it's laid out: 684 on Sequence, what the Song tab's divider leaves below it.
    @Environment(\.editorHeight) private var editorHeight
    /// The Song tab: its pattern header names the track, so this one goes (and the grid gets its rows).
    @Environment(\.arrangeCompact) private var inSongTab
    static let velocityHeight: CGFloat = 50
    static func rows(_ n: Int) -> String { n == 1 ? "1 row" : "\(n) rows" }

    var body: some View {
        let _ = BodyCounter.tick("PianoRoll")
        let t = session.tracks[track]
        let rows = Self.rows(t, keeping: ui.keptRows[track] ?? [])
        // Skiff: the motion lanes under the velocity, the grid shorter by their height
        let motion = session.dialect == .skiff
        let base = Self.gridHeight - (Self.panelHeight - editorHeight) + (inSongTab ? 40 : 0)
        let motionHeight = motion ? MotionLanes.height(session, ui, track: track) : 0
        let gridHeight = max(120, motionHeight > 0 ? base - motionHeight - 8 : base)
        let contentSize = CGSize(width: CGFloat(session.stepCount) * grid.stepWidth, height: max(gridHeight, CGFloat(rows.count) * grid.rowHeight))
        let first = Int((offset.x / grid.stepWidth).rounded()) + 1
        let topRow = Int((offset.y / grid.rowHeight).rounded())
        let hidden = (above: topRow, below: max(0, rows.count - topRow - 11))
        let rowsNote = hidden.below > 0 ? " · \(Self.rows(hidden.below)) below" : hidden.above > 0 ? " · \(Self.rows(hidden.above)) above" : ""
        let scaleName = t.scale == 0 ? "chromatic, folded to the notes used" : "\(Music.noteNames[t.root % 12]) \(Music.scales[min(t.scale, 15)].spoken)"

        VStack(spacing: 8) {
            if !inSongTab {
            EditorHeader(track: track, title: t.displayName + (t.mute ? " · muted" : ""), muted: t.mute,
                         detail: "\(scaleName) · length \(t.length) · steps \(first)–\(min(session.stepCount, first + 15)) of \(session.stepCount)\(rowsNote)" + (session.song.songPlaying ? " · song playing: edits here end at STOP" : ""))
            }

            StepNumbers(steps: session.stepCount, offsetX: offset.x, selected: ui.selectedStep[track],
                        picked: Binding(get: { ui.stepSel }, set: { ui.stepSel = $0; if !$0.isEmpty { ui.noteSel = [] } })) { ui.selectedStep[track] = $0 }
                .padding(.leading, 88)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.self) { n in
                        // off-scale rows (quantise off) keep readable grey and say so with a mark, not a fainter grey
                        AuditionLabel(text: Music.noteName(n) + (Music.inScale(n, root: t.root, scale: t.scale) ? "" : " ∗"),
                                      spoken: Music.spokenNoteName(n),
                                      down: { session.noteDown(n) }, up: { session.noteUp(n) })
                    }
                }
                .offset(y: -offset.y)
                .frame(width: 80, height: gridHeight, alignment: .top)
                .clipped()

                ZStack(alignment: .topLeading) {
                    TwoFingerScrollView(contentSize: contentSize, offset: $offset, request: request,
                                        rowKeys: rows, rowHeight: grid.rowHeight, snapX: grid.barWidth,
                                        holdRing: PianoRollContent.holdTime) {
                        PianoRollContent(grid: grid, session: session, ui: ui, track: track, rows: rows)
                    }
                    EditorPlayhead(session: session, track: track, offsetX: offset.x, height: gridHeight)
                }
                .frame(width: grid.barWidth, height: gridHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .recessed()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Track \(track + 1) steps")
            }

            HStack(spacing: 8) {
                Text("Velocity").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 8).frame(width: 80, alignment: .trailing)
                VelocityLane(track: t, selected: ui.selectedStep[track])
                    .offset(x: -offset.x)
                    .frame(width: grid.barWidth, height: Self.velocityHeight, alignment: .leading)
                    .clipped()
                    .recessed()
                    .accessibilityHidden(true)
            }
            if motionHeight > 0 {
                MotionLanes(session: session, ui: ui, track: track, offsetX: offset.x, width: grid.barWidth)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: editorHeight)
        .panel()
        .followsView(ui: ui, grid: grid, offset: offset) { request = .init(x: $0, id: $1) }
        .onChange(of: rows) { _, r in ui.keptRows[track] = Set(r) }
        .onChange(of: track) { _, _ in ui.keptRows = [:]; ui.noteSel = []; ui.stepSel = [] }
        // what's picked and what can be done to it, floating over the grid's foot (the Song tab: in its pattern
        // header instead, so the velocity and the motion lanes stay uncovered; 2026-11-06)
        .overlay(alignment: .bottom) {
            if !inSongTab { SelectionBar(edits: StepEdits(session: session, ui: ui, track: track, rows: rows)).padding(.bottom, 12) }
        }
    }

    // No paging with the playhead (removed 2026-11-01, Scott): the grid moves only when panned, since
    // what's on it is read by where it sits.

    /// Rows shown before stay while the track is on screen, so removing the highest or lowest note
    /// doesn't pull its row out from under the finger.
    static func rows(_ t: TrackState, keeping kept: Set<Int> = []) -> [Int] {
        var used = Set<Int>()
        for s in t.steps where s.time == .note { used.formUnion(s.notes) }
        let folded = Music.foldedRows(used: used, root: t.root, scale: t.scale, minRows: 11)
        return Set(folded).union(kept).sorted(by: >)
    }
}

/// A row label you can play: touch a note name (or a drum lane) to hear it, held while touched. A drum
/// lane's name also picks the lane the step panel edits (`select`), without touching the grid.
struct AuditionLabel: View {
    @Environment(\.grid) private var grid
    let text: String
    let spoken: String
    var bold = false
    var select: (() -> Void)? = nil
    let down: () -> Void
    let up: () -> Void
    @State private var pressed = false

    var body: some View {
        let _ = BodyCounter.tick("AuditionLabel")
        Text(text)
            .font(.system(size: 13, weight: bold ? .semibold : .regular))
            .foregroundStyle(pressed || bold ? Theme.text : Theme.textSecondary)
            .padding(.trailing, 8)
            .frame(width: grid.labelWidth, height: grid.rowHeight, alignment: .trailing)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(pressed ? 0.08 : 0)).padding(.vertical, 4))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true; select?(); down() } }
                .onEnded { _ in pressed = false; up() })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Play \(spoken)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                down()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { up() }
            }
            .accessibilityActions {
                if let select { Button("Edit \(spoken) on the selected step") { select() } }
            }
    }
}

struct EditorHeader: View {
    let track: Int
    let title: String
    var muted = false
    let detail: String
    var body: some View {
        let _ = BodyCounter.tick("EditorHeader")
        HStack {
            HStack(spacing: 10) {
                TrackChip(track: track, muted: muted)
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Track \(track + 1), \(title)")
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(detail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
        .frame(height: 32)
    }
}

/// The step numbers over a grid. Tapping one selects its step without touching its notes, as tapping a
/// row's name auditions it without writing one.
struct StepNumbers: View {
    @Environment(\.grid) private var grid
    var steps = 64
    let offsetX: CGFloat
    let selected: Int
    /// Steps with recorded motion (Skiff): a bar under the number, as Skiff's step row marks them.
    var motion: Set<Int> = []
    /// Picked steps: a drag along the numbers picks a range (as Arrange's bar ruler); while some are picked, a tap
    /// adds a step or takes it off. nil: numbers only select.
    var picked: Binding<Set<Int>>? = nil
    let select: (Int) -> Void
    @State private var dragFrom: Int?

    var body: some View {
        let _ = BodyCounter.tick("StepNumbers")
        HStack(spacing: 0) {
            ForEach(0..<steps, id: \.self) { i in
                // every step numbered now a bar fills the grid; beats a step heavier
                let on = picked?.wrappedValue.contains(i) == true
                Text("\(i + 1)")
                    .font(.system(size: 11, weight: i == selected || i % 4 == 0 || on ? .semibold : .regular))
                    .foregroundStyle(i == selected || on ? Theme.text : Theme.textSecondary)
                    .frame(width: grid.stepWidth, height: 20)       // centred over its column
                    .background { if on { RoundedRectangle(cornerRadius: 4).fill(Theme.text.opacity(0.18)) } }
                    .overlay(alignment: .bottom) {
                        if motion.contains(i) {
                            Capsule().fill(Theme.text).frame(width: max(8, grid.stepWidth - 12), height: 3)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let p = picked, !p.wrappedValue.isEmpty {
                            if p.wrappedValue.contains(i) { p.wrappedValue.remove(i) } else { p.wrappedValue.insert(i) }
                        } else {
                            select(i)
                        }
                    }
            }
        }
        .offset(x: -offsetX)
        .frame(width: grid.barWidth, height: 20, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 6).onChanged { v in
            guard let p = picked else { return }
            let at = { (x: CGFloat) in max(0, min(steps - 1, Int((x + offsetX) / grid.stepWidth))) }
            let a = dragFrom ?? at(v.startLocation.x)
            dragFrom = a
            let b = at(v.location.x)
            p.wrappedValue = Set(min(a, b)...max(a, b))
        }.onEnded { _ in dragFrom = nil }, including: picked == nil ? .subviews : .all)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// The current step, sliding smoothly between polls (stepping with Reduce Motion).
struct EditorPlayhead: View {
    @Environment(\.grid) private var grid
    let session: DeviceSession
    let track: Int
    let offsetX: CGFloat
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pageVisible) private var visible

    var body: some View {
        let _ = BodyCounter.tick("EditorPlayhead")
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.playing || !visible)) { tl in
            let pos = session.playhead(track: track, at: tl.date, interpolate: !reduceMotion)
            let x = CGFloat(pos) * grid.stepWidth - offsetX
            ZStack(alignment: .top) {
                LinearGradient(colors: [Theme.text.opacity(0.10), Theme.text.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                Rectangle().fill(Theme.text).frame(height: 3)
            }
            .frame(width: grid.stepWidth, height: height)
            .offset(x: x)
            .opacity(session.playing ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The scrolling content: grid, notes as lit pads, the selected ring. One finger selects a step.
struct PianoRollContent: View {
    /// Passed in, not read from the environment: it lives in a UIHostingController, which doesn't inherit it.
    var grid = GridMetrics.pad
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let rows: [Int]
    /// What a one-finger slide does, decided where it starts.
    enum Slide { case length(start: Int), paint(note: Int, on: Bool) }
    @State private var slide: Slide?
    @State private var painted: Set<Int> = []  // the steps a paint slide has already passed
    /// A hold, then a drag: the picked notes carried (by steps and rows), or a box drawn on empty grid.
    enum Held: Equatable { case move(refs: Set<NoteRef>, from: CGPoint, to: CGPoint), lasso(from: CGPoint, to: CGPoint) }
    @State private var held: Held?
    @State private var lifted = 0              // a light haptic as a hold takes
    /// A hold took during this touch: the tap and the slide that come with it are the hold's, not their own.
    @State private var holdTook = false
    /// The hold before a drag carries or boxes notes (the grid's ring fills over it).
    static let holdTime = 0.35

    private var edits: StepEdits { StepEdits(session: session, ui: ui, track: track, rows: rows) }

    var body: some View {
        let _ = BodyCounter.tick("PianoRollContent")
        let t = session.tracks[track]
        let selected = ui.selectedStep[track]
        let height = max(grid.gridHeight, CGFloat(rows.count) * grid.rowHeight)
        // read here, so a pick, a box or a carry redraws the canvas (its closure reads them as it draws)
        let _ = (ui.noteSel, ui.stepSel, held)
        ZStack(alignment: .topLeading) {
            WideCanvas(width: CGFloat(session.stepCount) * grid.stepWidth, height: height, barWidth: grid.barWidth) { ctx, size in draw(ctx, size, t, selected) }
                .contentShape(Rectangle())
                // one finger edits: drag a note's grip (its right end) to set its length; slide along a row
                // to paint, adding from an empty cell, erasing from a note; a tap turns a note on or off
                // a hold first (0.35 s without moving): carry the notes under it, or draw a box on empty grid; a
                // drag that starts at once: a note's grip sets its length, a slide paints; a tap adds, picks or
                // (on the note already picked) deletes
                .gesture(lengthGesture.exclusively(before: SpatialTapGesture().onEnded { e in tap(e.location) }))
                // (alongside, not before: a long press first in an exclusive chain kept the tap from ever firing)
                .simultaneousGesture(holdGesture)
                // a second finger cancelled the gesture (the grid pans): a slide or hold starts over
                .onReceive(NotificationCenter.default.publisher(for: .gridTwoFingers)) { _ in
                    slide = nil; painted = []; held = nil; holdTook = false
                }
                .sensoryFeedback(.impact(weight: .light), trigger: lifted)
                .accessibilityHidden(true)
            // VoiceOver: each step is a button, read in step order.
            HStack(spacing: 0) {
                ForEach(session.stepIndices, id: \.self) { i in
                    Color.clear
                        .frame(width: grid.stepWidth, height: height)
                        .accessibilityElement()
                        .accessibilityLabel(StepLabels.synth(track: track, index: i, t))
                        .accessibilityAddTraits(i == selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { ui.selectedStep[track] = i }
                        .accessibilityActions {
                            ForEach(rows, id: \.self) { n in
                                let has = t.steps[i].time == .note && t.steps[i].notes.contains(n)
                                Button("\(has ? "Remove" : "Add") \(Music.spokenNoteName(n))") {
                                    ui.selectedStep[track] = i
                                    session.toggle(track: track, index: i, note: n)
                                }
                            }
                        }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Scott's tap rules: an empty cell gets a note, picked; the picked note tapped again goes (a mistaken tap undone
    /// by a second); a note that isn't picked is picked, not deleted.
    private func tap(_ p: CGPoint) {
        if holdTook { holdTook = false; return }          // the lift after a hold isn't a tap
        let i = max(0, min(63, Int(p.x / grid.stepWidth)))
        let r = Int(p.y / grid.rowHeight)
        ui.stepSel = []
        guard r >= 0, r < rows.count else { ui.selectedStep[track] = i; return }
        let n = rows[r]
        if let start = noteStart(at: p) {
            let ref = NoteRef(step: start, note: n)
            ui.selectedStep[track] = start
            if ui.noteSel == [ref] {
                edits.apply("Deleted \(Music.noteName(n))") { s, _ in PatternEdit.remove(&s, ref) }
                ui.noteSel = []
            } else {
                ui.noteSel = [ref]
            }
            return
        }
        ui.selectedStep[track] = i
        var added = false
        edits.apply("Added \(Music.noteName(n))") { s, _ in added = PatternEdit.add(&s, step: i, note: n) }
        ui.noteSel = added ? [NoteRef(step: i, note: n)] : []
    }

    /// Hold, then drag: from a note, the picked notes (or that one) carried by whole steps and rows, lifted, landing
    /// where they're let go; from empty grid, a box picking the notes it touches. A hold that doesn't move does
    /// nothing more than pick the note under it.
    private var holdGesture: some Gesture {
        LongPressGesture(minimumDuration: Self.holdTime, maximumDistance: 8)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { v in
                guard case .second(true, let d?) = v else { return }
                if held == nil {
                    lifted += 1
                    holdTook = true
                    if let start = noteStart(at: d.startLocation), let r = row(d.startLocation) {
                        let ref = NoteRef(step: start, note: rows[r])
                        let refs = edits.refs.contains(ref) ? edits.refs : [ref]
                        if !edits.refs.contains(ref) { ui.noteSel = [ref]; ui.stepSel = [] }
                        held = .move(refs: refs, from: d.startLocation, to: d.location)
                    } else {
                        held = .lasso(from: d.startLocation, to: d.location)
                    }
                }
                switch held {
                case .move(let refs, let from, _): held = .move(refs: refs, from: from, to: d.location)
                case .lasso(let from, _): held = .lasso(from: from, to: d.location)
                case nil: break
                }
            }
            .onEnded { _ in
                defer { held = nil; Task { @MainActor in try? await Task.sleep(for: .milliseconds(80)); holdTook = false } }
                switch held {
                case .move(let refs, let from, let to):
                    let (ds, dr) = offset(from, to)
                    guard ds != 0 || dr != 0 else { return }
                    var dest: [NoteRef: NoteRef] = [:]
                    edits.apply("Moved") { s, _ in dest = PatternEdit.move(&s, refs, by: ds, pitch: edits.byRows(dr)) }
                    ui.stepSel = []
                    ui.noteSel = Set(refs.map { dest[$0] ?? $0 })
                    if let first = ui.noteSel.min() { ui.selectedStep[track] = first.step }
                case .lasso(let from, let to):
                    let box = CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
                    ui.stepSel = []
                    ui.noteSel = notes(in: box)
                case nil: break
                }
            }
    }

    private func row(_ p: CGPoint) -> Int? {
        let r = Int(p.y / grid.rowHeight)
        return r >= 0 && r < rows.count ? r : nil
    }

    /// A carry's offset in whole steps and rows (down the roll is lower: fewer rows up).
    private func offset(_ a: CGPoint, _ b: CGPoint) -> (Int, Int) {
        (Int(((b.x - a.x) / grid.stepWidth).rounded()), -Int(((b.y - a.y) / grid.rowHeight).rounded()))
    }

    /// The notes a box touches (their pads, held steps included).
    private func notes(in box: CGRect) -> Set<NoteRef> {
        let st = session.tracks[track].steps
        var out: Set<NoteRef> = []
        for i in st.indices where st[i].time == .note {
            let len = PatternEdit.length(st, i)
            for n in st[i].notes {
                guard let r = rows.firstIndex(of: n) else { continue }
                let rect = CGRect(x: CGFloat(i) * grid.stepWidth, y: CGFloat(r) * grid.rowHeight, width: CGFloat(len) * grid.stepWidth, height: grid.rowHeight)
                if rect.intersects(box) { out.insert(NoteRef(step: i, note: n)) }
            }
        }
        return out
    }

    /// From a note's grip (its right end, see gripInside): the drag's end step becomes the note's last step.
    /// Anywhere else, a slide along the row it began in: from an empty cell it adds that note on every
    /// step it passes, from a note it removes it, and never the other way (an adding slide leaves notes
    /// that are there alone). Held parts of other notes and full four-note steps are skipped.
    private var lengthGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { e in
                if holdTook || held != nil { return }      // a hold's carry or box, not a slide
                if slide == nil { slide = slideKind(at: e.startLocation) }
                switch slide {
                case .length(let start):
                    let end = max(start, min(63, Int(e.location.x / grid.stepWidth)))
                    session.setLength(track: track, start: start, steps: end - start + 1)
                    ui.selectedStep[track] = start
                case .paint(let note, let on):
                    let a = max(0, min(63, Int(e.startLocation.x / grid.stepWidth)))
                    let b = max(0, min(63, Int(e.location.x / grid.stepWidth)))
                    for i in min(a, b)...max(a, b) where !painted.contains(i) {
                        painted.insert(i)
                        let st = session.tracks[track].steps[i]
                        guard st.time == .note || (on && st.time == .rest) else { continue }
                        guard (st.time == .note && st.notes.contains(note)) != on else { continue }
                        // removing a step's only note: its held steps go with it
                        if !on, st.notes.count == 1, i < 63, session.tracks[track].steps[i + 1].time == .tie {
                            session.setLength(track: track, start: i, steps: 1)
                        }
                        session.toggle(track: track, index: i, note: note)
                    }
                    ui.selectedStep[track] = b
                case nil: break
                }
            }
            .onEnded { _ in slide = nil; painted = [] }
    }

    /// A note's grip reaches 24 pt into it and 16 pt past its end (2026-11-03: the 14 pt inside alone
    /// was hard to hit). A tap there still toggles; only a drag takes the length.
    static let gripInside: CGFloat = 24, gripOutside: CGFloat = 16

    private func slideKind(at p: CGPoint) -> Slide? {
        let r = Int(p.y / grid.rowHeight)
        guard r >= 0, r < rows.count else { return nil }
        if let start = noteStart(at: p) {
            return p.x >= noteEnd(start) - Self.gripInside ? .length(start: start) : .paint(note: rows[r], on: false)
        }
        // just past a note's end, in the empty cell after it: still that note's grip
        let back = CGPoint(x: p.x - Self.gripOutside, y: p.y)
        if back.x >= 0, let start = noteStart(at: back), p.x - noteEnd(start) <= Self.gripOutside { return .length(start: start) }
        return .paint(note: rows[r], on: true)
    }

    /// Where a note's pad ends on screen, held steps included.
    private func noteEnd(_ start: Int) -> CGFloat {
        let steps = session.tracks[track].steps
        var len = 1
        while start + len < steps.count, steps[start + len].time == .tie { len += 1 }
        return CGFloat(start + len) * grid.stepWidth - 2
    }

    /// The NOTE step a touch is on: that step, or the one a held (TIE) step belongs to, if the touched
    /// row is one of its notes.
    private func noteStart(at p: CGPoint) -> Int? {
        let steps = session.tracks[track].steps
        var i = max(0, min(63, Int(p.x / grid.stepWidth)))
        let r = Int(p.y / grid.rowHeight)
        guard r >= 0, r < rows.count else { return nil }
        while i > 0, steps[i].time == .tie { i -= 1 }
        return steps[i].time == .note && steps[i].notes.contains(rows[r]) ? i : nil
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: TrackState, _ selected: Int) {
        let w = grid.stepWidth, h = grid.rowHeight
        // beats: every other group of four steps a shade lighter; a bar line every 16
        for b in stride(from: 1, to: 16, by: 2) {
            ctx.fill(Path(CGRect(x: CGFloat(b * 4) * w, y: 0, width: 4 * w, height: size.height)), with: .color(.white.opacity(0.025)))
        }
        // the selected step's column, lit faintly the whole height; picked steps lit more, with an edge
        ctx.fill(Path(CGRect(x: CGFloat(selected) * w, y: 0, width: w, height: size.height)), with: .color(.white.opacity(0.07)))
        for i in ui.stepSel {
            ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: 0, width: w, height: size.height)), with: .color(.white.opacity(0.12)))
            ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: 0, width: w, height: 2)), with: .color(Theme.text))
        }
        for r in 1..<max(rows.count, 12) {
            ctx.fill(Path(CGRect(x: 0, y: CGFloat(r) * h, width: size.width, height: 1)), with: .color(.black.opacity(0.45)))
        }
        for bar in stride(from: 16, to: t.steps.count, by: 16) {
            ctx.fill(Path(CGRect(x: CGFloat(bar) * w, y: 0, width: 2, height: size.height)), with: .color(Color(hex: 0x34343C)))
        }
        // notes, held through the TIE steps after them
        let rowOf = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($1, $0) })
        var i = 0
        while i < t.steps.count {
            let s = t.steps[i]
            guard s.time == .note, !s.notes.isEmpty else { i += 1; continue }
            var len = 1
            while i + len < t.steps.count, t.steps[i + len].time == .tie { len += 1 }
            for (k, n) in s.notes.enumerated() {
                guard let r = rowOf[n] else { continue }
                let rect = CGRect(x: CGFloat(i) * w + 2, y: CGFloat(r) * h + 4, width: CGFloat(len) * w - 4, height: h - 8)
                let soft = k < s.levels.count && (s.levels[k] == 1 || s.levels[k] == 2)
                let ref = NoteRef(step: i, note: n)
                let picked = ui.noteSel.contains(ref) || ui.stepSel.contains(i)
                    || (ui.noteSel.isEmpty && ui.stepSel.isEmpty && i == selected)
                if case .move(let refs, _, _) = held, refs.contains(ref) {
                    // carried: faint in its place (the lifted copy is drawn after)
                    var c = ctx; c.opacity = 0.3
                    drawPad(c, rect, track: track)
                    continue
                }
                drawPad(ctx, rect, track: track, dim: soft || i >= t.length, selected: picked)
                // a grip at the note's end (two lines): it can be dragged longer or shorter
                for dx in [CGFloat(11), 6] {
                    ctx.fill(Path(roundedRect: CGRect(x: rect.maxX - dx, y: rect.minY + 8, width: 2, height: rect.height - 16), cornerRadius: 1),
                             with: .color(Theme.onColour.opacity(0.5)))
                }
            }
            i += len
        }
        // past the track's length: dimmed
        if t.length < t.steps.count {
            ctx.fill(Path(CGRect(x: CGFloat(t.length) * w, y: 0, width: CGFloat(t.steps.count - t.length) * w, height: size.height)),
                     with: .color(.black.opacity(0.4)))
        }
        // a carry: the notes lifted (level 3) where they'd land; a box: its outline
        switch held {
        case .move(let refs, let from, let to):
            let (ds, dr) = offset(from, to)
            let pitch = edits.byRows(dr)
            for ref in refs {
                guard let p = pitch(ref.note), let r = rowOf[p] else { continue }
                let len = PatternEdit.length(t.steps, ref.step)
                let rect = CGRect(x: CGFloat(ref.step + ds) * w + 2, y: CGFloat(r) * h + 4, width: CGFloat(len) * w - 4, height: h - 8)
                var c = ctx
                c.addFilter(.shadow(color: .black.opacity(0.5), radius: 8, y: 6))
                drawPad(c, rect.offsetBy(dx: 0, dy: -2), track: track, selected: true)
            }
        case .lasso(let from, let to):
            let box = CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
            ctx.fill(Path(roundedRect: box, cornerRadius: 4), with: .color(Theme.text.opacity(0.08)))
            ctx.stroke(Path(roundedRect: box, cornerRadius: 4), with: .color(Theme.text), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        case nil: break
        }
        // the selected step, when it has no note to ring: a hollow column
        if ui.noteSel.isEmpty, ui.stepSel.isEmpty, !t.steps[selected].isOn && t.steps[selected].time != .tie {
            let r = CGRect(x: CGFloat(selected) * w + 2, y: 2, width: w - 4, height: size.height - 4)
            ctx.stroke(Path(roundedRect: r, cornerRadius: 6), with: .color(Theme.text), lineWidth: 2)
        }
    }
}

/// A lit pad: one flat colour, no highlight or shadow (content stays flat); the selected one is ringed
/// and lifted (elevation 2's shadow, on that one pad only).
func drawPad(_ ctx: GraphicsContext, _ rect: CGRect, track: Int, dim: Bool = false, selected: Bool = false) {
    let p = Path(roundedRect: rect, cornerRadius: 6)
    var c = ctx
    if selected { c.addFilter(.shadow(color: .black.opacity(0.45), radius: 6, y: 4)) }
    c.opacity = dim ? 0.5 : 1
    c.fill(p, with: .color(Theme.track[track]))
    if selected {
        ctx.stroke(Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 9), with: .color(Theme.text), lineWidth: 2)
    }
}

struct VelocityLane: View {
    @Environment(\.grid) private var grid
    let track: TrackState
    let selected: Int
    var body: some View {
        let _ = BodyCounter.tick("VelocityLane")
        WideCanvas(width: CGFloat(track.steps.count) * grid.stepWidth, height: PianoRoll.velocityHeight, barWidth: grid.barWidth) { ctx, size in
            for i in track.steps.indices where track.steps[i].isOn {
                let v = CGFloat(track.steps[i].velocity) / 127
                let h = (size.height - 12) * v
                let r = CGRect(x: CGFloat(i) * grid.stepWidth + (grid.stepWidth - 12) / 2, y: size.height - 6 - h, width: 12, height: h)
                var c = ctx
                c.opacity = i >= track.length ? 0.5 : 1
                c.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(Theme.track[track.index]))
                if i == selected {
                    ctx.stroke(Path(roundedRect: r.insetBy(dx: -2, dy: -2), cornerRadius: 4), with: .color(Theme.text), lineWidth: 2)
                }
            }
        }
    }
}

enum StepLabels {
    static func synth(track: Int, index i: Int, _ t: TrackState) -> String {
        let s = t.steps[i]
        var parts = ["Track \(track + 1), step \(i + 1)"]
        switch s.time {
        case .note where !s.notes.isEmpty:
            parts.append("on")
            parts.append(s.notes.map(Music.spokenNoteName).joined(separator: ", "))
            if s.accent { parts.append("accent") }
            if s.slide { parts.append("slide") }
        case .tie: parts.append("held")
        default: parts.append("off")
        }
        if i >= t.length { parts.append("past the track's length") }
        return parts.joined(separator: ", ")
    }

    static func drums(index i: Int, _ t: TrackState, lanes: [String] = Music.drumLanes) -> String {
        let s = t.gridSteps[i]
        var parts = ["Drums, step \(i + 1)"]
        parts.append(s.isOn ? "on, " + s.lanes.map { lanes[safe: $0] ?? "lane \($0 + 1)" }.joined(separator: ", ") : "off")
        if i >= t.length { parts.append("past the track's length") }
        return parts.joined(separator: ", ")
    }
}

private struct EditorHeightKey: EnvironmentKey { static let defaultValue: CGFloat = PianoRoll.panelHeight }
extension EnvironmentValues {
    /// How tall the pattern editor's panels are (the piano roll, the drum grid, the left column).
    var editorHeight: CGFloat {
        get { self[EditorHeightKey.self] }
        set { self[EditorHeightKey.self] = newValue }
    }
}

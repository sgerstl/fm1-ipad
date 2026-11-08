import SloopKit
import SwiftUI

// The Song tab's Pads view (canvas board 25; Scott, 2026-11-07: "the most live playing friendly and the most ipad type
// interface"): the selected track's 16 entries as a 4 × 4 grid of pads, as Skiff's PERFORM layer puts them on the FM-1's
// white keys; all six tracks in a strip beside it (what each plays, what's waiting, its mute); the 16 scenes always in
// view underneath (Scott: "agreed on showing the available scenes"), not behind a switch as the board had them. A pad
// tapped launches its entry (LIST op 3: at once stopped, at the launch point playing); mutes and scenes are PERFORM's.

/// The Pads page's three layouts (SongPosition.layout).
enum PadsLayout { case full, compact, row }

struct PadsPage: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    /// Store is latched: the next scene tapped is stored into.
    @State private var storing = false
    @State private var launched = 0               // a light haptic as a pad or scene is sent
    /// Each pad's frame (global): where its menu opens when it's tapped (an empty pad) rather than held.
    @State private var padFrames: [Int: CGRect] = [:]
    /// A scene held: the strip shows what it would do (Scott, 2026-11-07); let go, it's gone.
    @State private var previewScene: Int?
    /// Where the finger is (global), for a hold's menu; and the key a hold took, so the tap its release makes is
    /// dropped (the pads redraw four times a second, which resets UIKit's long press: SwiftUI's, beside the button)
    @State private var pressAt: CGPoint = .zero
    @State private var heldKey: String?
    /// A pad being dragged to another (Scott, 2026-11-08): from the hold, as Timeline blocks; where the hold took, so
    /// the drag starts only once the finger leaves it; and the grid's place (global), for the dragged copy.
    @State private var drag: PadDrag?
    @State private var holdAt: CGPoint = .zero
    @State private var gridFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SelectionTint.key) private var selectionTint = SelectionTint.standard
    /// Full size (the editor shut), over the editor (the strip as lane heads, two rows of 8, a shorter scene row), or
    /// over the largest editor (a row of 16 small keys, no strip, no scenes) (Scott, 2026-11-07, boards 32–34).
    var layout: PadsLayout = .full
    private var compact: Bool { layout != .full }
    private var row: Bool { layout == .row }

    static let stripWidth: CGFloat = 248, gap: CGFloat = 12, sceneHeight: CGFloat = 56
    /// (2026-11-08, Scott: "shrink some of the containers… the scene buttons smaller": the scene row 32, the lane heads
    /// 42, so the editor at Half has the room its grid needs)
    static let compactStrip: CGFloat = 232, compactGap: CGFloat = 6, compactScenes: CGFloat = 32, rowHeight: CGFloat = 42
    /// A full card's height, fixed so the change from a lane head can be animated (its content needs about 93).
    static let cardHeight: CGFloat = 108
    /// A row and a card swapping as the slot resizes: a quick crossfade, so the two aren't seen over each other for the
    /// whole spring (2026-11-08)
    static let swap = AnyTransition.opacity.animation(.easeOut(duration: 0.12))
    /// The editor panel's tab (SkiffSongPage), in the scene row's line under the strip: the scene row and the room
    /// under it.
    static let tabHeight: CGFloat = compactScenes + 8
    /// Half: the pads exactly as tall as the track strip (the strip's rows; the tool row and switch over them; the
    /// scene row and the tab's line under them).
    static func halfTop(_ tracks: Int) -> CGFloat {
        let strip = CGFloat(tracks) * rowHeight + CGFloat(max(0, tracks - 1)) * 4
        return 44 + 10 + strip + 8 + compactScenes + 8
    }
    /// Max: the tool row and the row of 16 keys.
    static let rowHeight16: CGFloat = 64
    static let rowTop: CGFloat = 44 + 8 + rowHeight16 + 8

    var body: some View {
        let _ = BodyCounter.tick("PadsPage")
        let t = session.selectedTrack
        let cols = row ? 16 : compact ? 8 : 4, rows = row ? 1 : compact ? 2 : 4, gap = compact ? Self.compactGap : Self.gap
        HStack(alignment: .top, spacing: compact ? 12 : 16) {
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                SongViewSwitch(ui: ui).frame(height: 44).padding(.bottom, compact ? 6 : 0)
                // Max: the strip folds into the editor header's track menu (PatternPane)
                ForEach(row ? [] : Array(session.trackIndices), id: \.self) { k in
                    let preview = previewScene.flatMap { store.scenesSeen[$0]?[safe: k] }
                    // one place per track whose height moves between the lane head and the card, the two crossfading
                    // in it, so the change rides the divider's spring instead of jumping (Scott, 2026-11-07)
                    ZStack(alignment: .topLeading) {
                        if compact {
                            TrackStripRow(session: session, store: store, ui: ui, track: k, preview: preview).transition(Self.swap)
                        } else {
                            TrackStripCard(session: session, store: store, ui: ui, track: k, preview: preview)
                                .frame(maxHeight: .infinity, alignment: .top).transition(Self.swap)
                        }
                    }
                    .frame(height: compact ? Self.rowHeight : Self.cardHeight, alignment: .top)
                    .clipped()
                    .geometryGroup()
                }
                Spacer(minLength: Self.tabHeight)          // the editor panel's tab, in the scene row's line
            }
            .frame(width: compact ? Self.compactStrip : Self.stripWidth)
            VStack(spacing: compact ? 8 : Self.gap) {
                toolbar(t)
                GeometryReader { g in
                    // the full page: square pads; over the editor: two rows of 8 as wide and tall as the room allows
                    let w = (g.size.width - CGFloat(cols - 1) * gap) / CGFloat(cols)
                    let h = (g.size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
                    let size = row ? CGSize(width: max(40, w), height: Self.rowHeight16)
                        : compact ? CGSize(width: max(44, w), height: max(44, h)) : { let s = max(64, min(w, h)); return CGSize(width: s, height: s) }()
                    let framed = framedPad(t)
                    TimelineView(.periodic(from: .now, by: 0.25)) { tl in
                        let m = store.marks(t, launchIn: session.ticksToLaunch(t))
                        // a layout of its own, not a lazy grid: from 4 × 4 to 2 × 8 each pad keeps its identity and glides
                        // to its new place and size on the divider's spring
                        PadGrid(columns: cols, cell: size, gap: gap) {
                            ForEach(0..<16, id: \.self) { i in
                                pad(t, i, m, size: size, date: tl.date)
                                    // one piece on the spring: without it the box bounced and its words stood still
                                    // (Scott, 2026-11-08)
                                    .geometryGroup()
                                    .opacity(drag.map { !$0.refused && $0.track == t && $0.from == i } == true ? 0.35 : 1)
                                    .overlay {
                                        if let d = drag, d.track == t, landing(of: d) == i {
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    // (left showing under the selected pad: its tint covers it, and as a new pad is
                                    // picked the grid's own pad is there while the tint fades in, no blank flash)
                                    .allowsHitTesting(i != framed)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .top : .center)
                        .globalFrame($gridFrame)
                        .overlay(alignment: .topLeading) {
                            // another pad picked: the old tint and controls draw back into their pad as the new ones
                            // grow out of theirs, together, quick (Scott, 2026-11-08)
                            ZStack(alignment: .topLeading) {
                                if let i = framed {
                                    let s = selectedGeometry(i, area: g.size, cols: cols, rows: rows, cell: size, gap: gap)
                                    selectedTint(t, s, area: g.size)
                                        .id("tint\(t).\(i)")
                                        .transition(reduceMotion ? .opacity : Emerge.transition(s, row: row))
                                    selectedFace(t, i, m, s, date: tl.date, area: g.size)
                                        .id("face\(t).\(i)")
                                        .transition(.opacity)
                                }
                                if let d = drag, !d.refused, d.track == t { dragged(d, m, cell: size, date: tl.date) }
                            }
                            .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: framed)
                        }
                    }
                }
                if !row { sceneRow }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // room under the scene row over the editor: its keys' base edge sat on the clip and looked cut (2026-11-07)
        .padding(.bottom, compact ? 8 : 0)
        .sensoryFeedback(.impact(weight: .light), trigger: launched)
        .task(id: store.offline) { if !store.offline { await store.follow() } }
        .confirmationDialog(store.confirmation?.title ?? "", isPresented: Binding(
            get: { store.confirmation != nil }, set: { if !$0 { store.confirmation = nil } }), titleVisibility: .visible,
                            presenting: store.confirmation) { c in
            Button(c.confirmLabel, role: .destructive) {
                store.confirmation = nil
                Task { await c.action() }
            }
            Button("Cancel", role: .cancel) { store.confirmation = nil }
        } message: { c in Text(c.message) }
    }

    // MARK: The selected pad (Scott, 2026-11-07, board 32)

    /// The pad whose pattern the editor shows: the entry it's pinned to, else the one the track is on.
    private func framedPad(_ t: Int) -> Int? {
        if let p = ui.pinnedEntry, p.track == t { return p.entry }
        return store.song?.tracks[safe: t]?.entryOn
    }

    /// Where the selected pad and its controls go: the pad's cell, the controls' tab hanging from it, left-aligned
    /// (right-aligned where they'd run off the grid); from a bottom-row pad, upward.
    struct SelectedGeometry {
        var frame: CGRect, tab: CGSize, up: Bool, right: Bool, tabAt: CGPoint, border: CGFloat, inner: CGSize
    }

    private func selectedGeometry(_ i: Int, area: CGSize, cols: Int, rows: Int, cell: CGSize, gap: CGFloat) -> SelectedGeometry {
        let bw = CGFloat(cols) * cell.width + CGFloat(cols - 1) * gap, bh = CGFloat(rows) * cell.height + CGFloat(rows - 1) * gap
        let x0 = (area.width - bw) / 2, y0 = compact ? 0 : (area.height - bh) / 2
        let c = i % cols, r = i / cols
        let frame = CGRect(x: x0 + CGFloat(c) * (cell.width + gap), y: y0 + CGFloat(r) * (cell.height + gap), width: cell.width, height: cell.height)
        let tab = CGSize(width: TrackKnobBox.width, height: TrackKnobBox.height)
        let up = r == rows - 1, right = frame.minX + tab.width > area.width
        let tabAt = CGPoint(x: right ? frame.maxX - tab.width : frame.minX, y: up ? frame.minY - tab.height : frame.maxY)
        let b: CGFloat = row ? 4 : 6                       // the border: thinner round Max's small keys
        return SelectedGeometry(frame: frame, tab: tab, up: up, right: right, tabAt: tabAt, border: b,
                                inner: CGSize(width: cell.width - 2 * b, height: cell.height - 2 * b))
    }

    /// The selected pad's border of its track's tint and the track's controls hanging from it, as one shape, over the
    /// pads beneath (Scott, 2026-11-07, board 32). It grows out of its pad when picked.
    private func selectedTint(_ t: Int, _ s: SelectedGeometry, area: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            if row {
                // Max: the border alone (no track controls there for now, Scott 2026-11-07)
                RoundedRectangle(cornerRadius: 12).fill(SelectionTint.fill(t, selectionTint))
                    .frame(width: s.frame.width, height: s.frame.height).offset(x: s.frame.minX, y: s.frame.minY)
            } else {
                PadTabShape(cell: s.frame, tab: s.tab, up: s.up, right: s.right)
                    .fill(SelectionTint.fill(t, selectionTint))
                TrackKnobBox(session: session, ui: ui, embedded: true)
                    .frame(width: s.tab.width, height: s.tab.height, alignment: .topLeading)
                    .offset(x: s.tabAt.x, y: s.tabAt.y)
            }
        }
        .frame(width: area.width, height: area.height, alignment: .topLeading)
    }

    /// The selected pad itself, shrunk inside the border.
    private func selectedFace(_ t: Int, _ i: Int, _ m: SongPlayback.Marks, _ s: SelectedGeometry, date: Date, area: CGSize) -> some View {
        pad(t, i, m, size: s.inner, date: date)
            .frame(width: s.inner.width, height: s.inner.height)
            .geometryGroup()
            .offset(x: s.frame.minX + s.border, y: s.frame.minY + s.border)
            .frame(width: area.width, height: area.height, alignment: .topLeading)
    }

    // MARK: Toolbar

    private func toolbar(_ t: Int) -> some View {
        let launch = store.perform?.launch ?? session.launchMode
        let waiting = waitingCount
        return HStack(spacing: 12) {
            TrackChip(track: t, size: 28)
            Text("\(Entries.trackName(t, session: session))'s entries").font(.system(size: 15, weight: .semibold))
                .lineLimit(1).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let s = previewScene, store.scenesSeen[s] == nil {
                // (PERFORM says a scene is kept, not what's in it: Lupe knows the ones it stored or recalled)
                Text("Scene \(s + 1): not seen yet. Recall it once and holding it shows what it does")
                    .font(.system(size: 13)).foregroundStyle(Theme.text).lineLimit(2).layoutPriority(-1)
            } else if let r = store.refusal {
                RefusalLine(refusal: r, session: session, store: store).layoutPriority(-1)
            }
            Text("Launch at").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            SegmentedKeys(label: "Launch at", options: ["Loop", "Bar", "Beat", "Now"], selected: launch.rawValue,
                          enabled: Array(repeating: !store.offline, count: 4)) { k in
                let l = SongPlayback.Launch(rawValue: k) ?? .bar
                Task { if await store.performOp(.launch(l)) { session.adoptLaunch(l) } }
            }
            .fixedSize()
            .accessibilityHint("Where a pad, a scene or a mute lands while playing: the end of the track's pass, the next bar, the next beat, or at once")
            Button { Task { await store.performOp(.cancel) } } label: {
                Text(waiting > 0 ? "Cancel \(waiting) waiting" : "Cancel waiting").font(.system(size: 15))
                    .padding(.horizontal, 14).frame(height: 44).raisedKey()
            }
            .buttonStyle(PressSink())
            .disabled(waiting == 0 || store.offline)
            .accessibilityHint("Takes back every launch and mute still waiting for the launch point")
        }
        .frame(height: 44)
    }

    /// Launches and mutes waiting for the launch point (the song's own next isn't one).
    private var waitingCount: Int {
        let launches = session.trackIndices.filter { store.marks($0, launchIn: nil).queued != nil }.count
        return launches + (store.perform?.staged.filter { $0 != .none }.count ?? 0)
    }

    // MARK: Pads

    private func pad(_ t: Int, _ i: Int, _ m: SongPlayback.Marks, size: CGSize, date: Date, copy: Bool = false) -> some View {
        let side = min(size.width, size.height), small = size.height < 120 || size.width < 150
        let tiny = size.width < 90                // Max's row of 16: the letter and the number only
        let list = store.song?.tracks[safe: t]
        let e = list?.entries[safe: i] ?? .empty
        let blocks = store.blocks(t)
        let block = blocks.first { $0.entries.contains(i) }
        let playing = list?.entryOn == i && session.playing
        let on = list?.entryOn == i && !session.playing
        let waiting = block != nil && m.queued == block?.id && list?.staged == i
        let next = !waiting && block != nil && m.next == block?.id && block?.entries.lowerBound == i
        let colour = Theme.track[t]
        let ink = playing ? Theme.onColour : Theme.text
        let letter = Entries.letter(i)
        let title = e.isEmpty ? "" : e.label
        let state: String = {
            if e.isEmpty { return "Empty" }
            if playing {
                if small { return m.loops ? "Looping" : m.pass.map { "Pass \($0)/\(m.reps)" } ?? "Playing" }
                return m.loops ? "Playing · looping" : m.pass.map { "Playing · pass \($0) of \(m.reps)" } ?? "Playing"
            }
            if waiting { return "Waiting · " + LaneMarks.countdown(m.launchIn, session.launchMode) }
            if on { return "On it" }
            if next { return "Next" }
            return e.chained ? "Chained on" : "×\(e.reps)"
        }()
        return Button {
            // an empty pad: what to put there, beside it (Scott, 2026-11-07: "you want to create a new pattern when you
            // tap an empty pad", a menu so a stray tap mid-jam makes nothing)
            if heldKey == "p\(i)" { heldKey = nil; return }       // (the release of a hold: its menu is open)
            if ui.justPulled { return }                          // (the lift that ends a pull of the editor)
            if e.isEmpty { openMenu(t, i, at: padFrames[i].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero); return }
            guard list?.entryOn != i || !session.playing else { return }
            launched += 1
            Task { await store.send(.play(track: t, entry: i)) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(letter).font(.system(size: small ? 13 : 15, weight: .semibold)).foregroundStyle(playing ? ink : Theme.textSecondary)
                    Spacer(minLength: 4)
                    if waiting {
                        Text(LaneMarks.countdown(m.launchIn, session.launchMode)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Theme.onColour).padding(.horizontal, 8).frame(height: 24)
                            .background(Capsule().fill(Theme.text))
                    }
                }
                if !title.isEmpty {
                    Text(title).font(.system(size: side > 150 ? 34 : tiny ? (e.isRest ? 12 : 17) : small ? 20 : 24, weight: .bold)).monospacedDigit()
                        .foregroundStyle(e.isRest ? Theme.textSecondary : ink)
                }
                if !tiny {
                    Text(state).font(.system(size: small ? 12 : 13)).foregroundStyle(playing ? ink : Theme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if size.height >= 96, let p = e.poolIndex, let th = ui.padThumbs[p], th.length == store.pool?.patterns[safe: p]?.length {
                    PadThumbView(thumb: th, ink: playing ? Theme.onColour.opacity(0.6) : Theme.textSecondary)
                }
                if playing { passBar(t, m, ink: ink) }
            }
            .padding(tiny ? 6 : small ? 10 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { padSurface(playing: playing, on: on, empty: e.isEmpty, rest: e.isRest, colour: colour) }
            // (an empty pad is only an outline: the whole of it takes the tap and the hold)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                if waiting {
                    let pulse = reduceMotion ? 1 : 0.6 + 0.4 * abs(sin(date.timeIntervalSinceReferenceDate * .pi))
                    RoundedRectangle(cornerRadius: 16).strokeBorder(colour, style: StrokeStyle(lineWidth: 3, dash: [8, 5])).opacity(pulse)
                } else if next || on {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.text.opacity(on ? 1 : 0.55), lineWidth: on ? 2 : 1.5)
                }
            }
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        // held: its menu at the finger
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                pressAt = v.location
                // held, then moved off the hold: the pad lifts and follows the finger (its menu goes)
                guard heldKey == "p\(i)", !e.isEmpty else { return }
                if drag == nil, hypot(v.location.x - holdAt.x, v.location.y - holdAt.y) > 10 { beginDrag(t, i, at: v.location) }
                drag?.at = v.location
            }
            .onEnded { v in
                if drag != nil { endDrag(at: v.location) }
                releaseHold("p\(i)")
            })
        .simultaneousGesture(LongPressGesture(minimumDuration: holdToMenu).onEnded { _ in
            guard !store.offline else { return }
            heldKey = "p\(i)"
            holdAt = pressAt
            launched += 1
            openMenu(t, i, at: pressAt)
        })
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !copy { padFrames[i] = $0 } }   // (the dragged copy isn't the pad's place)
        .accessibilityLabel("Entry \(letter)" + (e.isEmpty ? ", empty" : e.isRest ? ", rest, \(e.reps) times" : ", pattern \(title), \(e.reps) times"))
        .accessibilityValue(e.isEmpty ? "" : state)
        .accessibilityHint(e.isEmpty ? "Opens a menu: a new pattern, a copy, one from the pool, or a rest"
                           : session.playing ? "Launches it at the launch point. Actions: its menu" : "Moves the track to it. Actions: its menu")
        .accessibilityActions {
            if !e.isEmpty {
                Button("Entry menu") { openMenu(t, i, at: padFrames[i].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero) }
            }
        }
    }

    /// The finger lifted: a hold's flag outlives the tap it drops by a moment, then goes (a hold that made no tap
    /// mustn't swallow the next one).
    // MARK: Drag and drop (Scott, 2026-11-08; batch list 2)

    struct PadDrag: Equatable {
        var track: Int, from: Int
        var at: CGPoint                  // the finger, global
        var refused = false              // playing: said so, nothing lifts
    }

    private func beginDrag(_ t: Int, _ i: Int, at: CGPoint) {
        ui.menu = nil
        // Skiff rewrites a list only while stopped: say so at the lift, not after the drop
        if session.playing {
            store.refuse(track: t, entry: i, "Stop to rearrange: the FM-1 moves pads only while stopped", needsStop: true)
            drag = PadDrag(track: t, from: i, at: at, refused: true)
            return
        }
        drag = PadDrag(track: t, from: i, at: at)
        launched += 1
    }

    private func endDrag(at: CGPoint) {
        guard let d = drag else { return }
        drag = nil
        guard !d.refused, let target = pad(at: at) else { return }
        move(d.track, from: d.from, to: target)
    }

    /// The pad under a point (global).
    private func pad(at p: CGPoint) -> Int? { padFrames.first { $0.value.contains(p) }?.key }

    /// Where the dragged pad would land: the pad under the finger, or past the list's end the first empty one after it.
    private func landing(of d: PadDrag) -> Int? {
        guard !d.refused, let target = pad(at: d.at), target != d.from,
              let es = store.song?.tracks[safe: d.track]?.entries else { return nil }
        return PadMove.apply(es, from: d.from, to: target)?.landed
    }

    private func move(_ t: Int, from: Int, to target: Int) {
        guard let es = store.song?.tracks[safe: t]?.entries, let r = PadMove.apply(es, from: from, to: target) else { return }
        Task { await store.rewrite(track: t, to: r.entries, focus: r.landed) }
    }

    /// The lifted copy under the finger, a little larger, over the grid.
    private func dragged(_ d: PadDrag, _ m: SongPlayback.Marks, cell: CGSize, date: Date) -> some View {
        pad(d.track, d.from, m, size: cell, date: date, copy: true)
            .frame(width: cell.width, height: cell.height)
            .scaleEffect(reduceMotion ? 1 : 1.06)
            .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
            .position(x: d.at.x - gridFrame.minX, y: d.at.y - gridFrame.minY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func releaseHold(_ key: String) {
        guard heldKey == key else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            if heldKey == key { heldKey = nil }
        }
    }

    // MARK: Pad menus (Scott, 2026-11-07), at the finger as every Lupe menu (MenuPanel)

    private var idle: Bool { !store.busy && !store.offline }

    private func openMenu(_ t: Int, _ i: Int, at: CGPoint) {
        guard !store.offline, let e = store.song?.tracks[safe: t]?.entries[safe: i] else { return }
        // an empty pad past the list's end fills the first empty one after the list instead, so the song has no
        // silent gaps (Scott, 2026-11-07); the title says where it goes
        let target = e.isEmpty ? Self.landing(store.song?.tracks[safe: t], i) : i
        let title = "T\(t + 1) · entry \(Entries.letter(i))" + (e.isEmpty ? (target == i ? " · empty" : " · goes on \(Entries.letter(target))") : "")
        ui.menu = AppMenu(title: title, groups: { e.isEmpty ? emptyMenu(t, target) : padMenu(t, i) }, at: at)
    }

    /// Where something put on empty pad `i` lands: there, or the first empty entry after the list's last filled one.
    static func landing(_ list: SongList?, _ i: Int) -> Int {
        guard let list else { return i }
        let next = (list.entries.lastIndex { !$0.isEmpty } ?? -1) + 1
        return min(i, next)
    }

    /// An empty pad: a new pattern (the editor on it), a copy of the one the track is on, one from the pool, a rest.
    private func emptyMenu(_ t: Int, _ i: Int) -> [[MenuItem]] {
        guard let list = store.song?.tracks[safe: t] else { return [] }
        let free = (store.pool?.free ?? 0) > 0
        var first = [MenuItem(title: free ? "New pattern" : "New pattern: all 64 taken", icon: "plus", enabled: free && idle) {
            Task { if await store.send(.new(track: t, entry: i)) { edit(t, i) } }
        }]
        if let on = list.entryOn, let p = list.entries[safe: on]?.poolIndex {
            first.append(MenuItem(title: free ? "Copy of \(Entries.letter(on)) · \(Entries.number(p + 1))" : "Copy of \(Entries.number(p + 1)): all 64 taken",
                                  icon: "square.on.square", enabled: free && idle) {
                // the same pattern into the entry, then a copy of its own (LIST SET, then COPY)
                Task { if await store.send(.set(track: t, entry: i, pattern: p + 1)) { await store.send(.copy(track: t, entry: i)) } }
            })
        }
        first.append(MenuItem(title: "Rest", icon: "pause", enabled: idle) {
            Task { await store.send(.set(track: t, entry: i, pattern: SongEntry.rest)) }
        })
        let kept = (0..<64).filter { (store.pool?.patterns[$0].length ?? 0) > 0 }
        let owners = Self.owners(store.song)
        let pick = MenuItem.submenu(title: "Pick a pattern…", icon: "square.grid.2x2", enabled: idle && !kept.isEmpty, children: {
            [kept.map { p in
                let tracks = owners[p] ?? []
                let colour = tracks.count == 1 ? Theme.track[tracks[0]] : Entries.tone(p + 1)
                let name = tracks.count == 1 ? "T\(tracks[0] + 1) \(Entries.trackName(tracks[0], session: session))"
                    : tracks.isEmpty ? "Not in this song" : tracks.map { "T\($0 + 1)" }.joined(separator: ", ")
                return MenuItem(title: name, chip: (Entries.number(p + 1), colour)) {
                    Task { await store.send(.set(track: t, entry: i, pattern: p + 1)) }
                }
            }]
        })
        return [first, [pick]]
    }

    /// A filled pad, held: edit it, its repeats, a copy of its own or beside it, its sound, clear it.
    private func padMenu(_ t: Int, _ i: Int) -> [[MenuItem]] {
        guard let list = store.song?.tracks[safe: t], let e = list.entries[safe: i] else { return [] }
        var g: [[MenuItem]] = []
        if e.poolIndex != nil { g.append([MenuItem(title: "Edit pattern", icon: "pencil", enabled: idle) { edit(t, i) }]) }
        if !e.chained {
            g.append([
                MenuItem(title: "Play once more (×\(min(16, e.reps + 1)))", icon: "plus", enabled: idle && e.reps < 16) {
                    Task { await store.send(.reps(track: t, entry: i, reps: e.reps + 1)) }
                },
                MenuItem(title: "Play once less (×\(max(1, e.reps - 1)))", icon: "minus", enabled: idle && e.reps > 1) {
                    Task { await store.send(.reps(track: t, entry: i, reps: e.reps - 1)) }
                },
            ])
        } else {
            g.append([.note("Chained on into the next entry: its repeats are the chain's last entry's")])
        }
        var copy: [MenuItem] = []
        if let p = e.poolIndex {
            let free = (store.pool?.free ?? 0) > 0
            let n = free ? ArrangeEdits(session: session, store: store).copyNumber(after: p).map { " (becomes \(Entries.number($0)))" } ?? "" : ": all 64 taken"
            copy.append(MenuItem(title: "Make unique\(n)", icon: "square.on.square.dashed", enabled: free && idle) {
                Task { await store.send(.copy(track: t, entry: i)) }
            })
            let room = list.entries.indices.contains { $0 > i && list.entries[$0].isEmpty }
            copy.append(MenuItem(title: room ? "Duplicate to next empty pad" : "Duplicate: no empty pad after it", icon: "plus.square.on.square",
                                 enabled: free && room && idle) {
                Task { await store.send(.copyPlus(track: t, entry: i)) }
            })
        }
        if !copy.isEmpty { g.append(copy) }
        if e.poolIndex != nil, store.sounds {
            // the sound panel, its header naming the pad (Scott, 2026-11-08), not a submenu
            g.append([MenuItem(title: "Select sound", icon: "waveform", enabled: idle) {
                ui.chooseSound(session, track: t, entry: SoundEntryTarget(ref: EntryRef(track: t, entry: i), pad: true))
            }])
        }
        g.append([MenuItem.submenu(title: "Move to…", icon: "arrow.up.and.down.and.arrow.left.and.right",
                           enabled: idle && !session.playing, children: { [moveTargets(t, i, list)] })])
        g.append([MenuItem(title: "Clear entry", icon: "trash", enabled: idle) { clear(t, i, e) }])
        return g
    }

    /// "Move to…": every other pad, as a drag would treat it (a swap onto a filled one).
    private func moveTargets(_ t: Int, _ i: Int, _ list: SongList) -> [MenuItem] {
        list.entries.indices.filter { $0 != i }.compactMap { j in
            guard let r = PadMove.apply(list.entries, from: i, to: j) else { return nil }
            let other = list.entries[j]
            let what = other.isEmpty ? (r.landed == j ? "empty" : "lands on \(Entries.letter(r.landed))")
                : "swap with \(other.label)"
            return MenuItem(title: "Pad \(Entries.letter(j)) · \(what)") { move(t, from: i, to: j) }
        }
    }

    /// The pattern in the editor: pinned on the Song tab's timeline, whose bottom half edits it (the pads have none).
    /// Stopped, the track goes to the entry first, as a block tapped does (SkiffArrangePage.pin).
    private func edit(_ t: Int, _ i: Int) {
        session.select(track: t)
        let l = store.song?.tracks[safe: t]
        if l?.entryOn != i, !session.playing { Task { await store.send(.play(track: t, entry: i)) } }
        ui.pinnedEntry = EntryRef(track: t, entry: i)
        // the editor is under the pads now: no trip to the Timeline (Scott, 2026-11-07); shut, it opens
        ui.openEditor += 1
    }

    /// CLEAR (stopped only: playing, the store says "Stop to…" with a Stop key). A pattern nothing else names goes with
    /// the entry and can't be undone: asked first.
    private func clear(_ t: Int, _ i: Int, _ e: SongEntry) {
        let alone = e.poolIndex.map { (store.pool?.patterns[safe: $0]?.uses ?? 0) <= 1 } ?? false
        if alone, let p = e.poolIndex, !session.playing {
            store.ask("Clear entry \(Entries.letter(i))?", "Pattern \(Entries.number(p + 1)) is used nowhere else, so it's erased with the entry. This can't be undone.",
                      confirm: "Clear entry \(Entries.letter(i))") { await store.send(.clear(track: t, entry: i)) }
        } else {
            Task { await store.send(.clear(track: t, entry: i)) }
        }
    }

    /// Pattern (0...63) → the tracks whose lists name it.
    static func owners(_ song: SkiffSong?) -> [Int: [Int]] {
        var m: [Int: [Int]] = [:]
        for (t, l) in (song?.tracks ?? []).enumerated() {
            for e in l.entries { if let p = e.poolIndex, !(m[p]?.contains(t) ?? false) { m[p, default: []].append(t) } }
        }
        return m
    }

    @ViewBuilder private func padSurface(playing: Bool, on: Bool, empty: Bool, rest: Bool, colour: Color) -> some View {
        if empty {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stepEmpty, lineWidth: 1)
        } else if rest {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.disabledOutline, lineWidth: 1.5)
        } else if playing {
            RoundedRectangle(cornerRadius: 16).fill(colour).elevationShadow(.selected)
        } else {
            // (Chiclet keeps its radius at 8 or less: a pad's own 16, the same base edge under it)
            RoundedRectangle(cornerRadius: 16).fill(Theme.control)
                .background { RoundedRectangle(cornerRadius: 16).fill(Theme.chicletEdge).offset(y: 2) }
        }
    }

    /// Through the pass (the counted clock), and below it the passes of its REPS: a second channel to the colour.
    private func passBar(_ t: Int, _ m: SongPlayback.Marks, ink: Color) -> some View {
        let pass = Double((m.pass ?? 1) - 1), reps = Double(max(1, m.reps)), loops = m.loops
        return SmoothBar(track: Theme.onColour.opacity(0.3), ink: ink) {
            let p = session.passProgress(t) ?? 0
            return loops ? p : (pass + p) / reps
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    // MARK: Scenes

    private var sceneRow: some View {
        let perf = store.perform
        return HStack(spacing: 8) {
            // the same word either way, lit while armed: the scenes beside it never move (Scott, 2026-11-07)
            ToggleKey(name: "Store", on: storing, enabled: !store.offline, height: compact ? Self.compactScenes : Self.sceneHeight) { if !ui.justPulled { storing.toggle() } }
                .frame(width: 88)               // (its word turns semibold when lit: a fixed width, not its own)
                .accessibilityValue(storing ? "on: tap a scene to store into it" : "")
                .accessibilityHint("Then tap a scene: it keeps the entry each track is on now, and its mute")
            HStack(spacing: 4) {
                ForEach(0..<PerformState.scenes, id: \.self) { s in sceneKey(s, perf).geometryGroup() }
            }
        }
        .frame(height: compact ? Self.compactScenes : Self.sceneHeight)
    }

    private func sceneKey(_ s: Int, _ perf: PerformState?) -> some View {
        let kept = perf?.kept[safe: s] == true
        let last = perf?.lastScene == s
        let word = last ? "last" : kept ? "" : "empty"
        return Button {
            if heldKey == "s\(s)" { heldKey = nil; return }       // (a hold's release: it previewed, it doesn't recall)
            if ui.justPulled { return }                          // (the lift that ends a pull of the editor)
            if storing {
                storing = false
                launched += 1
                Task { await store.performOp(.store(scene: s)) }
            } else if kept {
                launched += 1
                Task { await store.performOp(.recall(scene: s)) }
            } else {
                store.refuse(track: nil, entry: nil, "Scene \(s + 1) is empty. Tap Store, then the scene, to keep what plays now")
            }
        } label: {
            VStack(spacing: 0) {
                Text("\(s + 1)").font(.system(size: 15, weight: kept ? .semibold : .regular)).monospacedDigit()
                if !word.isEmpty, !compact { Text(word).font(.system(size: 10)) }   // (compact: the fill says it)
            }
            .foregroundStyle(last ? Theme.onColour : kept ? Theme.text : Theme.textSecondary)
            .frame(maxWidth: .infinity).frame(height: compact ? Self.compactScenes : Self.sceneHeight)
            .background {
                if last { RoundedRectangle(cornerRadius: 8).fill(Theme.text).elevationShadow(.selected) }
                else if kept { Chiclet(radius: 8, down: false, edge: true) }
                else { RoundedRectangle(cornerRadius: 8).strokeBorder(storing ? Theme.text.opacity(0.7) : Theme.stepEmpty, lineWidth: storing ? 1.5 : 1) }
            }
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        // held (a kept scene, not storing): the strip shows what it would do, nothing sent; let go, it's gone
        .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
            if previewScene == s { previewScene = nil }
            releaseHold("s\(s)")
        })
        .simultaneousGesture(LongPressGesture(minimumDuration: holdToMenu).onEnded { _ in
            guard kept, !storing else { return }
            heldKey = "s\(s)"
            previewScene = s
        })
        .accessibilityLabel("Scene \(s + 1)" + (kept ? "" : ", empty") + (last ? ", recalled or stored last" : ""))
        .accessibilityValue(kept ? sceneSpoken(s) : "")
        .accessibilityHint(storing ? "Stores what plays now here" : kept ? (session.playing ? "Recalls it at the launch point" : "Recalls it") : "Empty: store into it first")
    }

    /// What a scene holds, said (VoiceOver's version of holding it): each track's entry, then the muted ones.
    private func sceneSpoken(_ s: Int) -> String {
        guard let seen = store.scenesSeen[s] else { return "contents not seen yet" }
        let entries = seen.enumerated().map { t, x in "track \(t + 1) \(x.entry.map(Entries.letter) ?? "none")" }
        let muted = seen.indices.filter { seen[$0].muted }.map { "\($0 + 1)" }
        return entries.joined(separator: ", ") + (muted.isEmpty ? "" : "; muted: tracks " + muted.joined(separator: ", "))
    }
}

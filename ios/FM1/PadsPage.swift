import SloopKit
import SwiftUI

// The Song tab's Pads view: every track's entries in rows, like a clip launcher (Scott, 2026-11-09, canvas boards
// 35–39; design/structure-map.md › "Pads as a grid"). Each row is a track, each column an entry, so any track's pattern
// launches without selecting it first. The track heads stay on the left (what each plays, its mute; tap one to select
// it); the 16 scenes stay underneath. A pad tapped launches its entry (LIST op 3: at once stopped, at the launch point
// playing); mutes and scenes are PERFORM's. Over the editor (Half) the rows shrink to the lane heads' height; over the
// largest editor (Max) only the selected track's row of 16 is left (boards 37, 38).

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
    @State private var padFrames: [PadKey: CGRect] = [:]
    /// A scene held: the heads and the pads show what it would do (Scott, 2026-11-07); let go, it's gone.
    @State private var previewScene: Int?
    /// Where the finger is (global), for a hold's menu; and the key a hold took, so the tap its release makes is
    /// dropped (the pads redraw four times a second, which resets UIKit's long press: SwiftUI's, beside the button)
    @State private var pressAt: CGPoint = .zero
    @State private var heldKey: String?
    /// A pad being dragged to another (Scott, 2026-11-08): from the hold, as Timeline blocks; where the hold took, so
    /// the drag starts only once the finger leaves it; and the grid's place (global), for the dragged copy.
    @State private var drag: PadDrag?
    /// Whether the selected pad's track controls are open: the user's choice, kept until they close them (Scott,
    /// 2026-11-09: "keep it open unless the user closes it"). A double tap on a track head opens or closes them, as
    /// does the selected pad tapped while stopped; a change of size, another pad or track, or leaving Pads never does.
    @AppStorage("padControlsOpen") private var controlsOpen = true
    /// The head last double-tapped: another track's double tap shows its controls rather than flipping them away.
    @State private var lastDouble: Int?
    /// The pad whose menu is open (or just closed by the touch now landing): tapped again, it only closes.
    @State private var menuPad: PadKey?
    private var controlsShown: Bool { controlsOpen }
    private func showControls(_ v: Bool) { controlsOpen = v }
    @State private var holdAt: CGPoint = .zero
    @State private var gridFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Full size (the editor shut), over the editor (rows as tall as the lane heads, a shorter scene row), or over the
    /// largest editor (the selected track's row of 16, no heads, no scenes) (boards 35, 37, 38).
    var layout: PadsLayout = .full
    private var compact: Bool { layout != .full }
    private var row: Bool { layout == .row }

    /// A pad's place: its track and entry.
    struct PadKey: Hashable { var track: Int, entry: Int }

    static let gap: CGFloat = 12, sceneHeight: CGFloat = 56
    /// (2026-11-08, Scott: "shrink some of the containers… the scene buttons smaller": the scene row 32, the lane heads
    /// 42, so the editor at Half has the room its grid needs)
    static let compactStrip: CGFloat = 232, compactGap: CGFloat = 6, compactScenes: CGFloat = 32, rowHeight: CGFloat = 42
    /// The editor panel's tab under the heads: 5 pt wider than them, so its gap to Store matches the gap under Store
    /// (Scott, 2026-11-09; measured: 17 pt beside, 12 under, the key sitting inside its frame).
    static let panelTabWidth: CGFloat = compactStrip + 5
    /// The least a full head needs (its content is about 93).
    static let cardHeight: CGFloat = 96
    /// Between the rows at full size and over the editor.
    static let fullRowGap: CGFloat = 8, compactRowGap: CGFloat = 4
    /// Under the scene row at full size, clear of the editor panel's lip.
    static let sceneFoot: CGFloat = 12
    /// A row and a card swapping as the slot resizes: a quick crossfade, so the two aren't seen over each other for the
    /// whole spring (2026-11-08)
    static let swap = AnyTransition.opacity.animation(.easeOut(duration: 0.12))
    /// The editor panel's tab (SkiffSongPage), in the scene row's line under the strip: the scene row and the room
    /// under it.
    static let tabHeight: CGFloat = compactScenes + 8
    /// Half: the rows as tall as the lane heads (the tool row and switch over them; the scene row and the tab's line
    /// under them).
    static func halfTop(_ tracks: Int) -> CGFloat {
        let strip = CGFloat(tracks) * rowHeight + CGFloat(max(0, tracks - 1)) * compactRowGap
        return 44 + 10 + strip + 8 + compactScenes + 8
    }
    /// Max: the tool row and the row of 16 keys.
    static let rowHeight16: CGFloat = 64
    static let rowTop: CGFloat = 44 + 8 + rowHeight16 + 8

    /// Where the rows go: from `top` (under the switch and the tool row), `rows` of `rowHeight` with `rowGap` between,
    /// the heads on the left and the pads on the right on the same lines.
    struct Rows {
        var top: CGFloat, rowHeight: CGFloat, rowGap: CGFloat, sceneGap: CGFloat, count: Int
        var height: CGFloat { CGFloat(count) * rowHeight + CGFloat(max(0, count - 1)) * rowGap }
    }

    private func rows(_ size: CGSize, tracks: Int) -> Rows {
        switch layout {
        case .full:
            // the rows share what's left between the tool row and the scenes
            let top: CGFloat = 52, n = max(1, tracks)
            // (and a gap under the scenes: they touched the panel's lip, Scott 2026-11-09)
            let room = size.height - top - Self.gap - Self.sceneHeight - Self.sceneFoot - CGFloat(n - 1) * Self.fullRowGap
            return Rows(top: top, rowHeight: max(Self.cardHeight, floor(room / CGFloat(n))), rowGap: Self.fullRowGap, sceneGap: Self.gap, count: n)
        case .compact:
            return Rows(top: 54, rowHeight: Self.rowHeight, rowGap: Self.compactRowGap, sceneGap: 8, count: tracks)
        case .row:
            return Rows(top: 52, rowHeight: Self.rowHeight16, rowGap: 0, sceneGap: 0, count: 1)
        }
    }

    /// Entries A to the last any track uses, and one empty column after it so there's always room to add; at least 8.
    /// They share the width (no sideways pan): at 16 a pad is still over 60 pt wide.
    private var columns: Int {
        if row { return 16 }
        let used = (store.song?.tracks ?? []).map { ($0.entries.lastIndex { !$0.isEmpty } ?? -1) + 1 }.max() ?? 0
        return min(16, max(8, used + 1))
    }

    var body: some View {
        let _ = BodyCounter.tick("PadsPage")
        let t = session.selectedTrack
        let tracks = Array(session.trackIndices)
        GeometryReader { root in
            let r = rows(root.size, tracks: tracks.count)
            // the heads one width at every position, so the pads keep theirs as they shorten (Scott, 2026-11-09)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    // its place only: the live switch is the Song tab's, over both views, so it stays put as they
                    // slide past each other (Scott, 2026-11-09)
                    SongViewSwitch(ui: ui).frame(height: 44).hidden().accessibilityHidden(true)
                    Color.clear.frame(height: r.top - 44)
                    // Max: the heads fold into the editor header's track menu (PatternPane)
                    VStack(alignment: .leading, spacing: r.rowGap) {
                        ForEach(row ? [] : tracks, id: \.self) { k in
                            let preview = previewScene.flatMap { store.scenesSeen[$0]?[safe: k] }
                            // one place per track whose height moves between the lane head and the card, the two
                            // crossfading in it, so the change rides the divider's spring instead of jumping
                            ZStack(alignment: .topLeading) {
                                if compact {
                                    TrackStripRow(session: session, store: store, ui: ui, track: k, preview: preview).transition(Self.swap)
                                } else {
                                    TrackStripCard(session: session, store: store, ui: ui, track: k, preview: preview)
                                        .frame(maxHeight: .infinity, alignment: .top).transition(Self.swap)
                                }
                            }
                            .frame(height: r.rowHeight, alignment: .top)
                            .clipped()
                            .geometryGroup()
                            // double-tapped: the track controls in or out under its selected pad (its single tap
                            // selects it, beside this, with no wait)
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
                                session.select(track: k)
                                showControls(lastDouble != k || !controlsShown)
                                lastDouble = k
                            })
                            .accessibilityAction(named: controlsShown ? "Hide track controls" : "Show track controls") {
                                session.select(track: k)
                                showControls(!controlsShown)
                            }
                        }
                    }
                    Spacer(minLength: Self.tabHeight)          // the editor panel's tab, in the scene row's line
                }
                .frame(width: Self.compactStrip)
                VStack(spacing: 0) {
                    toolbar(t)
                    Color.clear.frame(height: r.top - 44)
                    grid(t, row ? [t] : tracks, r)
                        .frame(height: r.height)
                        .zIndex(1)                              // (the track controls hang over the scene row's gap)
                    if !row { sceneRow.padding(.top, r.sceneGap) }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        // room under the scene row over the editor: its keys' base edge sat on the clip and looked cut (2026-11-07)
        .padding(.bottom, compact ? 8 : 0)
        .sensoryFeedback(.impact(weight: .light), trigger: launched)
        // another pad, or another track: its controls back
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

    /// The pads: a row for each of `shown` (every track, or at Max the selected one), the columns sharing the width.
    private func grid(_ t: Int, _ shown: [Int], _ r: Rows) -> some View {
        GeometryReader { g in
            let cols = columns, gap = compact ? Self.compactGap : Self.gap * 0.5
            let w = (g.size.width - CGFloat(cols - 1) * gap) / CGFloat(cols)
            let cell = CGSize(width: max(40, w), height: r.rowHeight)
            let framed = framedPad(t)
            TimelineView(.periodic(from: .now, by: 0.25)) { tl in
                let marks = Dictionary(uniqueKeysWithValues: shown.map { ($0, store.marks($0, launchIn: session.ticksToLaunch($0))) })
                // a layout of its own, not a lazy grid: between positions each pad keeps its identity and glides to its
                // new place and size on the divider's spring
                PadGrid(columns: cols, cell: cell, gap: gap, rowGap: r.rowGap) {
                    ForEach(shown, id: \.self) { k in
                        ForEach(Array(0..<cols), id: \.self) { i in
                            pad(k, i, marks[k] ?? store.marks(k, launchIn: nil), size: cell, date: tl.date)
                                // one piece on the spring: without it the box bounced and its words stood still
                                .geometryGroup()
                                // the selected pad hidden under its tint: its outline and shadow showed round the
                                // tint's edges (Scott, 2026-11-09: "white border bleeding"); a crossfade as the tint
                                // moves, so switching pads still never leaves a blank
                                .opacity(k == t && i == framed ? 0 : drag.map { !$0.refused && $0.track == k && $0.from == i } == true ? 0.35 : 1)
                                .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: framed)
                                .overlay {
                                    if let d = drag, d.track == k, landing(of: d) == i {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                                            .allowsHitTesting(false)
                                    }
                                }
                                .allowsHitTesting(!(k == t && i == framed))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .globalFrame($gridFrame)
                .overlay(alignment: .topLeading) {
                    // another pad picked: the old tint and controls draw back into their pad as the new ones grow out
                    // of theirs, together, quick (Scott, 2026-11-08)
                    ZStack(alignment: .topLeading) {
                        if let i = framed, i < cols, let k = shown.firstIndex(of: t), let m = marks[t] {
                            let s = selectedGeometry(row: k, col: i, area: g.size, cell: cell, gap: gap, rowGap: r.rowGap, room: room(r))
                            // the track controls only at full size: over the editor the rows are too short to hang them
                            // from (Scott, 2026-11-09), so the border alone
                            let bare = !controlsShown
                            selectedTint(t, s, area: g.size, bare: bare)
                                .id("tint\(t).\(i).\(bare)")
                                .transition(reduceMotion ? .opacity : Emerge.transition(s, row: bare))
                            selectedFace(t, i, m, s, date: tl.date, area: g.size)
                                .id("face\(t).\(i)")
                                .transition(.opacity)
                        }
                        if let d = drag, !d.refused, let m = marks[d.track] { dragged(d, m, cell: cell, date: tl.date) }
                    }
                    .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: framed)
                    // the controls unrolling out of the pad's foot and rolling back in, shown or hidden (Scott, 2026-11-09)
                    .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.22), value: controlsShown)
                }
            }
        }
    }

    // MARK: The selected pad (Scott, 2026-11-07, board 32)

    /// The pad whose pattern the editor shows: the entry it's pinned to, else the one the track is on.
    private func framedPad(_ t: Int) -> Int? {
        if let p = ui.pinnedEntry, p.track == t { return p.entry }
        return store.song?.tracks[safe: t]?.entryOn
    }

    /// Where the selected pad and its controls go: the pad's cell, the tint's tab hanging from it (left-aligned, or
    /// right-aligned where it'd run off the grid; from the last row, upward), and the controls in that tab, a gap clear
    /// of the pad (Scott, 2026-11-09: they sat too high).
    struct SelectedGeometry {
        var frame: CGRect, tab: CGSize, drop: CGFloat, up: Bool, right: Bool, tabAt: CGPoint, knobsAt: CGPoint, border: CGFloat, inner: CGSize
        /// The face keeps a pad's own corners, like every pad beside it, and the tint round it grows by the border, so
        /// the two curves run parallel (Scott, 2026-11-09: "face 16, tint 24"; outer = inner + padding).
        var padRadius: CGFloat
        var innerRadius: CGFloat { padRadius }
        var radius: CGFloat { padRadius + border }
    }

    /// How far the track controls may hang past the grid inside the page: above it (under the switch and tool row) and
    /// below it (over the scene row). At Max they hang over the editor (SkiffSongPage lifts the pads over it there).
    private func room(_ r: Rows) -> (above: CGFloat, below: CGFloat) {
        switch layout {
        case .full: (r.top, r.sceneGap + Self.sceneHeight + Self.sceneFoot)
        case .compact: (r.top, r.sceneGap + Self.compactScenes + 8)
        case .row: (r.top, .infinity)
        }
    }

    private func selectedGeometry(row r: Int, col c: Int, area: CGSize, cell: CGSize, gap: CGFloat, rowGap: CGFloat,
                                  room: (above: CGFloat, below: CGFloat)) -> SelectedGeometry {
        let frame = CGRect(x: CGFloat(c) * (cell.width + gap), y: CGFloat(r) * (cell.height + rowGap), width: cell.width, height: cell.height)
        let drop = Labs.padControlsGap.value
        let tab = CGSize(width: TrackKnobBox.width, height: TrackKnobBox.height)
        // down where it fits inside the page, else up where that fits (Half's lower rows, full size's last), else down
        let fitsDown = frame.maxY + drop + tab.height <= area.height + room.below
        let fitsUp = frame.minY - drop - tab.height >= -room.above
        let up = !fitsDown && fitsUp, right = frame.minX + tab.width > area.width
        let x = right ? frame.maxX - tab.width : frame.minX
        // the reveal's box (the stem and the tab) and the knobs' place in it, a gap clear of the pads beside
        let tabAt = CGPoint(x: x, y: up ? frame.minY - drop - tab.height : frame.maxY)
        let knobsAt = CGPoint(x: x, y: up ? frame.minY - drop - tab.height : frame.maxY + drop)
        // the border: the knobs' own 8 pt inset, so the tint is one width round the pad and round them (Scott,
        // 2026-11-09); thinner round short rows
        let b: CGFloat = cell.height < 60 || cell.width < 90 ? 4 : 8   // (and round Max's narrow keys: "A 0")
        return SelectedGeometry(frame: frame, tab: tab, drop: drop, up: up, right: right, tabAt: tabAt, knobsAt: knobsAt, border: b,
                                inner: CGSize(width: cell.width - 2 * b, height: cell.height - 2 * b),
                                padRadius: Self.padRadius(cell))
    }

    /// The selected pad's border of its track's tint and the track's controls hanging from it, as one shape, over the
    /// pads beneath (Scott, 2026-11-07, board 32). It grows out of its pad when picked.
    private func selectedTint(_ t: Int, _ s: SelectedGeometry, area: CGSize, bare: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            if bare {
                // over the editor, or the controls tapped away: the border alone
                RoundedRectangle(cornerRadius: s.radius).fill(SelectionTint.fill(t))
                    .frame(width: s.frame.width, height: s.frame.height).offset(x: s.frame.minX, y: s.frame.minY)
            } else {
                PadTabShape(cell: s.frame, tab: s.tab, up: s.up, right: s.right, drop: s.drop, tabR: TrackKnobBox.outerRadius, turn: s.padRadius + s.drop, r: s.radius)
                    .fill(SelectionTint.fill(t))
                    // it floats over the pads and the page under it: the shadow of things at the finger (Scott, 2026-11-09)
                    .elevationShadow(.held)
                TrackKnobBox(session: session, ui: ui, embedded: true)
                    .frame(width: TrackKnobBox.width, height: TrackKnobBox.height, alignment: .topLeading)
                    .offset(x: s.knobsAt.x, y: s.knobsAt.y)
            }
        }
        .frame(width: area.width, height: area.height, alignment: .topLeading)
    }

    /// The selected pad itself, shrunk inside the border.
    private func selectedFace(_ t: Int, _ i: Int, _ m: SongPlayback.Marks, _ s: SelectedGeometry, date: Date, area: CGSize) -> some View {
        pad(t, i, m, size: s.inner, date: date, radius: s.innerRadius, selected: true)
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
            // (every track's on the grid now: Max alone shows one, named in the editor's header)
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

    /// A pad's corner radius at its size: 16, or 8 on Half's short rows.
    static func padRadius(_ size: CGSize) -> CGFloat { size.height < 56 ? 8 : 16 }

    private func pad(_ t: Int, _ i: Int, _ m: SongPlayback.Marks, size: CGSize, date: Date, copy: Bool = false,
                     radius: CGFloat? = nil, selected: Bool = false) -> some View {
        let side = min(size.width, size.height), small = size.height < 120 || size.width < 150
        let tiny = size.width < 90                // Max's row of 16: the letter and the number only
        let short = size.height < 56              // Half's rows, as tall as the lane heads: one line
        let rad = radius ?? Self.padRadius(size)
        // the selected pad outlined in its track's colour, not white (Scott, 2026-11-09: clearer on Half)
        let key = PadKey(track: t, entry: i)
        // ...and the empty pad whose menu is open, so you can see which one the choices are for (Scott, 2026-11-09)
        let mark: Color? = selected || (menuPad == key && ui.menu != nil) ? Theme.track[t] : nil
        let list = store.song?.tracks[safe: t]
        let e = list?.entries[safe: i] ?? .empty
        let blocks = store.blocks(t)
        let block = blocks.first { $0.entries.contains(i) }
        let playing = list?.entryOn == i && session.playing
        let on = list?.entryOn == i && !session.playing
        let waiting = block != nil && m.queued == block?.id && list?.staged == i
        let next = !waiting && block != nil && m.next == block?.id && block?.entries.lowerBound == i
        let colour = Theme.track[t]
        let ink = playing && !e.isRest ? Theme.onColour : Theme.text      // (a REST playing is only an outline: light ink)
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
        let held = previewScene.flatMap { store.scenesSeen[$0]?[safe: t] }?.entry == i
        return Button {
            // an empty pad: what to put there, beside it (Scott, 2026-11-07: "you want to create a new pattern when you
            // tap an empty pad", a menu so a stray tap mid-jam makes nothing)
            if heldKey == "p\(t).\(i)" { heldKey = nil; return }  // (the release of a hold: its menu is open)
            if ui.justPulled { return }                          // (the lift that ends a pull of the editor)
            if e.isEmpty {
                // the same empty pad tapped again: its menu closes and stays shut (the touch already closed it)
                if menuPad == key, OutsideTouch.justClosed || ui.menu != nil { menuPad = nil; ui.menu = nil; return }
                openMenu(t, i, at: padFrames[key].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero)
                menuPad = key
                return
            }
            if !session.playing, t == session.selectedTrack, framedPad(t) == i { controlsOpen.toggle(); return }
            launched += 1
            // a waiting pad tapped again takes its launch back: the entry playing is relaunched in its place, the
            // FM-1 having no per-track cancel (Scott, 2026-11-09, question 5)
            if waiting, session.playing, let on = list?.entryOn {
                Task { await store.send(.play(track: t, entry: on)) }
                return
            }
            // any other pad launches, on any row, without selecting its track (question 10); while playing, the one
            // playing too: it's queued again and comes back in at the launch point (Scott, 2026-11-09)
            Task { await store.send(.play(track: t, entry: i)) }
        } label: {
            if short {
                // a row as tall as a lane head (Half): one line, the letter, the number, the countdown when waiting,
                // the pass bar along the foot (board 37)
                HStack(spacing: 6) {
                    Text(letter).font(.system(size: 12, weight: .semibold)).foregroundStyle(playing ? ink : Theme.textSecondary)
                    if !title.isEmpty {
                        Text(title).font(.system(size: e.isRest ? 11 : 15, weight: .bold)).monospacedDigit()
                            .foregroundStyle(e.isRest ? Theme.textSecondary : ink).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if waiting {
                        Text(LaneMarks.countdown(m.launchIn, session.launchMode)).font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Theme.onColour).padding(.horizontal, 5).frame(height: 18)
                            .background(Capsule().fill(Theme.text)).lineLimit(1).layoutPriority(-1)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { if playing { passBar(t, m, ink: ink).frame(height: 3).padding(.horizontal, 6).padding(.bottom, 4) } }
                .background { padSurface(playing: playing, on: on, empty: e.isEmpty, rest: e.isRest, colour: colour, radius: rad, raised: !selected) }
                .contentShape(RoundedRectangle(cornerRadius: rad))
                .overlay { padOutline(held: held, waiting: waiting, next: next, on: on, colour: colour, date: date, radius: rad, mark: mark) }
            } else {
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
            .background { padSurface(playing: playing, on: on, empty: e.isEmpty, rest: e.isRest, colour: colour, radius: rad, raised: !selected) }
            // (an empty pad is only an outline: the whole of it takes the tap and the hold)
            .contentShape(RoundedRectangle(cornerRadius: rad))
            .overlay { padOutline(held: held, waiting: waiting, next: next, on: on, colour: colour, date: date, radius: rad, mark: mark) }
            }
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        // held: its menu at the finger
        .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                pressAt = v.location
                // held, then moved off the hold: the pad lifts and follows the finger (its menu goes)
                guard heldKey == "p\(t).\(i)", !e.isEmpty else { return }
                if drag == nil, hypot(v.location.x - holdAt.x, v.location.y - holdAt.y) > Labs.padDragStart.value { beginDrag(t, i, at: v.location) }
                drag?.at = v.location
            }
            .onEnded { v in
                if drag != nil { endDrag(at: v.location) }
                releaseHold("p\(t).\(i)")
            })
        .simultaneousGesture(LongPressGesture(minimumDuration: holdToMenu).onEnded { _ in
            guard !store.offline else { return }
            heldKey = "p\(t).\(i)"
            holdAt = pressAt
            launched += 1
            openMenu(t, i, at: pressAt)
        })
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !copy { padFrames[key] = $0 } }   // (the dragged copy isn't the pad's place)
        .accessibilityLabel("\(Entries.trackName(t, session: session)), entry \(letter)" + (e.isEmpty ? ", empty" : e.isRest ? ", rest, \(e.reps) times" : ", pattern \(title), \(e.reps) times"))
        .accessibilityValue(e.isEmpty ? "" : state + (held ? ", the held scene goes here" : ""))
        .accessibilityHint(e.isEmpty ? "Opens a menu: a new pattern, a copy, one from the pool, or a rest"
                           : waiting && session.playing ? "Takes the launch back. Actions: its menu"
                           : session.playing ? "Launches it at the launch point. Actions: its menu" : "Moves the track to it. Actions: its menu")
        .accessibilityActions {
            if !e.isEmpty {
                Button("Entry menu") { openMenu(t, i, at: padFrames[key].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero) }
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
        guard !d.refused, let target = pad(at: at, track: d.track) else { return }
        move(d.track, from: d.from, to: target)
    }

    /// The pad under a point (global) in a track's row: a drag rearranges one track's list, never across rows.
    private func pad(at p: CGPoint, track: Int) -> Int? { padFrames.first { $0.key.track == track && $0.value.contains(p) }?.key.entry }

    /// Where the dragged pad would land: the pad under the finger, or past the list's end the first empty one after it.
    private func landing(of d: PadDrag) -> Int? {
        guard !d.refused, let target = pad(at: d.at, track: d.track), target != d.from,
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
        // an empty pad's choices fan out of the finger as big separate buttons (Scott, 2026-11-09); a filled pad's
        // hold keeps the ordinary menu
        ui.menu = AppMenu(title: title, groups: { e.isEmpty ? emptyMenu(t, target) : padMenu(t, i) }, at: at, fan: e.isEmpty)
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

    @ViewBuilder private func padSurface(playing: Bool, on: Bool, empty: Bool, rest: Bool, colour: Color, radius: CGFloat = 16, raised: Bool = true) -> some View {
        if empty {
            RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.stepEmpty, lineWidth: 1)
        } else if rest {
            RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.disabledOutline, lineWidth: 1.5)
        } else if playing {
            if raised { RoundedRectangle(cornerRadius: radius).fill(colour).elevationShadow(.selected) }
            else { RoundedRectangle(cornerRadius: radius).fill(colour) }
        } else if !raised {
            // the selected pad, flat in its tint: its base edge showed as a dark band under the outline
            RoundedRectangle(cornerRadius: radius).fill(Theme.control)
        } else {
            // (Chiclet keeps its radius at 8 or less: a pad's own 16, the same base edge under it)
            RoundedRectangle(cornerRadius: radius).fill(Theme.control)
                .background { RoundedRectangle(cornerRadius: radius).fill(Theme.chicletEdge).offset(y: 2) }
        }
    }

    /// A pad's outline for its state: a held scene's (white, outside), waiting (dashed, pulsing), the song's next, on it.
    @ViewBuilder private func padOutline(held: Bool, waiting: Bool, next: Bool, on: Bool, colour: Color, date: Date, radius: CGFloat, mark: Color? = nil) -> some View {
        if held {
            // a scene held: where it would send this track (Scott, 2026-11-09, board 36)
            RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.text, lineWidth: 3).padding(-3)
        } else if waiting {
            let pulse = reduceMotion ? 1 : 0.6 + 0.4 * abs(sin(date.timeIntervalSinceReferenceDate * .pi))
            RoundedRectangle(cornerRadius: radius).strokeBorder(colour, style: StrokeStyle(lineWidth: radius < 12 ? 2 : 3, dash: [8, 5])).opacity(pulse)
        } else if let mark {
            // the selected pad: its track's colour (on a playing pad, filled in that colour, the tint round it says it)
            RoundedRectangle(cornerRadius: radius).strokeBorder(mark, lineWidth: radius < 8 ? 2 : 3)
        } else if next || on {
            RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.text.opacity(on ? 1 : 0.55), lineWidth: on ? 2 : 1.5)
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
            // the whole key takes the touch, and the gaps round it: an empty scene is only an outline, and only drawn
            // pixels are hit, so its inside missed (Scott, 2026-11-09: "hard to hit"), as the empty pads once did
            .contentShape(Rectangle().inset(by: -4))
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

import SloopKit
import SwiftUI

// The Song tab's Pads view (canvas board 25; Scott, 2026-11-07: "the most live playing friendly and the most ipad type
// interface"): the selected track's 16 entries as a 4 × 4 grid of pads, as Skiff's PERFORM layer puts them on the FM-1's
// white keys; all six tracks in a strip beside it (what each plays, what's waiting, its mute); the 16 scenes always in
// view underneath (Scott: "agreed on showing the available scenes"), not behind a switch as the board had them. A pad
// tapped launches its entry (LIST op 3: at once stopped, at the launch point playing); mutes and scenes are PERFORM's.

/// Which way the Song tab shows the song. It follows the playback mode when that changes (Loop entry: Pads; Play song
/// and Play once: Timeline) and holding ARP on the FM-1 (Skiff's PERFORM layer); in between, the switch is the user's.
enum SongView: Equatable { case timeline, pads }

/// Timeline / Pads, at the head of either view.
struct SongViewSwitch: View {
    let ui: EditorUI

    var body: some View {
        SegmentedKeys(label: "Song view", options: ["Timeline", "Pads"], selected: ui.songView == .pads ? 1 : 0) { k in
            ui.songView = k == 1 ? .pads : .timeline
        }
        .fixedSize()
        .accessibilityHint("Timeline: every track's entries along the bars. Pads: one track's entries as 16 pads to launch, the scenes under them.")
    }
}

struct PadsPage: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    /// Store is latched: the next scene tapped is stored into.
    @State private var storing = false
    /// Each pattern's rhythm, as seen while a track played it (Lupe only has the steps a track is on): 16 columns.
    @State private var thumbs: [Int: [Double]] = [:]
    @State private var launched = 0               // a light haptic as a pad or scene is sent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let stripWidth: CGFloat = 248, gap: CGFloat = 12, sceneHeight: CGFloat = 56

    var body: some View {
        let _ = BodyCounter.tick("PadsPage")
        let t = session.selectedTrack
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                SongViewSwitch(ui: ui).frame(height: 44)
                ForEach(Array(session.trackIndices), id: \.self) { k in TrackStripCard(session: session, store: store, track: k) }
                Spacer(minLength: 0)
            }
            .frame(width: Self.stripWidth)
            VStack(spacing: Self.gap) {
                toolbar(t)
                GeometryReader { g in
                    let side = max(64, min((g.size.width - 3 * Self.gap) / 4, (g.size.height - 3 * Self.gap) / 4))
                    TimelineView(.periodic(from: .now, by: 0.25)) { tl in
                        let m = store.marks(t, launchIn: session.ticksToLaunch(t))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: Self.gap), count: 4), spacing: Self.gap) {
                            ForEach(0..<16, id: \.self) { i in pad(t, i, m, side: side, date: tl.date) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                sceneRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: launched)
        .task(id: store.offline) { if !store.offline { await store.follow() } }
        // the rhythms seen: once a second, each track's pattern (the drawing a pad shows)
        .task {
            while !Task.isCancelled {
                learnThumbs()
                try? await Task.sleep(for: .seconds(1))
            }
        }
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

    // MARK: Toolbar

    private func toolbar(_ t: Int) -> some View {
        let launch = store.perform?.launch ?? session.launchMode
        let waiting = waitingCount
        return HStack(spacing: 12) {
            TrackChip(track: t, size: 28)
            Text("\(Entries.trackName(t, session: session))'s entries").font(.system(size: 15, weight: .semibold))
                .lineLimit(1).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let r = store.refusal {
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

    private func pad(_ t: Int, _ i: Int, _ m: SongPlayback.Marks, side: CGFloat, date: Date) -> some View {
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
        let title = e.isEmpty ? "" : e.isRest ? "REST" : String(format: "%02d", e.pattern)
        let state: String = {
            if e.isEmpty { return "Empty" }
            if playing { return m.loops ? "Playing · looping" : m.pass.map { "Playing · pass \($0) of \(m.reps)" } ?? "Playing" }
            if waiting { return "Waiting · " + LaneMarks.countdown(m.launchIn, session.launchMode) }
            if on { return "On it" }
            if next { return "Next" }
            return e.chained ? "Chained on" : "×\(e.reps)"
        }()
        return Button {
            guard !e.isEmpty, list?.entryOn != i || !session.playing else { return }
            launched += 1
            Task { await store.send(.play(track: t, entry: i)) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(letter).font(.system(size: 15, weight: .semibold)).foregroundStyle(playing ? ink : Theme.textSecondary)
                    Spacer(minLength: 4)
                    if waiting {
                        Text(LaneMarks.countdown(m.launchIn, session.launchMode)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Theme.onColour).padding(.horizontal, 8).frame(height: 24)
                            .background(Capsule().fill(Theme.text))
                    }
                }
                if !title.isEmpty {
                    Text(title).font(.system(size: side > 150 ? 34 : 24, weight: .bold)).monospacedDigit()
                        .foregroundStyle(e.isRest ? Theme.textSecondary : ink)
                }
                Text(state).font(.system(size: 13)).foregroundStyle(playing ? ink : Theme.textSecondary).lineLimit(1)
                Spacer(minLength: 0)
                if let p = e.poolIndex, let th = thumbs[p] { Thumb(heights: th, ink: playing ? Theme.onColour.opacity(0.6) : Theme.textSecondary) }
                if playing { passBar(t, m, ink: ink) }
            }
            .padding(14)
            .frame(width: side, height: side, alignment: .topLeading)
            .background { padSurface(playing: playing, on: on, empty: e.isEmpty, rest: e.isRest, colour: colour) }
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
        .disabled(e.isEmpty || store.offline)
        .accessibilityLabel("Entry \(letter)" + (e.isEmpty ? ", empty" : e.isRest ? ", rest, \(e.reps) times" : ", pattern \(title), \(e.reps) times"))
        .accessibilityValue(e.isEmpty ? "" : state)
        .accessibilityHint(e.isEmpty ? "" : session.playing ? "Launches it at the launch point" : "Moves the track to it")
    }

    @ViewBuilder private func padSurface(playing: Bool, on: Bool, empty: Bool, rest: Bool, colour: Color) -> some View {
        if empty {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stepEmpty, lineWidth: 1)
        } else if rest {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.disabledOutline, lineWidth: 1.5)
        } else if playing {
            RoundedRectangle(cornerRadius: 16).fill(colour).elevationShadow(.selected, Look())
        } else {
            // (Chiclet keeps its radius at 8 or less: a pad's own 16, the same base edge under it)
            RoundedRectangle(cornerRadius: 16).fill(Theme.control)
                .background { RoundedRectangle(cornerRadius: 16).fill(Theme.chicletEdge).offset(y: 2) }
        }
    }

    /// Through the pass (the counted clock), and below it the passes of its REPS: a second channel to the colour.
    private func passBar(_ t: Int, _ m: SongPlayback.Marks, ink: Color) -> some View {
        let p = session.passProgress(t) ?? 0
        let whole = m.loops ? p : (Double((m.pass ?? 1) - 1) + p) / Double(max(1, m.reps))
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.onColour.opacity(0.3))
                Capsule().fill(ink).frame(width: g.size.width * min(1, max(0, whole)))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private func learnThumbs() {
        for k in session.trackIndices {
            guard let p = store.song?.tracks[safe: k]?.patternOn else { continue }
            let th = Thumb.heights(session.tracks[k])
            if thumbs[p] != th { thumbs[p] = th }
        }
    }

    // MARK: Scenes

    private var sceneRow: some View {
        let perf = store.perform
        return HStack(spacing: 8) {
            ToggleKey(name: storing ? "Store: tap a scene" : "Store", on: storing, enabled: !store.offline) { storing.toggle() }
                .fixedSize()
                .accessibilityHint("Then tap a scene: it keeps the entry each track is on now, and its mute")
            HStack(spacing: 4) {
                ForEach(0..<PerformState.scenes, id: \.self) { s in sceneKey(s, perf) }
            }
        }
        .frame(height: Self.sceneHeight)
    }

    private func sceneKey(_ s: Int, _ perf: PerformState?) -> some View {
        let kept = perf?.kept[safe: s] == true
        let last = perf?.lastScene == s
        let word = last ? "last" : kept ? "" : "empty"
        return Button {
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
                if !word.isEmpty { Text(word).font(.system(size: 10)) }
            }
            .foregroundStyle(last ? Theme.onColour : kept ? Theme.text : Theme.textSecondary)
            .frame(maxWidth: .infinity).frame(height: Self.sceneHeight)
            .background {
                if last { RoundedRectangle(cornerRadius: 8).fill(Theme.text).elevationShadow(.selected, Look()) }
                else if kept { Chiclet(radius: 8, down: false, edge: true) }
                else { RoundedRectangle(cornerRadius: 8).strokeBorder(storing ? Theme.text.opacity(0.7) : Theme.stepEmpty, lineWidth: storing ? 1.5 : 1) }
            }
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        .accessibilityLabel("Scene \(s + 1)" + (kept ? "" : ", empty") + (last ? ", recalled or stored last" : ""))
        .accessibilityHint(storing ? "Stores what plays now here" : kept ? (session.playing ? "Recalls it at the launch point" : "Recalls it") : "Empty: store into it first")
    }
}

/// One track in the strip: tap to put its entries on the pads; what it plays and how far, what's waiting, and its mute
/// (PERFORM's: staged to the launch point while playing).
struct TrackStripCard: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let track: Int

    var body: some View {
        let t = track
        let selected = session.selectedTrack == t
        let list = store.song?.tracks[safe: t]
        let perf = store.perform
        let muted = perf?.muted[safe: t] ?? session.tracks[t].mute
        let staged = perf?.staged[safe: t] ?? PerformState.Staged.none
        return TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let m = store.marks(t, launchIn: session.ticksToLaunch(t))
            let lines = Self.lines(list, m, playing: session.playing, launch: session.launchMode)
            HStack(alignment: .top, spacing: 8) {
                Button { session.select(track: t) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            TrackChip(track: t, size: 26, muted: muted)
                            Text(Entries.trackName(t, session: session)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        }
                        Text(lines.plays).font(.system(size: 13)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1)
                        if session.playing, m.playing != nil {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.well)
                                    Capsule().fill(Theme.track[t]).frame(width: g.size.width * (session.passProgress(t) ?? 0))
                                }
                            }
                            .frame(height: 4)
                        }
                        if !lines.next.isEmpty { Text(lines.next).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Track \(t + 1), \(Entries.trackName(t, session: session))\(selected ? ", on the pads" : "")")
                .accessibilityValue([lines.plays, lines.next].filter { !$0.isEmpty }.joined(separator: ", "))
                .accessibilityHint(selected ? "" : "Puts its entries on the pads")
                muteKey(muted: muted, staged: staged)
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 8))
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.control)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.text, lineWidth: 2))
                        .elevationShadow(.selected, Look())
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.panel)
                }
            }
        }
    }

    private func muteKey(muted: Bool, staged: PerformState.Staged) -> some View {
        let cd = LaneMarks.countdown(session.ticksToLaunch(track), session.launchMode)
        let label = staged == .mute ? "Mutes\n\(cd)" : staged == .unmute ? "Unmutes\n\(cd)" : muted ? "Muted" : "Mute"
        return Button { Task { await store.performOp(.mute(track: track)) } } label: {
            Text(label).font(.system(size: 12, weight: muted || staged != .none ? .semibold : .regular)).multilineTextAlignment(.center)
                .foregroundStyle(muted && staged == .none ? Theme.onColour : Theme.text)
                .frame(width: 72, height: 52)
                .background {
                    if muted && staged == .none { RoundedRectangle(cornerRadius: 8).fill(Theme.text) }
                    else if staged != .none {
                        RoundedRectangle(cornerRadius: 8).fill(Theme.control)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.text, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
                    } else { Chiclet(radius: 8, down: false, edge: true) }
                }
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        .accessibilityLabel("Mute track \(track + 1)")
        .accessibilityValue(staged == .mute ? "mutes \(cd)" : staged == .unmute ? "unmutes \(cd)" : muted ? "muted" : "playing")
        .accessibilityHint(staged != .none ? "Takes the waiting change back" : session.playing ? "At the launch point" : "")
    }

    /// What the card says: what it plays (entry, pattern, pass), and what comes (a launch waiting, the song's next).
    static func lines(_ l: SongList?, _ m: SongPlayback.Marks, playing: Bool, launch: SongPlayback.Launch) -> (plays: String, next: String) {
        guard let l else { return ("—", "") }
        func name(_ i: Int) -> String {
            let e = l.entries[safe: i] ?? .empty
            return "\(Entries.letter(i)) · " + (e.isRest ? "REST" : e.isEmpty ? "empty" : String(format: "%02d", e.pattern))
        }
        guard let on = l.entryOn else { return (playing ? "Quiet" : "On no entry", "") }
        var plays = name(on)
        if playing { plays += m.loops ? "  looping" : m.pass.map { "  pass \($0) of \(m.reps)" } ?? "" }
        var next = ""
        if m.queued != nil, let s = l.staged { next = "\(name(s)) waiting, \(LaneMarks.countdown(m.launchIn, launch))" }
        else if playing, m.ends { next = "Ends after this" }
        else if playing, m.next != nil, let s = l.staged { next = "Then \(name(s))" }
        return (plays, next)
    }
}

/// A pattern's rhythm in 16 columns: a step with a note or hit is tall, a held one half, a rest a dot.
struct Thumb: View {
    let heights: [Double]
    let ink: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1).fill(heights[i] > 0.1 ? ink : ink.opacity(0.35))
                    .frame(height: max(3, 24 * heights[i]))
            }
        }
        .frame(height: 24, alignment: .bottom)
        .accessibilityHidden(true)
    }

    /// The track's pattern (its LENGTH folded into 16 columns, the loudest of each).
    @MainActor static func heights(_ tr: TrackState) -> [Double] {
        let n = max(1, min(tr.length, tr.steps.count))
        return (0..<16).map { c in
            let range = (c * n / 16)..<max(c * n / 16 + 1, (c + 1) * n / 16)
            return range.map { i -> Double in
                guard i < tr.steps.count else { return 0 }
                if tr.isOn(i) { return tr.steps[i].time == .tie ? 0.5 : 1 }
                return 0
            }.max() ?? 0
        }
    }
}

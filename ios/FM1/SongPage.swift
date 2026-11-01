import SloopKit
import SwiftUI

/// The song, as SLOOP holds it (GUIDE §14): four sections A–D (each a whole loop of the four tracks),
/// played live, chained, or in a song order of up to 16 steps; loop / song mode; SONG REC. Sections
/// take the track colours, as on the FM-1 (ui_layers.c: TE_COL[section]).

/// Left column, under the track box: the four sections, the mode, SONG REC.
struct SectionsPanel: View {
    let session: SloopSession
    let ui: EditorUI
    @State private var confirmStore: Int?
    @State private var confirmSong = false
    /// The key just held: its release isn't a tap (a tap loads the section, over the tracks being saved).
    @State private var held: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sections").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<4, id: \.self) { k in sectionKey(k) }
            }
            Text(session.playing ? "Tap: plays from the next bar. Hold: store the loop." : "Tap: loads it as the loop. Hold: store the loop.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            SegmentedKeys(label: "Mode", options: ["Loop", "Song"], selected: session.song.songMode ? 1 : 0) { k in
                guard (k == 1) != session.song.songMode else { return }
                // into song mode: PLAY will load sections over the tracks, so ask first
                if k == 1 { confirmSong = true } else { session.toggleSongMode() }
            }
            ToggleKey(name: session.song.songRecording ? "SONG REC: recording" : "SONG REC", on: session.song.songRecording) {
                session.toggleSongRec()
            }
            .accessibilityHint("From the next bar, every section you play, and how long, becomes the song")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .confirmationDialog("PLAY will play the song order", isPresented: $confirmSong, titleVisibility: .visible) {
            if let e = (0..<4).first(where: { !session.song.stored($0) }) {
                Button("Save the tracks to \(SloopSession.sectionName(e)), then switch") { session.storeThenSongMode(in: e) }
            }
            Button("Switch without saving", role: .destructive) { session.toggleSongMode() }
            Button("Stay in Loop mode", role: .cancel) {}
        } message: {
            Text((0..<4).contains(where: { !session.song.stored($0) })
                 ? "Each step loads its section over the tracks on screen. Anything not saved in a section is lost."
                 : "Each step loads its section over the tracks on screen. All four sections are used: hold one to save the tracks there first, or they're lost.")
        }
        .confirmationDialog("Section \(SloopSession.sectionName(confirmStore ?? 0)) already holds a loop",
                            isPresented: Binding(get: { confirmStore != nil }, set: { if !$0 { confirmStore = nil } }),
                            titleVisibility: .visible) {
            Button("Replace it with the loop", role: .destructive) {
                if let k = confirmStore { session.storeLoop(in: k) }
                confirmStore = nil
            }
            Button("Keep it", role: .cancel) { confirmStore = nil }
        } message: {
            Text("The FM-1 has no undo for this.")
        }
    }

    /// A section key: its colour lit while it plays, dim while stored, dark when empty; ringed when it
    /// starts on the next bar.
    private func sectionKey(_ k: Int) -> some View {
        let s = session.song
        let stored = s.stored(k), playing = s.sectionPlaying == k, queued = s.sectionQueued == k
        let colour = Theme.track[k]
        return Button {
            if held == k { held = nil; return }
            session.playSection(k)
        } label: {
            VStack(spacing: 2) {
                Text(SloopSession.sectionName(k)).font(.system(size: 30, weight: .semibold))
                Text(playing ? (session.playing ? "playing" : "the loop") : queued ? "next bar" : stored ? "stored" : "empty")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(playing ? Theme.onColour : stored ? Theme.text : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background {
                if playing {
                    RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Theme.trackTop[k], colour], startPoint: .top, endPoint: .bottom))
                        .shadow(color: colour.opacity(0.5), radius: 10)
                } else if stored {
                    RoundedRectangle(cornerRadius: 12).fill(colour.opacity(0.22))
                        .overlay(alignment: .bottom) { Capsule().fill(colour).frame(height: 3).padding(.horizontal, 18).padding(.bottom, 8) }
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.well).recessed(12)
                }
            }
            .overlay {
                if queued { RoundedRectangle(cornerRadius: 14).stroke(Theme.text, lineWidth: 2).padding(-3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            held = k
            if stored { confirmStore = k } else { session.storeLoop(in: k) }
        })
        .accessibilityLabel("Section \(SloopSession.sectionName(k))")
        .accessibilityValue(playing ? "playing" : queued ? "starts on the next bar" : stored ? "stored" : "empty")
        .accessibilityHint(stored ? (session.playing ? "Plays from the next bar" : "Loads it as the loop") : "Empty: hold to store the loop here")
        .accessibilityAction(named: "Store the loop here") { if stored { confirmStore = k } else { session.storeLoop(in: k) } }
    }
}

/// The main area: the song order as blocks, the selected step's editor, a chain.
struct SongPage: View {
    let session: SloopSession
    let ui: EditorUI
    @State private var draft: SongOrder?
    @State private var selected = 0
    @State private var saving = false
    @State private var chain: [Int] = []

    static let blockHeight: CGFloat = 140, lowerHeight: CGFloat = 290

    private var order: SongOrder { draft ?? session.songOrder ?? .standard }
    private var editable: Bool { !session.song.songPlaying && !session.song.songRecording }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            orderPanel
            HStack(alignment: .top, spacing: 16) {
                stepEditor
                chainPanel
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: session.songOrder) { _, o in if !saving { draft = nil; _ = o } }
        // save a second after the last change: every save writes the FM-1's flash
        .task(id: draft) {
            guard let d = draft else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, d == draft else { return }
            saving = true
            session.setSongOrder(d)
            try? await Task.sleep(for: .milliseconds(400))
            saving = false
            draft = nil
        }
    }

    // MARK: The order

    private var orderPanel: some View {
        let o = order
        let s = session.song
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Song").font(.system(size: 22, weight: .semibold))
                Text(position(o, s)).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).monospacedDigit()
                Spacer()
                if saving || draft != nil { Text("Saving to the FM-1…").font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }
                ToggleKey(name: "Loop the song", on: o.loop, enabled: editable) { edit { $0.loop.toggle() } }
            }
            if let m = session.songMessage {
                Text(m).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            timeline(o, s)
            Text(editable ? "Tap a block to edit it. The order is saved on the FM-1 a second after a change."
                          : "Stop the song to change its order, as on the FM-1.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        }
        .padding(20)
        .panel()
    }

    private func position(_ o: SongOrder, _ s: SongState) -> String {
        let mode = s.songRecording ? "SONG REC" : s.songMode ? (s.songPlaying ? "song playing" : "song mode") : "loop mode"
        let where_ = s.songPlaying ? " · step \(s.songStep + 1) of \(o.steps.count), bar \(s.songBar + 1) of \(s.songStepBars)" : ""
        return "\(o.steps.count) steps · \(o.totalBars) bars · \(mode)\(where_)"
    }

    /// The steps as blocks, each as wide as its bars (scaled to fit), in its section's colour.
    private func timeline(_ o: SongOrder, _ s: SongState) -> some View {
        GeometryReader { geo in
            let addWidth: CGFloat = 64, gap: CGFloat = 6
            let room = geo.size.width - addWidth - (gap + 8) * CGFloat(o.steps.count)
            let unit = max(14, min(48, room / CGFloat(max(o.totalBars, 1))))
            ScrollView(.horizontal) {
                HStack(spacing: gap) {
                    ForEach(Array(o.steps.enumerated()), id: \.offset) { k, step in
                        block(k, step, width: max(56, CGFloat(step.bars) * unit), live: s.songPlaying && s.songStep == k)
                    }
                    if o.steps.count < SongOrder.maxSteps {
                        Button { edit { $0.steps.append(.init(section: $0.steps.last?.section ?? 0, bars: 4)); selected = $0.steps.count - 1 } } label: {
                            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                                .frame(width: addWidth, height: Self.blockHeight).raisedKey(12)
                        }
                        .buttonStyle(PressSink())
                        .disabled(!editable)
                        .accessibilityLabel("Add a step")
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: Self.blockHeight + 20)
    }

    private func block(_ k: Int, _ step: SongOrder.Step, width: CGFloat, live: Bool) -> some View {
        let colour = Theme.track[step.section]
        let isSel = k == selected
        return Button { selected = k } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(SloopSession.sectionName(step.section)).font(.system(size: 22, weight: .semibold))
                Text(live ? "bar \(session.song.songBar + 1) of \(step.bars)" : "\(step.bars) bar\(step.bars == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            .foregroundStyle(Theme.onColour)
            .padding(.horizontal, 10).padding(.top, 12)
            .frame(width: width, height: Self.blockHeight, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [Theme.trackTop[step.section], colour], startPoint: .top, endPoint: .bottom)))
            // the step playing: how far through its bars, along the bottom
            .overlay(alignment: .bottomLeading) {
                if live {
                    let s = session.song
                    let done = CGFloat(s.songBar + 1) / CGFloat(max(s.songStepBars, 1))
                    Capsule().fill(Theme.onColour.opacity(0.7))
                        .frame(width: max(8, (width - 20) * min(done, 1)), height: 4)
                        .padding([.horizontal, .bottom], 10)
                }
            }
            .overlay { if isSel { RoundedRectangle(cornerRadius: 15).stroke(Theme.text, lineWidth: 2).padding(-4) } }
        }
        .buttonStyle(PressSink())
        .padding(4)
        .accessibilityLabel("Step \(k + 1), section \(SloopSession.sectionName(step.section)), \(step.bars) bars")
        .accessibilityAddTraits(isSel ? .isSelected : [])
        .accessibilityValue(live ? "playing" : "")
    }

    // MARK: The selected step

    private var stepEditor: some View {
        let o = order
        let k = min(selected, o.steps.count - 1)
        let step = o.steps[max(k, 0)]
        return VStack(alignment: .leading, spacing: 14) {
            Text("Step \(k + 1)").font(.system(size: 17, weight: .semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("Section").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                SegmentedKeys(label: "Section", options: ["A", "B", "C", "D"], selected: step.section,
                              enabled: (0..<4).map { _ in editable }, minWidth: 44) { s in edit { $0.steps[k].section = s } }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Length").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                StepperKeys(label: "Bars", value: step.bars, range: 1...64, step: 1, enabled: editable,
                            format: { "\($0) bar\($0 == 1 ? "" : "s")" }) { b in edit { $0.steps[k].bars = b } }
            }
            HStack(spacing: 8) {
                smallKey("arrow.left", "Move earlier", enabled: editable && k > 0) {
                    edit { $0.steps.swapAt(k, k - 1) }; selected = k - 1
                }
                smallKey("arrow.right", "Move later", enabled: editable && k < o.steps.count - 1) {
                    edit { $0.steps.swapAt(k, k + 1) }; selected = k + 1
                }
                smallKey("plus.square.on.square", "Duplicate", enabled: editable && o.steps.count < SongOrder.maxSteps) {
                    edit { $0.steps.insert(.init(section: step.section, bars: step.bars), at: k + 1) }; selected = k + 1
                }
                smallKey("trash", "Remove", enabled: editable && o.steps.count > 1) {
                    edit { $0.steps.remove(at: k) }; selected = max(0, k - 1)
                }
            }
        }
        .padding(20)
        .frame(width: 360, alignment: .topLeading)
        .frame(minHeight: Self.lowerHeight, alignment: .top)
        .panel()
    }

    private func smallKey(_ icon: String, _ label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).frame(width: 52, height: 44).raisedKey()
        }
        .buttonStyle(PressSink())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: A chain

    private var chainPanel: some View {
        let s = session.song
        let running = s.chainLength > 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Chain").font(.system(size: 17, weight: .semibold))
                Text("sections in turn, each for its pattern length, round and round")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { k in
                    Button { if chain.count < 8 { chain.append(k) } } label: {
                        Text(SloopSession.sectionName(k)).font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(s.stored(k) ? Theme.text : Theme.textTertiary)
                            .frame(width: 52, height: 44).raisedKey()
                    }
                    .buttonStyle(PressSink())
                    .disabled(!s.stored(k) || chain.count >= 8)
                    .accessibilityLabel("Add \(SloopSession.sectionName(k)) to the chain")
                }
                Spacer(minLength: 0)
            }
            // the chain so far (or the one playing), the section playing lit
            HStack(spacing: 6) {
                let shown = running ? session.chainAsked : chain
                if shown.isEmpty {
                    Text("Tap sections to build a chain of up to 8.").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
                ForEach(Array(shown.enumerated()), id: \.offset) { i, k in
                    Text(SloopSession.sectionName(k)).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(running && i == s.chainIndex ? Theme.onColour : Theme.text)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(running && i == s.chainIndex ? Theme.track[k] : Theme.track[k].opacity(0.22)))
                }
            }
            .frame(minHeight: 36)
            HStack(spacing: 8) {
                if running {
                    Button { session.stopChain() } label: { label("Stop the chain") }.buttonStyle(PressSink())
                } else {
                    Button { session.playChain(chain) } label: { label("Play the chain") }
                        .buttonStyle(PressSink())
                        .disabled(chain.count < 2)
                    Button { chain = [] } label: { label("Clear") }.buttonStyle(PressSink()).disabled(chain.isEmpty)
                }
            }
            if !session.playing && !running {
                Text("A chain starts on the next bar, so press play first.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: Self.lowerHeight, alignment: .topLeading)
        .panel()
    }

    private func label(_ t: String) -> some View {
        Text(t).fontWeight(.semibold).padding(.horizontal, 16).frame(height: 44).raisedKey()
    }

    /// One change to the order: shown at once, saved a second after the last change.
    private func edit(_ change: (inout SongOrder) -> Void) {
        guard editable else { return }
        var o = order
        change(&o)
        draft = o
    }
}

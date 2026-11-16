import SloopKit
import SwiftUI

// FREE TAKE, levels 2 and 3 (Skiff-Lupe's screen link v7; vault batch-list.md item 4, canvas boards 49–50, generator
// design/boards/freetake.py). Scott picked form A on 2026-11-11: the FM-1's picker shown in the editor's place, the
// way the sampler comes in, so nothing moves and the Timeline stays in view. The four choices are Skiff's four knobs in
// words; Listen is its PLAY, Put back its OCT−, Keep it its OCT+ (asked once more in place when it replaces a pattern).
// The FM-1 rewrites the track on every choice, and the notes here are the track's own steps as the live sync brings
// them: exact, not a preview.

/// The picker, in the editor panel on the track's tint (SkiffSongPage puts it where PatternPane is).
struct FreeTakePicker: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let picker: TakePicker
    /// Keep it asked once more (-demo-take-confirm: open on it, for the screenshots).
    @State private var confirming = LaunchArgs.all.contains("-demo-take-confirm")
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var t: Int { picker.track }
    private var name: String { Entries.trackName(t, session: session) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            HStack(alignment: .top, spacing: 24) {
                TakeNotes(session: session, track: t, bars: picker.bars)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ScrollView(.vertical) { choices.padding(.bottom, 4) }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: 392)
            }
            .frame(maxHeight: .infinity)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: picker.open) { _, _ in confirming = false }
    }

    // MARK: What it is, and what it replaces

    private var header: some View {
        HStack(spacing: 12) {
            TrackChip(track: t)
            VStack(alignment: .leading, spacing: 4) {
                Text("Keep that take on T\(t + 1) \(name)").font(.lupe(17, .semibold))
                Text(replaces).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
    }

    /// The pattern a keep writes over, and its other entries (they name the same pattern, so they change too).
    private var replaces: String {
        guard let p = picker.pattern else { return "The FM-1 writes it into the track. Undo brings back what was there." }
        let others = otherUses(p)
        let more = others > 0 ? ", and on its \(others) other entr\(others == 1 ? "y" : "ies")" : ""
        return "Replaces pattern \(Entries.number(p + 1)) there\(more). Undo brings it back."
    }

    private func otherUses(_ p: Int) -> Int {
        guard let song = store.song else { return 0 }
        let n = song.tracks.reduce(0) { $0 + $1.entries.filter { $0.poolIndex == p }.count }
        return max(0, n - 1)
    }

    // MARK: The four choices (Skiff's KNOB 1–4)

    private var choices: some View {
        VStack(alignment: .leading, spacing: 16) {
            choice("Tempo", help: "Skiff's guesses, the likeliest first") {
                CaptionedSegments(label: "Tempo", options: picker.guesses.enumerated().map { i, g in
                    ("\(g)", i == 0 ? "guess" : picker.relation(i) ?? "")
                }, selected: picker.guess) { session.takeOp(.guess($0)) }
            }
            choice("Bars", help: nil) {
                SegmentedKeys(label: "Bars", options: TakePicker.barChoices.map(String.init), selected: picker.barsIndex, minWidth: 56) {
                    session.takeOp(.bars($0))
                }
            }
            choice("Where the 1 is", help: "which note is the first beat") { firstBeat }
            choice("Song tempo", help: picker.externalClock ? "on an external clock: the clock's" : "the song's \(picker.tempoBefore) BPM before") {
                SegmentedKeys(label: "Song tempo", options: ["Set to \(picker.bpm)", "Keep \(picker.tempoBefore)"],
                              selected: picker.setsTempo ? 0 : 1, enabled: [!picker.externalClock, true]) {
                    session.takeOp(.setTempo($0 == 0))
                }
            }
        }
    }

    private func choice<C: View>(_ label: String, help: String?, @ViewBuilder _ control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(label).font(.lupe(13, .semibold))
                if let help { Text(help).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised) }
            }
            .foregroundStyle(Theme.text)
            .accessibilityHidden(true)                       // (each control carries its own label)
            control()
        }
    }

    /// ◀ note n of m ▶: taps, no drag (WCAG 2.5.7); VoiceOver swipes it up and down.
    private var firstBeat: some View {
        let n = picker.firstBeat, m = max(1, picker.firstBeats)
        return HStack(spacing: 8) {
            stepKey("chevron.left", "Earlier note", enabled: n > 0) { session.takeOp(.firstBeat(n - 1)) }
            Text("note \(n + 1) of \(m)").font(.lupe(15, .semibold)).monospacedDigit()
                .frame(minWidth: 112).accessibilityHidden(true)
            stepKey("chevron.right", "Later note", enabled: n < m - 1) { session.takeOp(.firstBeat(n + 1)) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Where the 1 is")
        .accessibilityValue("note \(n + 1) of \(m)")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: if n < m - 1 { session.takeOp(.firstBeat(n + 1)) }
            case .decrement: if n > 0 { session.takeOp(.firstBeat(n - 1)) }
            @unknown default: break
            }
        }
    }

    private func stepKey(_ symbol: String, _ label: String, enabled: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                .frame(width: 52, height: 44).raisedKey().contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: Listen, Put back, Keep it

    private var actions: some View {
        HStack(spacing: 12) {
            key(session.playing ? "Stop" : "Listen", symbol: session.playing ? "stop.fill" : "play.fill") { session.takeOp(.listen) }
            key("Put back", symbol: "arrow.uturn.backward") { confirming = false; session.takeOp(.putBack) }
            Spacer(minLength: 0)
            if confirming {
                key("Cancel") { confirming = false }
                    .transition(.opacity)
                Button { confirming = false; session.takeOp(.keep) } label: {
                    Text(confirmText).font(.lupe(15, .semibold)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 18).frame(minHeight: 44)
                        .background { Color.clear.raisedKey() }
                        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.recText, lineWidth: 3) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityHint("The pattern it replaces goes; Undo on the landing strip brings it back")
                .transition(.opacity)
            } else {
                Button {
                    if picker.pattern == nil { session.takeOp(.keep) } else { confirming = true }
                } label: {
                    Text("Keep it").font(.lupe(15, .semibold)).foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 28).frame(minHeight: 44)
                        .background { Color.clear.modifier(RaisedKey(primary: true)) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: confirming)
    }

    private var confirmText: String {
        guard let p = picker.pattern else { return "Keep it" }
        let others = otherUses(p)
        return "Replace pattern \(Entries.number(p + 1)) on T\(t + 1)" + (others > 0 ? " and \(others) more" : "")
    }

    private func key(_ title: String, symbol: String? = nil, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).accessibilityHidden(true) }
                Text(title).font(.lupe(15, .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18).frame(minHeight: 44)
            .raisedKey().contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
    }
}

/// One of several with a caption under each (the tempo guesses: half, guess, double), as SegmentedKeys draws them.
private struct CaptionedSegments: View {
    let label: String
    let options: [(String, String)]
    let selected: Int
    let choose: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { k, o in
                let on = k == selected
                Button { choose(k) } label: {
                    VStack(spacing: 0) {
                        Text(o.0).font(.lupe(15, on ? .semibold : .regular)).monospacedDigit()
                        Text(o.1).font(.lupe(11))
                    }
                    .foregroundStyle(on ? Theme.text : Theme.textSecondaryRaised)
                    .frame(minWidth: 64, minHeight: 48)
                    .background { if on { Color.clear.raisedKey() } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel(o.1.isEmpty ? "\(o.0) BPM" : "\(o.0) BPM, \(o.1)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// The take's notes as the FM-1 placed them: the track's steps over the picker's bars, a 16th grid with the bar lines
/// strong, each note a block at its pitch in the track's colour (held notes run on through their ties). Re-grids on a
/// 150 ms ease as the choices change (Reduce Motion: none).
struct TakeNotes: View {
    let session: DeviceSession
    let track: Int
    let bars: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Note: Identifiable, Equatable { let id: String; let step: Int; let len: Int; let pitch: Int }

    private var len: Int { max(1, min(session.tracks[safe: track]?.steps.count ?? 64, bars >= 8 ? 64 : 16 * bars)) }

    private var notes: [Note] {
        guard let tr = session.tracks[safe: track] else { return [] }
        var out: [Note] = []
        for i in 0..<min(len, tr.steps.count) where tr.steps[i].time == .note {
            for p in tr.steps[i].notes {
                var j = i + 1
                while j < len, tr.steps[j].time == .tie { j += 1 }
                out.append(Note(id: "\(i).\(p)", step: i, len: j - i, pitch: p))
            }
        }
        return out
    }

    var body: some View {
        let ns = notes
        let lo = (ns.map(\.pitch).min() ?? 60) - 2, hi = (ns.map(\.pitch).max() ?? 72) + 2
        let colour = Theme.track[track]
        GeometryReader { g in
            let w = g.size.width - 24, h = g.size.height - 40
            let sw = w / CGFloat(len), rows = CGFloat(max(1, hi - lo))
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for k in 0...len {
                        let x = 12 + CGFloat(k) * sw
                        let c: Color = k % 16 == 0 ? Theme.tones[3] : k % 4 == 0 ? Theme.tones[0] : Theme.stepOutside
                        ctx.fill(Path(CGRect(x: x, y: 8, width: k % 16 == 0 ? 2 : 1, height: h)), with: .color(c))
                    }
                }
                ForEach(ns) { n in
                    RoundedRectangle(cornerRadius: 3).fill(colour)
                        .frame(width: max(4, CGFloat(n.len) * sw - 2), height: max(6, min(12, h / rows)))
                        .offset(x: 12 + CGFloat(n.step) * sw + 1, y: 8 + (CGFloat(hi - n.pitch) / rows) * (h - 10))
                }
                ForEach(0..<max(1, (len + 15) / 16), id: \.self) { b in
                    Text("\(b + 1)").font(.lupe(11, .semibold)).foregroundStyle(Theme.textSecondaryRaised)
                        .offset(x: 16 + CGFloat(b * 16) * sw, y: h + 14)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: ns)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: len)
        }
        .frame(minHeight: 140)
        .background { RoundedRectangle(cornerRadius: 12).fill(Theme.well) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The take's notes")
        .accessibilityValue(ns.isEmpty ? "none yet" : "\(ns.count) notes over \(bars) bar\(bars == 1 ? "" : "s")")
    }
}


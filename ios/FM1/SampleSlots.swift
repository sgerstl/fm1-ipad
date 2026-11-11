import SloopKit
import SwiftUI

/// The FM-1's user sample slots in the sound panel (Skiff's USR1–3, SLOOP's SMPL1–4): the "Your samples" section, and
/// the same keys under the Sample engine. Each slot is a key that plays it on the track (a full one) with a ▶ that
/// reads it back and plays it here, and under it Record…, Import file… and, when full, Clear… (batch list 3,
/// 2026-11-11). On Skiff a line says the song stops for these and starts again after.
struct SampleSlotList: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(AudioThrough.self) private var through
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Plays a slot read back from the FM-1; one at a time.
    @State private var player = SampleRecorder()
    @State private var held: [Int: (samples: [Int16], rate: Double)] = [:]
    @State private var reading: Int?
    @State private var hearing: Int?
    @State private var problem: (slot: Int, text: String)?

    private var t: Int { session.selectedTrack }
    private var slots: [SampleSlot] { session.sampleSlots }
    private var sampleEngine: Int? { session.info?.engines.firstIndex(of: "SAMPLE") }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {       // 8 inside a slot, 24 between slots: three groups at a glance
            if session.sampleWorkStopsSong { StopsSongNote(session: session, what: "Saving, clearing or hearing a slot") }
            ForEach(0..<session.sampleSlotCount, id: \.self) { k in slot(k).id("usr-\(k)") }
        }
        .padding(4)
        .task { await session.refreshSampleSlots() }
        .onChange(of: player.state) { _, s in
            if s != .playing { hearing = nil; through.suspended = false }
        }
        .onDisappear { player.close(); through.suspended = false }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: problem?.text)
    }

    // MARK: One slot: its key and ▶, then Record…, Import file…, Clear…

    private func slot(_ k: Int) -> some View {
        let s = k < slots.count ? slots[k] : nil
        let full = s.map { !$0.isEmpty } ?? false
        let name = session.sampleSlotName(k)
        let current = full && session.tracks[t].engine == sampleEngine && session.tracks[t].presetName == name
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if full, let s { useKey(k, sound: s, current: current) } else { emptyKey(k) }
                // ▶ only where the slot can be read back (Skiff's backup objects 32–34; SLOOP's sample commands only write)
                if full, session.dialect == .skiff { hearKey(k, sound: s?.name ?? "") }
            }
            HStack(spacing: 8) {
                actionKey("Record…", icon: "mic", hint: full ? "Records a new take to replace \(s?.name.capitalized ?? "")" : "Records a take for \(name)") {
                    ui.sampler = SamplerRequest(track: t, slot: k, fromBrowse: true)
                }
                actionKey("Import file…", icon: "square.and.arrow.down", hint: "WAV, AIFF or M4A from Files, trimmed to fit \(name)") {
                    ui.sampler = SamplerRequest(track: t, slot: k, fromBrowse: true, importing: true)
                }
                Spacer(minLength: 0)
                if full { actionKey("Clear…", icon: "trash", hint: "Asks before erasing \(name)") { askClear(k) } }
            }
            if let p = problem, p.slot == k {
                Text(p.text).font(.lupe(13)).foregroundStyle(Theme.text)
                    .transition(.opacity)
            }
        }
        .disabled(session.isDrums(t))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
    }

    /// A full slot: plays it on the track at a tap (SAMPLE, SET = the slot), lit while the track plays it.
    private func useKey(_ k: Int, sound: SampleSlot, current: Bool) -> some View {
        let name = session.sampleSlotName(k)
        return Button { Task { await session.useSample(slot: k, onTrack: t) } } label: {
            HStack(spacing: 10) {
                LED(on: current, colour: Theme.track[t])
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.name.capitalized).fontWeight(current ? .semibold : .regular).lineLimit(1)
                    Text("\(name) · \(sound.kib) KB").font(.lupe(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .latchedKey(current, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: current))
        .accessibilityLabel("\(sound.name.capitalized), \(name), \(sound.kib) KB")
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityHint(current ? "" : "Plays it on track \(t + 1)")
    }

    /// An empty slot: dashed, as Skiff's empty user slots are; Record… and Import file… under it fill it.
    private func emptyKey(_ k: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sampleSlotName(k)).foregroundStyle(Theme.textSecondary)
                Text("Empty · Record or import a sound").font(.lupe(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ledOff, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .accessibilityElement(children: .combine)
    }

    /// ▶: what the slot holds, read back from the FM-1 once (the backup's objects 32–34) and played on the iPad.
    private func hearKey(_ k: Int, sound: String) -> some View {
        let on = hearing == k
        return Button { hear(k) } label: {
            ZStack {
                if reading == k { ProgressView().tint(Theme.text) }
                else { Image(systemName: on ? "stop.fill" : "play.fill").font(.system(size: 18, weight: .semibold)) }
            }
            .foregroundStyle(Theme.text)
            .frame(width: 56, height: 56).raisedKey(10).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(reading != nil && reading != k)
        .accessibilityLabel(reading == k ? "Reading \(sound.capitalized) from the FM-1" : on ? "Stop" : "Hear \(sound.capitalized)")
        .accessibilityHint(session.sampleWorkStopsSong && session.playing ? "Reading it stops the song for a moment; it starts again after" : "Read from the FM-1, played on the iPad")
    }

    private func actionKey(_ title: String, icon: String, hint: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).accessibilityHidden(true)
                Text(title).font(.lupe(13, .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12).frame(height: 44)
            .raisedKey()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!session.isConnected)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    // MARK: Hearing and clearing

    private func hear(_ k: Int) {
        if hearing == k { player.stop(); return }
        problem = nil
        if let h = held[k] { play(k, h); return }
        reading = k
        Task {
            defer { reading = nil }
            do {
                guard let h = try await session.storedSample(slot: k) else {
                    problem = (k, "This FM-1 can't send its samples back, so they can't be heard here.")
                    return
                }
                held[k] = h
                play(k, h)
            } catch {
                problem = (k, "The FM-1 didn't send it. Check the cable and try again.")
            }
        }
    }

    private func play(_ k: Int, _ h: (samples: [Int16], rate: Double)) {
        through.suspended = true
        player.play(h.samples, rate: h.rate)
        hearing = k
    }

    /// Clear a sample slot: asked once more in place, naming what goes; the FM-1 keeps no copy.
    private func askClear(_ k: Int) {
        let name = session.sampleSlotName(k)
        let sound = k < slots.count ? slots[k].name.capitalized : ""
        ui.menu = AppMenu.confirm("Clear \(name)", confirm: "Clear \(name) “\(sound)”",
                                  caption: session.sampleWorkStopsSong && session.playing
                                    ? "Erased from the FM-1, which keeps no copy. The song stops for a moment and starts again after."
                                    : "Erased from the FM-1, which keeps no copy.") {
            held[k] = nil
            Task { try? await session.eraseSample(slot: k) }
        }
    }
}

/// Skiff stops the song for any sample write or read-back, and its sound for a few seconds while flash is erased
/// (DeviceSession.sampleWorkStopsSong): said before it happens. A plain line when stopped; while playing, in the
/// caution colour with its icon (not colour alone), as that's when it matters.
struct StopsSongNote: View {
    let session: DeviceSession
    /// What does it, as the sentence's subject: "Saving to a slot".
    let what: String

    var body: some View {
        let playing = session.playing
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: playing ? "exclamationmark.triangle.fill" : "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(playing ? Theme.caution : Theme.textSecondary)
                .accessibilityHidden(true)
            Text(playing ? "The song is playing. \(what) stops it and the FM-1's sound for a few seconds; Lupe starts it again after."
                         : "\(what) stops the FM-1's sound for a few seconds.")
                .font(.lupe(13))
                .foregroundStyle(playing ? Theme.text : Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(playing ? "Warning: the song is playing. \(what) stops it for a few seconds; Lupe starts it again after."
                                    : "\(what) stops the FM-1's sound for a few seconds.")
    }
}

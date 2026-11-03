import SloopKit
import SwiftUI

/// Where the sampler was opened from: a track's long-press menu (the grid flips over to it) or an empty
/// USR slot on Browse (it slides up from the bottom). `slot` nil: the next empty one, or ask.
struct SamplerRequest: Equatable {
    var track: Int
    var slot: Int?
    var fromBrowse = false
}

/// Record a sample with the iPad's microphone and put it in a USR slot: the take as one big waveform in
/// the track's colour, trimmed with two handles, inside a small screen like the FM-1's (slot, name,
/// length, rate, peak). "Use on track" uploads it and sets the track to Sample › USRn (2026-11-03,
/// direction A with C's screen).
struct SamplerPanel: View {
    let session: SloopSession
    let ui: EditorUI
    let request: SamplerRequest
    @Environment(AudioThrough.self) private var through
    @State private var rec = SampleRecorder()
    @State private var slot: Int?
    @State private var replacing = false
    @State private var progress: Double?
    @State private var message: String?

    private var t: Int { request.track }
    private var colour: Color { Theme.track[t] }
    private var slots: [SampleSlot] { session.sampleSlots }
    private var name: String { "TAPE \((slot ?? 0) + 1)" }
    private var hasTake: Bool { rec.end > rec.start && rec.state != .recording }
    private var busy: Bool { progress != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            screen
            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
        .onAppear {
            through.suspended = true
            slot = request.slot ?? slots.firstIndex(where: \.isEmpty)
        }
        .onDisappear {
            rec.close()
            through.suspended = false
        }
        .task { if slots.isEmpty { await session.refreshSampleSlots(); if slot == nil { slot = request.slot ?? slots.firstIndex(where: \.isEmpty) } } }
        .alert("Replace USR\((slot ?? 0) + 1)?", isPresented: $replacing) {
            Button("Replace \(slotName(slot ?? 0))", role: .destructive) { upload() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(slotName(slot ?? 0))” is in that slot. The FM-1 keeps no copy of it.")
        }
    }

    // MARK: Header: what this is, Cancel, Use on track

    private var header: some View {
        HStack(spacing: 12) {
            TrackChip(track: t)
            VStack(alignment: .leading, spacing: 2) {
                Text("Record a sample").font(.system(size: 17, weight: .semibold))
                Text("Track \(t + 1) · iPad microphone").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { close() } label: {
                Text("Cancel").font(.system(size: 15, weight: .semibold)).padding(.horizontal, 16).frame(height: 44)
                    .background { Color.clear.raisedKey() }.contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(busy)
            Button { done() } label: {
                Text("Use on track \(t + 1)").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canUse ? Theme.onColour : Theme.textTertiary)
                    .padding(.horizontal, 16).frame(height: 44)
                    .background { RoundedRectangle(cornerRadius: 9).fill(canUse ? Theme.text : Theme.pressed) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(!canUse)
            .accessibilityHint(slot == nil ? "Pick a slot first" : "Puts the sample in USR\((slot ?? 0) + 1) and plays it on track \(t + 1)")
        }
    }

    private var canUse: Bool {
        guard case .connected = session.status else { return false }
        return hasTake && slot != nil && !busy
    }

    // MARK: The screen: slot and name, the waveform, the facts

    private var screen: some View {
        VStack(spacing: 10) {
            HStack {
                Text(slot.map { "USR\($0 + 1)  \(name)" } ?? "PICK A SLOT")
                Spacer()
                Text(rec.state == .recording ? String(format: "%.1fs / %.1fs", rec.seconds, rec.maxSeconds)
                                             : hasTake ? String(format: "%.1fs", rec.trimmedSeconds) : "")
            }
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.trackTop[t])
            .accessibilityElement(children: .combine)
            waveform
            HStack(spacing: 18) {
                Text("22 kHz"); Text("ONE-SHOT"); Text("ROOT C4")
                Spacer()
                Text(footerRight)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background { RoundedRectangle(cornerRadius: 12).fill(Theme.well).recessed(12) }
    }

    private var footerRight: String {
        if let p = progress { return "SENDING TO FM-1 \(Int(p * 100))%" }
        if let m = message { return m }
        if hasTake, rec.peakDB.isFinite { return String(format: "PEAK %.0f dB", rec.peakDB) }
        return ""
    }

    private var waveform: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            // while recording the screen is the whole slot; after, the take fills it for trimming
            let span = rec.state == .recording ? Int(rec.maxSeconds * rec.rate) : max(rec.take.count, 1)
            let bars = Self.bars(rec.take, span: span, count: Int(w / 4))
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x0A0A0C))
                if rec.take.isEmpty {
                    Text(emptyText).font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Canvas { c, size in
                        let n = bars.count, bw = size.width / CGFloat(max(n, 1))
                        for (i, v) in bars.enumerated() {
                            let x = CGFloat(i) * bw
                            let sample = Int(Double(i) / Double(n) * Double(span))
                            let inside = rec.state == .recording || (sample >= rec.start && sample <= rec.end)
                            let a = max(1, CGFloat(v) * size.height * 0.46)
                            c.fill(Path(roundedRect: CGRect(x: x + 0.5, y: size.height / 2 - a, width: max(1, bw - 1.5), height: a * 2), cornerRadius: 1),
                                   with: .color(inside ? colour : Theme.stepEmpty))
                        }
                    }
                    if hasTake {
                        handle(at: rec.start, of: span, width: w, height: h) { rec.start = min(max(0, $0), rec.end - Int(0.05 * rec.rate)) }
                            .accessibilityLabel("Start").accessibilityValue(String(format: "%.2f seconds", Double(rec.start) / rec.rate))
                        handle(at: rec.end, of: span, width: w, height: h) { rec.end = max(min(rec.take.count, $0), rec.start + Int(0.05 * rec.rate)) }
                            .accessibilityLabel("End").accessibilityValue(String(format: "%.2f seconds", Double(rec.end) / rec.rate))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(hasTake ? String(format: "Take, %.1f seconds after trimming", rec.trimmedSeconds) : "No take yet")
    }

    private var emptyText: String {
        switch rec.state {
        case .denied: "Jib can't use the microphone. Turn it on in Settings › Jib."
        case .failed(let why): why
        default: String(format: "Tap the red key and play. Up to %.0f seconds.", rec.maxSeconds)
        }
    }

    /// A trim handle: a line across the screen with a grip in the middle, dragged sideways. VoiceOver
    /// moves it by a tenth of a second with swipes.
    private func handle(at sample: Int, of span: Int, width: CGFloat, height: CGFloat, _ set: @escaping (Int) -> Void) -> some View {
        let x = CGFloat(sample) / CGFloat(span) * width
        return ZStack {
            Rectangle().fill(Theme.text).frame(width: 3, height: height)
            RoundedRectangle(cornerRadius: 7).fill(Theme.text).frame(width: 22, height: 44)
        }
        .frame(width: 44, height: height)
        .contentShape(Rectangle())
        .position(x: x, y: height / 2)
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            set(Int(max(0, min(width, v.location.x)) / width * CGFloat(span)))
        })
        .accessibilityElement()
        .accessibilityAdjustableAction { d in
            let step = Int(0.1 * rec.rate)
            set(sample + (d == .increment ? step : -step))
        }
    }

    /// The take's loudness in `count` columns over `span` samples (the peak in each).
    static func bars(_ x: [Float], span: Int, count: Int) -> [Float] {
        guard count > 0, !x.isEmpty else { return [] }
        let per = max(1, span / count)
        return (0..<count).compactMap { i in
            let a = i * per
            guard a < x.count else { return nil }
            return x[a..<min(x.count, a + per)].reduce(Float(0)) { max($0, abs($1)) }
        }
    }

    // MARK: REC, play, the input meter, the slots

    private var controls: some View {
        HStack(spacing: 16) {
            recKey
            playKey
            VStack(alignment: .leading, spacing: 6) {
                Text("Input").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.well)
                        Capsule().fill(rec.level > 0.9 ? Theme.rec : colour)
                            .frame(width: g.size.width * CGFloat(min(1, rec.level)))
                    }
                }
                .frame(height: 8)
            }
            .frame(width: 180)
            .accessibilityHidden(true)
            Spacer(minLength: 12)
            slotPicker
        }
        .frame(height: 88)
    }

    private var recKey: some View {
        let on = rec.state == .recording
        return Button {
            if on { rec.stop() } else { message = nil; Task { await rec.record() } }
        } label: {
            ZStack {
                Circle().fill(LinearGradient(colors: [Theme.raisedTop, Theme.raisedBottom], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                if on {
                    Circle().fill(Theme.rec)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.text).frame(width: 24, height: 24)
                } else {
                    Circle().fill(Theme.rec).frame(width: 30, height: 30)
                }
            }
            .frame(width: 88, height: 88)
            .contentShape(Circle())
        }
        .buttonStyle(PressSink())
        .disabled(busy)
        .accessibilityLabel(on ? "Stop recording" : hasTake ? "Record again" : "Record")
    }

    private var playKey: some View {
        let on = rec.state == .playing
        return Button { on ? rec.stop() : rec.play() } label: {
            Image(systemName: on ? "stop.fill" : "play.fill").font(.system(size: 20, weight: .semibold))
                .foregroundStyle(hasTake ? Theme.text : Theme.textTertiary)
                .frame(width: 56, height: 56)
                .background { Color.clear.raisedKey(12) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!hasTake || busy)
        .accessibilityLabel(on ? "Stop" : "Play the take")
    }

    private var slotPicker: some View {
        HStack(spacing: 6) {
            Text(slot == nil && !slots.isEmpty ? "Pick a slot to replace" : "Slot")
                .font(.system(size: 12)).foregroundStyle(slot == nil ? Theme.text : Theme.textSecondary)
            ForEach(0..<max(4, slots.count), id: \.self) { k in
                let picked = slot == k
                Button { slot = k } label: {
                    VStack(spacing: 2) {
                        Text("USR\(k + 1)").font(.system(size: 13, weight: .semibold))
                        Text(k < slots.count && !slots[k].isEmpty ? slots[k].name : "empty")
                            .font(.system(size: 10)).lineLimit(1)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .foregroundStyle(picked ? Theme.text : Theme.textSecondary)
                    .frame(width: 64, height: 48)
                    .background { if picked { Color.clear.raisedKey() } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(busy)
                .accessibilityLabel("USR\(k + 1), \(k < slots.count && !slots[k].isEmpty ? slots[k].name : "empty")")
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
    }

    private func slotName(_ k: Int) -> String { k < slots.count && !slots[k].isEmpty ? slots[k].name : "empty" }

    // MARK: Done and cancel

    private func done() {
        guard let k = slot else { return }
        rec.stop()
        if k < slots.count, !slots[k].isEmpty { replacing = true } else { upload() }
    }

    private func upload() {
        guard let k = slot else { return }
        let samples = rec.samplesForSlot()
        progress = 0
        message = nil
        Task {
            do {
                try await session.uploadSample(slot: k, name: name, samples: samples) { progress = $0 }
                await session.useSample(slot: k, onTrack: t)
                progress = nil
                close()
            } catch {
                progress = nil
                message = Self.describe(error)
            }
        }
    }

    private func close() {
        rec.close()
        ui.sampler = nil
    }

    private static func describe(_ e: Error) -> String {
        switch e {
        case SloopSession.SampleError.notConnected: "THE FM-1 ISN'T CONNECTED"
        case SloopSession.SampleError.tooLong: "TOO LONG FOR A SLOT: TRIM IT"
        case SloopSession.SampleError.empty: "NOTHING TO SEND: RECORD A TAKE"
        case SloopSession.SampleError.refused(let stage, let rc): "THE FM-1 REFUSED IT (\(stage.uppercased()) \(rc))"
        default: "THE FM-1 DIDN'T ANSWER: TRY AGAIN"
        }
    }
}

/// One face of a card turning about its vertical axis: shown while it faces the front (under 90°),
/// so the grid and the sampler swap exactly halfway through the turn.
struct FlipFace: ViewModifier, Animatable {
    var angle: Double
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .opacity(abs(angle) < 90 ? 1 : 0)
            .allowsHitTesting(abs(angle) < 90)
            .accessibilityHidden(abs(angle) >= 90)
    }
}

import SloopKit
import SwiftUI
import UniformTypeIdentifiers

/// Where the sampler was opened from: a track's long-press menu (the grid flips over to it) or a slot's Record… or
/// Import file… in the sound panel (it slides up from the bottom). `slot` nil: the next empty one, or ask. `importing`:
/// the Files picker opens at once (Import file…).
struct SamplerRequest: Equatable {
    var track: Int
    var slot: Int?
    var fromBrowse = false
    var importing = false
}

/// Record a sample with the iPad's microphone and put it in a sample slot: the take as one big waveform in
/// the track's colour, trimmed with two handles, inside a small screen like the FM-1's (slot, name,
/// length, rate, peak). "Use on track" uploads it and sets the track to Sample › USRn (2026-11-03,
/// direction A with C's screen).
struct SamplerPanel: View {
    let session: DeviceSession
    let ui: EditorUI
    let request: SamplerRequest
    @Environment(AudioThrough.self) private var through
    @State private var rec = SampleRecorder()
    @State private var slot: Int?
    /// A full slot tapped after a take: the dialog that asks before replacing it, and what it holds once read back.
    @State private var asking: Int?
    @State private var held: [Int: (samples: [Int16], rate: Double)] = [:]
    @State private var reading = false
    @State private var heldProblem: String?
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double?
    @State private var message: String?
    /// The Files picker (Import file…), and a file it couldn't read.
    @State private var picking = false
    @State private var askedAt = Date.distantPast
    @State private var loading = false

    private var t: Int { request.track }
    private var colour: Color { Theme.track[t] }
    private var slots: [SampleSlot] { session.sampleSlots }
    private var name: String { "\(session.sampleSlotName(slot ?? 0))" }
    private var hasTake: Bool { rec.end > rec.start && rec.state != .recording }
    private var busy: Bool { progress != nil || loading }
    /// Import file… takes these three (Scott, 2026-11-08); no drag and drop.
    static let fileTypes: [UTType] = [.wav, .aiff, .mpeg4Audio]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            screen
            if hasTake, session.sampleWorkStopsSong, asking == nil { StopsSongNote(session: session, what: "Saving to a slot") }
            ZStack {
                if let k = asking { replaceConfirm(k).transition(.opacity.combined(with: .move(edge: .bottom))) }
                else { controls.transition(.opacity) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
        .onAppear {
            through.suspended = true
            slot = request.slot ?? slots.firstIndex(where: \.isEmpty)
            if request.importing { picking = true }
            let a = LaunchArgs.all
            if let i = a.firstIndex(of: "-sampler-file"), a.indices.contains(i + 1) { load(URL(fileURLWithPath: a[i + 1])) }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: Self.fileTypes) { result in
            if case .success(let url) = result { load(url) }
        }
        .onDisappear {
            rec.close()
            through.suspended = false
        }
        .task { if slots.isEmpty { await session.refreshSampleSlots(); if slot == nil { slot = request.slot ?? slots.firstIndex(where: \.isEmpty) } } }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: asking)
    }

    // MARK: Header: what this is, Cancel, Use on track

    private var header: some View {
        HStack(spacing: 12) {
            TrackChip(track: t)
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.fileName == nil ? "Record a sample" : "Import a sound").font(.lupe(17, .semibold))
                Text("Track \(t + 1) · \(rec.fileName ?? "\(UIDevice.current.model) microphone")").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { close() } label: {
                Text("Cancel").font(.lupe(15, .semibold)).padding(.horizontal, 16).frame(height: 44)
                    .background { Color.clear.raisedKey() }.contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(busy)
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
                Text(busy ? "SAVING TO \(name)" : hasTake ? "TAKE · SAVE IT TO A SLOT" : "TAKE")
                Spacer()
                Text(rec.state == .recording ? String(format: "%.1fs / %.1fs", rec.seconds, rec.maxSeconds)
                                             : hasTake ? (rec.take.count > rec.maxLength
                                                          ? String(format: "%.1fs OF %.1fs · A SLOT HOLDS %.1fs", rec.trimmedSeconds, rec.seconds, rec.maxSeconds)
                                                          : String(format: "%.1fs", rec.trimmedSeconds)) : "")
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
        // the FM-1 gets the take normalised, and the screen shows and plays that: say how far it came up
        if hasTake, rec.peakDB.isFinite {
            return rec.raiseDB > 30 ? String(format: "RAISED %.0f dB · NOISE CAME UP TOO", rec.raiseDB)
                                    : String(format: "RAISED %.0f dB", rec.raiseDB)
        }
        return ""
    }

    private var waveform: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            // while recording the screen is the whole slot; after, the take fills it for trimming
            let span = rec.state == .recording ? Int(rec.maxSeconds * rec.rate) : max(rec.take.count, 1)
            // after recording, the bars show the take as the FM-1 will have it (shaping is monotonic, so
            // a column's shaped peak is its raw peak, shaped)
            let raw = Self.bars(rec.take, span: span, count: Int(w / 4))
            let g = rec.normGain
            let bars = rec.state == .recording ? raw : raw.map { min(1, abs(rec.shape($0, gain: g))) }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x0A0A0C))
                if rec.take.isEmpty {
                    Text(emptyText).font(.lupe(15)).foregroundStyle(Theme.textSecondary)
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
                        handle(at: rec.start, of: span, width: w, height: h) { rec.setStart($0) }
                            .accessibilityLabel("Start").accessibilityValue(String(format: "%.2f seconds", Double(rec.start) / rec.rate))
                        handle(at: rec.end, of: span, width: w, height: h) { rec.setEnd($0) }
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
        case .denied: "Lupe can't use the microphone. Turn it on in Settings › Lupe."
        case .failed(let why): why
        default: loading ? "Reading the file…" : String(format: "Tap the red key and play, or import a file. Up to %.0f seconds.", rec.maxSeconds)
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
            importKey
            // the input meter while there's nothing to shape; Drive once there's a take (same place)
            if hasTake { drive } else { meter }
            Spacer(minLength: 12)
            slotPicker
        }
        .frame(height: 88)
    }

    private var meter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Input").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
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
    }

    /// Drive: louder without a higher peak. Changing it while the take plays starts it again, so you
    /// hear the new setting at once.
    private var drive: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Drive").font(.lupe(12)).foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
            StepperKeys(label: "Drive", value: rec.driveDB, range: 0...18, step: 3, enabled: !busy,
                        format: { $0 == 0 ? "Off" : "+\($0) dB" }) { v in
                rec.driveDB = v
                if rec.state == .playing { rec.play() }
            }
        }
        .frame(width: 180, alignment: .leading)
    }

    private var recKey: some View {
        let on = rec.state == .recording
        return Button {
            if on { rec.stop() } else { message = nil; Task { await rec.record() } }
        } label: {
            ZStack {
                RecKeyChiclet()
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

    /// The slots: what each holds; after a take they glow, the next step (Scott, 2026-11-09), and a tap saves there.
    private var slotPicker: some View {
        let saving = hasTake && !busy
        return HStack(spacing: 6) {
            Text(saving ? "Save to" : "Slots")
                .font(.lupe(12, saving ? .semibold : .regular)).foregroundStyle(saving ? Theme.text : Theme.textSecondary)
            ForEach(0..<session.sampleSlotCount, id: \.self) { k in
                let picked = slot == k && busy
                Button { save(to: k) } label: {
                    VStack(spacing: 2) {
                        Text(session.sampleSlotName(k)).font(.lupe(13, .semibold))
                        Text(k < slots.count && !slots[k].isEmpty ? slots[k].name : "empty")
                            .font(.lupe(10)).lineLimit(1)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .foregroundStyle(picked || saving ? Theme.text : Theme.textSecondary)
                    .frame(width: 64, height: 48)
                    .background { if picked || saving { Color.clear.raisedKey() } }
                    .overlay {
                        if saving {
                            RoundedRectangle(cornerRadius: 9).strokeBorder(colour, lineWidth: 2)
                                .shadow(color: colour.opacity(glow ? 0.9 : 0.3), radius: glow ? 8 : 2)
                                .opacity(reduceMotion ? 1 : (glow ? 1 : 0.55))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .disabled(!saving)
                .accessibilityLabel("\(session.sampleSlotName(k)), \(k < slots.count && !slots[k].isEmpty ? slots[k].name : "empty")")
                .accessibilityHint(saving ? (slotName(k) == "empty" ? "Saves the take here and plays it on track \(t + 1)" : "Asks before replacing what's here") : "")
            }
        }
        .onChange(of: saving, initial: true) { _, on in
            guard on, !reduceMotion else { glow = false; return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    /// A tap on a slot after a take: an empty one saves at once; a full one asks first.
    private func save(to k: Int) {
        rec.stop()
        if k < slots.count, !slots[k].isEmpty { heldProblem = nil; askedAt = Date(); asking = k } else { slot = k; upload() }
    }

    /// Before a full slot is replaced, in place of the keys (no dialog, no dimming): what's there by name, a ▶ to hear
    /// it, Keep it, and the red-outlined Replace that names what goes (house rule: in-place confirms, 2026-11-10).
    private func replaceConfirm(_ k: Int) -> some View {
        let name = slotName(k).capitalized, playingHeld = rec.state == .playing && held[k] != nil
        let stops = session.sampleWorkStopsSong && session.playing
        return HStack(spacing: 12) {
            if session.dialect == .skiff {
            Button { hear(k) } label: {
                ZStack {
                    if reading { ProgressView().tint(Theme.text) }
                    else { Image(systemName: playingHeld ? "stop.fill" : "play.fill").font(.system(size: 18, weight: .semibold)) }
                }
                .foregroundStyle(Theme.text)
                .frame(width: 56, height: 56).background { Color.clear.raisedKey(12) }.contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(reading)
            .accessibilityLabel(reading ? "Reading \(name) from the FM-1" : playingHeld ? "Stop" : "Hear \(name)")
            .accessibilityHint(stops ? "Reading it stops the song for a moment; it starts again after" : "Read from the FM-1, played on the iPad")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.sampleSlotName(k)) holds “\(name)”").font(.lupe(15, .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(heldProblem ?? (reading ? "Reading it from the FM-1…"
                                     : stops ? "The FM-1 keeps no other copy. Hearing it or replacing it stops the song; Lupe starts it again after."
                                             : session.dialect == .skiff ? "The FM-1 keeps no other copy. ▶ hears it first." : "The FM-1 keeps no other copy."))
                    .font(.lupe(13)).foregroundStyle(heldProblem == nil ? Theme.textSecondary : Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button { rec.stop(); asking = nil } label: {
                Text("Keep it").font(.lupe(15, .semibold)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 16).frame(height: 56)
                    .background { Color.clear.raisedKey(12) }.contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityHint("Leaves \(session.sampleSlotName(k)) as it is")
            Button {
                // Replace sits where the slot was tapped: a double tap mustn't reach it (as the menus' confirms, 0.4 s)
                guard Date().timeIntervalSince(askedAt) > 0.4 else { return }
                rec.stop(); asking = nil; slot = k; upload()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.recText).accessibilityHidden(true)
                    Text("Replace “\(name)”").font(.lupe(15, .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16).frame(height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 12).fill(Elevation.held.surface)
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.recText, lineWidth: 3) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel("Replace \(name) with your take")
            .accessibilityHint("Can't be undone")
        }
        .frame(height: 88)
        .accessibilityElement(children: .contain)
        // the scrub leaves it as Keep it does
        .accessibilityAction(.escape) { rec.stop(); asking = nil }
    }

    /// Import file…: a WAV, AIFF or M4A from Files as the take, mono at 22,050 Hz, then trimmed as a recording is.
    private var importKey: some View {
        Button { rec.stop(); message = nil; picking = true } label: {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(Theme.text) }
                else { Image(systemName: "square.and.arrow.down").font(.system(size: 16, weight: .semibold)).accessibilityHidden(true) }
                Text("Import file…").font(.lupe(15, .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14).frame(height: 56)
            .background { Color.clear.raisedKey(12) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(busy || rec.state == .recording)
        .accessibilityHint("WAV, AIFF or M4A from Files; a long one is trimmed to what a slot holds")
    }

    private func load(_ url: URL) {
        loading = true
        message = nil
        Task {
            defer { loading = false }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let x = try await Task.detached(priority: .userInitiated) { try SampleFile.read(url) }.value
                rec.load(x, rate: Double(UserSample.rate), fileName: url.lastPathComponent)
            } catch SampleFile.Problem.silent {
                message = "THAT FILE IS SILENT"
            } catch {
                message = "LUPE CAN'T READ THAT FILE: WAV, AIFF OR M4A"
            }
        }
    }

    /// Plays what a slot holds (read back once, then kept), or stops it.
    private func hear(_ k: Int) {
        if rec.state == .playing { rec.stop(); return }
        if let h = held[k] { rec.play(h.samples, rate: h.rate); return }
        reading = true; heldProblem = nil
        Task {
            defer { reading = false }
            do {
                guard let h = try await session.storedSample(slot: k) else { heldProblem = "This FM-1 can't send it back."; return }
                held[k] = h
                if asking == k { rec.play(h.samples, rate: h.rate) }
            } catch {
                heldProblem = "The FM-1 didn't send it. Try again."
            }
        }
    }

    private func slotName(_ k: Int) -> String { k < slots.count && !slots[k].isEmpty ? slots[k].name : "empty" }

    // MARK: Done and cancel


    private func upload() {
        guard let k = slot else { return }
        let samples = rec.samplesForSlot()
        progress = 0
        message = nil
        Task {
            do {
                try await session.uploadSample(slot: k, name: uploadName, samples: samples) { progress = $0 }
                await session.useSample(slot: k, onTrack: t)
                progress = nil
                close()
            } catch {
                progress = nil
                message = Self.describe(error)
            }
        }
    }

    /// What the slot is called on the FM-1: an imported file's name (its first eight letters, as the FM-1 shows), else the slot's.
    private var uploadName: String {
        guard let f = rec.fileName else { return name }
        let stem = (f as NSString).deletingPathExtension.trimmingCharacters(in: .whitespaces)
        return stem.isEmpty ? name : stem
    }

    private func close() {
        rec.close()
        ui.sampler = nil
    }

    private static func describe(_ e: Error) -> String {
        switch e {
        case DeviceSession.SampleError.notConnected: "THE FM-1 ISN'T CONNECTED"
        case DeviceSession.SampleError.tooLong: "TOO LONG FOR A SLOT: TRIM IT"
        case DeviceSession.SampleError.empty: "NOTHING TO SEND: RECORD A TAKE"
        case DeviceSession.SampleError.refused(let stage, let rc): "THE FM-1 REFUSED IT (\(stage.uppercased()) \(rc))"
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

/// The sampler's round REC key: a round chiclet on its 2 pt edge.
private struct RecKeyChiclet: View {
    @Environment(\.keyPressed) private var pressed
    var body: some View {
        Circle().fill(pressed ? Theme.controlPressed : Theme.control)
            .background { if !pressed { Circle().fill(Theme.chicletEdge).offset(y: 2) } }
    }
}

import AVFoundation
import SloopKit

/// The sampler's audio: records the iPad's own microphone (never the FM-1's USB input, which iOS would
/// otherwise prefer while it's plugged in), up to what a USR slot holds, and plays the trimmed take back
/// on the iPad. iPad audio is held off meanwhile (AudioThrough.suspended), so its speaker can't feed the mic.
@MainActor @Observable
final class SampleRecorder {
    enum State: Equatable { case idle, recording, playing, denied, failed(String) }

    private(set) var state: State = .idle
    /// The take, mono, at `rate`: what's been recorded so far while recording.
    private(set) var take: [Float] = []
    private(set) var rate: Double = 48_000
    /// The input's level now, 0…1 (peak of the last buffer), for the meter.
    private(set) var level: Float = 0
    /// Where the take starts and ends, in samples: set from the sound when recording stops, then by the handles.
    var start = 0
    var end = 0

    /// The longest take that still fits a slot once it's resampled to 22,050 Hz.
    var maxSeconds: Double { UserSample.maxSeconds - 0.05 }
    var seconds: Double { Double(take.count) / rate }
    var trimmedSeconds: Double { Double(max(0, end - start)) / rate }
    /// The trimmed take's peak, in dBFS (before the upload's normalising).
    var peakDB: Double {
        guard end > start else { return -.infinity }
        let p = take[start..<end].reduce(Float(0)) { max($0, abs($1)) }
        return p > 0 ? 20 * log10(Double(p)) : -.infinity
    }

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player: AVAudioPlayerNode?
    @ObservationIgnored private var collected: [Float] = []

    // MARK: Recording

    func record() async {
        stop()
        guard await AVAudioApplication.requestRecordPermission() else { state = .denied; return }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try s.setActive(true)
            // the iPad's microphone, explicitly: with the FM-1 plugged in, its USB audio is an input too
            if let mic = s.availableInputs?.first(where: { $0.portType == .builtInMic }) { try s.setPreferredInput(mic) }
            let e = AVAudioEngine()
            let input = e.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { state = .failed("No microphone"); return }
            rate = format.sampleRate
            collected = []
            take = []
            let limit = Int(maxSeconds * rate)
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buf, _ in
                guard let ch = buf.floatChannelData else { return }
                let n = Int(buf.frameLength)
                let mono = Array(UnsafeBufferPointer(start: ch[0], count: n))
                let peak = mono.reduce(Float(0)) { max($0, abs($1)) }
                Task { @MainActor in self?.received(mono, peak: peak, limit: limit) }
            }
            try e.start()
            engine = e
            state = .recording
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func received(_ mono: [Float], peak: Float, limit: Int) {
        guard state == .recording else { return }
        level = peak
        collected += mono.prefix(max(0, limit - collected.count))
        take = collected
        if collected.count >= limit { finish() }        // the end of the slot: stops by itself
    }

    /// Recording stopped: keep the take and find where the sound starts and ends.
    private func finish() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        level = 0
        take = collected
        (start, end) = Self.sound(in: take, rate: rate)
        state = .idle
    }

    /// From the first sample above 2 % of the peak (sampleio.onset's threshold) to 80 ms after the last.
    static func sound(in x: [Float], rate: Double) -> (Int, Int) {
        let peak = x.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0 else { return (0, x.count) }
        let thr = peak * 0.02
        let first = x.firstIndex { abs($0) > thr } ?? 0
        let last = x.lastIndex { abs($0) > thr } ?? x.count - 1
        return (max(0, first - Int(0.005 * rate)), min(x.count, last + Int(0.08 * rate)))
    }

    // MARK: Playing the take back

    func play() {
        stop()
        guard end > start else { return }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try s.setActive(true)
            let e = AVAudioEngine(), p = AVAudioPlayerNode()
            guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
                  let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(end - start)) else { return }
            buf.frameLength = AVAudioFrameCount(end - start)
            take.withUnsafeBufferPointer { src in buf.floatChannelData![0].update(from: src.baseAddress! + start, count: end - start) }
            e.attach(p)
            e.connect(p, to: e.mainMixerNode, format: fmt)
            try e.start()
            p.scheduleBuffer(buf) { [weak self] in Task { @MainActor in if self?.state == .playing { self?.stop() } } }
            p.play()
            engine = e; player = p
            state = .playing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Stops recording (keeping the take) or playing.
    func stop() {
        if state == .recording { finish(); return }
        player?.stop()
        engine?.stop()
        engine = nil; player = nil
        if state == .playing { state = .idle }
    }

    /// Lets go of the microphone and the audio session (the sampler closed).
    func close() {
        stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: For the FM-1

    /// The trimmed take as the slot wants it: 22,050 Hz, 16-bit, peak normalised (SLOOP's own pipeline).
    func samplesForSlot() -> [Int16] {
        guard end > start else { return [] }
        let x = take[start..<end].map(Double.init)
        let r = UserSample.resample(x, from: Int(rate.rounded()), to: UserSample.rate)
        return UserSample.toInt16(Array(r.prefix(UserSample.maxSamples)))
    }
}

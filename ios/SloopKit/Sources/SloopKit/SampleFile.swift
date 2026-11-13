#if canImport(AVFoundation)
// Apple-only: not built for Android (android/BRIDGE.md §3).
import AVFoundation

/// A sound file brought into the sampler (Import file…): WAV, AIFF or M4A, read as a slot wants it, mono at
/// 22,050 Hz. Longer than a slot is fine: the sampler's trim view picks what goes in (UserSample.maxSeconds).
public enum SampleFile {
    public enum Problem: Error, Equatable {
        case unreadable                 // not a sound file iOS can open (or not one of the three kinds)
        case silent                     // opened, but nothing in it
    }

    /// The file types the picker offers, as uniform type identifiers: WAV, AIFF (and AIFC), MPEG-4 audio (.m4a).
    public static let typeIdentifiers = ["com.microsoft.waveform-audio", "public.aiff-audio", "public.aifc-audio", "com.apple.m4a-audio", "public.mpeg-4-audio"]

    /// The longest stretch of a file kept for trimming, in seconds: a long file's first minute.
    public static let longest: Double = 60

    /// Reads the file mixed to mono (the channels averaged) at the slot's 22,050 Hz, -1…1, at most `longest` seconds.
    public static func read(_ url: URL, longest: Double = SampleFile.longest) throws -> [Float] {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch { throw Problem.unreadable }
        let source = file.processingFormat
        guard source.sampleRate > 0, source.channelCount > 0, file.length > 0 else { throw Problem.silent }
        let rate = Double(UserSample.rate)
        guard let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source, to: mono) else { throw Problem.unreadable }
        converter.downmix = true
        let limit = Int(longest * rate)
        let chunk: AVAudioFrameCount = 8192
        guard let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: chunk),
              let output = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(Double(chunk) * rate / source.sampleRate) + 64)
        else { throw Problem.unreadable }
        var out: [Float] = []
        out.reserveCapacity(min(limit, Int(Double(file.length) * rate / source.sampleRate) + 64))
        var ended = false, failed = false
        while out.count < limit {
            output.frameLength = 0
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, outStatus in
                // (reading at the end throws rather than giving nothing)
                if ended || file.framePosition >= file.length { ended = true; outStatus.pointee = .endOfStream; return nil }
                do { try file.read(into: input, frameCount: chunk) } catch { failed = true; ended = true; outStatus.pointee = .endOfStream; return nil }
                if input.frameLength == 0 { ended = true; outStatus.pointee = .endOfStream; return nil }
                outStatus.pointee = .haveData
                return input
            }
            if status == .error || failed { throw Problem.unreadable }
            if output.frameLength > 0, let ch = output.floatChannelData {
                out += UnsafeBufferPointer(start: ch[0], count: Int(output.frameLength))
            }
            if status == .endOfStream || (ended && output.frameLength == 0) { break }
        }
        if out.count > limit { out.removeLast(out.count - limit) }
        guard out.contains(where: { abs($0) > 1e-4 }) else { throw Problem.silent }
        return out
    }
}

#endif

import AVFoundation
import Foundation
import Testing
@testable import SloopKit

/// Import file…: WAV, AIFF and M4A in, mono at 22,050 Hz, a long one cut at SampleFile.longest.
@Suite struct SampleFileTests {
    /// A stereo 440 Hz tone (left at full, right silent, so the mix is half) written as `ext` at `rate`.
    static func tone(_ ext: String, rate: Double = 44_100, seconds: Double = 1.5) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lupe-tone-\(UUID().uuidString).\(ext)")
        var settings: [String: Any] = [AVSampleRateKey: rate, AVNumberOfChannelsKey: 2]
        switch ext {
        case "m4a": settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        default:
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = ext == "aiff"
        }
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let n = AVAudioFrameCount(rate * seconds)
        let buf = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: n))
        buf.frameLength = n
        for i in 0..<Int(n) {
            buf.floatChannelData![0][i] = 0.8 * Float(sin(2 * .pi * 440 * Double(i) / rate))
            buf.floatChannelData![1][i] = 0
        }
        try file.write(from: buf)
        return url
    }

    /// Zero crossings a second: about twice the pitch.
    static func pitch(_ x: [Float]) -> Double {
        let body = x.dropFirst(2205).dropLast(2205)
        let crossings = zip(body, body.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        return Double(crossings) / 2 / (Double(body.count) / Double(UserSample.rate))
    }

    @Test(arguments: ["wav", "aiff", "m4a"]) func readsMonoAtTheSlotsRate(_ ext: String) throws {
        let url = try Self.tone(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        let x = try SampleFile.read(url)
        // 1.5 s at 22,050 Hz (AAC adds a little priming at the ends)
        #expect(abs(x.count - Int(1.5 * Double(UserSample.rate))) < 3000)
        let peak = x.reduce(Float(0)) { max($0, abs($1)) }
        #expect(peak > 0.3 && peak < 0.9, "the two channels mixed: \(peak)")
        #expect(abs(Self.pitch(x) - 440) < 10)
    }

    @Test func aLongFileStopsAtTheLongestKept() throws {
        let url = try Self.tone("wav", rate: 48_000, seconds: 4)
        defer { try? FileManager.default.removeItem(at: url) }
        let x = try SampleFile.read(url, longest: 2)
        #expect(x.count == 2 * UserSample.rate)
    }

    @Test func notASoundFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lupe-not-\(UUID().uuidString).wav")
        try Data("not audio at all".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: SampleFile.Problem.unreadable) { try SampleFile.read(url) }
    }
}

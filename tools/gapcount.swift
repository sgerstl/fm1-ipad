// gapcount: counts gaps in the FM-1's USB audio, by the same rules as Lupe's Android engine
// (android/app/src/main/cpp/through/through_core.h, ThroughCore::take), on the Mac or in a WAV.
//
//   swift tools/gapcount.swift live [seconds] [device-name-part]   record the FM-1 ("Felucca") through CoreAudio
//   swift tools/gapcount.swift live 20 Felucca --wav /tmp/fm1.wav  ... and keep the recording
//   swift tools/gapcount.swift file capture.wav                    a WAV: a Lupe capture from the phone
//                                                                   (--ei throughCapture 10, then adb pull), or the above
//   swift tools/gapcount.swift selftest                            the rules against a made-up stream with known gaps
//
// Why: both Pixels show gaps on both input paths (2026-11-15). The question is whether the FM-1 sends them, or the
// phone's USB path makes them. The Mac's USB audio driver follows an asynchronous source's rate properly. So:
//   * no gaps on the Mac, gaps on the phone → Android's USB path (it can't follow this source).
//   * gaps on the Mac too → the FM-1's stream. Repeats point at its own ring running dry (uac_packet repeats its last
//     frame); zeros, at frames it never sent.
// The intervals tell more: evenly spaced gaps (a low CV) at about |clock offset| x 48,000 per second mean a host that
// takes exactly 48 frames per USB millisecond from a source whose clock is off. Random spacing means something else.
//
// Rules (the FM-1 dithers, Skiff 2.5 #110, so even its silence is never a long run of exact zeros):
//   zero gap: 4+ exact-zero stereo frames right after a loud frame (|x| > 1e-3), or 32+ in quiet.
//   repeat gap: 8+ identical loud frames (dither makes shorter repeats happen by chance on flat waveform tops).
//   blind: half a second of pure digital zero (not dithered: not the FM-1's quiet; nothing can be seen).
// Play something on the FM-1 while it records: a held note is best; then the pattern.
//
// The Mac needs microphone access for the terminal app the first time (System Settings › Privacy › Microphone).

import AVFoundation
import CoreAudio
import Foundation

// MARK: The rules

final class GapCounter {
    let rate: Double
    var frames: Int64 = 0
    var zeroGaps: [(at: Int64, len: Int)] = []
    var repeatGaps: [(at: Int64, len: Int)] = []
    var blindFrames: Int64 = 0
    var peak: Float = 0
    private var held = 0, sinceNonZero: Int64 = 0, repeatRun = 0
    private var lastLoud = false, passZeros = false
    private var lastL: Float = 0, lastR: Float = 0
    private let loud: Float = 1e-3

    init(rate: Double) { self.rate = rate }

    func take(_ l: Float, _ r: Float) {
        frames += 1
        peak = max(peak, abs(l), abs(r))
        if l == 0, r == 0 {
            sinceNonZero += 1
            if sinceNonZero >= Int64(rate / 2) { blindFrames += 1 }
            if passZeros { return }
            held += 1
            if held >= 256 {
                if lastLoud { zeroGaps.append((frames - Int64(held), held)) }
                held = 0; passZeros = true
            }
            return
        }
        if held > 0 {
            if lastLoud ? held >= 4 : held >= 32 { zeroGaps.append((frames - 1 - Int64(held), held)) }
            held = 0
        }
        passZeros = false
        sinceNonZero = 0
        let isLoud = abs(l) > loud || abs(r) > loud
        if isLoud, l == lastL, r == lastR {
            repeatRun += 1
            if repeatRun == 7 { repeatGaps.append((frames - 8, 8)) }
        } else {
            repeatRun = 0
        }
        lastL = l; lastR = r
        lastLoud = isLoud
    }

    func report(title: String) {
        let secs = Double(frames) / rate
        print("\n\(title): \(String(format: "%.1f", secs)) s at \(Int(rate)) Hz, peak \(String(format: "%.4f", peak))\(peak < 1e-3 ? "  (quiet: only zero gaps of 32+ can be seen; play something)" : "")")
        if blindFrames > Int64(rate) { print("  blind for \(String(format: "%.1f", Double(blindFrames) / rate)) s: pure digital zero, not the FM-1's dithered quiet") }
        line("zero gaps", zeroGaps, secs)
        line("repeat gaps", repeatGaps, secs)
        if !zeroGaps.isEmpty {
            var hist: [Int: Int] = [:]
            for g in zeroGaps { hist[min(g.len, 256), default: 0] += 1 }
            let top = hist.sorted { $0.value > $1.value }.prefix(6).map { "\($0.key)×\($0.value)" }.joined(separator: " ")
            print("  zero-gap lengths (frames×count): \(top)")
        }
    }

    private func line(_ name: String, _ gaps: [(at: Int64, len: Int)], _ secs: Double) {
        print("  \(name): \(gaps.count) (\(String(format: "%.1f", Double(gaps.count) / max(secs, 0.001))) a second)")
        guard gaps.count >= 3 else { return }
        let iv = zip(gaps.dropFirst(), gaps).map { Double($0.0.at - $0.1.at) / rate * 1000 }
        let mean = iv.reduce(0, +) / Double(iv.count)
        let sd = (iv.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(iv.count)).squareRoot()
        let cv = sd / max(mean, 1e-9)
        print("    intervals: mean \(String(format: "%.1f", mean)) ms, sd \(String(format: "%.1f", sd)) ms, CV \(String(format: "%.2f", cv)) → \(cv < 0.3 ? "evenly spaced: a clock-rate mismatch" : cv < 0.7 ? "partly regular" : "irregular")")
        if cv < 0.3 { print("    as a clock offset: ~\(Int((1000 / mean) / rate * 1e6)) ppm at one frame per gap, ~\(Int((1000 / mean) * 48 / rate * 1e6)) ppm at a packet per gap") }
    }
}

// MARK: Input

func readWav(_ path: String) throws -> (GapCounter, String) {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path), commonFormat: .pcmFormatFloat32, interleaved: false)
    let fmt = file.processingFormat
    let counter = GapCounter(rate: fmt.sampleRate)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 65536)!
    while file.framePosition < file.length {
        try file.read(into: buf)
        let n = Int(buf.frameLength), ch = Int(fmt.channelCount)
        guard let d = buf.floatChannelData, n > 0 else { break }
        for i in 0..<n { counter.take(d[0][i], d[ch > 1 ? 1 : 0][i]) }
    }
    return (counter, (path as NSString).lastPathComponent)
}

func inputDevice(matching part: String) -> (AudioDeviceID, String)? {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return nil }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return nil }
    for id in ids {
        var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var nsize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nsize, &name) == noErr, let n = name?.takeRetainedValue() as String? else { continue }
        var inAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var ssize: UInt32 = 0
        AudioObjectGetPropertyDataSize(id, &inAddr, 0, nil, &ssize)
        if ssize > 0, n.localizedCaseInsensitiveContains(part) { return (id, n) }
    }
    return nil
}

func live(seconds: Double, part: String, wavOut: String?) throws -> (GapCounter, String) {
    guard let (dev, name) = inputDevice(matching: part) else {
        throw NSError(domain: "gapcount", code: 1, userInfo: [NSLocalizedDescriptionKey: "no input device with \"\(part)\" in its name: plug the FM-1 into the Mac"])
    }
    let engine = AVAudioEngine()
    var d = dev
    guard let unit = engine.inputNode.audioUnit,
          AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &d, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr else {
        throw NSError(domain: "gapcount", code: 2, userInfo: [NSLocalizedDescriptionKey: "couldn't select \(name)"])
    }
    let fmt = engine.inputNode.inputFormat(forBus: 0)
    let counter = GapCounter(rate: fmt.sampleRate)
    let out: AVAudioFile? = try wavOut.map { try AVAudioFile(forWriting: URL(fileURLWithPath: $0), settings: fmt.settings, commonFormat: .pcmFormatFloat32, interleaved: false) }
    let lock = NSLock()
    var firstHost: UInt64 = 0, lastHost: UInt64 = 0, framesAtLast: Int64 = 0
    engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: fmt) { buf, when in
        lock.lock(); defer { lock.unlock() }
        let n = Int(buf.frameLength), ch = Int(fmt.channelCount)
        guard let data = buf.floatChannelData else { return }
        for i in 0..<n { counter.take(data[0][i], data[ch > 1 ? 1 : 0][i]) }
        try? out?.write(from: buf)
        if when.isHostTimeValid {
            if firstHost == 0 { firstHost = when.hostTime; counter.frames = Int64(n) }   // count from the first buffer's start
            else { lastHost = when.hostTime; framesAtLast = counter.frames - Int64(n) }
        }
    }
    print("recording \(name) for \(Int(seconds)) s at \(Int(fmt.sampleRate)) Hz, \(fmt.channelCount) ch…")
    try engine.start()
    Thread.sleep(forTimeInterval: seconds)
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    lock.lock(); defer { lock.unlock() }
    if lastHost > firstHost {
        // the FM-1's clock against the Mac's: frames between two buffer starts over the host time between them
        let secs = AVAudioTime.seconds(forHostTime: lastHost) - AVAudioTime.seconds(forHostTime: firstHost)
        let measured = Double(framesAtLast - 0) / secs
        print("  the FM-1's rate by the Mac's clock: \(String(format: "%.1f", measured)) Hz, \(String(format: "%+.0f", (measured / fmt.sampleRate - 1) * 1e6)) ppm (CoreAudio may already correct for it: take as a rough figure)")
    }
    return (counter, name)
}

/** A made-up dithered stream with known gaps: the rules must find exactly them. */
func selftest() -> Bool {
    let c = GapCounter(rate: 48000)
    var rng = SystemRandomNumberGenerator()
    func dither() -> Float { let r = Int.random(in: 0..<128, using: &rng) + Int.random(in: 0..<128, using: &rng); return Float((64 + r - 127) >> 7) / 32768 }
    var expected = 0
    for i in 0..<(48000 * 10) {
        let quiet = (i / 48000) % 2 == 1
        if i % 3200 == 100 { for _ in 0..<48 { c.take(0, 0) }; expected += 1 }   // a 48-frame gap 15 times a second
        let v = quiet ? dither() : Float(0.3 * sin(2 * Double.pi * 440 * Double(i) / 48000)) + dither()
        c.take(v, quiet ? dither() : v)
    }
    c.report(title: "selftest (15 gaps a second of 48 frames, loud and quiet seconds alternating)")
    let ok = abs(c.zeroGaps.count - expected) <= 2 && c.repeatGaps.isEmpty
    print(ok ? "  selftest passed (\(c.zeroGaps.count) of \(expected))" : "  selftest FAILED: \(c.zeroGaps.count) zero gaps, \(c.repeatGaps.count) repeat gaps, expected \(expected) and 0")
    return ok
}

// MARK: Main

var args = Array(CommandLine.arguments.dropFirst())
var wavOut: String?
if let i = args.firstIndex(of: "--wav"), i + 1 < args.count { wavOut = args[i + 1]; args.removeSubrange(i...(i + 1)) }
do {
    switch args.first {
    case "live":
        let secs = args.count > 1 ? Double(args[1]) ?? 20 : 20
        let (c, name) = try live(seconds: secs, part: args.count > 2 ? args[2] : "Felucca", wavOut: wavOut)
        c.report(title: "\(name) on the Mac")
    case "file":
        guard args.count > 1 else { throw NSError(domain: "gapcount", code: 3, userInfo: [NSLocalizedDescriptionKey: "file needs a path"]) }
        let (c, name) = try readWav(args[1])
        c.report(title: name)
    case "selftest":
        exit(selftest() ? 0 : 1)
    default:
        print("usage: swift tools/gapcount.swift live [seconds] [device-name-part] [--wav out.wav] | file <wav> | selftest")
        exit(2)
    }
} catch {
    print("gapcount: \(error.localizedDescription)")
    exit(1)
}

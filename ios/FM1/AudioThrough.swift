import AVFoundation
import MediaPlayer
import SloopKit
import SwiftUI

/// Plays the FM-1 through the iPad. SLOOP is also a class-compliant USB audio input ("Felucca", the
/// master output, GUIDE §22), so the iPad listens to that input and plays it to its speakers or
/// whatever headphones are on. The FM-1's own speaker is untouched: unplugged, or with this off,
/// nothing changes there (HOME > AUDIO > USB AUDIO = FULL lets its MASTER go down without the iPad
/// getting quieter).
///
/// The UI side: the switch and what the audio side last reported. All the audio work happens on
/// `AudioCore`'s own queue, never on the main thread (the first version reconfigured the session on
/// every route change, on the main thread, and each reconfiguration caused another route change:
/// the app froze, 2026-11-02).
@MainActor @Observable
final class AudioThrough {
    enum State: Equatable, Sendable {
        case off
        case starting
        case noInput                    // on, but no USB audio input: FM-1 not plugged in, or USB AUDIO missing
        case playing(to: String)        // the output's name: "Speaker", "AirPods Pro"…
        case denied                     // iOS counts the USB input as a microphone, and access is off
        case failed(String)
    }

    private(set) var state: State = .off
    /// Where the sound goes and comes from right now, as iOS reports it (the connection menu shows it).
    private(set) var route = ""
    var enabled: Bool {
        didSet {
            guard enabled != oldValue else { return }
            UserDefaults.standard.set(enabled, forKey: Self.key)
            core.set(enabled)
        }
    }

    /// (A new key: the frozen first version may have left the old one on.)
    private static let key = "playThroughIPad.v2"
    @ObservationIgnored private let core = AudioCore()

    init() {
        enabled = UserDefaults.standard.bool(forKey: Self.key)
        core.onState = { [weak self] s in
            Task { @MainActor in self?.state = s }
        }
        core.onRoute = { [weak self] r in
            Task { @MainActor in self?.route = r }
        }
        core.set(enabled)
    }

    /// Short, for the connection menu and VoiceOver.
    var summary: String {
        switch state {
        case .off: "Off"
        case .starting: "Starting…"
        case .noInput: "No FM-1 audio input"
        case .playing(let to): "Playing through \(to)"
        case .denied: "Microphone access is off"
        case .failed(let why): why
        }
    }
}

/// The audio side, all on one serial queue. Every route change, interruption or engine reset only
/// schedules a check (bursts collapse into one), and a check changes nothing that's already right:
/// a running engine on a USB input is left alone, so the session's own notifications can't loop.
///
/// Only the USB input is ever played. If the route falls back to the iPad's microphone (the FM-1
/// unplugged), playing it to the speaker would howl, so the engine stops before anything else.
final class AudioCore: @unchecked Sendable {
    var onState: (@Sendable (AudioThrough.State) -> Void)?
    var onRoute: (@Sendable (String) -> Void)?

    private let queue = DispatchQueue(label: "fm1.audio-through", qos: .userInitiated)
    /// Rebuilt for each start: an engine left over from another output keeps that output's format, and
    /// played nothing on Bluetooth headphones (2026-11-02).
    private var engine = AVAudioEngine()
    private var engineObserver: NSObjectProtocol?
    /// The output the running engine was built for: another one means a fresh engine.
    private var builtFor: String?
    private var enabled = false
    private var sessionReady = false
    private var pending: DispatchWorkItem?
    private var last: AudioThrough.State?
    private var observers: [NSObjectProtocol] = []

    init() {
        let nc = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: nil) { [weak self] _ in
            self?.queue.async {
                // safety first: never let the iPad's microphone reach the speaker
                guard let self else { return }
                if self.engine.isRunning, !Self.usbInputInRoute() { self.stopEngine() }
                self.reportRoute()
                self.schedule()
            }
        })
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(nc.addObserver(forName: name, object: session, queue: nil) { [weak self] n in
                self?.queue.async {
                    guard let self else { return }
                    if name == AVAudioSession.mediaServicesWereResetNotification { self.sessionReady = false; self.builtFor = nil }
                    self.schedule()
                }
            })
        }
    }

    func set(_ on: Bool) {
        queue.async {
            self.enabled = on
            if on { self.publish(.starting) }
            self.pending?.cancel()
            self.check()
        }
    }

    /// A check a moment from now; another request before then replaces it.
    private func schedule() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.check() }
        pending = w
        queue.asyncAfter(deadline: .now() + 0.3, execute: w)
    }

    private static func usbInputInRoute() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.inputs.contains { $0.portType == .usbAudio }
    }

    /// Brings things to where they should be, touching only what isn't.
    private func check() {
        let s = AVAudioSession.sharedInstance()
        guard enabled else {
            stopEngine()
            if sessionReady {
                try? s.setActive(false, options: .notifyOthersOnDeactivation)
                sessionReady = false
            }
            publish(.off)
            return
        }
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] _ in self?.queue.async { self?.check() } }
            return
        case .denied:
            stopEngine()
            publish(.denied)
            return
        default:
            break
        }
        do {
            if !sessionReady {
                // Bluetooth headphones as an output (A2DP), the input staying USB. No .defaultToSpeaker: the
                // iPad has no receiver to avoid, and that option kept the sound on the speaker with
                // headphones connected (2026-11-02); not .allowBluetooth either, which is the phone-call profile
                try s.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP])
                try s.setPreferredIOBufferDuration(0.005)
                try s.setActive(true)
                sessionReady = true
            }
            guard let usb = s.availableInputs?.first(where: { $0.portType == .usbAudio }) else {
                stopEngine()
                publish(.noInput)
                return
            }
            if s.preferredInput?.uid != usb.uid {
                try s.setPreferredInput(usb)
            }
            guard Self.usbInputInRoute() else {
                stopEngine()
                publish(.noInput)
                return
            }
            let out = s.currentRoute.outputs.first
            let output = out?.portName ?? "the iPad"
            if engine.isRunning, builtFor == out?.uid {
                reportRoute()
                publish(.playing(to: output))       // already right: nothing to restart
                return
            }
            // a fresh engine for this output: input → mixer → output, each at the hardware's format now
            freshEngine()
            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                publish(.noInput)
                return
            }
            engine.connect(input, to: engine.mainMixerNode, format: format)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: engine.outputNode.outputFormat(forBus: 0))
            engine.prepare()
            try engine.start()
            builtFor = out?.uid
            reportRoute()
            publish(.playing(to: output))
        } catch {
            stopEngine()
            publish(.failed("iPad audio couldn't start"))
        }
    }

    private func freshEngine() {
        stopEngine()
        if let o = engineObserver { NotificationCenter.default.removeObserver(o) }
        engine = AVAudioEngine()
        engineObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            // the engine stopped itself for a new configuration: build again for it
            self?.queue.async { self?.builtFor = nil; self?.schedule() }
        }
    }

    /// For the connection menu: the route, and the rates in and out (a mismatch shows here first).
    private func reportRoute() {
        let s = AVAudioSession.sharedInstance()
        let r = s.currentRoute
        let outs = r.outputs.map(\.portName).joined(separator: ", ")
        let ins = r.inputs.map(\.portName).joined(separator: ", ")
        var line = "Out: \(outs.isEmpty ? "none" : outs) · In: \(ins.isEmpty ? "none" : ins)"
        if engine.isRunning {
            let i = engine.inputNode.inputFormat(forBus: 0).sampleRate, o = engine.outputNode.outputFormat(forBus: 0).sampleRate
            line += String(format: " · %.1f → %.1f kHz", i / 1000, o / 1000)
        } else {
            line += " · stopped"
        }
        onRoute?(line)
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        builtFor = nil
    }

    private func publish(_ s: AudioThrough.State) {
        guard s != last else { return }
        last = s
        onState?(s)
    }
}

/// The top bar's key: a speaker with a light. Lit and a speaker when it plays; lit with a warning
/// when it's on but can't (the connection menu says why).
struct AudioThroughKey: View {
    let through: AudioThrough

    var body: some View {
        let on = through.enabled
        let trouble: Bool = {
            switch through.state {
            case .playing, .starting, .off: false
            default: on
            }
        }()
        Button { through.enabled.toggle() } label: {
            HStack(spacing: 8) {
                LED(on: on)
                Image(systemName: trouble ? "speaker.badge.exclamationmark" : on ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background {
                if on { RoundedRectangle(cornerRadius: 9).fill(Theme.pressed).recessed(9) } else { Color.clear.raisedKey() }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel("Play through the iPad")
        .accessibilityValue(on ? through.summary : "off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint("Plays the FM-1's sound on the iPad's speakers or headphones")
    }
}

/// While the iPad plays the FM-1's sound, the app is iOS's Now Playing app. Bluetooth headphones hand
/// their stream to the device that plays media, and an app that only records and monitors didn't count:
/// Sony XM6s stayed silent until Music had played (2026-11-02). Their play / pause then starts and stops
/// the FM-1.
@MainActor
final class NowPlaying {
    static let shared = NowPlaying()
    private var targets: [(MPRemoteCommand, Any)] = []
    private weak var session: SloopSession?

    func update(active: Bool, session: SloopSession) {
        let center = MPRemoteCommandCenter.shared()
        guard active else {
            for (c, t) in targets { c.removeTarget(t) }
            targets = []
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        self.session = session
        if targets.isEmpty {
            func on(_ c: MPRemoteCommand, _ act: @escaping @MainActor (SloopSession) -> Void) {
                c.isEnabled = true
                let t = c.addTarget { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let s = self?.session else { return .noActionableNowPlayingItem }
                        act(s)
                        return .success
                    }
                }
                targets.append((c, t))
            }
            on(center.togglePlayPauseCommand) { $0.setPlaying(!$0.playing) }
            on(center.playCommand) { $0.setPlaying(true) }
            on(center.pauseCommand) { $0.setPlaying(false) }
            on(center.stopCommand) { $0.setPlaying(false) }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: session.song.songMode ? "FM-1 · song" : "FM-1",
            MPMediaItemPropertyArtist: "SLOOP",
            MPNowPlayingInfoPropertyPlaybackRate: session.playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
    }
}

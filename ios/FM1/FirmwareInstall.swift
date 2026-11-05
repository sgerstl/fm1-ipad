import SloopKit
import SwiftUI
import UIKit

/// Installing the firmware Jib carries (Skiff 2.2, SLOOP 2.8.4 with the screen link) over USB-MIDI, 2026-11-05, and
/// putting M-VAVE's stock V15 back (its own update loader writes it).
/// Offers it when the FM-1 runs something else or waits in an update loader; picks it from the Developer menu.
/// While it runs the session lets go of the FM-1, the screen stays awake, and a cover keeps the app on this.
@Observable @MainActor
final class FirmwareCentre {
    enum Offer: Equatable {
        case loader(String)                 // a Felucca-family update loader waits, or M-VAVE's: finish the write
        case foreignLoader(String)          // another firmware's update mode: not ours to finish
        case unsupported(String)            // runs something Jib doesn't speak
    }

    enum Phase: Equatable {
        case idle
        case backingUp(Double)
        case installing(InstallStep)
        case done(String, backup: String?)
        case failed(message: String, inUpdateMode: Bool, backup: String?, refused: Bool = false)
    }

    var offer: Offer?
    var dismissedOffer: Offer?
    var phase: Phase = .idle
    var target: BundledFirmware = .skiff
    var showPicker = false
    /// Why the picker can't start (the battery, a backup that failed).
    var pickerNote: String?
    /// The backup failed: the next start goes on without one, if asked.
    var skipBackup = false
    /// While true, the session is paused so the installer has the FM-1 to itself.
    private(set) var holdsDevice = false
    /// This install starts with a backup (the session was connected).
    private(set) var backsUp = false

    private let ports: UpdatePorts
    private let demo: String?
    private var installer: FirmwareInstaller?
    private var backupName: String?

    init() {
        // -demo-firmware loader | stock | foreign | picker | installing | failed | done, and for the way back to stock
        // picker-stock | restoring | restored | stock-loader | v16: a fake FM-1 for screenshots
        let a = ProcessInfo.processInfo.arguments
        demo = a.firstIndex(of: "-demo-firmware").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
        if let demo {
            let sloop = try? BundledFirmware.sloop.load(), skiff = try? BundledFirmware.skiff.load()
            let stock = try? BundledFirmware.stock.load()
            let fake: FakeFM1
            switch demo {
            case "loader": fake = FakeFM1(inLoaderOf: skiff!, was: sloop)
            case "stock": fake = FakeFM1(running: nil)
            case "foreign": fake = FakeFM1(running: nil, stockIdentity: "ota-FM-1_301")
            case "stock-loader": fake = FakeFM1(inLoaderOf: stock!, was: sloop)
            case "v16": fake = FakeFM1(running: sloop, startedOn: 16)
            default: fake = FakeFM1(running: sloop)
            }
            fake.knows(skiff!, sloop!, stock!)
            if demo == "failed" { fake.faults = [.unplug(stage: 2, after: 900, replugAfter: nil)] }
            ports = fake
        } else {
            ports = CoreMIDIUpdatePorts()
        }
    }

    var isActive: Bool { phase != .idle }
    var demoState: String? { demo }

    // MARK: Watching for an FM-1 Jib can't use

    /// Follows the session: a firmware it refused is offered at once; when nothing connects, the update ports are
    /// asked who is there (a loader on "Felucca Update", a stock FM-1 on "FM-1"). Never while installing.
    func watch(_ session: DeviceSession) async {
        if let demo {                                        // the screenshots' states, once
            try? await Task.sleep(for: .seconds(1))
            switch demo {
            case "picker": showPicker = true
            case "picker-stock": target = .stock; showPicker = true
            case "installing", "failed", "done", "restoring", "restored", "v16":
                for _ in 0..<50 {                            // with the demo FM-1 connected, so it backs up
                    if case .connected = session.status { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                start(["restoring", "restored", "v16"].contains(demo) ? .stock : .skiff, session: session)
            default: await probe()
            }
            return
        }
        while !Task.isCancelled {
            if !isActive {
                switch session.status {
                case .wrongFirmware(let found, _): offer = .unsupported(found)
                case .searching, .lost: await probe()
                case .connected: offer = nil
                case .connecting: break
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func probe() async {
        let i = FirmwareInstaller(ports: ports)
        guard let id = await i.probe() else { if case .unsupported = offer {} else { offer = nil }; return }
        if id.isLoader {
            let ours = FirmwareInstaller.isResumable(loader: id) || id.text == FirmwareInstaller.officialLoader
            offer = ours ? .loader(id.text) : .foreignLoader(id.text)
            if let f = BundledFirmware.matching(identity: id.text) { target = f }
        } else if BundledFirmware.matching(identity: id.text).map({ $0.isStock }) ?? true {
            offer = .unsupported(id.text)               // (stock V15 is one Jib carries, not one it speaks)
        }
    }

    var visibleOffer: Offer? { offer == dismissedOffer ? nil : offer }

    // MARK: Installing

    /// The battery's say: nil to go ahead, else why not. Unknown (the simulator) goes ahead.
    func batteryRefusal() -> String? {
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        let level = d.batteryLevel, state = d.batteryState
        guard level >= 0, state == .unplugged, level < 0.3 else { return nil }
        let device = d.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "Charge the \(device) first: it's at \(Int(level * 100))%. The \(device) powers the FM-1 while it writes, so Jib installs below 30% only while charging."
    }

    func start(_ firmware: BundledFirmware, session: DeviceSession) {
        if demo == nil, let why = batteryRefusal() { pickerNote = why; showPicker = true; return }
        target = firmware
        pickerNote = nil
        showPicker = false
        offer = nil
        Task { await run(session: session) }
    }

    private func run(session: DeviceSession) async {
        let pkg: FirmwarePackage
        do { pkg = try target.load() } catch {
            phase = .failed(message: "\(error)", inUpdateMode: false, backup: nil)
            return
        }
        backupName = nil
        backsUp = false
        // a backup first, through the connected session (the store survives an install, but not every firmware reads
        // the other's projects: FirmwareBackup.swift)
        if case .connected = session.status, !skipBackup {
            backsUp = true
            phase = .backingUp(0)
            do {
                let b = try await session.firmwareBackup { done, total in
                    Task { @MainActor in self.phase = .backingUp(total > 0 ? Double(done) / Double(total) : 1) }
                }
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                backupName = try b.save(in: docs).lastPathComponent
            } catch {
                phase = .idle
                pickerNote = "The backup didn't finish: \(error) Nothing was installed."
                skipBackup = true
                showPicker = true
                return
            }
        }
        skipBackup = false
        phase = .installing(.start(""))
        holdsDevice = true                                  // the session lets go of the FM-1
        UIApplication.shared.isIdleTimerDisabled = true
        let background = UIApplication.shared.beginBackgroundTask(withName: "FM-1 firmware")
        defer {
            UIApplication.shared.isIdleTimerDisabled = false
            UIApplication.shared.endBackgroundTask(background)
            holdsDevice = false
        }
        try? await Task.sleep(for: .milliseconds(600))
        var delays = FirmwareInstaller.Delays()
        if demo == "failed" { delays.waitResume = .seconds(4) }
        let i = FirmwareInstaller(ports: ports, delays: delays)
        installer = i
        do {
            let id = try await i.install(pkg) { s in Task { @MainActor in self.phase = .installing(s) } }
            phase = .done(id, backup: backupName)
            if target.isStock { dismissedOffer = .unsupported(id) }     // (it asked for stock: no offer to undo it)
        } catch let e as InstallError {
            phase = .failed(message: e.message, inUpdateMode: e.inUpdateMode, backup: backupName, refused: e.code == .otherStock)
        } catch {
            phase = .failed(message: "\(error)", inUpdateMode: false, backup: backupName)
        }
        installer = nil
    }

    func close() { phase = .idle }

    /// "Installing Skiff 2.2", "Restoring stock V15".
    var doing: String { target.isStock ? "Restoring stock V15" : "Installing \(target.title)" }
}

// MARK: - The layer over the app

/// The offer card, the picker and the install cover, over everything (iPad and phone alike).
struct FirmwareLayer: View {
    @Bindable var centre: FirmwareCentre
    let session: DeviceSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if centre.isActive {
                FirmwareInstallCover(centre: centre, session: session)
                    .transition(.opacity)
            } else if centre.showPicker {
                scrim { centre.showPicker = false }
                fitted { FirmwarePicker(centre: centre, session: session) }
            } else if let o = centre.visibleOffer {
                scrim { centre.dismissedOffer = o }
                fitted { FirmwareOfferCard(offer: o, centre: centre, session: session) }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: centre.isActive)
    }

    /// Centred, scrolling when it can't fit (a landscape phone).
    private func fitted(@ViewBuilder _ card: () -> some View) -> some View {
        ScrollView {
            card().padding(16).frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, alignment: .center) { h, _ in h }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func scrim(_ tap: @escaping () -> Void) -> some View {
        Theme.page.opacity(0.72).ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: tap)
            .accessibilityHidden(true)
    }
}

/// A card on the scrim: a title, its words, then the actions, right-aligned.
private struct FirmwareCard<Content: View, Actions: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 22, weight: .semibold)).accessibilityAddTraits(.isHeader)
            content
            HStack(spacing: 8) { Spacer(minLength: 0); actions }
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
        .panel()
        .accessibilityElement(children: .contain)
    }
}

/// A key: the primary one light, the rest quiet.
private struct CardKey: View {
    let title: String
    var primary = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(primary ? Theme.onColour : Theme.text)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .raisedKey(9, primary: primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(!enabled)
    }
}

struct FirmwareOfferCard: View {
    /// What it runs, in words: M-VAVE's firmware reports FM-1_0xx.
    static func name(_ found: String) -> String {
        if let v = found.range(of: #"^FM-1_0\d\d$"#, options: .regularExpression).map({ _ in Int(found.suffix(2)) ?? 0 }) {
            return "M-VAVE’s own firmware, V\(v)"
        }
        return "“\(found.replacingOccurrences(of: "FELUCCA ", with: ""))”"
    }

    let offer: FirmwareCentre.Offer
    let centre: FirmwareCentre
    let session: DeviceSession

    var body: some View {
        switch offer {
        case .loader(let id) where id == FirmwareInstaller.officialLoader:
            FirmwareCard(title: "Finish restoring stock V15") {
                Text("The FM-1 is waiting in M-VAVE’s update mode (\(id)): a restore was cut off. Nothing is lost. Jib can finish it now with stock V15, the only firmware that update mode takes from Jib.")
                    .bodyText()
                Text("If you were installing something else with M-VAVE’s own updater, finish it there instead.")
                    .bodyText()
                KeepPluggedNote()
            } actions: {
                CardKey(title: "Not now") { centre.dismissedOffer = offer }
                CardKey(title: "Finish restoring", primary: true) { centre.start(.stock, session: session) }
            }
        case .loader(let id):
            FirmwareCard(title: "Finish the firmware install") {
                Text("The FM-1 is waiting in update mode (\(id)): an install was cut off. Nothing is lost. Jib can finish it now with \(centre.target.title).")
                    .bodyText()
                KeepPluggedNote()
            } actions: {
                CardKey(title: "Not now") { centre.dismissedOffer = offer }
                CardKey(title: "Choose firmware…") { centre.showPicker = true }
                CardKey(title: "Finish installing", primary: true) { centre.start(centre.target, session: session) }
            }
        case .foreignLoader(let id):
            FirmwareCard(title: "The FM-1 is in another update mode") {
                Text("It reports \(id), another firmware’s update mode. Jib only finishes installs of Skiff, SLOOP and stock V15. Finish this one with the updater that started it, then plug the FM-1 in again.")
                    .bodyText()
            } actions: {
                CardKey(title: "OK", primary: true) { centre.dismissedOffer = offer }
            }
        case .unsupported(let found):
            FirmwareCard(title: "Jib needs other firmware") {
                Text("This FM-1 runs \(Self.name(found)). Jib works with Skiff 2.2 or SLOOP 2.8.4, and carries both. Installing takes about a minute; your projects are backed up first when the firmware allows it.")
                    .bodyText()
            } actions: {
                CardKey(title: "Not now") { centre.dismissedOffer = offer }
                CardKey(title: "Choose firmware…", primary: true) { centre.showPicker = true }
            }
        }
    }
}

/// Skiff or SLOOP: the Developer menu's way in, and the offer's.
struct FirmwarePicker: View {
    @Bindable var centre: FirmwareCentre
    let session: DeviceSession

    var body: some View {
        FirmwareCard(title: "Install firmware") {
            VStack(spacing: 8) {
                ForEach(BundledFirmware.allCases.filter { !$0.isStock }) { f in row(f) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Back to stock").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                row(.stock)
            }
            if let note = centre.pickerNote {
                Label { Text(note).bodyText(primary: true) } icon: { Image(systemName: "exclamationmark.triangle") }
                    .font(.system(size: 15))
            } else {
                Text(backupLine).bodyText()
            }
            Text(centre.target.isStock ? "Apache-2.0, unchanged. From \(centre.target.source.replacingOccurrences(of: " (Apache-2.0)", with: ""))."
                                       : "GPL-3.0. Source: \(centre.target.source).")
                .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            CardKey(title: "Cancel") { centre.showPicker = false; centre.pickerNote = nil; centre.skipBackup = false }
            CardKey(title: centre.skipBackup ? (centre.target.isStock ? "Restore without a backup" : "Install without a backup")
                                             : centre.target.isStock ? "Restore stock V15" : "Install \(centre.target.title)", primary: true) {
                centre.start(centre.target, session: session)
            }
        }
    }

    private func row(_ f: BundledFirmware) -> some View {
        Button { centre.target = f } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: centre.target == f ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17)).frame(width: 24)
                    .foregroundStyle(centre.target == f ? Theme.text : Theme.textTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(f.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                        if running == f {
                            Text("On this FM-1").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Text(f.detail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .latchedKey(centre.target == f, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(centre.target == f ? [.isSelected] : [])
    }

    private var running: BundledFirmware? {
        guard case .connected = session.status else { return nil }
        return session.dialect == .skiff ? .skiff : .sloop
    }

    private var backupLine: String {
        let stock = centre.target.isStock
            ? " Stock V15 can’t read Skiff’s or SLOOP’s projects, and installing over it later can write over some of them: the backup is how they come back."
            : ""
        if case .connected = session.status {
            return "Jib backs up the projects, settings, presets and samples to Files first (On My \(deviceWord) › Jib › Backups), then writes. Keep the FM-1 plugged in for about a minute." + stock
        }
        return "There’s no backup this time: the FM-1 isn’t connected to Jib. Keep it plugged in for about a minute." + stock
    }
}

// MARK: - The cover while it writes

struct FirmwareInstallCover: View {
    let centre: FirmwareCentre
    let session: DeviceSession

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch centre.phase {
                    case .done(let id, let backup): done(id, backup)
                    case .failed(let message, let inUpdate, let backup, let refused): failed(message, inUpdate, backup, refused)
                    default: working
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, 24).padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, alignment: .center) { h, _ in h }   // centred, scrolling when it can't fit
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .persistentSystemOverlays(.hidden)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Working

    private var working: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(centre.doing).font(.system(size: 28, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text("Keep Jib open and the FM-1 plugged in.").font(.system(size: 20, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 8) {
                ProgressTrack(value: overall)
                HStack {
                    Text(status).font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Int(overall * 100))%").font(.system(size: 15).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(overall * 100)) percent, \(status)")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(stages.enumerated()), id: \.offset) { i, name in
                    StageRow(name: name, state: i < stage ? .done : i == stage ? .now : .later)
                }
            }
            if case .installing(.dropped) = centre.phase {
                Label { Text("The FM-1 dropped off USB. It waits in update mode: plug it straight back in and Jib carries on by itself.").bodyText(primary: true) }
                    icon: { Image(systemName: "cable.connector.slash") }
            }
            Text("Don’t unplug it or lock the screen. If it’s cut off anyway, nothing is lost: the FM-1 waits in update mode and running the install again finishes it.")
                .font(.system(size: 13)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stages: [String] {
        (centre.backsUp ? ["Back up the projects"] : []) + ["Check the firmware file", "Write", "Restart the FM-1"]
    }

    private var stage: Int { rawStage - (centre.backsUp ? 0 : 1) }

    private var rawStage: Int {
        switch centre.phase {
        case .backingUp: 0
        case .installing(let s):
            switch s {
            case .start, .check, .loader: 1
            case .write, .dropped, .resume: 2
            case .reboot: 3
            case .done: 4
            }
        default: 0
        }
    }

    private var overall: Double {
        switch centre.phase {
        case .backingUp(let f): 0.08 * f
        case .installing(let s):
            switch s {
            case .start: 0.08
            case .check(let n): 0.08 + 0.04 * min(1, Double(n) / 20)
            case .loader: 0.12
            case .write(let p): 0.14 + 0.80 * Double(p) / 100
            case .dropped, .resume: 0.14
            case .reboot: 0.96
            case .done: 1
            }
        default: 0
        }
    }

    private var status: String {
        switch centre.phase {
        case .backingUp: "Backing up"
        case .installing(let s):
            switch s {
            case .start: "Starting"
            case .check: "Checking the firmware file"
            case .loader: "Switching the FM-1 to update mode"
            case .write: "Writing the firmware"
            case .dropped: "Waiting for the FM-1 to come back"
            case .resume(let n): "Writing again (try \(n))"
            case .reboot: "Restarting the FM-1"
            case .done: "Done"
            }
        default: ""
        }
    }

    // MARK: Done and failed

    private func done(_ id: String, _ backup: String?) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label { Text(centre.target.isStock ? "Stock V15 is back" : "\(centre.target.title) is installed").font(.system(size: 28, weight: .semibold)) }
                icon: { Image(systemName: "checkmark.circle").font(.system(size: 28)) }
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 8) {
                Text("The FM-1 restarted and reports \(id), as it should.").bodyText(primary: true)
                if centre.target.isStock {
                    Text("Jib can’t connect to the stock firmware. When you want Jib back, plug the FM-1 in and choose Skiff or SLOOP.").bodyText(primary: true)
                }
                if let backup {
                    Text("The backup is in Files: On My \(deviceWord) › Jib › Backups › \(backup)." + (centre.target.isStock ? " Restore it with that firmware’s editor once it’s back on." : "")).bodyText()
                }
            }
            HStack { Spacer(); CardKey(title: "Done", primary: true) { centre.close() } }
        }
    }

    private func failed(_ message: String, _ inUpdate: Bool, _ backup: String?, _ refused: Bool) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label { Text(refused ? "Stock V15 can’t go on this FM-1" : centre.target.isStock ? "The restore stopped" : "The install stopped").font(.system(size: 28, weight: .semibold)) }
                icon: { Image(systemName: "exclamationmark.triangle").font(.system(size: 28)) }
                .accessibilityAddTraits(.isHeader)
            Text(message).bodyText(primary: true)
            VStack(alignment: .leading, spacing: 12) {
                if inUpdate {
                    Text("Nothing is lost. The FM-1 waits in update mode (its screen says UPDATE MODE, or stays dark) until a write finishes.").bodyText()
                    NumberedLine(n: 1, text: "Plug the FM-1 straight into the \(deviceWord), without a hub or adapter chain if you can.")
                    NumberedLine(n: 2, text: "Tap Run the install again. It finds the update mode and finishes the write.")
                    NumberedLine(n: 3, text: centre.target.isStock
                                  ? "Still stuck? M-VAVE’s own updater, M-UPGRADE (m-vave.com › Downloads), puts the stock firmware back from a computer."
                                  : "Still stuck? Skiff’s README, “If the FM-1 does not start”, has the ways back, from a computer.")
                } else if refused {
                    Text("The FM-1 still runs its firmware, and Skiff and SLOOP still install as usual.").bodyText()
                } else {
                    Text("Nothing was written: the FM-1 still runs its firmware. Check the cable and try again.").bodyText()
                }
                if let backup { Text("The backup taken first is in Files: Jib › Backups › \(backup).").bodyText() }
            }
            HStack(spacing: 8) {
                Spacer()
                if refused {
                    CardKey(title: "Close", primary: true) { centre.close() }
                } else {
                    CardKey(title: "Close") { centre.close() }
                    CardKey(title: "Run the install again", primary: true) { centre.close(); centre.start(centre.target, session: session) }
                }
            }
        }
    }
}

private struct ProgressTrack: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.stepEmpty)
                Capsule().fill(Theme.text).frame(width: max(8, g.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
    }
}

private struct StageRow: View {
    enum State { case done, now, later }
    let name: String
    let state: State
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state == .done ? "checkmark.circle.fill" : state == .now ? "circle.dotted.circle" : "circle")
                .font(.system(size: 17)).frame(width: 24)
                .foregroundStyle(state == .later ? Theme.textTertiary : Theme.text)
            Text(name).font(.system(size: 17, weight: state == .now ? .semibold : .regular))
                .foregroundStyle(state == .later ? Theme.textSecondary : Theme.text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(state == .done ? "done" : state == .now ? "now" : "to come")
    }
}

private struct NumberedLine: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)").font(.system(size: 15, weight: .semibold).monospacedDigit()).frame(width: 20, alignment: .trailing)
            Text(text).bodyText(primary: true)
        }
    }
}

/// "Keep it plugged in", for the offers.
private struct KeepPluggedNote: View {
    var body: some View {
        Text("Keep the FM-1 plugged in and Jib open while it writes, about a minute.")
            .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
    }
}

@MainActor private var deviceWord: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

private extension Text {
    func bodyText(primary: Bool = false) -> some View {
        font(.system(size: 15)).foregroundStyle(primary ? Theme.text : Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

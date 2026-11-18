import SloopKit
import SwiftUI
import UIKit

/// Installing the firmware Lupe offers (Skiff-Lupe: Skiff with the screen link) over USB-MIDI, 2026-11-05, and putting
/// M-VAVE's stock V15 back (its own update loader writes it). SLOOP-Lupe left with SLOOP (decision 43, 2026-11-15); an
/// FM-1 on SLOOP is offered Skiff-Lupe. Since 2026-11-08 the GPL builds aren't in the app: the chosen one is downloaded from Lupe's GitHub release first (FirmwareStore), checked
/// against its pin, and kept for next time. Stock V15 stays in the app.
/// Offers it when the FM-1 runs something else or waits in an update loader; picks it from the connection menu (the phone: the song-name menu, FM-1 firmware…).
/// The phone offers Skiff-Lupe 2.5.1 over anything else, once per connection (decision 42, 2026-11-15).
/// While it runs the session lets go of the FM-1, the screen stays awake, and a cover keeps the app on this.
@Observable @MainActor
final class FirmwareCentre {
    enum Offer: Equatable {
        case loader(String)                 // a Felucca-family update loader waits, or M-VAVE's: finish the write
        case foreignLoader(String)          // another firmware's update mode: not ours to finish
        case unsupported(String)            // runs something Lupe doesn't speak
        case update(String)                 // runs stock Skiff 2.2: Lupe offers Skiff-Lupe, the same with the screen link
        case fork(ForkFrom)                 // the phone (decision 42): anything but Skiff-Lupe 2.5.1 with the current link
    }

    /// What a phone's FM-1 runs instead of Skiff-Lupe 2.5.1 (decision 42, 2026-11-15): the phone app is built on the
    /// screen link, so it offers the fork for each of these, once per connection. The text is what the FM-1 reports.
    enum ForkFrom: Equatable {
        case stockSkiff(String)             // Skiff 2.5.1 or earlier, without the link
        case newerSkiff(String)             // Skiff 2.6 or later, without the link: going to 2.5.1 loses what it added
        case sloop(String)                  // SLOOP or SLOOP-Lupe: Lupe no longer connects to it (decision 43)
        case olderLupe(String)              // Skiff-Lupe 2.2, or 2.5.1 with an earlier link
        case mvave(String)                  // M-VAVE's own firmware: Lupe can't connect at all

        var found: String {
            switch self { case .stockSkiff(let f), .newerSkiff(let f), .sloop(let f), .olderLupe(let f), .mvave(let f): f }
        }
    }

    enum Phase: Equatable {
        case idle
        case downloading(Double)
        /// The download didn't finish: nothing reached the FM-1.
        case downloadFailed(String)
        case backingUp(Double)
        case installing(InstallStep)
        case done(String, backup: String?)
        case failed(message: String, inUpdateMode: Bool, backup: String?, refused: Bool = false)
    }

    var offer: Offer?
    var dismissedOffer: Offer?
    var phase: Phase = .idle
    var target: LupeFirmware = .skiff
    /// The phone: Skiff-Lupe 2.5.1 is the firmware it offers, from the song-name menu and the fork offer (decision 42).
    let phone = UIDevice.current.userInterfaceIdiom == .phone
    /// Skiff-Lupe, downloaded when chosen and kept (Application Support).
    #if DEBUG
    // a Debug build carries firmware/releases/ (the "Bundle release firmware (Debug)" build phase): no GitHub release needed
    let store = FirmwareStore(localReleases: Bundle.main.url(forResource: "DebugFirmware", withExtension: nil))
    #else
    let store = FirmwareStore()
    #endif
    /// This install starts with a download (the file wasn't on the device yet).
    private(set) var downloads = false
    var showPicker = false
    /// Why the picker can't start (the battery, a backup that failed).
    var pickerNote: String?
    /// The backup failed: the next start goes on without one, if asked.
    var skipBackup = false
    /// While true, the session is paused so the installer has the FM-1 to itself.
    private(set) var holdsDevice = false
    /// This install starts with a backup (the session was connected).
    private(set) var backsUp = false
    /// What the update ports last said the FM-1 runs (stock firmware, or a loader): what can't go on it follows.
    private(set) var seen: DeviceIdentity?

    private let ports: UpdatePorts
    private let demo: String?
    private var installer: FirmwareInstaller?
    private var backupName: String?

    init() {
        // -demo-firmware loader | stock | foreign | picker | installing | failed | done, and for the way back to stock
        // picker-stock | restoring | restored | stock-loader | v16, and a new unit on stock V16 v16-new | v16-picker:
        // a fake FM-1 for screenshots
        let a = LaunchArgs.all
        demo = a.firstIndex(of: "-demo-firmware").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
        if phone { target = .skiff251 }
        if let demo {
            let skiff = try? LupeFirmware.skiff.load(), stock = try? LupeFirmware.stock.load()
            let fake: FakeFM1
            switch demo {
            case "loader": fake = FakeFM1(inLoaderOf: skiff!, was: skiff)
            case "stock": fake = FakeFM1(running: nil)
            case "foreign": fake = FakeFM1(running: nil, stockIdentity: "ota-FM-1_301")
            case "stock-loader": fake = FakeFM1(inLoaderOf: stock!, was: skiff)
            case "v16": fake = FakeFM1(running: skiff, startedOn: 16)
            case "v16-new", "v16-picker":
                fake = FakeFM1(running: nil, stockIdentity: "FM-1_016", startedOn: 16)
                fake.newFlashChip = true
            default: fake = FakeFM1(running: skiff)
            }
            fake.knows(skiff!, stock!)
            if let s251 = try? LupeFirmware.skiff251.load() { fake.knows(s251) }
            if demo == "failed" { fake.faults = [.unplug(stage: 2, after: 900, replugAfter: nil)] }
            ports = fake
        } else {
            ports = CoreMIDIUpdatePorts()
        }
    }

    var isActive: Bool { phase != .idle }

    // MARK: Watching for an FM-1 Lupe can't use

    /// Follows the session: a firmware it refused is offered at once; when nothing connects, the update ports are
    /// asked who is there (a loader on "Felucca Update", a stock FM-1 on "FM-1"). Never while installing.
    func watch(_ session: DeviceSession) async {
        if let demo {                                        // the screenshots' states, once
            try? await Task.sleep(for: .seconds(1))
            switch demo {
            case "picker": showPicker = true
            // the phone's fork offer (decision 42) over the demo FM-1, as each firmware would bring it
            case "fork-skiff", "fork-newer", "fork-sloop", "fork-older", "fork-mvave":
                try? await Task.sleep(for: .seconds(1))
                offer = .fork([
                    "fork-skiff": .stockSkiff("Skiff 2.5.1"), "fork-newer": .newerSkiff("Skiff 2.6"),
                    "fork-sloop": .sloop("SLOOP 2.8.4"), "fork-older": .olderLupe("Skiff-Lupe 2.2"),
                    "fork-mvave": .mvave("FM-1_015"),
                ][demo]!)
            case "picker-stock": target = .stock; showPicker = true
            case "v16-picker": await probe(); showPicker = true
            case "installing", "failed", "done", "restoring", "restored", "v16":
                for _ in 0..<50 {                            // with the demo FM-1 connected, so it backs up
                    if case .connected = session.status { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                start(["restoring", "restored", "v16"].contains(demo) ? .stock : phone ? .skiff251 : .skiff, session: session)
            default: await probe()
            }
            return
        }
        var wasConnected = false
        while !Task.isCancelled {
            if !isActive {
                // the phone: once per connection. A new connection brings the offer back unless Not now holds it off
                let connected = if case .connected = session.status { true } else { false }
                if phone, connected, !wasConnected { dismissedOffer = nil }
                wasConnected = connected
                switch session.status {
                // (SLOOP connects no more: its INFO lands here, and both offers name Skiff-Lupe for it)
                case .wrongFirmware(let found, _): offer = phone ? Self.phoneOffer(unsupported: found) : .unsupported(found)
                case .searching, .lost: await probe()
                // stock Skiff 2.2 (no screen link tag in INFO), or an earlier screen-link build (56 01 01 no cursor,
                // 56 01 02 no METER, 56 01 03 no SCOPE, 56 01 04 the scope at 15 a second, 56 01 05 the scope after MASTER): the firmware Lupe carries
                // is an update
                case .connected where phone:
                    offer = session.isDemo ? nil : Self.forkFrom(session).map { .fork($0) }
                case .connected:
                    offer = session.dialect == .skiff && !session.screenCurrent && !session.isDemo
                        ? .update(session.screenLinked ? "Skiff 2.2 with the screen link" : "Skiff 2.2") : nil
                case .connecting: break
                }
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func probe() async {
        let i = FirmwareInstaller(ports: ports)
        guard let id = await i.probe() else { if case .unsupported = offer {} else { offer = nil }; return }
        seen = id
        if refusal(target) != nil, let ok = LupeFirmware.allCases.first(where: { refusal($0) == nil }) { target = ok }
        if id.isLoader {
            let ours = FirmwareInstaller.isResumable(loader: id) || id.text == FirmwareInstaller.officialLoader
            offer = ours ? .loader(id.text) : .foreignLoader(id.text)
            if let f = LupeFirmware.matching(identity: id.text) { target = f }
        } else if LupeFirmware.matching(identity: id.text).map({ $0.isStock }) ?? true {
            // (stock V15 is one Lupe carries, not one it speaks)
            offer = phone ? Self.phoneOffer(unsupported: id.text) : .unsupported(id.text)
        }
    }

    /// The phone's offer for firmware Lupe can't connect to: M-VAVE's own and SLOOP (its INFO, "FELUCCA SLOOP 2.8.4") as
    /// the fork offer, anything else as before.
    static func phoneOffer(unsupported found: String) -> Offer {
        if found.range(of: #"^FM-1_0\d\d$"#, options: .regularExpression) != nil { return .fork(.mvave(found)) }
        if FirmwareDialect.isSLOOP(found) { return .fork(.sloop(sloopName(found))) }
        return .unsupported(found)
    }

    /// SLOOP's INFO as the offers say it: "FELUCCA SLOOP 2.8.4" → "SLOOP 2.8.4".
    static func sloopName(_ found: String) -> String {
        let v = found.replacingOccurrences(of: "FELUCCA ", with: "")
        return "SLOOP \(v.drop { !$0.isNumber })"
    }

    /// Why a connected FM-1 isn't on Skiff-Lupe 2.5.1 with the current link, or nil when it is (decision 42).
    static func forkFrom(_ s: DeviceSession) -> ForkFrom? {
        let v = (s.info?.version ?? "").replacingOccurrences(of: "FELUCCA ", with: "")
        let n = v.drop { !$0.isNumber }.split(separator: ".").map { Int($0) ?? 0 }
        let newer = n.lexicographicallyPrecedes([2, 5, 1]) == false && n != [2, 5, 1] && !n.isEmpty
        switch s.dialect {
        case .skiff?:
            let short = String(v.drop { !$0.isNumber })
            if !s.screenLinked { return newer ? .newerSkiff("Skiff \(short)") : .stockSkiff("Skiff \(short)") }
            if newer { return nil }                     // (a later Skiff-Lupe than this app knows: nothing to offer)
            return s.skiffFirmware == .v2_5_1 && s.screenCurrent ? nil : .olderLupe("Skiff-Lupe \(short)")
        case nil: return nil
        }
    }

    // MARK: Not now, per FM-1 (the phone)

    /// How long the phone's Not now holds the fork offer off for the FM-1 that brought it. It's always in the
    /// song-name menu (FM-1 firmware…) meanwhile.
    static let snoozeDays = 14
    private static let snoozeKey = "firmware.forkSnooze"

    /// The FM-1 reports no serial number, so "this FM-1" is what it runs: the same unit on the same firmware.
    func snooze(_ f: ForkFrom) {
        var d = UserDefaults.standard.dictionary(forKey: Self.snoozeKey) as? [String: Date] ?? [:]
        d[f.found] = Date().addingTimeInterval(Double(Self.snoozeDays) * 86_400)
        UserDefaults.standard.set(d, forKey: Self.snoozeKey)
        dismissedOffer = .fork(f)
    }

    private func snoozed(_ f: ForkFrom) -> Bool {
        guard demo == nil else { return false }
        let d = UserDefaults.standard.dictionary(forKey: Self.snoozeKey) as? [String: Date] ?? [:]
        return (d[f.found] ?? .distantPast) > Date()
    }

    var visibleOffer: Offer? {
        if case .fork(let f)? = offer, snoozed(f) { return nil }
        return offer == dismissedOffer ? nil : offer
    }

    /// Why `f` can't go on the FM-1 Lupe last saw, in a line for the picker, or nil.
    func refusal(_ f: LupeFirmware) -> String? {
        switch FirmwareInstaller.refusal(for: f, running: seen)?.code {
        case .otherStock?: "Not on this FM-1. It started out on a newer official version, so V15 can’t go back on."
        default: nil
        }
    }

    /// The FM-1 Lupe last saw runs stock V16 or later.
    var seesNewStock: Bool {
        guard let id = seen, !id.isLoader, id.text.range(of: #"^FM-1_0\d\d$"#, options: .regularExpression) != nil else { return false }
        return id.version >= 16
    }

    // MARK: Installing

    /// The battery's say: nil to go ahead, else why not. Unknown (the simulator) goes ahead.
    func batteryRefusal() -> String? {
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        let level = d.batteryLevel, state = d.batteryState
        guard level >= 0, state == .unplugged, level < 0.3 else { return nil }
        let device = d.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "Charge the \(device) first: it's at \(Int(level * 100))%. The \(device) powers the FM-1 while it writes, so Lupe installs below 30% only while charging."
    }

    func start(_ firmware: LupeFirmware, session: DeviceSession) {
        if demo == nil, let why = batteryRefusal() { pickerNote = why; showPicker = true; return }
        target = firmware
        pickerNote = nil
        showPicker = false
        offer = nil
        Task { await run(session: session) }
    }

    /// Installable now, without a download first (the demos use the repository's copies in a Debug build).
    func isReady(_ f: LupeFirmware) -> Bool { demo != nil ? f.localCopy != nil : store.isReady(f) }

    private func run(session: DeviceSession) async {
        // the file first: downloaded from Lupe's release and checked against its pin, before a backup or anything else
        downloads = !isReady(target)
        if downloads {
            phase = .downloading(0)
            do {
                try await store.fetch(target) { f in Task { @MainActor in if case .downloading = self.phase { self.phase = .downloading(f) } } }
            } catch {
                phase = .downloadFailed("\(error)")
                return
            }
        }
        let pkg: FirmwarePackage
        do { pkg = try demo != nil ? target.load() : store.package(target) } catch {
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
                backupName = b.place(try b.save(in: docs))
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

    /// "Installing Skiff-Lupe 2.2", "Restoring stock V15".
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
                    // on a scrim: VoiceOver stays on the card, the scrub closes it as the scrim's tap does (2026-11-10)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { centre.showPicker = false }
            } else if let o = centre.visibleOffer {
                scrim { centre.dismissedOffer = o }
                fitted { FirmwareOfferCard(offer: o, centre: centre, session: session) }
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { centre.dismissedOffer = o }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: centre.isActive)
    }

    /// Centred, scrolling from its top when it can't fit (a landscape phone). At least the screen's height, never
    /// exactly it: a taller card spilt over both ends and its title couldn't be scrolled to (2026-11-15).
    private func fitted(@ViewBuilder _ card: () -> some View) -> some View {
        let c = card()
        return GeometryReader { g in
            ScrollView {
                c.padding(16).frame(maxWidth: .infinity)
                    .frame(minHeight: g.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
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
            Text(title).font(.lupe(22, .semibold)).accessibilityAddTraits(.isHeader)
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
            Text(title).font(.lupe(15, .semibold))
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
                Text("The FM-1 is waiting in M-VAVE’s update mode (\(id)): a restore was cut off. Nothing is lost. Lupe can finish it now with stock V15, the only firmware that update mode takes from Lupe.")
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
                Text("The FM-1 is waiting in update mode (\(id)): an install was cut off. Nothing is lost. Lupe can finish it now with \(centre.target.title).")
                    .bodyText()
                KeepPluggedNote()
            } actions: {
                CardKey(title: "Not now") { centre.dismissedOffer = offer }
                CardKey(title: "Choose firmware…") { centre.showPicker = true }
                CardKey(title: "Finish installing", primary: true) { centre.start(centre.target, session: session) }
            }
        case .foreignLoader(let id):
            FirmwareCard(title: "The FM-1 is in another update mode") {
                Text("It reports \(id), another firmware’s update mode. Lupe only finishes installs of Skiff and stock V15. Finish this one with the updater that started it, then plug the FM-1 in again.")
                    .bodyText()
            } actions: {
                CardKey(title: "OK", primary: true) { centre.dismissedOffer = offer }
            }
        case .update(let found):
            FirmwareCard(title: "An update for \(found)") {
                Text(found.hasSuffix("screen link")
                     ? "This FM-1 runs an earlier build of the screen link. The newer one sends the FM-1’s oscilloscope to the EDIT cards, 30 times a second, along with its cursor (turn KNOB 1 on MOD and Lupe picks the same route) and each track’s level for the Mixer. Everything else stays as it is, your projects included, and they’re backed up first. Installing takes about a minute."
                     : "Lupe can install Skiff-Lupe, which is \(found) with Lupe’s screen link: press a button on the FM-1 and Lupe shows that page, pick a tab in Lupe and the FM-1 goes there too. Everything else stays as it is, your projects included, and they're backed up first. Installing takes about a minute.")
                    .bodyText()
            } actions: {
                CardKey(title: "Not now") { centre.dismissedOffer = offer }
                CardKey(title: "Install the update", primary: true) { centre.target = .skiff; centre.showPicker = true }
            }
        case .fork(let from):
            ForkOfferCard(from: from, centre: centre, session: session)
        case .unsupported(let found):
            FirmwareCard(title: FirmwareDialect.isSLOOP(found) ? "Lupe needs Skiff-Lupe" : "Lupe needs other firmware") {
                if FirmwareDialect.isSLOOP(found) {
                    // (decision 43: SLOOP no longer connects; the iPad's card offers Skiff-Lupe for it, as the phone's does)
                    Text("This FM-1 runs \(FirmwareCentre.sloopName(found)). Lupe works with Skiff now, and can install Skiff-Lupe: Skiff with Lupe’s screen link, downloaded when you choose it. Installing takes about a minute.")
                        .bodyText()
                    Text(ForkOfferCard.sloopProjects).bodyText()
                } else {
                    Text("This FM-1 runs \(Self.name(found)). Lupe works with Skiff 2.2 or 2.5.1, and can install Skiff-Lupe (Skiff with Lupe’s screen link, downloaded when you choose it). Installing takes about a minute; your projects are backed up first when the firmware allows it.")
                        .bodyText()
                }
            } actions: {
                CardKey(title: "Not now") { centre.dismissedOffer = offer }
                CardKey(title: "Choose firmware…", primary: true) { centre.showPicker = true }
            }
        }
    }
}

/// The phone's offer of Skiff-Lupe 2.5.1 (decision 42, 2026-11-15): what this FM-1 runs, what Lupe can't do on it,
/// then Not now (held off for this FM-1 for two weeks) or Install… (the picker, with the backup and the download).
struct ForkOfferCard: View {
    let from: FirmwareCentre.ForkFrom
    let centre: FirmwareCentre
    let session: DeviceSession

    /// What becomes of SLOOP's projects (from Skiff's sources, 2026-11-15: 2.x keeps a project of an earlier format in its
    /// slot as OLD FORMAT, project.c proj_old; its web editor's Restore converts it, README "Updating to 2.0"). Lupe
    /// can't read SLOOP any more, so it takes no backup first.
    static let sloopProjects = "Installing leaves SLOOP’s projects in the FM-1’s memory, but Skiff doesn’t open them: it keeps each one as OLD FORMAT. Lupe can’t back up SLOOP, so save a backup in SLOOP’s own web editor first. Once Skiff is on, Skiff’s web editor can convert old projects: take a backup there and restore it."

    /// What the phone loses without Lupe's screen link (each one is a `session.screenLinked` gate in the phone's views).
    static let withoutLink = "Without Lupe’s screen link, Lupe and the FM-1 don’t follow each other: a button on the FM-1 doesn’t open its page or sound panel here, a tab here doesn’t move the FM-1, and the Mix meters, the scope in the page pictures and MOD’s route stay still."

    /// Lupe is connected to this firmware, so it backs up through the session first.
    private var backsUp: Bool {
        switch from { case .sloop, .mvave: false; default: true }
    }

    private var title: String {
        switch from {
        case .mvave: "Lupe needs Skiff-Lupe"
        case .olderLupe: "An update for Skiff-Lupe"
        default: "Get all of Lupe with Skiff-Lupe"
        }
    }

    var body: some View {
        FirmwareCard(title: title) {
            switch from {
            case .stockSkiff(let f):
                Text("This FM-1 runs \(f). " + Self.withoutLink).bodyText(primary: true)
                Text("Skiff-Lupe 2.5.1 is Skiff 2.5.1 with that link added; everything else stays as it is.").bodyText()
            case .newerSkiff(let f):
                // (Scott's wording, 2026-11-16: the benefits first, the step back once; the same text as Android's)
                Text("This FM-1 runs \(f). Lupe works with it, but Skiff-Lupe, a custom build of Skiff, turns on all of Lupe’s features. The most important is the screen link, which keeps the FM-1 and Lupe fully linked in what they show and in their controls. Press a button or turn a knob on either one, and the other follows.").bodyText(primary: true)
                Text("Skiff-Lupe is built on Skiff 2.5.1, so installing it goes back from \(f.replacingOccurrences(of: "Skiff ", with: "")), and CAST goes. Your projects stay, and Lupe backs them up first. It takes about a minute.").bodyText()
            case .sloop(let f):
                Text("This FM-1 runs \(f). Lupe works with Skiff now: songs, the Timeline and the screen link, which keeps Lupe and the FM-1 on the same page.").bodyText(primary: true)
                Text(Self.sloopProjects).bodyText()
            case .olderLupe(let f):
                Text("This FM-1 runs \(f). Skiff-Lupe 2.5.1 adds FX › DELAY and REVERB, the FILTR insert and chord strum, and the screen link’s newest build: the scope at 30 a second, MOD’s route and the Mix meters.").bodyText(primary: true)
            case .mvave(let f):
                Text("This FM-1 runs \(FirmwareOfferCard.name(f)). Lupe can’t connect to it at all. Skiff-Lupe 2.5.1 is Skiff, a firmware for the FM-1 with six tracks and songs, plus Lupe’s screen link.").bodyText(primary: true)
            }
            // (SLOOP and M-VAVE's own: Lupe can't connect, so there's nothing to back up through; the card says so above)
            if case .newerSkiff = from {} else {
            Text(backsUp ? "Lupe backs up your projects to Files first. Installing takes about a minute; you can put stock V15 back any time from FM-1 firmware… in the song-name menu."
                         : "Installing takes about a minute; you can put stock V15 back any time from FM-1 firmware… in the song-name menu.")
                .bodyText()
            }
        } actions: {
            CardKey(title: "Not now") { centre.snooze(from) }
                .accessibilityHint("Asks again in \(FirmwareCentre.snoozeDays) days. FM-1 firmware… in the song-name menu has it meanwhile")
            CardKey(title: "Install…", primary: true) { centre.target = .skiff251; centre.pickerNote = nil; centre.showPicker = true }
        }
    }
}

/// Skiff-Lupe or stock V15: the connection menu's way in (the phone's song-name menu, FM-1 firmware…), and the offer's.
struct FirmwarePicker: View {
    @Bindable var centre: FirmwareCentre
    let session: DeviceSession

    /// The phone's choices: Skiff-Lupe 2.5.1, then stock V15 (decision 42). The iPad's: all of them.
    private var choices: [LupeFirmware] { centre.phone ? [.skiff251] : LupeFirmware.allCases.filter { !$0.isStock } }

    /// What the FM-1 runs, in a line (the phone's picker opens with it).
    private var runs: String {
        if case .connected = session.status, let i = session.info {
            let v = i.version.replacingOccurrences(of: "FELUCCA ", with: "")
            let lupe = session.screenLinked ? "Skiff-Lupe" : "Skiff"
            return session.isDemo ? "The demo FM-1 runs \(lupe) \(v.drop { !$0.isNumber })." : "This FM-1 runs \(lupe) \(v.drop { !$0.isNumber })."
        }
        if case .wrongFirmware(let found, _) = session.status { return "This FM-1 runs \(FirmwareOfferCard.name(found))." }
        return "No FM-1 is connected. Plug it in to see what it runs; Lupe can still install, without a backup."
    }

    var body: some View {
        FirmwareCard(title: centre.phone ? "FM-1 firmware" : "Install firmware") {
            if centre.phone { Text(runs).bodyText(primary: true) }
            VStack(spacing: 8) {
                ForEach(choices) { f in row(f) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Back to stock").font(.lupe(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                row(.stock)
            }
            if let note = centre.pickerNote {
                Label { Text(note).bodyText(primary: true) } icon: { Image(systemName: "exclamationmark.triangle") }
                    .font(.system(size: 15))
            } else {
                Text(backupLine).bodyText()
            }
            Text(centre.target.isStock ? "Apache-2.0, unchanged. From \(centre.target.source.replacingOccurrences(of: " (Apache-2.0)", with: "")). In the app, no download."
                                       : "\(centre.target.credit) GPL-3.0. Source: \(centre.target.source)."
                                         + (centre.isReady(centre.target) ? " Downloaded already." : " Lupe downloads it from its GitHub release first (about 600 KB)."))
                .font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            CardKey(title: "Cancel") { centre.showPicker = false; centre.pickerNote = nil; centre.skipBackup = false }
            CardKey(title: centre.skipBackup ? (centre.target.isStock ? "Restore without a backup" : "Install without a backup")
                                             : centre.target.isStock ? "Restore stock V15"
                                             : centre.isReady(centre.target) ? "Install \(centre.target.title)" : "Download and install", primary: true,
                    enabled: centre.refusal(centre.target) == nil) {
                centre.start(centre.target, session: session)
            }
        }
    }

    private func row(_ f: LupeFirmware) -> some View {
        Button { centre.target = f } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: centre.target == f ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 17)).frame(width: 24)
                    .foregroundStyle(centre.target == f ? Theme.text : Theme.textTertiary)
                    .accessibilityHidden(true)      // (the row says it with .isSelected; the symbol's name was read too)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(f.title).font(.lupe(17, .semibold)).foregroundStyle(Theme.text)
                        if running == f {
                            Text("On this FM-1").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Text(f.detail).font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let why = centre.refusal(f) {
                        Label { Text(why) } icon: { Image(systemName: "nosign") }
                            .font(.system(size: 13)).foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .latchedKey(centre.target == f, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(centre.refusal(f) != nil)
        .accessibilityAddTraits(centre.target == f ? [.isSelected] : [])
    }

    private var running: LupeFirmware? {
        guard case .connected = session.status, !centre.seesNewStock else { return nil }
        if centre.phone {
            return session.dialect == .skiff && session.screenLinked && session.skiffFirmware == .v2_5_1 ? .skiff251 : nil
        }
        return session.dialect == .skiff ? .skiff : nil
    }

    private var backupLine: String {
        let stock = centre.target.isStock
            ? " Stock V15 can’t read Skiff’s projects, and installing over it later can write over some of them: the backup is how they come back."
            : ""
        if case .connected = session.status {
            return "Lupe backs up the projects, settings, presets and samples to Files first (On My \(deviceWord) › Lupe › Skiff › Backups), then writes. Keep the FM-1 plugged in for about a minute." + stock
        }
        return "There’s no backup this time: the FM-1 isn’t connected to Lupe. Keep it plugged in for about a minute." + stock
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
                    case .downloadFailed(let message): downloadFailed(message)
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
        // the end of a write is a new screen in place: VoiceOver goes to it, so "done" or "failed" is heard without
        // hunting for it (2026-11-10, WCAG 4.1.3)
        .onChange(of: centre.phase) { _, p in
            switch p {
            case .done, .failed, .downloadFailed: AccessibilityNotification.ScreenChanged(nil).post()
            default: break
            }
        }
    }

    // MARK: Working

    private var working: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(centre.doing).font(.lupe(28, .semibold)).accessibilityAddTraits(.isHeader)
                Text("Keep Lupe open and the FM-1 plugged in.").font(.lupe(20, .semibold))
            }
            VStack(alignment: .leading, spacing: 8) {
                ProgressTrack(value: overall)
                HStack {
                    Text(status).font(.lupe(15)).foregroundStyle(Theme.textSecondary)
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
                Label { Text("The FM-1 dropped off USB. It waits in update mode: plug it straight back in and Lupe carries on by itself.").bodyText(primary: true) }
                    icon: { Image(systemName: "cable.connector.slash") }
            }
            Text("Don’t unplug it or lock the screen. If it’s cut off anyway, nothing is lost: the FM-1 waits in update mode and running the install again finishes it.")
                .font(.lupe(13)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stages: [String] {
        (centre.downloads ? ["Download \(centre.target.title)"] : []) + (centre.backsUp ? ["Back up the projects"] : [])
            + ["Check the firmware file", "Write", "Restart the FM-1"]
    }

    private var stage: Int {
        let d = centre.downloads ? 1 : 0, b = centre.backsUp ? 1 : 0
        switch centre.phase {
        case .downloading: return 0
        case .backingUp: return d
        case .installing(let s):
            switch s {
            case .start, .check, .loader: return d + b
            case .write, .dropped, .resume: return d + b + 1
            case .reboot: return d + b + 2
            case .done: return d + b + 3
            }
        default: return 0
        }
    }

    /// The download takes the first 6 % when there is one; the rest as before.
    private var overall: Double {
        let d = centre.downloads ? 0.06 : 0
        let rest: Double
        switch centre.phase {
        case .downloading(let f): return 0.06 * f
        case .backingUp(let f): rest = 0.08 * f
        case .installing(let s):
            switch s {
            case .start: rest = 0.08
            case .check(let n): rest = 0.08 + 0.04 * min(1, Double(n) / 20)
            case .loader: rest = 0.12
            case .write(let p): rest = 0.14 + 0.80 * Double(p) / 100
            case .dropped, .resume: rest = 0.14
            case .reboot: rest = 0.96
            case .done: rest = 1
            }
        default: rest = 0
        }
        return d + (1 - d) * rest
    }

    private var status: String {
        switch centre.phase {
        case .downloading: "Downloading \(centre.target.title) from GitHub"
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
            Label { Text(centre.target.isStock ? "Stock V15 is back" : "\(centre.target.title) is installed").font(.lupe(28, .semibold)) }
                icon: { Image(systemName: "checkmark.circle").font(.system(size: 28)) }
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 8) {
                Text("The FM-1 restarted and reports \(id), as it should.").bodyText(primary: true)
                if centre.target.isStock {
                    Text("Lupe can’t connect to the stock firmware. When you want Lupe back, plug the FM-1 in and choose Skiff-Lupe.").bodyText(primary: true)
                }
                if let backup {
                    Text("The backup is in Files: On My \(deviceWord) › Lupe › \(backup)." + (centre.target.isStock ? " Restore it with that firmware’s editor once it’s back on." : "")).bodyText()
                }
            }
            HStack { Spacer(); CardKey(title: "Done", primary: true) { centre.close() } }
        }
    }

    /// The download stopped: nothing was sent, so it's a retry, not a recovery.
    private func downloadFailed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label { Text("The download didn’t finish").font(.lupe(28, .semibold)) }
                icon: { Image(systemName: "exclamationmark.triangle").font(.system(size: 28)) }
                .accessibilityAddTraits(.isHeader)
            Text(message).bodyText(primary: true)
            Text("The FM-1 still runs its firmware. Once \(centre.target.title) is downloaded, Lupe keeps it, so the next install needs no internet.").bodyText()
            HStack(spacing: 8) {
                Spacer()
                CardKey(title: "Close") { centre.close() }
                CardKey(title: "Try again", primary: true) { centre.close(); centre.start(centre.target, session: session) }
            }
        }
    }

    private func failed(_ message: String, _ inUpdate: Bool, _ backup: String?, _ refused: Bool) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label { Text(refused ? "Stock V15 can’t go on this FM-1" : centre.target.isStock ? "The restore stopped" : "The install stopped").font(.lupe(28, .semibold)) }
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
                    Text("The FM-1 still runs its firmware, and Skiff-Lupe still installs as usual.").bodyText()
                } else {
                    Text("Nothing was written: the FM-1 still runs its firmware. Check the cable and try again.").bodyText()
                }
                if let backup { Text("The backup taken first is in Files: Lupe › \(backup).").bodyText() }
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
            Text(name).font(.lupe(17, state == .now ? .semibold : .regular))
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
        Text("Keep the FM-1 plugged in and Lupe open while it writes, about a minute.")
            .font(.lupe(13)).foregroundStyle(Theme.textSecondary)
    }
}

@MainActor private var deviceWord: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

private extension Text {
    func bodyText(primary: Bool = false) -> some View {
        font(.system(size: 15)).foregroundStyle(primary ? Theme.text : Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

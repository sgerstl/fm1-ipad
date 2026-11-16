// Installing Skiff-Lupe from the phone (decision 42: the phone apps offer the fork Lupe needs). The iPad's
// FirmwareCentre (ios/FM1/FirmwareInstall.swift) on SloopKit's own pieces: FirmwareInstaller (both update steps, the
// resume after a cut), FirmwarePackage and FirmwareStore (only the pinned file, by its SHA-256), FirmwareBackup (the
// running firmware's own backup first). FIRMWARE.md, "How the install works".
//
// What is the phone's own:
// - The ports. Android gives one client one device, so the installer's ports are the link's (AndroidLink's
//   UpdateLink.swift), and the editor's Session lets go of the FM-1 while an install runs (`FirmwareLink.hold`).
// - The download. The app fetches the file (Kotlin, the platform's own HTTPS) into its storage and hands the path in;
//   the store takes it only if it is exactly the pinned file. While it waits, the area's `download` says what to get.
// - Storage. The app says where its files live (`appStorage`); the cached package and the backups go there.
//
// An install is not behind the read-only gate: it is asked for and confirmed by name on its own screen. It is refused
// while a change from the editor is still going in.
import Foundation
import SloopKit

/// What the firmware flow needs from the link (LupeNative gives the real one; the tests a fake FM-1).
public struct FirmwareLink {
    public var ports: UpdatePorts
    /// true: the installer has the FM-1 to itself; false: the editor's Session may have it back.
    public var hold: (Bool) -> Void
    public var delays: FirmwareInstaller.Delays
    /// Whether the installer may ask the open device who it is while nothing is being installed. False for a device
    /// the editor's Session is about to talk to: the two would read each other's answers off the one connection.
    public var mayProbe: () -> Bool
    public init(ports: UpdatePorts, hold: @escaping (Bool) -> Void, delays: FirmwareInstaller.Delays = .init(),
                mayProbe: @escaping () -> Bool = { true }) {
        self.ports = ports; self.hold = hold; self.delays = delays; self.mayProbe = mayProbe
    }
}

public struct FirmwareArea: Codable, Equatable, Sendable {
    public struct Offer: Codable, Equatable, Sendable {
        /// "install" (it runs something Lupe doesn't speak: put Skiff-Lupe on), "update" (an older Skiff: the same,
        /// newer), "finish" (it waits in update mode after a cut: write again), "foreign" (another firmware's update
        /// mode: not Lupe's to finish; nothing to install).
        public var kind: String
        /// What the FM-1 runs, as the iPhone's offer names it: "stockSkiff" (Skiff without Lupe's screen link),
        /// "newerSkiff" (a Skiff newer than 2.5.1: installing goes back a version), "olderLupe" (a Skiff-Lupe before
        /// 2.5.1 or with an earlier screen link), "sloop", "mvave" (M-VAVE's own firmware), "unknown", or "loader".
        public var from: String
        /// The same for the same FM-1 state (`from` and what it reports): for the app's "not now for 14 days".
        public var key: String
        /// The firmware it would install (firmwareInstall's `which`); absent for "foreign".
        public var firmware: String?
        public var title: String
        public var text: String
    }
    public struct Download: Codable, Equatable, Sendable {
        public var firmware: String
        public var url: String
        public var fileName: String
        public var sha256: String
        public var size: Int
    }
    /// What the FM-1 runs, in words ("Skiff-Lupe 2.5.1", "M-VAVE's own firmware, V16", "update mode"); absent when no
    /// FM-1 is there.
    public var running: String?
    /// Its identity from the update handshake, or the editor's version string ("FM-1_016", "FELUCCA v2.5.1").
    public var identity: String?
    public var offer: Offer?
    /// "idle", "downloading", "backingUp", "staging" (the running firmware checks the file and starts its update
    /// loader), "writing", "resuming" (cut off: waiting for the loader, or writing again), "restarting", "done",
    /// "failed".
    public var state: String
    /// The whole install, 0…1.
    public var progress: Double
    /// One line for the screen: what is happening, or what went wrong and what to do.
    public var message: String
    /// The firmware being installed (its title), while one is.
    public var installing: String?
    /// While "downloading": the file the app must fetch and hand in with firmwareFile.
    public var download: Download?
    /// The backup taken before the install: its file's path in the app's storage (for sharing).
    public var backup: String?
    /// After a failure: the FM-1 may be waiting in update mode. Installing again finishes it.
    public var inUpdateMode: Bool
}

extension PhoneCore {
    /// The firmware the phone installs: Skiff 2.5.1 with Lupe's screen link, the one the phone's pages are checked
    /// against (PageParityTests).
    public static let phoneFirmware = LupeFirmware.skiff251

    public func firmwareArea() -> FirmwareArea {
        var a = FirmwareArea(running: fwRunning, identity: fwIdentity, offer: fwOffer == fwDismissed ? nil : fwOffer, state: fwState,
                             progress: (fwProgress * 1000).rounded() / 1000, message: fwMessage, installing: nil, download: nil,
                             backup: fwBackup, inUpdateMode: fwInUpdateMode)
        if fwState != "idle" { a.installing = fwTarget.title }
        if fwState == "downloading", fwAwaitingFile, let url = fwTarget.downloadURL {
            a.download = .init(firmware: fwTarget.rawValue, url: url.absoluteString, fileName: fwTarget.fileName, sha256: fwTarget.sha256, size: fwTarget.size)
        }
        return a
    }

    var fwActive: Bool { !["idle", "done", "failed"].contains(fwState) }

    private func fwSet(_ state: String, _ progress: Double, _ message: String) {
        fwState = state; fwProgress = max(0, min(1, progress)); fwMessage = message
        log("firmware: \(state) \(Int(fwProgress * 100))% \(message)")
        publishNow(["firmware"])
    }

    static func stockName(_ found: String) -> String {
        if found.range(of: #"^FM-1_0\d\d$"#, options: .regularExpression) != nil, let v = Int(found.suffix(2)) { return "M-VAVE's own firmware, V\(v)" }
        if let f = LupeFirmware.matching(identity: found) { return f.title }
        return "\"\(found.replacingOccurrences(of: "FELUCCA ", with: ""))\""
    }

    /// One look at what is plugged in, as the iPad's FirmwareCentre.watch: a firmware the Session refused, an older
    /// Skiff it speaks, or (nothing connecting) whoever answers the update handshake: a loader, a stock FM-1.
    func watchFirmware() async {
        guard !fwActive, let link = firmwareLink else { return }
        let s = session
        let target = Self.phoneFirmware
        var offer: FirmwareArea.Offer?, running: String?, identity: String?
        func make(_ kind: String, _ from: String, _ found: String, _ f: LupeFirmware?, _ title: String, _ text: String) -> FirmwareArea.Offer {
            .init(kind: kind, from: from, key: "\(from)|\(found)", firmware: f?.rawValue, title: title, text: text)
        }
        let keeps = "It takes about a minute, and your projects stay on the FM-1."
        func foreign(_ found: String) -> FirmwareArea.Offer {
            let mvave = found.range(of: #"^FM-1_0\d\d$"#, options: .regularExpression) != nil
            return make("install", mvave ? "mvave" : "unknown", found, target, "Lupe needs other firmware",
                        "This FM-1 runs \(Self.stockName(found)). Lupe works with \(target.title) (Skiff with Lupe's screen link) and can install it now. It takes about a minute."
                        + (mvave ? " Back up anything you want to keep with M-VAVE's own app first: Lupe can't read this firmware's projects." : ""))
        }
        switch s.status {
        case .wrongFirmware(let found, _):
            running = Self.stockName(found); identity = found
            offer = foreign(found)
        case .connected(let version):
            // (by name: "Skiff-Lupe 2.5.1" with the screen link, "Skiff 2.6" without; the app said "Skiff-Lupe" for any
            // FM-1 with nothing on offer, so a stock 2.6 unit read "Skiff-Lupe 2.6 · up to date" after Not now, 2026-11-16)
            let named = String(version.replacingOccurrences(of: "FELUCCA ", with: "").drop { !$0.isNumber })
            running = s.dialect == .skiff && !named.isEmpty ? (s.screenLinked ? "Skiff-Lupe \(named)" : "Skiff \(named)") : version
            identity = version
            if s.dialect != .skiff {
                offer = make("install", "sloop", version, target, "Skiff-Lupe for this FM-1",
                             "This FM-1 runs \(version). The phone app is made for \(target.title) (Skiff with Lupe's screen link) and can install it now. SLOOP's projects stay on the FM-1, and Skiff converts them when it loads them. \(keeps)")
            } else {
                // (the iPhone's rules, decision 42) newer than 2.5.1: a version Lupe's table doesn't know, above it
                let nums = version.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
                let shortVersion = String(version.replacingOccurrences(of: "FELUCCA ", with: "").drop { !$0.isNumber })
                let newer = (nums.count >= 2 && (nums[0], nums[1], nums.count > 2 ? nums[2] : 0) > (2, 5, 1))
                if !s.screenLinked {
                    offer = newer
                        ? make("install", "newerSkiff", version, target, "Get all of Lupe with Skiff-Lupe",
                               "This FM-1 runs Skiff \(shortVersion). Lupe works with it, but Skiff-Lupe, a custom build of Skiff, turns on all of Lupe's features. The most important is the screen link, which keeps the FM-1 and Lupe fully linked in what they show and in their controls. Press a button or turn a knob on either one, and the other follows.\n\nSkiff-Lupe is built on Skiff 2.5.1, so installing it goes back from \(shortVersion), and CAST goes. Your projects stay, and Lupe backs them up first. It takes about a minute.")
                        : make("install", "stockSkiff", version, target, "Skiff-Lupe for this FM-1",
                               "This FM-1 runs \(version). \(target.title) is the same Skiff with Lupe's screen link: press a button on the FM-1 and the phone shows that page, and the other way round. \(keeps)")
                } else if !newer, !(s.skiffFirmware == .v2_5_1 && s.screenCurrent) {
                    offer = make("update", "olderLupe", version, target, "An update for this FM-1",
                                 "This FM-1 runs an earlier Skiff-Lupe (\(version)). \(target.title) is the one this app is made for: its pages match the phone's. \(keeps)")
                }
            }
        case .connecting: return
        case .searching, .lost:
            // only a device the Session will never take (an update loader, a stock FM-1): see FirmwareLink.mayProbe
            // (nothing there, or the editor's own device still connecting: no offer, and what was said before goes)
            let installer = FirmwareInstaller(ports: link.ports, delays: link.delays)
            let mayProbe = link.mayProbe()
            let found = mayProbe ? await installer.probe() : nil
            if found == nil, fwOffer?.kind == "finish", fwLoaderMisses < 2 {
                // (a loader that missed one handshake still waits: keep its offer for two more rounds)
                fwLoaderMisses += 1
                return
            }
            if let id = found {
                guard !fwActive else { return }
                fwLoaderMisses = 0
                fwSeen = id
                identity = id.text
                if id.isLoader {
                    running = "update mode"
                    let official = id.text == FirmwareInstaller.officialLoader
                    if FirmwareInstaller.isResumable(loader: id), let f = LupeFirmware.matching(identity: id.text) ?? Optional(target), !f.isStock {
                        offer = make("finish", "loader", id.text, f, "Finish the firmware install",
                                     "The FM-1 is waiting in update mode (\(id.text)): an install was cut off. Nothing is lost. Lupe can finish it now with \(f.title).")
                    } else {
                        offer = make("foreign", "loader", id.text, nil, official ? "The FM-1 is in M-VAVE's update mode" : "The FM-1 is in another update mode",
                                     official
                                        ? "It reports \(id.text): a return to stock V15 was cut off. Finish it from Lupe on an iPad, or with M-VAVE's own updater, then plug the FM-1 in again."
                                        : "It reports \(id.text), another firmware's update mode. Finish that install with the updater that started it, then plug the FM-1 in again.")
                    }
                } else {
                    running = Self.stockName(id.text)
                    offer = foreign(id.text)
                }
            }
        }
        guard !fwActive else { return }
        if fwOffer != offer || fwRunning != running || fwIdentity != identity {
            fwOffer = offer; fwRunning = running; fwIdentity = identity
            if offer == nil { fwDismissed = nil }
            pokeAreas(["firmware"])
        }
    }

    private struct FirmwareWire: Decodable {
        let intent: String
        let which: String?, confirmed: Bool?, path: String?, message: String?, progress: Double?
        let battery: Int?, charging: Bool?, skipBackup: Bool?
    }

    /// appStorage, firmwareInstall, firmwareCancelOffer, firmwareFile, firmwareDownloadProgress, firmwareDownloadFailed,
    /// firmwareClose. True when `json` was one of them.
    func handleFirmwareJSON(_ json: String) -> Bool {
        let names = ["appStorage", "firmwareInstall", "firmwareCancelOffer", "firmwareFile", "firmwareDownloadProgress", "firmwareDownloadFailed", "firmwareClose"]
        guard names.contains(where: { json.contains("\"\($0)\"") }),
              let w = try? JSONDecoder().decode(FirmwareWire.self, from: Data(json.utf8)), names.contains(w.intent) else { return false }
        switch w.intent {
        case "appStorage":
            // where the app keeps its files: the cached firmware and the backups go under it
            if let p = w.path, !p.isEmpty {
                appStorage = URL(fileURLWithPath: p, isDirectory: true)
                // a release file copied here by hand (adb) is used without a download, still only if it matches its
                // pin: for installing before Lupe's GitHub release of it exists
                if firmwareLocalReleases == nil { firmwareLocalReleases = appStorage?.appendingPathComponent("DebugFirmware", isDirectory: true) }
                log("storage: \(p)")
            }
        case "firmwareCancelOffer":
            fwDismissed = fwOffer
            pokeAreas(["firmware"])
        case "firmwareClose":
            guard !fwActive else { log("firmwareClose: an install is running"); return true }
            fwState = "idle"; fwProgress = 0; fwMessage = ""; fwBackup = nil; fwInUpdateMode = false
            pokeAreas(["firmware"])
        case "firmwareDownloadProgress":
            if fwState == "downloading", fwAwaitingFile, let p = w.progress { fwSet("downloading", 0.06 * max(0, min(1, p)), "Downloading \(fwTarget.title) from GitHub") }
        case "firmwareDownloadFailed":
            guard fwState == "downloading", fwAwaitingFile else { return true }
            fwAwaitingFile = false
            fwSet("failed", 0, "The download didn't finish (\(w.message ?? "no reason given")). Nothing was sent to the FM-1. Try again.")
        case "firmwareFile":
            guard fwState == "downloading", fwAwaitingFile, let p = w.path else { log("firmwareFile: no download is waited for"); return true }
            fwAwaitingFile = false
            do {
                try firmwareStore().adopt(fwTarget, file: URL(fileURLWithPath: p))
                try? FileManager.default.removeItem(atPath: p)
            } catch {
                fwSet("failed", 0, "\(error)")
                return true
            }
            let skip = fwSkipBackup
            Task { await self.runInstall(skipBackup: skip) }
        default:    // firmwareInstall
            startFirmware(which: w.which, confirmed: w.confirmed == true, battery: w.battery, charging: w.charging, skipBackup: w.skipBackup == true)
        }
        return true
    }

    func firmwareStore() -> FirmwareStore {
        let dir = (appStorage ?? FileManager.default.temporaryDirectory).appendingPathComponent("Firmware", isDirectory: true)
        return FirmwareStore(directory: dir, localReleases: firmwareLocalReleases)
    }

    private func startFirmware(which: String?, confirmed: Bool, battery: Int?, charging: Bool?, skipBackup: Bool) {
        guard !fwActive else { refuse("A firmware install is already running."); return }
        guard firmwareLink != nil else { refuse("This build can't install firmware."); return }
        guard let f = which.flatMap(LupeFirmware.init(rawValue:)) ?? Optional(Self.phoneFirmware) else { return }
        // (the phone carries no stock V15 file: the way back to stock is the iPad's, or M-VAVE's updater)
        guard !f.isStock else { refuse("Stock V15 can't be installed from the phone. Use Lupe on an iPad, or M-VAVE's own updater."); return }
        if let e = FirmwareInstaller.refusal(for: f, running: fwSeen) { refuse(e.message); return }
        // never while a change from the editor is still going in
        if session.skiffSong?.busy == true || !clearedPads.isEmpty && clearedPads.contains(where: { !$0.parked.isEmpty }) {
            refuse("A change is still going to the FM-1. Wait a few seconds, then install."); return
        }
        if session.playing { refuse("Stop playback before installing firmware."); return }
        // the phone powers the FM-1 while it writes (the iPad's rule: below 30 % only while charging)
        if let b = battery, b < 30, charging != true {
            refuse("Charge the phone first: it's at \(b)%. The phone powers the FM-1 while it writes, so Lupe installs below 30% only while charging."); return
        }
        guard confirmed else { log("firmwareInstall \(f.rawValue): the screen must confirm first"); return }
        fwTarget = f; fwSkipBackup = skipBackup; fwBackup = nil; fwInUpdateMode = false; fwOffer = nil
        fwDownloads = !firmwareStore().isReady(f)
        if fwDownloads {
            // the file first, from Lupe's release: the app fetches it and hands it in (firmwareFile)
            fwAwaitingFile = true
            fwSet("downloading", 0, "Downloading \(f.title) from GitHub")
            return
        }
        Task { await self.runInstall(skipBackup: skipBackup) }
    }

    /// The file is here and pinned: a backup through the connected Session, then the two update steps.
    func runInstall(skipBackup: Bool) async {
        guard let link = firmwareLink else { return }
        let d = fwDownloads ? 0.06 : 0.0
        func overall(_ rest: Double) -> Double { d + (1 - d) * rest }
        let pkg: FirmwarePackage
        do { pkg = try firmwareStore().package(fwTarget) } catch { fwSet("failed", 0, "\(error)"); return }
        if case .connected = session.status, !skipBackup {
            fwSet("backingUp", overall(0), "Backing up the FM-1")
            do {
                let b = try await session.firmwareBackup { done, total in
                    Task { @MainActor in
                        guard self.fwState == "backingUp" else { return }
                        self.fwProgress = overall(0.08 * (total > 0 ? Double(done) / Double(total) : 1))
                        self.pokeAreas(["firmware"])
                    }
                }
                let dir = (appStorage ?? FileManager.default.temporaryDirectory).appendingPathComponent("Backups", isDirectory: true)
                fwBackup = try b.save(in: dir).path
            } catch {
                fwSet("failed", 0, "The backup didn't finish: \(error) Nothing was installed. Try again, or install without a backup.")
                return
            }
        }
        fwSet("staging", overall(0.08), "Starting")
        link.hold(true)                                   // the Session lets go of the FM-1
        defer { link.hold(false) }
        try? await Task.sleep(for: link.delays.start < .milliseconds(600) ? link.delays.start : .milliseconds(600))
        let installer = FirmwareInstaller(ports: link.ports, delays: link.delays)
        fwInstaller = installer
        defer { fwInstaller = nil }
        do {
            let id = try await installer.install(pkg) { step in
                Task { @MainActor in
                    guard self.fwActive else { return }
                    switch step {
                    case .start: self.fwSet("staging", overall(0.08), "Starting")
                    case .check(let n): self.fwSet("staging", overall(0.08 + 0.04 * min(1, Double(n) / 20)), "Checking the firmware file")
                    case .loader: self.fwSet("staging", overall(0.12), "Switching the FM-1 to update mode")
                    case .write(let p): self.fwSet("writing", overall(0.14 + 0.80 * Double(p) / 100), "Writing the firmware")
                    case .dropped: self.fwSet("resuming", overall(0.14), "Waiting for the FM-1 to come back")
                    case .resume(let n): self.fwSet("resuming", overall(0.14), "Writing again (try \(n))")
                    case .reboot: self.fwSet("restarting", overall(0.96), "Restarting the FM-1")
                    case .done: break
                    }
                }
            }
            await Task.yield()
            fwSet("done", 1, "\(fwTarget.title) is installed. The FM-1 reports \(id).")
        } catch let e as InstallError {
            fwInUpdateMode = e.inUpdateMode
            fwSet("failed", fwProgress, e.message + (e.inUpdateMode ? " The FM-1 may be waiting in update mode: install again to finish it." : ""))
        } catch {
            fwSet("failed", fwProgress, "\(error)")
        }
    }

    /// Between requests; the FM-1 stays where it was (update mode, if the write had begun).
    func cancelFirmware() { fwInstaller?.cancel() }
}

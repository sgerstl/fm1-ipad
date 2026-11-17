import Foundation
import SloopKit

/// A project saved on the iPad: what the FM-1 held and a name. Skiff's project record and the patterns it plays
/// (`skiff`, SkiffProject.swift). (SLOOP's projects, before 2026-11-15, stay in Files › Lupe › SLOOP; Lupe no longer
/// reads them, decision 43.)
struct ProjectFile: Codable, Identifiable, Equatable {
    var format = "lupe-skiff-project"
    var version = 1
    var id = UUID()
    var name: String
    var saved = Date()
    /// A copy Lupe took by itself before opening something over it ("Before opening Night Drive").
    var isSafetyCopy = false
    /// The FM-1's fingerprint right after this project was saved or opened: how Lupe recognises it on
    /// the FM-1 later.
    var baseline: String
    var skiff: SkiffProjectData

    init(name: String, skiff: SkiffProjectData, baseline: String, isSafetyCopy: Bool = false) {
        self.name = name
        self.baseline = baseline
        self.isSafetyCopy = isSafetyCopy
        self.skiff = skiff
    }
}

/// The projects on the iPad, and which one the FM-1 holds. Opening one writes it to the FM-1 (stopped);
/// before anything goes over unsaved work, a safety copy is kept. Kept in Files › Lupe › Skiff › Projects.
@MainActor @Observable
final class ProjectStore {
    private(set) var projects: [ProjectFile] = []
    private(set) var safetyCopies: [ProjectFile] = []
    /// The project the FM-1 holds, when it is one of ours.
    private(set) var currentID: UUID?
    /// The FM-1's fingerprint when the current work was last saved or put there; nil: Lupe doesn't know
    /// what the FM-1 holds (it came from somewhere else).
    private(set) var baseline: String?
    private(set) var edited = false
    /// Opening, starting fresh, or saving: the label and how far along.
    private(set) var busy: (label: String, progress: Double?)?
    var message: String?

    static let keptSafetyCopies = 5
    @ObservationIgnored private var session: DeviceSession?
    @ObservationIgnored private let documents: URL
    @ObservationIgnored private var demo = false
    private var folder: URL { ProjectFirmware.skiff.projects(in: documents) }
    /// The FM-1's current project (kept apart for the demo).
    private var currentKey: String { "currentProject.skiff" + (demo ? ".demo" : "") }

    init(documents: URL = URL.documentsDirectory) {
        self.documents = documents
        ProjectFolders.migrate(documents: documents)
        load()
    }

    var current: ProjectFile? { projects.first { $0.id == currentID } }

    enum State: Equatable {
        case project(String)        // one of ours
        case untitled               // a fresh start (or a safety copy opened), not saved yet
        case unknown                // whatever the FM-1 held when it was plugged in
        case offline(String?)       // no FM-1: the last project's name, if any
    }

    var state: State {
        guard let s = session, case .connected = s.status else { return .offline(current?.name) }
        if let c = current { return .project(c.name) }
        return baseline == nil ? .unknown : .untitled
    }

    /// What Save would do without asking anything: there is a project to save into.
    var canSaveInPlace: Bool { current != nil }
    var needsSaving: Bool { edited || (baseline == nil && state == .unknown) }

    // MARK: The session

    /// A new session (the FM-1, or the demo): nothing is known of what it holds until it connects.
    func attach(_ s: DeviceSession) {
        session = s
        demo = s.isDemo
        currentID = UserDefaults.standard.string(forKey: currentKey).flatMap(UUID.init)
        baseline = nil
        edited = false
        s.onEdit = { [weak self] in self?.noteEdit() }
    }

    /// Connected: match what the FM-1 holds against the saved projects.
    func connected() { skiffConnected() }

    /// Skiff: reading the music stops the transport, so there's no quiet fingerprint. The music still carrying the name
    /// Lupe gave the current project on opening it (and on no slot) is taken as that project, perhaps edited; anything
    /// else is unknown, so opening over it asks first.
    private func skiffConnected() {
        Task {
            guard let s = session else { return }
            await s.refreshSkiffProjects()
            if let c = current, let p = s.skiffProjects, p.musicSlot == nil, !p.name.isEmpty,
               p.name == String(decoding: SKF4.skiffName(c.name), as: UTF8.self) {
                baseline = c.baseline
                edited = true
            } else if let p = s.skiffProjects, p.musicSlot != nil {
                // the music came from (or was saved to) one of the FM-1's slots: that slot is its home
                cameFromSlot(changed: p.changed)
            } else {
                setCurrent(nil)
                baseline = nil
                edited = false
            }
        }
    }

    /// Something may have changed: say so. (Skiff's music can't be read without stopping it, so there's no quiet
    /// check against the FM-1 afterwards.)
    func noteEdit() {
        if !edited { edited = true }
    }

    // MARK: Saving

    /// Saves into the current project (Save), or as a new one with this name (first save, Save as).
    func save(as name: String? = nil) async {
        guard session != nil, busy == nil else { return }
        busy = ("Saving…", nil)
        defer { busy = nil }
        do {
            let (taken, fp) = try await capture(name: Self.cleaned(name) ?? current?.name ?? nextName())
            if name == nil, var p = current {
                p.skiff = taken.skiff
                p.baseline = fp
                p.saved = Date()
                try write(p)
            } else {
                var p = taken
                p.name = Self.cleaned(name) ?? nextName()
                try write(p)
                setCurrent(p.id)
            }
            baseline = fp
            edited = false
            message = nil
        } catch {
            message = "Couldn't save: \(Self.describe(error))"
        }
    }

    /// What the FM-1 holds now, as a project, and its fingerprint.
    private func capture(name: String, safetyCopy: Bool = false) async throws -> (ProjectFile, String) {
        guard let s = session else { throw DeviceSession.ProjectError.notConnected }
        let k = try await s.readSkiffProject()
        return (ProjectFile(name: name, skiff: k, baseline: k.fingerprint, isSafetyCopy: safetyCopy), k.fingerprint)
    }

    /// "Project 4": the next number no project uses.
    func nextName() -> String {
        let used = Set(projects.map(\.name))
        var n = projects.count + 1
        while used.contains("Project \(n)") { n += 1 }
        return "Project \(n)"
    }

    // MARK: Opening

    /// Puts a project (or a fresh start, `nil`) on the FM-1. Stops it first; keeps a safety copy of
    /// unsaved work. The caller has already asked about saving.
    func open(_ p: ProjectFile?) async {
        guard let s = session, busy == nil else { return }
        let label = p.map { "Opening \($0.name)…" } ?? "Starting a new project…"
        busy = (label, 0)
        defer { busy = nil }
        do {
            if s.playing {
                s.setPlaying(false)
                for _ in 0..<40 where s.playing { try await Task.sleep(for: .milliseconds(50)) }
            }
            if needsSaving {
                let (copy, _) = try await capture(name: p.map { "Before opening \($0.name)" } ?? "Before a new project", safetyCopy: true)
                try keepSafetyCopy(copy)
            }
            let progress: @MainActor (Double) -> Void = { [weak self] v in
                if let b = self?.busy { self?.busy = (b.label, v) }
            }
            let target = p?.skiff ?? .blank(for: s.skiffFirmware)
            // the FM-1 shows the project's name; a safety copy or a fresh start goes on unnamed
            try await s.writeSkiffProject(target, name: p.flatMap { $0.isSafetyCopy ? nil : $0.name } ?? "", progress: progress)
            let fp = target.fingerprint
            if var opened = p, !opened.isSafetyCopy {
                opened.baseline = fp            // recognised by this from now on
                try write(opened)
                setCurrent(opened.id)
            } else {
                setCurrent(nil)
            }
            baseline = fp
            edited = false
            message = nil
        } catch SkiffProjectError.poolFull(let n, let f) {
            message = "Couldn't open it: \(SkiffProjectError.poolFull(needed: n, free: f)). Nothing on the FM-1 changed."
        } catch DeviceSession.ProjectError.playing, SkiffProjectError.playing {
            message = "The FM-1 is still playing. Stop it and try again."
        } catch {
            message = "Couldn't open it: \(Self.describe(error)). The music on the FM-1 is as it was; patterns it brought may be in the pool."
        }
    }

    // MARK: The FM-1's slots

    /// The music came from one of the FM-1's slots, or was just saved to one: that slot is its home now, not an iPad
    /// file. (The slot holds it, so opening over it needs no safety copy unless it changed.)
    func cameFromSlot(changed: Bool = false) {
        setCurrent(nil)
        baseline = Self.slotBaseline
        edited = changed
    }
    static let slotBaseline = "fm1-slot"

    /// Copies FM-1 slot k to a project on this device, then puts back what was playing. The FM-1 can only read a slot by
    /// loading it, so: what's playing is read first (and kept as a safety copy unless its slot still holds it as it is),
    /// the slot is loaded and read into a new file, then the music goes back (by reloading its slot when that holds it
    /// unchanged, else by writing what was read). Returns the new project's name, or nil when it didn't finish.
    @discardableResult
    func copySlot(_ k: Int, name: String) async -> String? {
        guard let s = session, busy == nil, let slots = s.skiffProjects else { return nil }
        let wasCurrent = current, wasBaseline = baseline, wasEdited = edited
        let fromSlot = slots.musicSlot
        // the slot it came from holds this music exactly: put it back by loading that slot again
        let cleanSlot = fromSlot != nil && !slots.changed && !edited && current == nil
        busy = ("Copying P\(k + 1)…", nil)
        defer { busy = nil }
        var kept = false
        do {
            if s.playing {
                s.setPlaying(false)
                for _ in 0..<40 where s.playing { try await Task.sleep(for: .milliseconds(50)) }
            }
            let file = Self.cleaned(name) ?? nextName()
            // it's the one playing, unchanged: read it as it is
            if fromSlot == k && cleanSlot {
                busy = ("Reading P\(k + 1)…", nil)
                var (copy, _) = try await capture(name: file)
                copy.baseline = ""
                try write(copy)
                message = nil
                return file
            }
            busy = ("Reading what's playing…", nil)
            let (before, _) = try await capture(name: "Before copying P\(k + 1)", safetyCopy: true)
            if !cleanSlot { try keepSafetyCopy(before); kept = true }
            busy = ("Loading P\(k + 1)…", nil)
            guard await s.loadSkiffProject(slot: k) else { throw CopyError.load }
            busy = ("Reading P\(k + 1)…", nil)
            var (copy, _) = try await capture(name: file)
            copy.baseline = ""                  // not on the FM-1 as the music: what was playing goes back
            try write(copy)
            busy = ("Putting back what was playing…", nil)
            if cleanSlot, let j = fromSlot {
                guard await s.loadSkiffProject(slot: j) else { throw CopyError.restore }
                cameFromSlot()
            } else {
                // named as it was, so an iPad project is still recognised as itself
                try await s.writeSkiffProject(before.skiff, name: wasCurrent?.name ?? slots.name)
                setCurrent(wasCurrent?.id)
                baseline = wasBaseline
                edited = wasEdited || fromSlot != nil     // off its slot now: only a save keeps it
            }
            message = nil
            return file
        } catch CopyError.restore {
            message = "P\(k + 1) is copied, but the slot that was playing didn't load again. Load it from the list."
            return Self.cleaned(name)
        } catch CopyError.load {
            message = "P\(k + 1) didn't load, so nothing was copied. The music on the FM-1 is as it was."
        } catch {
            let where_ = kept ? " What was playing is in Safety copies." : ""
            message = "Couldn't finish copying P\(k + 1): \(Self.describe(error)).\(where_)"
        }
        return nil
    }

    private enum CopyError: Error { case load, restore }

    // MARK: Managing

    func rename(_ p: ProjectFile, to name: String) {
        guard var q = (projects + safetyCopies).first(where: { $0.id == p.id }), let n = Self.cleaned(name) else { return }
        q.name = n
        q.isSafetyCopy = false                  // a named safety copy is a project now
        do { try write(q) } catch { message = "Couldn't rename it: \(error.localizedDescription)" }
    }

    func duplicate(_ p: ProjectFile) {
        var q = p
        q.id = UUID()
        q.name = "\(p.name) copy"
        q.saved = Date()
        q.isSafetyCopy = false
        q.baseline = ""                         // the original is the one the FM-1 matches
        try? write(q)
    }

    func delete(_ p: ProjectFile) {
        try? FileManager.default.removeItem(at: url(p))
        if p.id == currentID { setCurrent(nil); baseline = nil }
        load()
    }

    // MARK: Files

    private func url(_ p: ProjectFile) -> URL {
        (p.isSafetyCopy ? folder.appending(path: "Safety copies") : folder).appending(path: "\(p.id.uuidString).json")
    }

    private func write(_ p: ProjectFile) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder.appending(path: "Safety copies"), withIntermediateDirectories: true)
        // a safety copy renamed into a project moves folders
        for old in [folder, folder.appending(path: "Safety copies")].map({ $0.appending(path: "\(p.id.uuidString).json") })
        where old != url(p) { try? fm.removeItem(at: old) }
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        try e.encode(p).write(to: url(p), options: .atomic)
        load()
    }

    private func keepSafetyCopy(_ p: ProjectFile) throws {
        try write(p)
        for old in safetyCopies.dropFirst(Self.keptSafetyCopies) { try? FileManager.default.removeItem(at: url(old)) }
        load()
    }

    private func load() {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        func read(_ dir: URL) -> [ProjectFile] {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            return files.filter { $0.pathExtension == "json" }
                .compactMap { try? d.decode(ProjectFile.self, from: Data(contentsOf: $0)) }
                .filter { $0.format == "lupe-skiff-project" }      // (a SLOOP project put here by hand: not one Lupe reads)
                .sorted { $0.saved > $1.saved }
        }
        projects = read(folder).filter { !$0.isSafetyCopy }
        safetyCopies = read(folder.appending(path: "Safety copies")).filter(\.isSafetyCopy)
    }

    private func setCurrent(_ id: UUID?) {
        currentID = id
        UserDefaults.standard.set(id?.uuidString, forKey: currentKey)
    }

    private static func cleaned(_ name: String?) -> String? {
        let n = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? nil : String(n.prefix(40))
    }

    private static func describe(_ e: Error) -> String {
        switch e {
        case DeviceSession.ProjectError.notConnected: "the FM-1 isn't connected"
        case DeviceSession.ProjectError.playing: "the FM-1 is playing"
        case DeviceSession.ProjectError.unreadable(let why): why
        case let e as SkiffProjectError: e == .playing ? "the FM-1 is playing" : e.description
        case DeviceSession.ProjectError.refused(_, let rc): "the FM-1 refused it (code \(rc))"
        default: "the FM-1 didn't answer"
        }
    }
}

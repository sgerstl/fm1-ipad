import CoreTransferable
import Foundation
import SloopKit

/// A project saved on the iPad: what the FM-1 held (its loop, sections A–D, the song order) and a name.
/// The objects are stored as the web editor's backup stores them (id, length, CRC, base64 bytes).
struct ProjectFile: Codable, Identifiable, Equatable {
    var format = "jib-project"
    var version = 1
    var id = UUID()
    var name: String
    var saved = Date()
    /// A copy Jib took by itself before opening something over it ("Before opening Night Drive").
    var isSafetyCopy = false
    /// The FM-1's fingerprint right after this project was saved or opened: how Jib recognises it on
    /// the FM-1 later (the device keeps a few values of its own, so it can differ from the data's).
    var baseline: String
    var objects: [StoredObject]
    var songOrder: Data

    struct StoredObject: Codable, Equatable {
        var id: Int
        var len: Int
        var crc: UInt32
        var data: Data
    }

    init(name: String, data: ProjectData, baseline: String, isSafetyCopy: Bool = false) {
        self.name = name
        self.baseline = baseline
        self.isSafetyCopy = isSafetyCopy
        objects = []
        songOrder = Data()
        self.data = data
    }

    var data: ProjectData {
        get {
            func bytes(_ id: Int) -> [UInt8] { objects.first { $0.id == id }.map { Array($0.data) } ?? [] }
            return ProjectData(working: bytes(0), sections: (2...5).map(bytes), songOrder: Array(songOrder))
        }
        set {
            objects = ([(0, newValue.working)] + newValue.sections.enumerated().map { (2 + $0.offset, $0.element) })
                .map { StoredObject(id: $0.0, len: $0.1.count, crc: CRC32.of($0.1), data: Data($0.1)) }
            songOrder = Data(newValue.songOrder)
        }
    }
}

/// The projects on the iPad, and which one the FM-1 holds. Opening one writes it to the FM-1 (stopped);
/// before anything goes over unsaved work, a safety copy is kept.
@MainActor @Observable
final class ProjectStore {
    private(set) var projects: [ProjectFile] = []
    private(set) var safetyCopies: [ProjectFile] = []
    /// The project the FM-1 holds, when it is one of ours.
    private(set) var currentID: UUID?
    /// The FM-1's fingerprint when the current work was last saved or put there; nil: Jib doesn't know
    /// what the FM-1 holds (it came from somewhere else).
    private(set) var baseline: String?
    private(set) var edited = false
    /// Opening, starting fresh, or saving: the label and how far along.
    private(set) var busy: (label: String, progress: Double?)?
    var message: String?

    static let keptSafetyCopies = 5
    @ObservationIgnored private var session: DeviceSession?
    @ObservationIgnored private var verifyTask: Task<Void, Never>?
    @ObservationIgnored private var verifyWhenStopped = false
    @ObservationIgnored private let folder: URL
    @ObservationIgnored private var currentKey = "currentProject"

    init(folder: URL = URL.documentsDirectory.appending(path: "Projects")) {
        self.folder = folder
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
        currentKey = s.isDemo ? "currentProject.demo" : "currentProject"
        currentID = UserDefaults.standard.string(forKey: currentKey).flatMap(UUID.init)
        baseline = nil
        edited = false
        s.onEdit = { [weak self] in self?.noteEdit() }
    }

    /// Connected: match what the FM-1 holds against the saved projects.
    func connected() {
        Task {
            guard let s = session, let fp = try? await s.deviceFingerprint() else { return }
            if let c = current, c.baseline == fp {
                baseline = fp
            } else if let match = projects.first(where: { $0.baseline == fp }) {
                setCurrent(match.id)
                baseline = fp
            } else {
                setCurrent(nil)
                baseline = nil
            }
            edited = false
        }
    }

    /// Something may have changed: say so at once, then check against the FM-1 once things go quiet.
    func noteEdit() {
        if !edited { edited = true }
        verifyTask?.cancel()
        verifyTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            verify()
        }
    }

    /// The FM-1 stopped: a check that waited for the stop runs now.
    func playingChanged(_ playing: Bool) {
        if !playing, verifyWhenStopped { verify() }
    }

    /// Compares the FM-1 with the baseline. Only stopped: while playing, parameter locks move the
    /// values a snapshot holds, so a check would flicker.
    private func verify() {
        guard let s = session, busy == nil, let b = baseline else { return }
        guard !s.playing else { verifyWhenStopped = true; return }
        verifyWhenStopped = false
        Task {
            guard let fp = try? await s.deviceFingerprint() else { return }
            let e = fp != b
            if edited != e { edited = e }
        }
    }

    // MARK: Saving

    /// Saves into the current project (Save), or as a new one with this name (first save, Save as).
    func save(as name: String? = nil) async {
        guard let s = session, busy == nil else { return }
        busy = ("Saving…", nil)
        defer { busy = nil }
        do {
            let data = try await s.readProject()
            let fp = try await s.deviceFingerprint()
            if name == nil, var p = current {
                p.data = data
                p.baseline = fp
                p.saved = Date()
                try write(p)
            } else {
                let p = ProjectFile(name: Self.cleaned(name) ?? nextName(), data: data, baseline: fp)
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
        let target = p?.data ?? .blank
        let label = p.map { "Opening \($0.name)…" } ?? "Starting a new project…"
        busy = (label, 0)
        defer { busy = nil }
        do {
            if s.playing || s.song.songPlaying {
                s.setPlaying(false)
                for _ in 0..<40 where s.playing || s.song.songPlaying { try await Task.sleep(for: .milliseconds(50)) }
            }
            if needsSaving {
                let copy = try await s.readProject()
                let fp = try await s.deviceFingerprint()
                try keepSafetyCopy(ProjectFile(name: p.map { "Before opening \($0.name)" } ?? "Before a new project",
                                               data: copy, baseline: fp, isSafetyCopy: true))
            }
            try await s.writeProject(target) { [weak self] v in
                if let b = self?.busy { self?.busy = (b.label, v) }
            }
            let fp = try await s.deviceFingerprint()
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
        } catch DeviceSession.ProjectError.playing {
            message = "The FM-1 is still playing. Stop it and try again."
        } catch {
            message = "Couldn't open it: \(Self.describe(error)). The FM-1 may hold part of it."
        }
    }

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
        case DeviceSession.ProjectError.refused(let object, let rc):
            "the FM-1 didn't take \(object == 0 ? "the loop" : object == 1 ? "the song order" : "section \(DeviceSession.sectionName(object - 2))") (code \(rc))"
        default: "the FM-1 didn't answer"
        }
    }
}

/// A project as SLOOP's song file, for the share sheet: written when shared (AirDrop, Files, Mail), so
/// it opens in SLOOP's web editor (Song file › Load) as well as in Jib.
struct SloopSongExport: Transferable {
    let project: ProjectFile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { e in SentTransferredFile(try e.write()) }
    }

    private func write() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "Export")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = project.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = dir.appending(path: "\(name).\(SloopSong.fileExtension)")
        try SloopSong.encode(project.data, name: project.name).write(to: url, options: .atomic)
        return url
    }
}

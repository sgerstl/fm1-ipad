// Projects on the phone (Scott, 2026-11-17: "a clear way to save a project to the phone or to one of the FM-1's 4 slots").
// The files themselves are Kotlin's (android/app/.../core/PhoneProjectStore.kt): this side only moves a whole Skiff project
// in and out of the FM-1, through the same SloopKit calls the iPad's ProjectStore uses (ios/FM1/Projects.swift):
//   read      Session.readSkiffProject: the music with the patterns it plays (it stops the transport). A read: allowed
//             while read-only (BACKUP_LIST, BACKUP_GET).
//   write     Session.writeSkiffProject: a project onto the FM-1 as the music. Identical patterns are reused, the rest go
//             to free pool numbers and are renumbered; it throws poolFull rather than write over a pattern anything uses.
//   loadSlot  Session.loadSkiffProject, saveSlot Session.saveSkiffProject: the FM-1's own slots, for Copy to phone,
//             which needs to wait for each step (projectLoad / projectSave answer only through `notice`).
// Each request carries the screen's id; the answer goes out as a `transfer` event (progress, done or failed), never as a
// notice: the screen says what happened, once, in the app strip.
import Foundation
import SloopKit

/// One answer to a `projectTransfer` intent. An event, like `notice`: published as it happens, not watched.
public struct TransferArea: Codable, Equatable, Sendable {
    public var id: Int
    /// "progress", "done" or "failed".
    public var phase: String
    /// 0…1 while a write goes on.
    public var progress: Double?
    /// A read's result: Skiff's project record and its patterns, as the iPad's project files hold it.
    public var skiff: SkiffProjectData?
    /// The project's fingerprint (SkiffProjectData.fingerprint), for a read or a write.
    public var fingerprint: String?
    /// Why it failed: "poolFull", "playing", "notConnected", "readOnly", "busy", "empty", "refused", "noAnswer".
    public var error: String?
    /// SloopKit's words for it.
    public var text: String?
    /// poolFull: the numbers the project needs and the numbers free.
    public var needed: Int?
    public var free: Int?
}

extension PhoneCore {
    private struct TransferWire: Decodable {
        let intent: String
        let id: Int
        let op: String
        let skiff: SkiffProjectData?
        let name: String?
        let slot: Int?
        /// A write that puts back changed music (Copy to phone): it stays "changed" after.
        let edited: Bool?
    }

    /// `{"intent":"projectTransfer","id":3,"op":"read"}`: true when `json` was one.
    func handleProjectTransferJSON(_ json: String) -> Bool {
        guard json.contains("\"projectTransfer\"") else { return false }
        let w: TransferWire
        do { w = try JSONDecoder().decode(TransferWire.self, from: Data(json.utf8)) } catch {
            log("projectTransfer not understood: \(error)"); return true
        }
        guard w.intent == "projectTransfer" else { return false }
        let s = session
        func fail(_ error: String, _ text: String, needed: Int? = nil, free: Int? = nil) {
            log("projectTransfer \(w.op) #\(w.id) failed: \(error), \(text)")
            publishTransfer(TransferArea(id: w.id, phase: "failed", error: error, text: text, needed: needed, free: free))
        }
        guard s.isConnected else { fail("notConnected", "the FM-1 isn't connected"); return true }
        if w.op != "read" && !canWrite() { fail("readOnly", Self.readOnlyNotice); return true }
        guard !projectBusy else { fail("busy", "a project load or save is still going"); return true }
        projectBusy = true; pokeAreas(["projects"])
        let finish: @MainActor () -> Void = { [weak self] in self?.projectBusy = false; self?.pokeAreas(["projects", "top"]) }
        switch w.op {
        case "read":
            Task {
                do {
                    let k = try await s.readSkiffProject()
                    self.phoneEdited = false
                    finish()
                    self.publishTransfer(TransferArea(id: w.id, phase: "done", skiff: k, fingerprint: k.fingerprint))
                } catch { finish(); let f = Self.transferFailure(error); fail(f.0, f.1, needed: f.2, free: f.3) }
            }
        case "write":
            guard let p = w.skiff else { finish(); fail("refused", "the project file has no Skiff project in it"); return true }
            Task {
                do {
                    // the iPad stops it first and waits up to 2 s (ProjectStore.open): the write refuses a playing FM-1
                    if s.playing {
                        s.setPlaying(false)
                        for _ in 0..<40 where s.playing { try await Task.sleep(for: .milliseconds(50)) }
                    }
                    try await s.writeSkiffProject(p, name: w.name ?? "") { v in
                        self.publishTransfer(TransferArea(id: w.id, phase: "progress", progress: v))
                    }
                    self.phoneEdited = w.edited ?? false
                    finish()
                    self.publishTransfer(TransferArea(id: w.id, phase: "done", fingerprint: p.fingerprint))
                } catch { finish(); let f = Self.transferFailure(error); fail(f.0, f.1, needed: f.2, free: f.3) }
            }
        case "loadSlot":
            guard let slot = w.slot, s.skiffProjects?.slots[safe: slot]?.used == true else {
                finish(); fail("empty", "that project slot is empty"); return true
            }
            Task {
                let ok = await s.loadSkiffProject(slot: slot)
                finish()
                if ok { self.publishTransfer(TransferArea(id: w.id, phase: "done")) }
                else { fail("noAnswer", "the FM-1 didn't load project slot \(slot + 1)") }
            }
        case "saveSlot":
            guard let slot = w.slot, (0..<4).contains(slot) else { finish(); fail("refused", "there is no such project slot"); return true }
            let name = w.name ?? s.skiffProjects?.name ?? ""
            Task {
                let rc = await s.saveSkiffProject(slot: slot, name: name)
                finish()
                if rc == 0 { self.publishTransfer(TransferArea(id: w.id, phase: "done")) }
                else { fail("refused", "the FM-1 refused the save (code \(rc))") }
            }
        default:
            finish(); fail("refused", "no transfer called \(w.op)")
        }
        return true
    }

    func publishTransfer(_ t: TransferArea) { publishEvent("transfer", AreaJSON.encode(t)) }

    /// The error's kind, SloopKit's words, and for a full pool what it needs and what is free.
    static func transferFailure(_ e: Error) -> (String, String, Int?, Int?) {
        switch e {
        case SkiffProjectError.poolFull(let n, let f): ("poolFull", "\(e)", n, f)
        case SkiffProjectError.playing, DeviceSession.ProjectError.playing: ("playing", "the FM-1 is playing", nil, nil)
        case DeviceSession.ProjectError.notConnected: ("notConnected", "the FM-1 isn't connected", nil, nil)
        case DeviceSession.ProjectError.unreadable(let why): ("refused", why, nil, nil)
        case DeviceSession.ProjectError.refused(_, let rc): ("refused", "the FM-1 refused it (code \(rc))", nil, nil)
        case let k as SkiffProjectError: ("refused", k.description, nil, nil)
        default: ("noAnswer", "the FM-1 didn't answer", nil, nil)
        }
    }
}

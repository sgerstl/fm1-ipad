// P5's intents on the real FM-1, each through the call the iPad uses for the same thing: the Mix strips and cards
// (MixerPanel.swift: Session.set(track:param:), set(global:), showOnDevice), solo (SkiffSongStore.toggleSolo), the
// Sounds panel (Library.swift: loadPreset, loadUserPreset, an entry's sound through the song store's rewrite as
// ArrangeEdits.setSound; SkiffSaveViews: storeUserPreset) and the FM-1's project slots (load, save as, rename).
// Writes are refused while read-only; anything that loses something waits for the screen's confirm in place.
import Foundation
import SloopKit

extension PhoneCore {
    func handle(_ i: P5Intent) {
        if i.writes && !canWrite() {
            log("read-only: \(i) not sent (allow writes to send it)")
            return
        }
        let s = session
        switch i {
        // MARK: mix
        case .mixSection(let key):
            guard Self.mixSectionKeys.contains(key) else { log("no Mix section \(key)"); return }
            mixSection = key
            // linked, the FM-1 shows the same GLO page (the iPad's Mix does); that part is a write
            if s.screenLinked, canWrite(), let k = Self.mixSectionKeys.firstIndex(of: key) {
                s.showOnDevice(page: SkiffButtonMap.MixerTab.allCases[k].page)
            }
            pokeAreas(["mix"])
        case .setLevel(let t1, let v):
            guard let t = track(t1) else { return }
            s.set(track: t, param: Param.level, to: v)
        case .setPan(let t1, let v):
            guard let t = track(t1) else { return }
            s.set(track: t, param: Param.pan, to: v)
        case .setReverb(let t1, let v):
            guard let t = track(t1), let id = reverbSendID else { return }
            s.set(track: t, param: id, to: v)
        case .trackSolo(let t1):
            guard let t = track(t1), let store = s.skiffSong else { return }
            Task { if !(await store.toggleSolo(t)) { reportRefusal(store) } }
        case .setMixParam(let slot, let v):
            guard let p = mixPage(mixSection), let id = p.ids[safe: slot] ?? nil, p.scope(of: slot) == 1 else {
                log("no knob \(slot + 1) on the \(mixSection) card"); return
            }
            s.set(global: id, to: v)
        case .setMixSetting(let k, let v):
            guard let p = mixPage(mixSection), let id = p.settings[safe: k] else { log("no setting \(k) on the \(mixSection) card"); return }
            s.set(global: id, to: v)

        // MARK: sounds
        case .soundsTarget(let t1, let entry):
            guard let t = track(t1) else { return }
            soundsTrack = t; soundsEntry = entry; soundsViewing = nil
            // a track's sound loads onto the selected track (PRESET, UP_LOAD): the target is selected first, so a
            // pick can never land on the track that was selected before (a write)
            if entry == nil, t != s.selectedTrack, canWrite() { s.select(track: t) }
            pokeAreas(["sounds"])
        case .soundsView(let e):
            soundsViewing = e
            pokeAreas(["sounds"])
        case .pickPreset(let e, let p):
            if let entry = soundsEntry { setEntrySound(entry, SloopKit.EntrySound(s0: e + 1, s1: p)); return }
            guard selectSoundsTrack() else { return }
            s.loadPreset(engine: e, index: p)
        case .pickUser(let slot):
            if let entry = soundsEntry { setEntrySound(entry, SloopKit.EntrySound(s0: 64 + slot, s1: 0)); return }
            guard let p = s.userPresets.first(where: { $0.slot == slot }) else { log("user slot \(slot + 1) is empty"); return }
            guard selectSoundsTrack() else { return }
            s.loadUserPreset(p)
        case .clearEntrySound:
            guard let entry = soundsEntry else { log("clearEntrySound: the browser is on a track, not a pad"); return }
            setEntrySound(entry, nil)
        case .saveSound(let slot, let name, let confirmed):
            guard (0..<32).contains(slot) else { return }
            if let old = s.userPresets.first(where: { $0.slot == slot }), !confirmed {
                log("user slot \(slot + 1) holds \(old.name): the screen must confirm before replacing it"); return
            }
            guard selectSoundsTrack() else { return }
            Task { let rc = await s.storeUserPreset(slot: slot, name: name); if rc != 0 { log("FM-1 refused SAVE into slot \(slot + 1) (rc \(rc))") } }
        case .eraseUser(let slot, let confirmed):
            guard confirmed else { log("erasing user slot \(slot + 1) needs the screen's confirm"); return }
            Task { let rc = await s.eraseUserPreset(slot: slot); if rc != 0 { log("FM-1 refused erasing slot \(slot + 1) (rc \(rc))") } }

        // MARK: projects (the FM-1's four slots)
        case .projectLoad(let slot, let confirmed):
            guard s.skiffProjects?.slots[safe: slot]?.used == true else { log("project slot \(slot + 1) is empty"); return }
            if s.skiffProjects?.changed == true, !confirmed {
                log("the music has unsaved changes: loading slot \(slot + 1) loses them, so the screen must confirm"); return
            }
            projectOp { if !(await s.loadSkiffProject(slot: slot)) { self.log("FM-1 didn't load slot \(slot + 1)") } }
        case .projectSave(let confirmed):
            guard let slot = s.skiffProjects?.musicSlot else { log("the music has no slot yet: use Save as"); return }
            guard confirmed else { log("saving replaces what slot \(slot + 1) held: the screen must confirm"); return }
            let name = s.skiffProjects?.name ?? ""
            projectOp { let rc = await s.saveSkiffProject(slot: slot, name: name); if rc != 0 { self.log("FM-1 refused the save (rc \(rc))") } }
        case .projectSaveAs(let slot, let name, let confirmed):
            guard (0..<4).contains(slot) else { return }
            if let old = s.skiffProjects?.slots[safe: slot], old.used, !confirmed {
                log("slot \(slot + 1) holds \(old.name): the screen must confirm before saving over it"); return
            }
            projectOp { let rc = await s.saveSkiffProject(slot: slot, name: name); if rc != 0 { self.log("FM-1 refused Save as (rc \(rc))") } }
        case .projectRename(let slot, let name):
            projectOp { let rc = await s.renameSkiffProject(slot: slot, name: name); if rc != 0 { self.log("FM-1 refused the rename (rc \(rc): an empty slot?)") } }
        }
    }

    /// 1-based track → index, or nil (logged).
    func track(_ t1: Int) -> Int? {
        let t = t1 - 1
        guard session.trackIndices.contains(t) else { log("no track \(t1)"); return nil }
        return t
    }

    /// The browser's track as the selected one before a load (they agree unless the FM-1 selected another since).
    func selectSoundsTrack() -> Bool {
        let t = soundsTrack ?? session.selectedTrack
        if t != session.selectedTrack {
            log("the FM-1 selected track \(session.selectedTrack + 1) since: pick track \(t + 1) in the browser again"); return false
        }
        return true
    }

    /// A pad's own sound (decision 15), as ArrangeEdits.setSound: on the first entry of its block, through the song
    /// store's rewrite.
    func setEntrySound(_ e: Int, _ snd: SloopKit.EntrySound?) {
        let t = soundsTrack ?? session.selectedTrack
        guard let store = session.skiffSong, var es = store.song?.tracks[safe: t]?.entries,
              let b = store.blocks(t).first(where: { $0.entries.contains(e) }) else { log("no pad at T\(t + 1) \(e)"); return }
        es[b.entries.lowerBound].sound = snd
        Task { if !(await store.rewrite(track: t, to: es, focus: b.entries.lowerBound)) { reportRefusal(store) } }
    }

    /// One project op at a time, `busy` shown meanwhile.
    func projectOp(_ op: @escaping @MainActor () async -> Void) {
        guard !projectBusy else { log("a project load or save is still going"); return }
        projectBusy = true; pokeAreas(["projects"])
        Task { await op(); self.projectBusy = false; self.pokeAreas(["projects", "top"]) }
    }
}

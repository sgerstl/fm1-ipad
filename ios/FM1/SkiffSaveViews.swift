import SloopKit
import SwiftUI

// Skiff's SAVE pages in Lupe (Scott, 2026-11-06, "as proposed"): PRESETS and USER on the Sounds tab, PATTERNS in the
// Song tab's drawer, PROJECT in the Projects sheet. This file: the FM-1's 4 project slots in that sheet, and saving the
// track's sound to a user slot (the sound panel's Save sound, the Sounds tab's USER slots). Every write is to the
// FM-1's flash: a confirm scaled to what it loses, and nothing replaced without saying so.

// MARK: - Saving a sound to a user slot

/// A sound waiting on its name: the selected track's sound into user slot 0…31; `replacing` the name it overwrites.
struct SaveSoundRequest: Identifiable, Equatable {
    let id = UUID()
    let slot: Int
    var replacing: String?
}

enum SaveSound {
    /// The menu behind Save sound: the next empty slot, or a used one replaced (a submenu, its names).
    @MainActor static func menu(session: DeviceSession, ui: EditorUI, at: CGPoint) -> AppMenu {
        AppMenu(title: "Save T\(session.selectedTrack + 1)'s sound", groups: {
            let used = Dictionary(session.userPresets.map { ($0.slot, $0.name) }, uniquingKeysWith: { a, _ in a })
            let free = (0..<32).first { used[$0] == nil }
            var first: [MenuItem] = []
            if let free {
                first.append(MenuItem(title: "Save to \(slotName(free))…", icon: "square.and.arrow.down") {
                    ui.saveSound = SaveSoundRequest(slot: free)
                })
            } else {
                first.append(.note("All 32 user slots hold a sound. Replace one, or erase one on the Sounds tab."))
            }
            var g = [first]
            if !used.isEmpty {
                g.append([MenuItem.submenu(title: "Replace a saved sound", icon: "arrow.triangle.2.circlepath", children: {
                    [used.keys.sorted().map { k in
                        MenuItem(title: "\(slotName(k)) · \(used[k]!.capitalized)") { ui.saveSound = SaveSoundRequest(slot: k, replacing: used[k]) }
                    }]
                })])
            }
            return g
        }, at: at, fromKey: true)
    }

    static func slotName(_ k: Int) -> String { String(format: "U%02d", k + 1) }
}

/// The name prompt for a sound saved to a user slot, over the whole app (from the panel or the Sounds tab). A slot
/// that holds a sound says it's replaced; a refusal says so after.
struct SaveSoundPrompt: ViewModifier {
    let session: DeviceSession
    let ui: EditorUI

    func body(content: Content) -> some View {
        // asked: Lupe's name card at the finger (2026-11-10: no system alert); a refusal shows in the card
        content.onChange(of: ui.saveSound?.id) {
            guard let r = ui.saveSound else { return }
            ui.saveSound = nil
            let current = session.tracks[safe: session.selectedTrack]?.presetName ?? ""
            let slot = SaveSound.slotName(r.slot)
            ui.textPrompt = TextPrompt(
                title: r.replacing == nil ? "Save to \(slot)" : "Replace \(slot)?",
                message: r.replacing.map { "\(slot) holds “\($0.capitalized)”. Saving replaces it on the FM-1; it can't be undone." }
                    ?? "T\(session.selectedTrack + 1)'s sound goes to \(slot) on the FM-1. Up to 12 letters.",
                // the track's sound's own name, the one going in (not the one it replaces)
                text: String((current.isEmpty ? "Sound \(r.slot + 1)" : current).uppercased().prefix(12)),
                confirm: r.replacing == nil ? "Save sound" : "Replace \(slot)", destructive: r.replacing != nil,
                uppercase: true, maxLength: 12) { name in
                    let rc = await session.storeUserPreset(slot: r.slot, name: name)
                    return rc == 0 ? nil : "The FM-1 didn't save it to \(slot). Stop the transport and try again."
                }
        }
    }
}

struct SaveSoundKey: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var frame: CGRect = .zero

    var body: some View {
        Button { ui.menu = SaveSound.menu(session: session, ui: ui, at: CGPoint(x: frame.maxX - MenuPanel.width, y: frame.maxY)) } label: {
            Label("Save sound", systemImage: "square.and.arrow.down").labelStyle(.iconOnly)
                .font(.lupe(15, .semibold)).foregroundStyle(Theme.text)
                .frame(width: 44, height: 44).raisedKey(8).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(session.selectedIsDrums || !session.capabilities.contains(.userPresets))
        .globalFrame($frame)
        .accessibilityHint("Saves this track's sound to a user slot on the FM-1")
    }
}

// MARK: - PROJECT: what's playing and the FM-1's 4 slots, in the Projects sheet

/// "iPad" or "iPhone": where Lupe keeps its own project files (Files › Lupe › Skiff › Projects).
enum ThisDevice {
    static var name: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }
    static var icon: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }
}

/// The top of the Projects sheet on Skiff (Scott, 2026-11-17, "a more clear way to save things to the iPad vs to the 4
/// slots"): Playing now (its name, where it lives, Save back there, Save to… this device or a slot, New project), then
/// the FM-1's slots (Load; ⋯ Save the playing music here, Copy to this device) over a line saying how full the pattern
/// pool is and how much of it only the slots hold. The FM-1 gives one use count per pattern, not which slot uses it,
/// so the line can't say per slot.
struct SkiffProjectSlots: View {
    let session: DeviceSession
    let store: ProjectStore
    /// The sheet's own layers: confirms at the finger, name cards (2026-11-10: no system alerts).
    @Binding var menu: AppMenu?
    @Binding var prompt: TextPrompt?
    /// Save to this device (asks a name) and New project (asks about saving first): the sheet's own.
    let saveHere: () -> Void
    let newProject: () -> Void
    @State private var busy: String?
    @State private var message: String?
    @State private var done: String?
    @State private var saveToFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduce

    private enum Home { case file(ProjectFile), slot(Int), none }

    /// Where the music lives: an iPad file Lupe put there or saved it to, else the slot the FM-1 says it came from.
    private var home: Home {
        if let c = store.current { return .file(c) }
        if let k = session.skiffProjects?.musicSlot { return .slot(k) }
        return .none
    }
    private var changed: Bool {
        switch home {
        case .file: store.edited
        case .slot: (session.skiffProjects?.changed ?? false) || store.edited
        case .none: true
        }
    }
    private var idle: Bool { busy == nil && store.busy == nil }

    var body: some View {
        Section {
            if session.isConnected { playingRow }
            Button { newProject() } label: { Label("New project", systemImage: "plus") }
                .disabled(!session.isConnected || !idle)
                .accessibilityHint("Clears the music: each track's power-on sound, no patterns. The pattern pool keeps its patterns")
        } header: {
            Text("Playing now")
        } footer: {
            if !session.isConnected { Text("Plug in the FM-1 to open or save a project. You can still rename and delete the ones on this \(ThisDevice.name).") }
        }
        Section {
            if let busy { HStack(spacing: 12) { ProgressView(); Text(busy) }.accessibilityElement(children: .combine) }
            if let message {
                MessageRow(kind: .refusal, text: message, dismiss: { self.message = nil })
                    .transition(MessageMotion.transition(reduce)).listRowBackground(Color.clear)
            }
            if let done {
                MessageRow(kind: .confirmation, text: done, dismiss: { self.done = nil })
                    .transition(MessageMotion.transition(reduce)).listRowBackground(Color.clear)
            }
            if let p = session.skiffProjects {
                ForEach(0..<p.slots.count, id: \.self) { k in row(k, p) }
            } else if session.isConnected {
                HStack(spacing: 12) { ProgressView(); Text("Reading the FM-1's projects…").foregroundStyle(Theme.textSecondary) }
            }
        } header: {
            Text("On the FM-1")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let poolLine { Text(poolLine).foregroundStyle(Theme.text) }
                Text("Skiff keeps 4 projects on the FM-1. A slot keeps the arrangement but shares its patterns with what's playing, so editing a pattern changes every slot that uses it. A project on this \(ThisDevice.name) keeps its own copy. Loading stops the FM-1; saving over a slot backs the FM-1 up to Files first.")
            }
        }
        .animation(MessageMotion.animation(reduce, coming: done != nil), value: done)
        .animation(MessageMotion.animation(reduce, coming: message != nil), value: message)
        .onChange(of: message) { if let message { MessageMotion.announce(message) } }
        .task(id: done) {
            guard done != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            done = nil
        }
    }

    // MARK: Playing now

    private var playingName: String {
        switch home {
        case .file(let c): return c.name
        case .slot(let k): return slotName(k)
        case .none:
            let n = session.skiffProjects?.name ?? ""
            return n.isEmpty ? "Untitled" : n.capitalized
        }
    }

    private var whereLine: String {
        switch home {
        case .file: return "Saved on this \(ThisDevice.name)" + (changed ? " · changed since" : "")
        case .slot(let k): return "From the FM-1's P\(k + 1)" + (changed ? " · changed since" : "")
        case .none: return store.state == .unknown ? "Was on the FM-1 when it was plugged in · not saved by Lupe" : "Not saved yet"
        }
    }

    private var playingRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(playingName).font(.lupe(17, .semibold)).foregroundStyle(Theme.text)
                Text(whereLine).font(.lupe(13)).foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 12)
            if case .none = home {} else {
                Button("Save") { saveHome() }
                    .buttonStyle(.bordered).disabled(!idle || !changed)
                    .accessibilityHint(saveHint)
            }
            Button("Save to…") { openSaveTo() }
                .buttonStyle(.bordered).disabled(!idle)
                .globalFrame($saveToFrame)
                .accessibilityHint("This \(ThisDevice.name), or one of the FM-1's four slots")
        }
        .frame(minHeight: 52)
    }

    private var saveHint: String {
        switch home {
        case .file(let c): "Saves the changes into “\(c.name)” on this \(ThisDevice.name)"
        case .slot(let k): "Saves the music back into the FM-1's P\(k + 1)"
        case .none: ""
        }
    }

    /// Save: back to where it lives.
    private func saveHome() {
        switch home {
        case .file: Task { await store.save() }
        case .slot(let k): askSave(k, String(slotName(k).uppercased().prefix(12)))
        case .none: break
        }
    }

    /// Save to…: this device (no limit, the patterns go with it), or a slot (replacing one says so).
    private func openSaveTo() {
        let start = String((playingName == "Untitled" ? "" : playingName).uppercased().prefix(12))
        let slots = session.skiffProjects?.slots ?? []
        menu = AppMenu(title: "Save to", groups: {
            var here = MenuItem(title: "This \(ThisDevice.name)…", icon: ThisDevice.icon) { saveHere() }
            here.sub = "No limit. The patterns go with it"
            let fm1 = slots.indices.map { k in
                var m = MenuItem(title: "FM-1 P\(k + 1) · " + (slots[k].used ? slots[k].name.capitalized : "Empty"), icon: "square.and.arrow.down") {
                    askSave(k, slots[k].used ? String(slots[k].name.prefix(12)) : (start.isEmpty ? "PROJECT \(k + 1)" : start))
                }
                if slots[k].used { m.sub = "Replaces it, after a backup" }
                return m
            }
            return [[here], fm1]
        }, at: CGPoint(x: saveToFrame.maxX - MenuPanel.width, y: saveToFrame.maxY), fromKey: true)
    }

    // MARK: The slots

    private func used(_ k: Int) -> Bool { session.skiffProjects?.slots[safe: k]?.used ?? false }
    private func slotName(_ k: Int) -> String { (session.skiffProjects?.slots[safe: k]?.name ?? "").capitalized }

    private func row(_ k: Int, _ p: SkiffProjects) -> some View {
        let s = p.slots[k]
        let here: Bool = if case .slot(let j) = home { j == k } else { false }
        return HStack(spacing: 12) {
            Text("P\(k + 1)").font(.lupe(13, .semibold)).foregroundStyle(Theme.textSecondary).frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.used ? s.name.capitalized : "Empty").font(.lupe(17, s.used ? .semibold : .regular))
                    .foregroundStyle(s.used ? Theme.text : Theme.textSecondary)
                if here { Text(changed ? "Playing now · changed since" : "Playing now").font(.lupe(13)).foregroundStyle(Theme.textSecondary) }
            }
            Spacer(minLength: 12)
            if s.used && !(here && !changed) {         // (the slot playing, unchanged: nothing to load)
                Button("Load") { askLoad(k) }.buttonStyle(.bordered).disabled(!idle || !session.isConnected)
            }
            RowMenuKey(name: "P\(k + 1)", hint: s.used ? "Save the playing music here, or copy it to this \(ThisDevice.name)" : "Save the playing music here",
                       disabled: !idle || !session.isConnected) { at in slotMenu(k, at) }
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("P\(k + 1), \(s.used ? s.name.capitalized : "empty")\(here ? (changed ? ", playing now, changed" : ", playing now") : "")")
    }

    private func slotMenu(_ k: Int, _ at: CGPoint) {
        let start = String((playingName == "Untitled" ? "PROJECT \(k + 1)" : playingName).uppercased().prefix(12))
        menu = AppMenu(title: "P\(k + 1)" + (used(k) ? " · \(slotName(k))" : ""), groups: {
            var save = MenuItem(title: used(k) ? "Save the playing music here…" : "Save the playing music here…", icon: "square.and.arrow.down") {
                askSave(k, start)
            }
            if used(k) { save.sub = "Replaces \(slotName(k)), after a backup" }
            var g = [[save]]
            if used(k) {
                var copy = MenuItem(title: "Copy to this \(ThisDevice.name)", icon: ThisDevice.icon) { askCopy(k) }
                copy.sub = "Keeps P\(k + 1) on the FM-1 too"
                g.append([copy])
            }
            return g
        }, at: at, fromKey: true)
    }

    /// Copy a slot here: the FM-1 can only read a slot by loading it, so say that, then put back what was playing.
    private func askCopy(_ k: Int) {
        let name = freeName(slotName(k).isEmpty ? "P\(k + 1)" : slotName(k))
        menu = AppMenu(title: "Copy P\(k + 1)", groups: {
            [[MenuItem(title: "Copy P\(k + 1) to this \(ThisDevice.name)", icon: ThisDevice.icon) { copy(k, name) }, MenuItem(title: "Cancel", icon: "xmark") {}]]
        }, at: TouchPoint.last, fan: true,
           caption: "The FM-1 loads P\(k + 1) to read it, then puts back what's playing. It stops the transport. The copy is called “\(name)”.")
    }

    private func copy(_ k: Int, _ name: String) {
        Task {
            message = nil; done = nil
            if let n = await store.copySlot(k, name: name) {
                done = "P\(k + 1) is on this \(ThisDevice.name) as “\(n)”"
                MessageMotion.announce(done!)
            }
        }
    }

    /// "Dub", or "Dub 2" when this device already has a Dub.
    private func freeName(_ base: String) -> String {
        let taken = Set((store.projects + store.safetyCopies).map(\.name))
        var n = base, i = 2
        while taken.contains(n) { n = "\(base) \(i)"; i += 1 }
        return n
    }

    /// Load: replaces the FM-1's music and stops it. Changes no slot or file holds go for good, so then it asks in red.
    private func askLoad(_ k: Int) {
        let what = "Load P\(k + 1) “\(slotName(k))”"
        if store.needsSaving || session.skiffProjects?.changed == true {
            menu = AppMenu.confirm("Load P\(k + 1)", confirm: what, caption: "The music on the FM-1 has changes nothing holds. Loading replaces them for good and stops the transport. Save them first with Save to….",
                                   icon: "arrow.down.doc") { load(k) }
        } else {
            menu = AppMenu(title: "Load P\(k + 1)", groups: { [[MenuItem(title: what, icon: "arrow.down.doc") { load(k) }, MenuItem(title: "Cancel", icon: "xmark") {}]] },
                           at: TouchPoint.last, fan: true, caption: "It replaces the music on the FM-1 (it's saved already) and stops the transport.")
        }
    }

    /// Save to a slot: its name asked in place; over a used slot, the whole FM-1 is backed up to Files first.
    private func askSave(_ k: Int, _ start: String) {
        let over = used(k)
        prompt = TextPrompt(title: over ? "Replace P\(k + 1)?" : "Save to P\(k + 1)",
                            message: over ? "P\(k + 1) holds “\(slotName(k))”. A backup of the whole FM-1 goes to Files first, then the music replaces it."
                                          : "The music on the FM-1 goes to P\(k + 1). It stops the transport. Up to 12 letters.",
                            text: start, confirm: over ? "Back up and replace" : "Save project", destructive: over, uppercase: true, maxLength: 12) { n in
            save(k, n); return nil
        }
    }

    private func load(_ k: Int) {
        Task {
            busy = "Loading P\(k + 1)…"; message = nil
            defer { busy = nil }
            if await session.loadSkiffProject(slot: k) { store.cameFromSlot() }
            else { message = "P\(k + 1) didn't load. Try again with the FM-1 stopped." }
        }
    }

    private func save(_ k: Int, _ n: String) {
        Task {
            message = nil
            defer { busy = nil }
            if used(k) {
                busy = "Backing up the FM-1…"
                do { _ = try await session.backUpDevice() } catch {
                    message = "The backup didn't finish, so P\(k + 1) was left as it is."
                    return
                }
            }
            busy = "Saving to P\(k + 1)…"
            if await session.saveSkiffProject(slot: k, name: n) != 0 { message = "The FM-1 didn't save to P\(k + 1). Try again." }
            else { store.cameFromSlot(); done = "Saved to P\(k + 1)"; MessageMotion.announce(done!) }
        }
    }

    // MARK: The pool

    /// "41 of 64 pattern numbers taken · 3 unused · 12 kept only by FM-1 slots". A pattern's use count covers what's
    /// playing and the saved slots; one that's used but not by what's playing is held only by slots.
    private var poolLine: String? {
        guard let st = session.skiffSong, let pool = st.pool?.patterns, !pool.isEmpty else { return nil }
        let kept = pool.indices.filter { pool[$0].length > 0 }
        var parts = ["\(kept.count) of \(pool.count) pattern numbers taken"]
        let unused = kept.filter { pool[$0].uses == 0 }.count
        if unused > 0 { parts.append("\(unused) unused") }
        if let song = st.song {
            let slotsOnly = kept.filter { p in
                pool[p].uses > 0 && !song.tracks.contains { l in
                    l.patternOn == p || l.entries.contains { $0.poolIndex == p }
                }
            }.count
            if slotsOnly > 0 { parts.append("\(slotsOnly) kept only by FM-1 slots") }
        }
        return parts.joined(separator: " · ")
    }
}

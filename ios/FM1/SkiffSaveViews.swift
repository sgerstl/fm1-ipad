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

// MARK: - PROJECT: the FM-1's 4 slots, in the Projects sheet

/// Skiff's project slots: load one (it replaces the music and stops), or save the music to one (a used slot is backed up
/// to Files first). Stopped as Skiff wants it: the FM-1 stops itself for both.
struct SkiffProjectSlots: View {
    let session: DeviceSession
    /// The sheet's own layers: Load's confirm at the finger, Save's name card (2026-11-10: no system alerts).
    @Binding var menu: AppMenu?
    @Binding var prompt: TextPrompt?
    @State private var busy: String?
    @State private var message: String?

    var body: some View {
        Section {
            if let busy { HStack(spacing: 12) { ProgressView(); Text(busy) }.accessibilityElement(children: .combine) }
            if let message { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.text) }
            if let p = session.skiffProjects {
                ForEach(0..<p.slots.count, id: \.self) { k in row(k, p) }
            } else {
                HStack(spacing: 12) { ProgressView(); Text("Reading the FM-1's projects…").foregroundStyle(Theme.textSecondary) }
            }
        } header: {
            Text("On the FM-1")
        } footer: {
            Text("Skiff keeps 4 projects on the FM-1. Loading one stops it; saving over one backs the FM-1 up to Files first.")
        }
        .task { await session.refreshSkiffProjects() }
    }

    private func used(_ k: Int) -> Bool { session.skiffProjects?.slots[safe: k]?.used ?? false }
    private func slotName(_ k: Int) -> String { (session.skiffProjects?.slots[safe: k]?.name ?? "").capitalized }

    private func row(_ k: Int, _ p: SkiffProjects) -> some View {
        let s = p.slots[k]
        let here = p.musicSlot == k
        return HStack(spacing: 12) {
            Text("P\(k + 1)").font(.lupe(13, .semibold)).foregroundStyle(Theme.textSecondary).frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.used ? s.name.capitalized : "Empty").font(.lupe(17, s.used ? .semibold : .regular))
                    .foregroundStyle(s.used ? Theme.text : Theme.textSecondary)
                if here { Text(p.changed ? "Playing now · changed since" : "Playing now").font(.lupe(13)).foregroundStyle(Theme.textSecondary) }
            }
            Spacer(minLength: 12)
            if s.used {
                Button("Load") { askLoad(k) }.buttonStyle(.bordered).disabled(busy != nil)
            }
            Button(s.used ? "Save over…" : "Save here…") {
                askSave(k, String((here || !s.used ? (p.name.isEmpty ? "PROJECT \(k + 1)" : p.name) : s.name).prefix(12)))
            }
            .buttonStyle(.bordered).disabled(busy != nil)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("P\(k + 1), \(s.used ? s.name.capitalized : "empty")\(here ? (p.changed ? ", playing now, changed" : ", playing now") : "")")
    }

    /// Load: replaces the FM-1's music and stops it. Changes no slot holds go for good, so then it asks in red.
    private func askLoad(_ k: Int) {
        let what = "Load P\(k + 1) “\(slotName(k))”"
        if session.skiffProjects?.changed == true {
            menu = AppMenu.confirm("Load P\(k + 1)", confirm: what, caption: "The music on the FM-1 has changes no slot holds. Loading replaces them for good and stops the transport.",
                                   icon: "arrow.down.doc") { load(k) }
        } else {
            menu = AppMenu(title: "Load P\(k + 1)", groups: { [[MenuItem(title: what, icon: "arrow.down.doc") { load(k) }, MenuItem(title: "Cancel", icon: "xmark") {}]] },
                           at: TouchPoint.last, fan: true, caption: "It replaces the music on the FM-1 (a slot holds what's there) and stops the transport.")
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
            if !(await session.loadSkiffProject(slot: k)) { message = "P\(k + 1) didn't load. Try again with the FM-1 stopped." }
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
        }
    }
}

import SloopKit
import SwiftUI

/// The projects on the iPad: open one onto the FM-1, start fresh, save, rename, duplicate, delete.
struct ProjectsSheet: View {
    let store: ProjectStore
    let session: DeviceSession
    @Environment(\.dismiss) private var dismiss
    @State private var opening: Opening?
    @State private var naming: NamePrompt?
    @State private var deleting: ProjectFile?
    @State private var tab: Tab = .projects
    /// A row's menu, Jib's own (the sheet covers the app's root, so it has its own layer).
    @State private var menu: JibMenu?

    enum Tab { case projects, safety }

    /// What tapping a row (or New project) asked for, waiting on the save / stop question.
    struct Opening: Identifiable {
        let id = UUID()
        let target: ProjectFile?            // nil: a fresh start
        var name: String { target?.name ?? "a new project" }
    }

    private var connected: Bool { if case .connected = session.status { true } else { false } }

    var body: some View {
        NavigationStack {
            List {
                // what's going on (and what went wrong) shows on either tab
                if store.busy != nil || store.message != nil {
                    Section {
                        if let b = store.busy { busyRow(b) }
                        if let m = store.message {
                            Label(m, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.text)
                        }
                    }
                }
                switch tab {
                case .projects:
                    Section {
                        Button { request(nil) } label: { Label("New project", systemImage: "plus") }
                            .disabled(!connected || store.busy != nil)
                            .accessibilityHint("Clears the FM-1: empty tracks, no sections, the default sounds, 90 BPM")
                        Button { naming = .saveAs(store.nextName()) } label: { Label("Save as…", systemImage: "square.and.arrow.down") }
                            .disabled(!connected || store.busy != nil)
                    } footer: {
                        if !connected { Text("Plug in the FM-1 to open or save a project. You can still rename and delete.") }
                    }
                    Section {
                        if store.projects.isEmpty {
                            Text("No projects yet. Save what's on the FM-1 to make your first one.")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(store.projects) { row($0) }
                    }
                case .safety:
                    Section {
                        if store.safetyCopies.isEmpty {
                            Text("No safety copies yet.").foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(store.safetyCopies) { row($0) }
                    } footer: {
                        Text("Lupe takes one before it opens something over unsaved work, and keeps the last \(ProjectStore.keptSafetyCopies). Rename one to keep it as a project.")
                    }
                }
            }
            .navigationTitle(tab == .projects ? "Projects" : "Safety copies")    // (spoken; the picker shows the tabs)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Show", selection: $tab) {
                        Text("Projects").tag(Tab.projects)
                        Text(store.safetyCopies.isEmpty ? "Safety copies" : "Safety copies (\(store.safetyCopies.count))").tag(Tab.safety)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .overlay { JibMenuLayer(menu: $menu) }
        .interactiveDismissDisabled(store.busy != nil)
        .alert(openTitle, isPresented: Binding(get: { opening != nil }, set: { if !$0 { opening = nil } }),
               presenting: opening) { o in
            if store.needsSaving {
                Button(store.canSaveInPlace ? "Save and open" : "Save as “\(store.nextName())” and open") {
                    go(o, saveFirst: true)
                }
                Button("Open without saving") { go(o, saveFirst: false) }
            } else {
                Button("Stop and open") { go(o, saveFirst: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { o in
            Text(openMessage(o))
        }
        .alert("Delete “\(deleting?.name ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
               presenting: deleting) { p in
            Button("Delete project", role: .destructive) { store.delete(p) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It's removed from this iPad. What's on the FM-1 stays as it is.")
        }
        .namePrompt($naming, store: store)
    }

    // MARK: Rows

    /// The row opens the project; its ⋯ menu (and a long press, and a swipe) manages it. The menu sits
    /// outside the open button so it still works with the FM-1 unplugged: rename used to live only in a
    /// long press on that button, which is disabled then, and nothing on screen said it was there (2026-11-02).
    private func row(_ p: ProjectFile) -> some View {
        HStack(spacing: 8) {
            openButton(p)
            RowMenuKey(name: p.name, disabled: store.busy != nil) { at in openMenu(p, at) }
        }
        // a long press anywhere on the row: the same menu, at the finger
        .gesture(HoldRecognizer(space: .named("projectRows"), began: { _, g in if store.busy == nil { openMenu(p, g) } },
                                changed: { _, _ in }, ended: { _, _, _ in }))
        .swipeActions {
            Button(role: .destructive) { deleting = p } label: { Label("Delete", systemImage: "trash") }
            Button { naming = .rename(p) } label: { Label("Rename", systemImage: "pencil") }
        }
    }

    /// A project's menu (Jib's own): rename, duplicate, export, delete.
    private func openMenu(_ p: ProjectFile, _ at: CGPoint) {
        menu = JibMenu(title: p.name, groups: {
            var g: [[MenuItem]] = [[MenuItem(title: "Rename", icon: "pencil") { naming = .rename(p) }]]
            if !p.isSafetyCopy { g[0].append(MenuItem(title: "Duplicate", icon: "plus.square.on.square") { store.duplicate(p) }) }
            // SLOOP's song file: opens in SLOOP's web editor too; the share sheet is the system's
            g[0].append(MenuItem(title: "Export…", icon: "square.and.arrow.up") {
                if let url = try? SloopSongExport(project: p).write() { ShareSheet.present(url, at: at) }
            })
            g.append([MenuItem(title: "Delete", icon: "trash") { deleting = p }])
            return g
        }, at: at)
    }

    private func openButton(_ p: ProjectFile) -> some View {
        let onFM1 = p.id == store.currentID && connected
        return Button { request(p) } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(p.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                        if onFM1 {
                            Text(store.edited ? "On FM-1 · edited" : "On FM-1")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.onColour)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.text))
                        }
                    }
                    Text(detail(p)).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 12)
                SectionMarks(filled: p.data.sectionsFilled)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .disabled(!connected || store.busy != nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(p, onFM1: onFM1))
        .accessibilityHint(connected ? "Opens it on the FM-1" : "Plug in the FM-1 to open it")
    }

    private func busyRow(_ b: (label: String, progress: Double?)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(b.label).foregroundStyle(Theme.text)
            if let v = b.progress { ProgressView(value: v) } else { ProgressView() }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ p: ProjectFile) -> String {
        let when = p.saved.formatted(.relative(presentation: .named))
        return [p.isSafetyCopy ? "Taken \(when)" : "Saved \(when)", p.data.bpm.map { "\($0) BPM" }].compactMap { $0 }.joined(separator: " · ")
    }

    private func accessibilityLabel(_ p: ProjectFile, onFM1: Bool) -> String {
        let filled = p.data.sectionsFilled.enumerated().filter(\.element).map { DeviceSession.sectionName($0.offset) }
        let sections = filled.isEmpty ? "no sections" : "sections \(filled.joined(separator: ", "))"
        return [p.name, onFM1 ? (store.edited ? "on the FM-1, edited" : "on the FM-1") : nil, detail(p), sections]
            .compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: Opening

    private func request(_ target: ProjectFile?) {
        let o = Opening(target: target)
        if store.needsSaving || session.playing || session.song.songPlaying { opening = o } else { go(o, saveFirst: false) }
    }

    private func go(_ o: Opening, saveFirst: Bool) {
        Task {
            if saveFirst {
                await store.save(as: store.canSaveInPlace ? nil : store.nextName())
                guard store.message == nil else { return }
            }
            await store.open(o.target)
            if store.message == nil { dismiss() }
        }
    }

    private var openTitle: String {
        guard store.needsSaving else { return "Stop the FM-1?" }
        switch store.state {
        case .project(let n): return "Save “\(n)” first?"
        case .untitled: return "Save this project first?"
        default: return "Save what's on the FM-1 first?"
        }
    }

    private func openMessage(_ o: Opening) -> String {
        let replaces = "Opening \(o.name) replaces what's on the FM-1."
        let stops = session.playing || session.song.songPlaying ? " It stops first." : ""
        let copy = store.needsSaving ? " Without saving, Lupe still keeps a safety copy." : ""
        return replaces + stops + copy
    }
}

/// A, B, C, D: bright for a filled section, dim for an empty one (the letters say it without colour).
struct SectionMarks: View {
    let filled: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { k in
                let on = k < filled.count && filled[k]
                Text(DeviceSession.sectionName(k))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(on ? Theme.onColour : Theme.textSecondary)    // 4.5:1 and up on the sheet
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(on ? Theme.text : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(on ? Color.clear : Theme.ledOff, lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Asking for a name: the first save, Save as, or a rename.
enum NamePrompt: Identifiable {
    case saveAs(String)
    case rename(ProjectFile)
    var id: String { if case .rename(let p) = self { "rename-\(p.id)" } else { "save" } }
}

private struct NamePromptModifier: ViewModifier {
    @Binding var prompt: NamePrompt?
    let store: ProjectStore
    @State private var text = ""

    func body(content: Content) -> some View {
        content.alert(title, isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })) {
            TextField("Name", text: $text)
            Button("Cancel", role: .cancel) {}
            Button(isRename ? "Rename" : "Save") {
                let name = text
                switch prompt {
                case .rename(let p): store.rename(p, to: name)
                default: Task { await store.save(as: name) }
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)    // an empty name did nothing, silently
        }
        .onChange(of: prompt?.id) {
            switch prompt {
            case .saveAs(let n): text = n
            case .rename(let p): text = p.name
            case nil: break
            }
        }
    }

    private var isRename: Bool { if case .rename = prompt { true } else { false } }
    private var title: String { isRename ? "Rename project" : "Save project" }
}

extension View {
    func namePrompt(_ prompt: Binding<NamePrompt?>, store: ProjectStore) -> some View {
        modifier(NamePromptModifier(prompt: prompt, store: store))
    }
}

/// A row's ⋯ key: opens the row's menu under itself.
private struct RowMenuKey: View {
    let name: String
    let disabled: Bool
    let open: (CGPoint) -> Void
    @State private var frame: CGRect = .zero

    var body: some View {
        Button { open(CGPoint(x: frame.maxX - 300, y: frame.maxY)) } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)           // its own target in the row, not part of the open button
        .disabled(disabled)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel("Manage \(name)")
        .accessibilityHint("Rename, duplicate, export or delete")
    }
}

/// The system's share sheet for a file, from wherever a Jib menu was (a sheet included).
@MainActor enum ShareSheet {
    static func present(_ url: URL, at point: CGPoint) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var top = scene.keyWindow?.rootViewController else { return }
        while let p = top.presentedViewController { top = p }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(origin: top.view.convert(point, from: nil), size: .zero)
        top.present(vc, animated: true)
    }
}

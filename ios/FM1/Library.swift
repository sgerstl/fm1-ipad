import SloopKit
import SwiftUI

/// Pass 1 step 3: browse each engine's presets by name and load one onto the selected track, instead
/// of scrolling them on the FM-1. Tapping a preset loads it at once, as scrolling does on the device;
/// SLOOP keeps the pattern, the mix and the key. The keyboard drawer stays available to audition.
struct LibraryPage: View {
    let session: DeviceSession
    let ui: EditorUI
    var columns = 4                 // 2 in the Presets panel on the Sequencer
    /// The sound panel choosing an entry's own sound (a pad's, a block's): the keys show and set that, not the track's.
    var entry: SoundEntryTarget? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the user last scrolled the list themselves: the knob's follow leaves them be for a moment.
    @State private var scrolledByHand: Date = .distantPast
    @State private var clearing: Int?
    /// A user slot waiting on its erase confirm (Skiff's SAVE > USER).
    @State private var erasing: UserPreset?
    /// The sound panel pushing the page (Browse, 2026-11-06): two columns while it's open, back to four after.
    @Environment(\.soundPanelRoom) private var panelRoom

    var body: some View {
        // the track it loads onto is the track strip, collapsed beside it; the engines sit under that
        presetGrid
        .padding(.trailing, panelRoom)       // the panel's room: the grid beside it, never under it
        .task(id: session.selectedTrack) {
            session.refreshLibrary()
            // the entry's own sound's engine (or user slots); else the track's engine; the user slots stay (SAVE > USER
            // lands here, and they aren't an engine's)
            if entry != nil {
                if entryNow?.isUser == true { ui.librarySection = .user }
                else { ui.librarySection = .engine(entryNow?.engine ?? session.tracks[session.selectedTrack].engine) }
            } else if !session.selectedIsDrums, ui.librarySection != .user { ui.librarySection = .engine(session.tracks[session.selectedTrack].engine) }
        }
    }

    // MARK: The presets (or kits, or user presets) as keys

    private var presetGrid: some View {
        let t = session.selectedTrack
        let track = session.tracks[t]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: panelRoom > 0 ? min(2, self.columns) : self.columns)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(gridTitle).font(.system(size: 22, weight: .semibold))
                Text(gridDetail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if let r = session.soundRefusal { SoundRefusalNote(session: session, refusal: r) }
            ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    if session.isDrums(t) && entry == nil {
                        // ids unique across the three lists, or the grid reuses another list's keys
                        ForEach(Array(session.kitNames.enumerated()), id: \.offset) { k, name in
                            presetKey(name, detail: nil, current: track.preset == k) { session.loadKit(k) }
                                .id("kit-\(k)")
                        }
                    } else if case .engine(let e) = ui.librarySection {
                        ForEach(Array((session.namesCache[e] ?? []).enumerated()), id: \.offset) { i, name in
                            presetKey(name, detail: nil, current: entry != nil ? entryNow?.engine == e && entryNow?.s1 == i : track.engine == e && track.preset == i) {
                                if entry != nil { setEntry(EntrySound(s0: e + 1, s1: i)) } else { session.loadPreset(engine: e, index: i) }
                            }
                            .id("preset-\(e)-\(i)")
                        }
                    } else if skiff, entry != nil {
                        // an entry's own sound from the saved slots: only the kept ones (saving belongs to the track's panel)
                        ForEach(session.userPresets.filter { LibraryEngines.offered(session, $0.engine) }) { p in
                            presetKey(p.name, detail: "\(SaveSound.slotName(p.slot)) · \(engineName(p.engine))", current: entryNow?.userSlot == p.slot) {
                                setEntry(EntrySound(s0: 64 + p.slot, s1: 0))
                            }
                            .id("user-\(p.slot)")
                        }
                    } else if skiff {
                        // all 32 of Skiff's slots: a sound loads at a tap (its ⋯ replaces or erases it); an empty one saves
                        ForEach(0..<32, id: \.self) { k in userSlot(k).id("user-\(k)") }
                    } else {
                        ForEach(session.userPresets) { p in
                            presetKey(p.name, detail: String(format: "U%02d · %@", p.slot + 1, engineName(p.engine)),
                                      current: track.presetName == p.name && track.engine == p.engine) {
                                session.loadUserPreset(p)
                            }
                            .id("user-\(p.slot)")
                        }
                    }
                }
                .padding(4)
                if entry == nil, !session.isDrums(t), session.capabilities.contains(.samples), case .engine(let e) = ui.librarySection, e == sampleEngine { userSamples(columns) }
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in if phase.isScrolling { scrolledByHand = Date() } }
            // the sound it has always in view: the FM-1's knob stepping through sounds took the lit key off below the
            // scroll (Scott, 2026-11-08, batch list 1); scrolled only as far as it takes, so a tap on a visible key
            // moves nothing, and never against a scroll of the user's in the last two seconds
            .onChange(of: currentKey) { _, k in
                guard let k, Date().timeIntervalSince(scrolledByHand) > 2 else { return }
                if reduceMotion { proxy.scrollTo(k) } else { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(k) } }
            }
            .onAppear { if let k = currentKey { proxy.scrollTo(k) } }
            }
            if session.isDrums(t) && session.kitNames.isEmpty { emptyNote("Reading the kits from the FM-1…") }
            if !session.isDrums(t) && ui.librarySection == .user && session.userPresets.isEmpty && !skiff {
                emptyNote("No user presets yet. Save one on the FM-1: SAVE, then the USER page.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
        .alert("Erase \(erasing.map { SaveSound.slotName($0.slot) } ?? "")?", isPresented: Binding(get: { erasing != nil }, set: { if !$0 { erasing = nil } }),
               presenting: erasing) { p in
            Button("Erase sound", role: .destructive) { Task { _ = await session.eraseUserPreset(slot: p.slot) } }
            Button("Cancel", role: .cancel) {}
        } message: { p in
            Text("“\(p.name.capitalized)” is removed from the FM-1. Tracks playing it keep their sound. This can't be undone.")
        }
    }

    private var skiff: Bool { session.dialect == .skiff }

    /// The entry's own sound now (nil: none, the track's carries on).
    private var entryNow: EntrySound? {
        guard let entry else { return nil }
        return session.skiffSong?.song?.tracks[safe: entry.ref.track]?.entries[safe: entry.ref.entry]?.sound
    }
    private func setEntry(_ s: EntrySound) {
        guard let entry, let store = session.skiffSong,
              let b = store.blocks(entry.ref.track).first(where: { $0.entries.contains(entry.ref.entry) }) else { return }
        ArrangeEdits(session: session, store: store).setSound(entry.ref.track, b, s)
    }
    /// The lit key's id in the grid (what the target has now), for keeping it in view.
    private var currentKey: String? {
        let t = session.selectedTrack, track = session.tracks[t]
        if entry != nil {
            guard let s = entryNow else { return nil }
            if let u = s.userSlot { return "user-\(u)" }
            return s.engine.map { "preset-\($0)-\(s.s1)" }
        }
        if session.isDrums(t) { return "kit-\(track.preset)" }
        if case .engine = ui.librarySection { return "preset-\(track.engine)-\(track.preset)" }
        return session.userPresets.first { $0.name.uppercased() == track.presetName.uppercased() && $0.engine == track.engine }.map { "user-\($0.slot)" }
    }

    /// One of Skiff's 32 user slots. A sound: loads at a tap, its ⋯ menu replaces it with the track's sound or erases
    /// it. Empty: a dashed key that saves the track's sound there (its name asked).
    @ViewBuilder private func userSlot(_ k: Int) -> some View {
        let t = session.selectedTrack, track = session.tracks[t]
        if let p = session.userPresets.first(where: { $0.slot == k }) {
            presetKey(p.name, detail: "\(SaveSound.slotName(k)) · \(engineName(p.engine))",
                      current: track.presetName.uppercased() == p.name.uppercased() && track.engine == p.engine) { session.loadUserPreset(p) }
                .overlay(alignment: .trailing) {
                    UserSlotMore(name: p.name) { at in
                        ui.menu = AppMenu(title: "\(SaveSound.slotName(k)) · \(p.name.capitalized)", groups: {
                            [[MenuItem(title: "Replace with T\(t + 1)'s sound…", icon: "arrow.triangle.2.circlepath") {
                                ui.saveSound = SaveSoundRequest(slot: k, replacing: p.name)
                             }],
                             [MenuItem(title: "Erase…", icon: "trash") { erasing = p }]]
                        }, at: at, fromKey: true)
                    }
                }
        } else {
            Button { ui.saveSound = SaveSoundRequest(slot: k) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SaveSound.slotName(k)).foregroundStyle(Theme.textSecondary)
                        Text("Empty").font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ledOff, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .disabled(session.isDrums(t))
            .accessibilityLabel("\(SaveSound.slotName(k)), empty")
            .accessibilityHint("Saves track \(t + 1)'s sound here")
        }
    }

    private var gridTitle: String {
        if session.selectedIsDrums { return "Drum kits" }
        switch ui.librarySection {
        case .engine(let e): return engineName(e)
        case .user: return "User presets"
        }
    }

    private var gridDetail: String {
        let t = session.selectedTrack
        let n = session.isDrums(t) ? session.kitNames.count : {
            if case .engine(let e) = ui.librarySection { return session.namesCache[e]?.count ?? 0 }
            return session.userPresets.count
        }()
        let what = session.isDrums(t) ? "kits" : ui.librarySection == .user ? (skiff ? "of 32 saved" : "saved") : "presets"
        return columns < 4 ? "\(n) \(what)" : "\(n) \(what) · Tap one to load it onto track \(t + 1); its pattern, mix and key stay."
    }

    private func engineName(_ e: Int) -> String {
        let names = session.info?.engines ?? []
        return e < names.count ? names[e].capitalized : "Engine \(e + 1)"
    }

    /// A preset key: raised; the one the track plays is sunk with its LED lit.
    private func presetKey(_ name: String, detail: String?, current: Bool, _ load: @escaping () -> Void) -> some View {
        Button(action: load) {
            HStack(spacing: 10) {
                LED(on: current, colour: Theme.track[session.selectedTrack])
                VStack(alignment: .leading, spacing: 2) {
                    Text(name.capitalized).fontWeight(current ? .semibold : .regular).lineLimit(1)
                    if let detail { Text(detail).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .latchedKey(current, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink(latched: current))
        .accessibilityLabel(name.capitalized + (detail.map { ", \($0)" } ?? ""))
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityHint(current ? "" : "Loads onto track \(session.selectedTrack + 1)")
    }

    // MARK: The FM-1's four user sample slots (under the Sample engine)

    private var sampleEngine: Int? { session.info?.engines.firstIndex(of: "SAMPLE") }

    /// The user sample slots (SLOOP SMPL1–4, Skiff USR1–3), as sections work: an empty slot records (the sampler slides up), a full one plays on the
    /// track at a tap, and a long press offers Record over and Clear.
    private func userSamples(_ columns: [GridItem]) -> some View {
        let t = session.selectedTrack
        let slots = session.sampleSlots
        return VStack(alignment: .leading, spacing: 8) {
            Text("Your samples").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4).padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<session.sampleSlotCount, id: \.self) { k in
                    let s = k < slots.count ? slots[k] : nil
                    let full = s.map { !$0.isEmpty } ?? false
                    let current = full && session.tracks[t].engine == sampleEngine && session.tracks[t].presetName == session.sampleSlotName(k)
                    presetKey(full ? s!.name : "Empty", detail: full ? "\(session.sampleSlotName(k)) · \(s!.kib) KB" : "\(session.sampleSlotName(k)) · Tap to record", current: current) {
                        if full { Task { await session.useSample(slot: k, onTrack: t) } }
                        else { ui.sampler = SamplerRequest(track: t, slot: k, fromBrowse: true) }
                    }
                    // a long press on a recorded slot: Lupe's menu at the finger (it was the system's)
                    .gesture(HoldRecognizer(space: .named(AppView.space), began: { _, at in
                        guard full else { return }
                        ui.menu = AppMenu(title: "\(session.sampleSlotName(k)) · \(s?.name ?? "")", groups: {
                            [[MenuItem(title: "Record over", icon: "mic") { ui.sampler = SamplerRequest(track: t, slot: k, fromBrowse: true) }],
                             [MenuItem(title: "Clear", icon: "trash") { clearing = k }]]
                        }, at: at)
                    }, changed: { _, _ in }, ended: { _, _, _ in }))
                    .accessibilityAction(named: "Record over") { if full { ui.sampler = SamplerRequest(track: t, slot: k, fromBrowse: true) } }
                    .accessibilityAction(named: "Clear") { if full { clearing = k } }
                    .id("usr-\(k)")
                }
            }
            .padding(4)
        }
        .task { await session.refreshSampleSlots() }
        .alert("Clear \(session.sampleSlotName(clearing ?? 0))?", isPresented: Binding(get: { clearing != nil }, set: { if !$0 { clearing = nil } })) {
            Button("Clear \(session.sampleSlotName(clearing ?? 0))", role: .destructive) {
                if let k = clearing { Task { try? await session.eraseSample(slot: k) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The FM-1 keeps no copy of it.")
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text).font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 24)
    }
}

/// The engines (and user presets) for the library, in the left column under the track strip.
struct LibraryEngines: View {
    let session: DeviceSession
    let ui: EditorUI
    /// Choosing a pad's or block's own sound: only what that track can take (Scott, 2026-11-09: "contextually
    /// relevant"), a drum track's drum engines, a synth track's synth engines it may play; the rest left out, not greyed.
    var entry = false
    /// How much of the list is past each edge: there it fades out, so a cut list reads as one that scrolls (Scott,
    /// 2026-11-06: the engines ran past the box with no hint). Nothing past an edge, no fade.
    @State private var past = (above: false, below: false)
    private static let fade: CGFloat = 56            // past a row: the cut one shows faintly, the one above it starts to go

    var body: some View { engineList }

    /// An engine an entry on the selected track may take as its own sound: the track's kind (drum or synth), and one
    /// the track may play (op 9 refuses the rest).
    @MainActor static func offered(_ session: DeviceSession, _ e: Int) -> Bool {
        let t = session.selectedTrack
        guard let name = session.info?.engines[safe: e], name != "-" else { return false }     // ("-": a retired engine)
        return name.hasPrefix("DRUM") == session.isDrums(t) && session.shape.canPlay(track: t, engine: e)
    }

    // MARK: Engines (synth tracks), then user presets

    var engineList: some View {
        let t = session.tracks[session.selectedTrack]
        let engines = session.info?.engines ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {       // 12 engines + user presets fit without scrolling
                Text("Engines").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 8).padding(.bottom, 6)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(engines.enumerated()).filter { !entry || Self.offered(session, $0.offset) }, id: \.offset) { e, name in
                    // Skiff's light tracks (5 and 6) can't play GRAIN or PHYS: there they show, greyed, and say why
                    let plays = session.shape.canPlay(track: session.selectedTrack, engine: e)
                    row(name.capitalized, count: session.namesCache[e]?.count ?? 0,
                        current: t.engine == e, browsing: ui.librarySection == .engine(e),
                        notHere: plays ? nil : "not on track \(session.selectedTrack + 1)") { ui.librarySection = .engine(e) }
                }
                row("User presets", count: session.userPresets.count, current: false,
                    browsing: ui.librarySection == .user) { ui.librarySection = .user }
                    .padding(.top, 4)
            }
        }
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 1 } action: { _, v in past.above = v }
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentSize.height - (g.contentOffset.y + g.containerSize.height - g.contentInsets.bottom) > 1
        } action: { _, v in past.below = v }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: past.above ? Self.fade : 0)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: past.below ? Self.fade : 0)
            }
        }
        // and the bar: shown while it scrolls, flashed when the list comes up cut
        .scrollIndicators(.automatic)
        .scrollIndicatorsFlash(onAppear: true)
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .panel()
    }

    /// A list row: raised while it's the one being browsed; an LED marks the track's own engine.
    private func row(_ name: String, count: Int, current: Bool, browsing: Bool, notHere: String? = nil,
                     _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LED(on: current)
                Text(name).fontWeight(browsing ? .semibold : .regular)
                Spacer()
                Text(notHere ?? "\(count)").font(.system(size: notHere == nil ? 13 : 11)).foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(browsing ? Theme.text : Theme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background { if browsing { Color.clear.selectedKey(10) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(notHere != nil)
        .opacity(notHere == nil ? 1 : 0.5)
        .accessibilityLabel("\(name), \(notHere ?? "\(count) presets")\(current ? ", the track's engine" : "")")
        .accessibilityAddTraits(browsing ? .isSelected : [])
    }

}

enum LibrarySection: Equatable {
    case engine(Int)
    case user
}

/// A user slot's ⋯: its menu (replace, erase) under it, a 44 pt target at the key's right.
private struct UserSlotMore: View {
    let name: String
    let open: (CGPoint) -> Void
    @State private var frame: CGRect = .zero

    var body: some View {
        Button { open(CGPoint(x: frame.maxX - MenuPanel.width, y: frame.maxY)) } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 56).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .globalFrame($frame)
        .accessibilityLabel("Manage \(name.capitalized)")
        .accessibilityHint("Replace or erase this saved sound")
    }
}

/// The FM-1 kept the track's sound (Session.soundRefusal): said over the presets, gone after a few seconds or ✕.
private struct SoundRefusalNote: View {
    let session: DeviceSession
    let refusal: DeviceSession.SoundRefusal

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.caution).accessibilityHidden(true)
            Text(refusal.text).font(.system(size: 13)).foregroundStyle(Theme.text)
            Spacer(minLength: 0)
            Button { session.dismissSoundRefusal() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
        .accessibilityElement(children: .contain)
        .task(id: refusal.at) {
            AccessibilityNotification.Announcement(refusal.text).post()
            try? await Task.sleep(for: .seconds(6))
            if session.soundRefusal == refusal { session.dismissSoundRefusal() }
        }
    }
}

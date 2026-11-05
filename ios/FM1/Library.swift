import SloopKit
import SwiftUI

/// Pass 1 step 3: browse each engine's presets by name and load one onto the selected track, instead
/// of scrolling them on the FM-1. Tapping a preset loads it at once, as scrolling does on the device;
/// SLOOP keeps the pattern, the mix and the key. The keyboard drawer stays available to audition.
struct LibraryPage: View {
    let session: DeviceSession
    let ui: EditorUI
    var columns = 4                 // 2 in the Presets panel on the Sequencer
    @State private var clearing: Int?

    var body: some View {
        // the track it loads onto is the track strip, collapsed beside it; the engines sit under that
        presetGrid
        .task(id: session.selectedTrack) {
            session.refreshLibrary()
            if !session.selectedIsDrums { ui.librarySection = .engine(session.tracks[session.selectedTrack].engine) }
        }
    }

    // MARK: The presets (or kits, or user presets) as keys

    private var presetGrid: some View {
        let t = session.selectedTrack
        let track = session.tracks[t]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: self.columns)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(gridTitle).font(.system(size: 22, weight: .semibold))
                Text(gridDetail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    if session.isDrums(t) {
                        // ids unique across the three lists, or the grid reuses another list's keys
                        ForEach(Array(session.kitNames.enumerated()), id: \.offset) { k, name in
                            presetKey(name, detail: nil, current: track.preset == k) { session.loadKit(k) }
                                .id("kit-\(k)")
                        }
                    } else if case .engine(let e) = ui.librarySection {
                        ForEach(Array((session.namesCache[e] ?? []).enumerated()), id: \.offset) { i, name in
                            presetKey(name, detail: nil, current: track.engine == e && track.preset == i) {
                                session.loadPreset(engine: e, index: i)
                            }
                            .id("preset-\(e)-\(i)")
                        }
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
                if !session.isDrums(t), session.capabilities.contains(.samples), case .engine(let e) = ui.librarySection, e == sampleEngine { userSamples(columns) }
            }
            .scrollIndicators(.hidden)
            if session.isDrums(t) && session.kitNames.isEmpty { emptyNote("Reading the kits from the FM-1…") }
            if !session.isDrums(t) && ui.librarySection == .user && session.userPresets.isEmpty {
                emptyNote("No user presets yet. Save one on the FM-1: SAVE, then the USER page.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
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
        let what = session.isDrums(t) ? "kits" : ui.librarySection == .user ? "saved" : "presets"
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

    /// USR1–4, as sections work: an empty slot records (the sampler slides up), a full one plays on the
    /// track at a tap, and a long press offers Record over and Clear.
    private func userSamples(_ columns: [GridItem]) -> some View {
        let t = session.selectedTrack
        let slots = session.sampleSlots
        return VStack(alignment: .leading, spacing: 8) {
            Text("Your samples").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4).padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<max(4, slots.count), id: \.self) { k in
                    let s = k < slots.count ? slots[k] : nil
                    let full = s.map { !$0.isEmpty } ?? false
                    let current = full && session.tracks[t].engine == sampleEngine && session.tracks[t].presetName == "SMPL\(k + 1)"
                    presetKey(full ? s!.name : "Empty", detail: full ? "SMPL\(k + 1) · \(s!.kib) KB" : "SMPL\(k + 1) · Tap to record", current: current) {
                        if full { Task { await session.useSample(slot: k, onTrack: t) } }
                        else { ui.sampler = SamplerRequest(track: t, slot: k, fromBrowse: true) }
                    }
                    // a long press on a recorded slot: Jib's menu at the finger (it was the system's)
                    .gesture(HoldRecognizer(space: .named(AppView.space), began: { _, at in
                        guard full else { return }
                        ui.menu = JibMenu(title: "SMPL\(k + 1) · \(s?.name ?? "")", groups: {
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
        .alert("Clear SMPL\((clearing ?? 0) + 1)?", isPresented: Binding(get: { clearing != nil }, set: { if !$0 { clearing = nil } })) {
            Button("Clear SMPL\((clearing ?? 0) + 1)", role: .destructive) {
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

    var body: some View { engineList }

    // MARK: Engines (synth tracks), then user presets

    var engineList: some View {
        let t = session.tracks[session.selectedTrack]
        let engines = session.info?.engines ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {       // 12 engines + user presets fit without scrolling
                Text("Engines").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 8).padding(.bottom, 6)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(engines.enumerated()), id: \.offset) { e, name in
                    row(name.capitalized, count: session.namesCache[e]?.count ?? 0,
                        current: t.engine == e, browsing: ui.librarySection == .engine(e)) { ui.librarySection = .engine(e) }
                }
                row("User presets", count: session.userPresets.count, current: false,
                    browsing: ui.librarySection == .user) { ui.librarySection = .user }
                    .padding(.top, 4)
            }
        }
        .scrollIndicators(.hidden)
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .panel()
    }

    /// A list row: raised while it's the one being browsed; an LED marks the track's own engine.
    private func row(_ name: String, count: Int, current: Bool, browsing: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LED(on: current)
                Text(name).fontWeight(browsing ? .semibold : .regular)
                Spacer()
                Text("\(count)").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(browsing ? Theme.text : Theme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background { if browsing { Color.clear.selectedKey(10) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel("\(name), \(count) presets\(current ? ", the track's engine" : "")")
        .accessibilityAddTraits(browsing ? .isSelected : [])
    }

}

enum LibrarySection: Equatable {
    case engine(Int)
    case user
}

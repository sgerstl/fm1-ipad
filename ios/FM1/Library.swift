import SloopKit
import SwiftUI

/// Pass 1 step 3: browse each engine's presets by name and load one onto the selected track, instead
/// of scrolling them on the FM-1. Tapping a preset loads it at once, as scrolling does on the device;
/// SLOOP keeps the pattern, the mix and the key. The keyboard drawer stays available to audition.
struct LibraryPage: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 16) {
                trackPicker
                if session.selectedTrack < 3 { engineList }
                Spacer(minLength: 0)
            }
            .frame(width: 320)
            presetGrid
        }
        .task(id: session.selectedTrack) {
            session.refreshLibrary()
            if session.selectedTrack < 3 { ui.librarySection = .engine(session.tracks[session.selectedTrack].engine) }
        }
    }

    // MARK: Which track the presets load onto (selects it on the FM-1)

    private var trackPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Load onto").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                .padding(.leading, 8).padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
            ForEach(0..<4, id: \.self) { t in
                let selected = session.selectedTrack == t
                Button { session.select(track: t) } label: {
                    HStack(spacing: 12) {
                        TrackChip(track: t)
                        Text(session.tracks[t].displayName).font(.system(size: 15, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(selected ? 0.06 : 0)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel("Track \(t + 1), \(session.tracks[t].displayName)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(12)
        .panel()
    }

    // MARK: Engines (synth tracks), then user presets

    private var engineList: some View {
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
            .background { if browsing { Color.clear.raisedKey(10) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel("\(name), \(count) presets\(current ? ", the track's engine" : "")")
        .accessibilityAddTraits(browsing ? .isSelected : [])
    }

    // MARK: The presets (or kits, or user presets) as keys

    private var presetGrid: some View {
        let t = session.selectedTrack
        let track = session.tracks[t]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
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
                    if t == 3 {
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
            }
            .scrollIndicators(.hidden)
            if t == 3 && session.kitNames.isEmpty { emptyNote("Reading the kits from the FM-1…") }
            if t < 3 && ui.librarySection == .user && session.userPresets.isEmpty {
                emptyNote("No user presets yet. Save one on the FM-1: SAVE, then the USER page.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel()
    }

    private var gridTitle: String {
        if session.selectedTrack == 3 { return "Drum kits" }
        switch ui.librarySection {
        case .engine(let e): return engineName(e)
        case .user: return "User presets"
        }
    }

    private var gridDetail: String {
        let t = session.selectedTrack
        let n = t == 3 ? session.kitNames.count : {
            if case .engine(let e) = ui.librarySection { return session.namesCache[e]?.count ?? 0 }
            return session.userPresets.count
        }()
        let what = t == 3 ? "kits" : ui.librarySection == .user ? "saved" : "presets"
        return "\(n) \(what) · Tap one to load it onto track \(t + 1); its pattern, mix and key stay."
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
            .background {
                if current { RoundedRectangle(cornerRadius: 10).fill(Theme.pressed).recessed(10) } else { Color.clear.raisedKey(10) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(name.capitalized + (detail.map { ", \($0)" } ?? ""))
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityHint(current ? "" : "Loads onto track \(session.selectedTrack + 1)")
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text).font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 24)
    }
}

enum LibrarySection: Equatable {
    case engine(Int)
    case user
}

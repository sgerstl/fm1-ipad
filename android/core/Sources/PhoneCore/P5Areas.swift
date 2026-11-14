// P5's areas built from DeviceSession the way the iPad's screens read the same state: the Mix strips and cards
// (ios/FM1/MixerPanel.swift), the Sounds panel (Library.swift, PresetsPanel.swift) and the FM-1 side of Projects.
import Foundation
import SloopKit

extension PhoneCore {
    // MARK: mix

    static let mixSectionKeys = ["mixer", "delay", "reverb", "chorus", "global"]

    /// The GLO page the FM-1's screen is on (30…34: MIXER, DELAY, REVERB, CHORUS, GLOBAL), nil on any other screen.
    func fm1GloPage() -> Int? {
        guard session.screenLinked, let sc = session.deviceScreen, !sc.home, sc.menu == 0, sc.layer == 0, (30...34).contains(sc.page) else { return nil }
        return sc.page
    }

    /// The Mix section follows the FM-1's GLO page by itself (no write): each time the FM-1 comes onto a GLO page, or
    /// steps to another, the section is that page's. Run as an area watch's builder, so the screen moving re-runs it.
    /// The phone's own choice stays until the FM-1's GLO page next changes.
    func followGloPage() -> String? {
        let page = fm1GloPage()
        if page != lastGloPage {
            lastGloPage = page
            if let page, let key = Self.mixSectionKeys[safe: page - 30], key != mixSection {
                mixSection = key
                pokeAreas(["mix"])
            }
        }
        return nil
    }

    /// The REVERB send's id: the FX page's fourth knob (MixerPanel.revID).
    var reverbSendID: Int? { SoundPage.pages(session).first { $0.title == "FX" }?.ids[safe: 3] ?? nil }

    /// LEVEL as Skiff writes it under the fader: (v − 112) / 2 dB, OFF at 0 (MixerStrips.dB).
    static func levelText(_ v: Int) -> String {
        if v <= 0 { return "OFF" }
        let d = Double(v - 112) / 2
        return d == d.rounded() ? "\(Int(d)) dB" : String(format: "%.1f dB", d)
    }
    static func panText(_ v: Int) -> String { v == 0 ? "C" : v < 0 ? "L\(-v)" : "R\(v)" }

    func globalControl(_ id: Int, label: String? = nil) -> PageArea.Control {
        let d = session.globalDescs[id]
        let v = session.globalCell(id).value
        let lo = d?.min ?? 0, hi = max(d?.max ?? 127, lo)
        return PageArea.Control(label: label ?? d?.label ?? "", value: formatValue(d, v, skiff: true).shown, raw: v, min: lo, max: hi,
                                list: d.map { $0.format == 8 || !$0.names.isEmpty } ?? false, ringless: false, fixed: false, locked: false,
                                names: nil)
    }

    /// The card's page: GLO's page with that title (SoundPage, as the iPad's Mix cards).
    func mixPage(_ key: String) -> SoundPage? {
        guard let k = Self.mixSectionKeys.firstIndex(of: key), k > 0 else { return nil }
        let title = SkiffButtonMap.MixerTab.allCases[k].pageTitle
        return SoundPage.pages(session).first { $0.family == .glo && $0.title == title }
    }

    public func mixArea() -> MixArea {
        let s = session
        let sections = SkiffButtonMap.MixerTab.allCases.map { MixArea.Section(key: Self.mixSectionKeys[$0.rawValue], title: $0.title, page: $0.page) }
        let rid = reverbSendID
        let perf = s.skiffSong?.perform
        let soloed = s.skiffSong?.soloed ?? []
        let rows = s.trackIndices.map { t -> MixArea.Row in
            let tr = s.tracks[t]
            var rev: Int?, revText: String?, revMax = 127
            if let id = rid {
                let d = s.trackDesc(id)
                revMax = d?.max ?? 127
                rev = t == s.selectedTrack && id < s.params.count ? s.params[id] : s.everyTrack[id]?[t]
                revText = rev.map { formatValue(d, $0, skiff: true).shown }
            }
            return MixArea.Row(track: t + 1, name: tr.displayName, selected: t == s.selectedTrack, level: tr.level,
                               levelText: Self.levelText(tr.level), pan: tr.pan, panText: Self.panText(tr.pan),
                               mute: perf?.muted[safe: t] ?? tr.mute, solo: soloed.contains(t), reverb: rev, reverbText: revText, reverbMax: revMax)
        }
        var card: MixArea.Card?
        if let p = mixPage(mixSection) {
            let controls: [PageArea.Control?] = (0..<4).map { k in
                guard let id = p.ids[safe: k] ?? nil else { return nil }
                // a send page's knob 1 is the track's own send (scope 0): the Mix cards are GLO's, all globals
                return p.scope(of: k) == 1 ? globalControl(id, label: p.knobLabels[safe: k] ?? nil) : nil
            }
            card = MixArea.Card(title: p.title, controls: controls, settings: p.settings.map { globalControl($0) })
        }
        return MixArea(sections: sections, section: mixSection, rows: rows, card: card)
    }

    public func metersArea() -> MetersArea {
        let s = session, perf = s.skiffSong?.perform
        return MetersArea(levels: s.trackIndices.map { t in
            (s.meters.level(track: t, muted: perf?.muted[safe: t] ?? s.tracks[t].mute) * 100).rounded() / 100
        })
    }

    // MARK: sounds

    func isKitEngine(_ e: Int) -> Bool {
        guard let names = session.info?.engines, let n = names[safe: e] else { return false }
        return n == "DRUM" || n == "DRUM-X"
    }

    public func soundsArea() -> SoundsArea {
        let s = session
        let t = max(0, min(s.tracks.count - 1, soundsTrack ?? s.selectedTrack))
        let tr = s.tracks[t]
        let names = s.info?.engines ?? []
        let engines = names.indices.map { e in
            SoundsArea.Engine(index: e, name: names[e], offered: names[e] != "-" && s.shape.canPlay(track: t, engine: e), kit: isKitEngine(e))   // "-": a reserved number
        }
        // the entry's own sound, when a pad is the target (LIST2's sound bytes: s0 1…63 engine s0 − 1 with preset s1,
        // 64…127 user slot s0 − 64)
        var entrySound: SoundsArea.EntrySound?
        if let e = soundsEntry {
            let snd = s.skiffSong?.song?.tracks[safe: t]?.entries[safe: e]?.sound
            if let snd, snd.s0 >= 64 {
                let slot = snd.s0 - 64
                entrySound = .init(kind: "user", engine: nil, preset: nil, slot: slot, name: s.userPresets.first { $0.slot == slot }?.name)
            } else if let snd, snd.s0 >= 1 {
                let eng = snd.s0 - 1
                entrySound = .init(kind: "preset", engine: eng, preset: snd.s1, slot: nil, name: s.namesCache[eng]?[safe: snd.s1])
            } else {
                entrySound = .init(kind: "none", engine: nil, preset: nil, slot: nil, name: nil)
            }
        }
        let viewing = soundsViewing ?? entrySound?.engine ?? tr.engine
        let presets = (s.namesCache[viewing] ?? []).enumerated().map { i, n in
            SoundsArea.Preset(index: i, name: n,
                              current: soundsEntry != nil ? (entrySound?.engine == viewing && entrySound?.preset == i) : (tr.engine == viewing && tr.preset == i))
        }
        let user = (0..<32).map { k -> SoundsArea.UserSlot in
            guard let p = s.userPresets.first(where: { $0.slot == k }) else { return .init(slot: k, used: false, name: "", engine: nil, engineName: nil, current: false) }
            let current = soundsEntry != nil ? entrySound?.slot == k : (tr.engine == p.engine && tr.presetName.uppercased() == p.name.uppercased())
            return .init(slot: k, used: true, name: p.name, engine: p.engine, engineName: names[safe: p.engine], current: current)
        }
        return SoundsArea(target: .init(track: t + 1, entry: soundsEntry), trackName: tr.displayName, engine: tr.engine, preset: tr.preset,
                          engines: engines, viewing: viewing, presets: presets, user: user, entrySound: entrySound,
                          refusal: s.soundRefusal?.text)
    }

    // MARK: projects

    public func projectsArea() -> ProjectsArea {
        let p = session.skiffProjects
        let slots = (0..<4).map { k in
            ProjectsArea.Slot(slot: k, used: p?.slots[safe: k]?.used ?? false, name: p?.slots[safe: k]?.name ?? "", current: p?.musicSlot == k)
        }
        return ProjectsArea(slots: slots, name: p?.name ?? "", changed: p?.changed ?? false, busy: projectBusy)
    }
}

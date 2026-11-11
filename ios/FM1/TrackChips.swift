import SloopKit
import SwiftUI

/// What a track has applied, as chips (Scott, 2026-11-10, board 46): its per-track effects, the ones a pad's own sound
/// never changes (Skiff params.c param_kept): ARP, CHORD, SCALE (QUANTIZE on), SLICER, DUCK, FOLLOW. A chip is words
/// with a symbol first, never colour alone; it opens the sound panel at that effect's page.
struct EffectChip: Identifiable, Equatable {
    let id: String          // the Sound page it opens
    let symbol: String
    let word: String
    let spoken: String
    let family: SoundFamily
}

enum TrackChips {
    @MainActor static func of(_ s: DeviceSession, _ t: Int) -> [EffectChip] {
        guard s.dialect == .skiff, s.trackIndices.contains(t) else { return [] }
        let tr = s.tracks[t], ids = s.ids
        func shown(_ id: Int?, _ v: Int) -> String { id.map { formatValue(s.trackDesc($0), v, skiff: true).shown } ?? "\(v)" }
        var c: [EffectChip] = []
        if !s.isDrums(t), tr.arpMode > 0 {
            let m = shown(ids.arpMode, tr.arpMode)
            c.append(EffectChip(id: "ARP", symbol: "arrow.up.right", word: "ARP \(m)", spoken: "Arpeggio, \(m.lowercased())", family: .arp))
        }
        if !s.isDrums(t), tr.chord > 0 {
            let m = shown(ids.chord, tr.chord)
            c.append(EffectChip(id: "CHORD", symbol: "number", word: m, spoken: "Chord, \(m.lowercased())", family: .sel))
        }
        if !s.isDrums(t), tr.quant > 0 {
            let m = shown(ids.scale, tr.scale)
            c.append(EffectChip(id: "SCALE", symbol: "pianokeys", word: m, spoken: "Scale, \(m.lowercased())", family: .sel))
        }
        if tr.slicer > 0 {
            let m = shown(ids.slicer, tr.slicer)
            c.append(EffectChip(id: "SLICER", symbol: "scissors", word: "SLICE", spoken: "Slicer, \(m.lowercased())", family: .fx))
        }
        if tr.duck > 0 {
            let m = shown(ids.duck, tr.duck)
            c.append(EffectChip(id: "DUCK", symbol: "arrow.down.right", word: "DUCK", spoken: "Ducks under \(m.lowercased())", family: .fx))
        }
        if !s.isDrums(t), tr.follow > 0 {
            c.append(EffectChip(id: "FOLLOW", symbol: "arrow.triangle.branch", word: "FOLLOW", spoken: "Chord follow on", family: .sel))
        }
        return c
    }

    /// The track selected and the sound panel open at that chip's page (as the panel's own key would, then its page).
    @MainActor static func open(_ c: EffectChip, track t: Int, session: DeviceSession, ui: EditorUI) {
        if session.selectedTrack != t { session.select(track: t) }
        ui.soundPanel = SoundPanelState(family: c.family)
        ui.soundFamily = c.family
        if let p = SoundPage.reached(session, c.family).first(where: { $0.title == c.id }) ?? SoundPage.reached(session, c.family).first {
            ui.focus(p)
            if session.screenLinked, ui.followDevice { session.showOnDevice(page: p.fw) }
        }
    }

    /// The chips that fit `room`, the last of them "+N" when more don't (Scott, 2026-11-10).
    static func fit(_ cs: [EffectChip], max n: Int) -> (shown: [EffectChip], more: [EffectChip]) {
        guard cs.count > n, n > 0 else { return (cs, []) }
        return (Array(cs.prefix(n - 1)), Array(cs.dropFirst(n - 1)))
    }
    /// How many of `cs` fit a row `width` wide (each chip's width estimated from its word), the "+N" counted.
    static func fitting(_ cs: [EffectChip], width: CGFloat, size: ChipView.Size) -> Int {
        var used: CGFloat = 0, k = 0
        for (i, c) in cs.enumerated() {
            let w = ChipView.estimate(c, size) + (i > 0 ? 6 : 0)
            let roomForMore = i < cs.count - 1 ? ChipView.plusWidth(size) + 6 : 0
            if used + w + roomForMore > width && i < cs.count - 1 { break }
            if used + w > width { break }
            used += w; k += 1
        }
        return k == cs.count ? k : k + 1       // (+1: the "+N" takes the next place)
    }
}

/// One chip: a symbol and words on the control grey with a hairline (#EDEDF0 on #26262B: 12.9:1).
struct ChipView: View {
    enum Size { case small, regular }
    let chip: EffectChip
    var size: Size = .small
    let open: () -> Void

    static func font(_ s: Size) -> CGFloat { s == .small ? 11 : 12 }
    static func height(_ s: Size) -> CGFloat { s == .small ? 18 : 22 }
    static func estimate(_ c: EffectChip, _ s: Size) -> CGFloat { CGFloat(c.word.count) * font(s) * 0.6 + font(s) + (s == .small ? 14 : 20) }
    static func plusWidth(_ s: Size) -> CGFloat { s == .small ? 28 : 34 }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 3) {
                Image(systemName: chip.symbol).font(.system(size: Self.font(size) - 2, weight: .bold))
                Text(chip.word).font(.lupe(Self.font(size), .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, size == .small ? 6 : 8)
            .frame(height: Self.height(size))
            .background(Capsule().fill(Theme.control))
            .overlay(Capsule().strokeBorder(Color(hex: 0x4A4A52), lineWidth: 1))
            .contentShape(Rectangle().inset(by: -6))      // (the touch a little beyond the drawn chip; neighbours 4–6 apart)
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(chip.spoken)
        .accessibilityHint("Opens its panel")
    }
}

/// "+N": the rest, as a menu of them, each opening its own panel (they can sit under different buttons: FX, SEL, ARP).
struct MoreChips: View {
    let chips: [EffectChip]
    var size: ChipView.Size = .small
    var countOnly = false           // the Half head: the whole list's count, no "+"
    let open: (EffectChip) -> Void

    var body: some View {
        Menu {
            ForEach(chips) { c in
                Button { open(c) } label: { Label(c.word, systemImage: c.symbol) }
            }
        } label: {
            Text(countOnly ? "\(chips.count)" : "+\(chips.count)").font(.lupe(ChipView.font(size), .bold)).monospacedDigit()
                .foregroundStyle(Theme.text)
                .frame(minWidth: ChipView.height(size)).padding(.horizontal, 5)
                .frame(height: ChipView.height(size))
                .background(Capsule().fill(Theme.control))
                .overlay(Capsule().strokeBorder(Color(hex: 0x4A4A52), lineWidth: 1))
                .contentShape(Rectangle().inset(by: -6))
        }
        .accessibilityLabel(countOnly ? "\(chips.count) effects" : "\(chips.count) more effects")
        .accessibilityValue(chips.map(\.spoken).joined(separator: ", "))
        .accessibilityHint("Lists them; each opens its panel")
    }
}

/// A row of chips, as many as fit, the last "+N" when more don't.
struct ChipRow: View {
    let session: DeviceSession
    let ui: EditorUI
    let track: Int
    let chips: [EffectChip]
    let width: CGFloat
    var size: ChipView.Size = .regular

    var body: some View {
        let f = TrackChips.fit(chips, max: TrackChips.fitting(chips, width: width, size: size))
        HStack(spacing: 6) {
            ForEach(f.shown) { c in ChipView(chip: c, size: size) { TrackChips.open(c, track: track, session: session, ui: ui) } }
            if !f.more.isEmpty { MoreChips(chips: f.more, size: size) { TrackChips.open($0, track: track, session: session, ui: ui) } }
        }
        .frame(width: width, alignment: .leading)
    }
}

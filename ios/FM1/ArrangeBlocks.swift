import SloopKit
import SwiftUI

// The Song tab's timeline blocks: an entry or a chain drawn on its lane, the chain's dividers, the playhead, and a
// REST opening to hold a gap.

struct BlockView: View {
    let session: DeviceSession
    let track: Int
    let block: SongBlock
    let list: SongList
    let width: CGFloat
    let selected: Bool
    let linked: Bool
    let playing: Bool
    /// The Song tab while playing: what VoiceOver says of its playback ("pass 2 of 4", "next", "queued, …").
    var state: String? = nil
    /// Loop entry (SONG OFF): every entry loops and REPS doesn't apply, so the block says ↻, not ×N.
    var loops = false
    /// Its pattern's picture, as the pads show it (Scott, 2026-11-09: the blocks tell as much as the pads); drawn where
    /// the block has room.
    var thumb: PadThumb? = nil
    @Environment(\.arrangeCompact) private var compact
    @Environment(\.arrangeLaneHeight) private var laneHeight

    private var first: SongEntry { list.entries[block.entries.lowerBound] }
    private var isRest: Bool { block.kind != .pattern }
    private var sound: EntrySound? { list.entries[block.entries.lowerBound].sound }

    private var label: String {
        if isRest { return "REST" }
        if block.isChain {
            return block.entries.map { list.entries[$0].label }.joined(separator: "→")
        }
        return Entries.number(first.pattern)
    }

    /// How many times it plays: ×N, or ↻ in Loop entry, playing or stopped (Scott, 2026-11-06: blocks said ×N in a
    /// mode where they loop whatever their REPS).
    private var count: String { loops ? "↻" : "×\(block.reps)" }

    private var sub: String {
        var s = (block.isChain ? "chain " : "") + count
        if let snd = sound { s += " · " + Entries.soundName(snd, session: session) }
        return s
    }

    var body: some View {
        let _ = BodyCounter.tick("BlockView")
        let shape = BlockShape(cut: sound != nil ? 12 : 0)
        let wide = width >= 56
        let solid = !isRest
        // on a solid track colour every line is the dark text (6:1 or better on each); weight ranks them
        let strong = solid ? Theme.onColour : Theme.textSecondary
        let dim = strong
        VStack(alignment: .leading, spacing: 2) {
            if laneHeight < 52 {
                // a short lane (the Song tab): one line, "B · 05 ×2"; a narrow block, its count under it where the
                // lane has room for two lines, else after it, shrinking before it cuts (Scott, 2026-11-06: narrow
                // blocks hid their count)
                if wide {
                    Text("\(Entries.letters(block.entries)) · \(isRest ? "REST" : label) \(count)")
                        .font(.lupe(11, .semibold)).foregroundStyle(strong)
                } else if laneHeight >= 40 {
                    Text(isRest ? "–" : label).font(.lupe(11, .semibold)).foregroundStyle(strong)
                    Text(count).font(.lupe(11)).foregroundStyle(dim)
                } else {
                    Text("\(isRest ? "–" : label) \(count)").font(.lupe(11, .semibold)).foregroundStyle(strong)
                }
            } else if wide {
                HStack(spacing: 4) {
                    Text(Entries.letters(block.entries)).font(.lupe(11)).foregroundStyle(dim)
                    // an entry with its own sound: Skiff loads it as the entry starts (and the corner is cut)
                    if sound != nil { Image(systemName: "waveform").font(.system(size: 10, weight: .semibold)).foregroundStyle(dim) }
                }
                Text(label).font(.lupe(15, .semibold)).foregroundStyle(strong)
                Text(sub).font(.lupe(12)).foregroundStyle(dim)
                if let thumb, !isRest, laneHeight >= 76, width >= 80 {
                    Spacer(minLength: 0)
                    PadThumbView(thumb: thumb, ink: Theme.onColour.opacity(0.6)).frame(height: 14)
                }
            } else {
                // narrow: the pattern, then its count (and the sound's mark beside it)
                Text(isRest ? "–" : label).font(.lupe(13, .semibold)).foregroundStyle(strong)
                HStack(spacing: 2) {
                    Text(count).font(.lupe(12)).foregroundStyle(dim)
                    if sound != nil { Image(systemName: "waveform").font(.system(size: 10, weight: .semibold)).foregroundStyle(strong) }
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(wide ? 1 : 0.7)
        .padding(.horizontal, wide ? 8 : 4).padding(.vertical, laneHeight < 52 ? 0 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: laneHeight < 52 ? .leading : .topLeading)
        .background {
            if isRest {
                shape.stroke(Theme.disabledOutline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else {
                shape.fill(Theme.track[track])
                    .overlay { if block.isChain { ChainDividers(parts: block.parts, reps: block.reps) } }
            }
        }
        .overlay {
            // on a solid colour the ring goes outside, on the lane (light on amber would be under 3:1), and
            // the linked copies' dashes are dark
            if selected { shape.stroke(Theme.text, lineWidth: 2).padding(solid ? -3 : 1) }
            // the Song tab while playing: the block each track plays outlined inside
            else if compact, playing { shape.stroke(Theme.text, lineWidth: 2).padding(2) }
            else if linked { shape.stroke(solid ? Theme.onColour : Theme.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).padding(4) }
        }
        .compositingGroup()
        // the Song tab while playing: what isn't playing dimmed, so each track's playing block stands out; the change
        // fades as the pads' play colours do (Labs › Pads: play colours fade in; out quicker)
        .opacity(compact && session.playing && !playing && !selected ? 0.5 : 1)
        .animation(Labs.padPlayFade.value > 0 ? (playing ? .easeOut(duration: Labs.padPlayFade.value) : .easeIn(duration: Labs.padPlayFade.value * 0.7)) : nil,
                   value: playing)
        .animation(Labs.padPlayFade.value > 0 ? .easeOut(duration: Labs.padPlayFade.value) : nil, value: session.playing)
        .shadow(color: .black.opacity(selected ? Elevation.selected.shadow.opacity : 0),
                radius: Elevation.selected.shadow.radius, y: selected ? Elevation.selected.shadow.y : 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// "T1 Drums, entry B, pattern 02, 8 times, bars 5 to 12, also on entry D"
    private var spoken: String {
        let from = Int(block.start / SongPlacement.ticksPerBar) + 1
        let to = max(from, Int((block.end / SongPlacement.ticksPerBar).rounded(.up)))
        var s = "T\(track + 1) \(Entries.trackName(track, session: session)), entr\(block.isChain ? "ies" : "y") \(Entries.letters(block.entries)), "
        s += isRest ? "rest" : block.isChain ? "chain \(label)" : "pattern \(label)"
        s += loops ? ", loops" : ", \(block.reps) time\(block.reps == 1 ? "" : "s")"
        s += ", bars \(from) to \(to)"
        let others = list.sharing(block.entries.lowerBound)
        if !isRest, !others.isEmpty { s += ", also on entr\(others.count == 1 ? "y" : "ies") " + others.map(Entries.letter).joined(separator: ", ") }
        if let snd = sound { s += ", sound \(Entries.soundName(snd, session: session))" }
        if let state { s += ", " + state } else if playing { s += ", playing now" }
        return s
    }
}

/// A block's outline; an entry with a sound has its top right corner cut, as on Skiff's own screen.
struct BlockShape: Shape {
    var cut: CGFloat = 0
    func path(in r: CGRect) -> Path {
        guard cut > 0 else { return Path(roundedRect: r, cornerRadius: 6) }
        var p = Path()
        let c = min(cut, r.width / 2)
        p.move(to: CGPoint(x: r.minX + 6, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 6, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 6, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 6), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 6))
        p.addQuadCurve(to: CGPoint(x: r.minX + 6, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        return p
    }
}

/// A thin divider at each part of a chain, every pass.
struct ChainDividers: View {
    let parts: [Double]
    let reps: Int
    var body: some View {
        let _ = BodyCounter.tick("ChainDividers")
        GeometryReader { g in
            let total = parts.reduce(0, +) * Double(reps)
            Path { p in
                var at = 0.0
                for k in 0..<(parts.count * reps - 1) {
                    at += parts[k % parts.count]
                    let x = g.size.width * at / max(1, total)
                    p.addRect(CGRect(x: x - 1, y: 0, width: 2, height: g.size.height))
                }
            }
            .fill(Theme.page)
        }
        .allowsHitTesting(false)
    }
}

/// One line through every lane: MIDI clock counted since Start, wrapped at the song's end. Lanes that end
/// apart loop apart, so on those it's where the song's top would be.
struct SongPlayhead: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let barWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let _ = BodyCounter.tick("SongPlayhead")
        // the song's length once per body, not per frame (laneEnds places every lane's blocks); 30 frames a second
        // move a 2 pt line smoothly enough at any tempo
        let songTicks = (store.laneEnds.max() ?? 0) * SongPlacement.ticksPerBar
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.playing)) { _ in
            let ticks = session.clockTicks
            if ticks >= 0, songTicks > 0 {
                let at = Double(ticks).truncatingRemainder(dividingBy: songTicks)
                Rectangle().fill(Theme.text).frame(width: 2, height: height + 8)
                    .offset(x: CGFloat(at / SongPlacement.ticksPerBar) * barWidth + 1, y: -4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A REST that opens to hold a gap: it grows from its left edge, and closes back into it. A scale, not a
/// mask: at full size it's no change at all, so nothing is ever clipped.
struct Reveal: ViewModifier {
    var amount: CGFloat
    func body(content: Content) -> some View {
        content.scaleEffect(x: max(0.001, amount), y: 1, anchor: .leading)
    }
}

extension AnyTransition {
    /// In with the rearrange's own motion; out faster (exits quicker than entrances).
    static var accordion: AnyTransition {
        .asymmetric(insertion: .modifier(active: Reveal(amount: 0), identity: Reveal(amount: 1)),
                    removal: AnyTransition.modifier(active: Reveal(amount: 0), identity: Reveal(amount: 1))
                        .animation(.easeIn(duration: 0.16)))
    }
}

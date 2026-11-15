import SwiftUI

// Labs (Scott, 2026-11-09): values and gestures still being settled by feel, set from Settings › Labs instead of asked
// for one round at a time. Each item is dated with a review two weeks on: by then it's either made the default (and
// leaves Labs) or it's gone, so Labs never becomes a second settings menu. Unbuilt features join it when they're built
// (jam capture, wait-for-the-first-note recording).

/// One value under trial: where it's stored, its range and step, the shipped default, and its dates.
struct LabItem: Identifiable {
    let key: String
    let title: String
    let detail: String
    let range: ClosedRange<Double>
    let step: Double
    let standard: Double
    /// How the value reads: "%.2f s", "%.0f pt".
    let format: String
    let added: String
    let review: String
    var id: String { key }

    var value: Double {
        get { (UserDefaults.standard.object(forKey: key) as? Double).map { min(max($0, range.lowerBound), range.upperBound) } ?? standard }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    var changed: Bool { abs(value - standard) > step / 2 }
    func reset() { UserDefaults.standard.removeObject(forKey: key) }
}

enum Labs {
    // Scott, 2026-11-10 (motion options cleaned up): plain names, a line saying what you'd notice, no review dates on the
    // rows. Two values moved to Settings › Touch for good (holdToMenu, columnTravel: same keys, so what was set carries
    // over); the divider's two springs became one feel (DividerFeel); menus one speed; the two pad-drag distances one;
    // three cut and fixed (the track-controls gap, grid pan start, flick speed).

    // MARK: Motion

    static let menuOpen = LabItem(
        key: "labs.menuOpen", title: "Menu speed", detail: "How quickly menus open from your finger. They close in two thirds of it.",
        range: 0.1...0.5, step: 0.02, standard: 0.24, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")
    /// Closing follows opening (was its own value, "Menus: closing", 0.16 s: two thirds of 0.24).
    static var menuCloseTime: Double { menuOpen.value * 2 / 3 }
    static let songSlide = LabItem(
        key: "labs.songSlide", title: "Switch between Pads and Timeline", detail: "How long the switch between Pads and the Timeline takes. 0 switches at once.",
        range: 0...0.6, step: 0.02, standard: 0.3, format: "%.2f s", added: "2026-11-08", review: "2026-11-23")
    /// The phone's tab change with the track thread (design/boards/tab-thread.html; Android's default). Added 2026-11-14.
    static let tabChange = LabItem(
        key: "labs.tabChange", title: "Tab change (iPhone)", detail: "How long Pads, Edit and Timeline take to slide past each other, the track's outline travelling between them.",
        range: 0.15...0.7, step: 0.01, standard: 0.38, format: "%.2f s", added: "2026-11-14", review: "2026-11-28")
    /// The phone's hold menu (design/boards/radial-menu.html): how far its circle springs past its size, and its speed.
    static let menuSpring = LabItem(
        key: "labs.menuSpring", title: "Hold menu spring (iPhone)", detail: "How far the hold menu's circle springs past its size as it opens. 0 is a plain ease-out.",
        range: 0...100, step: 5, standard: 60, format: "%.0f", added: "2026-11-14", review: "2026-11-28")
    static let menuSpeed = LabItem(
        key: "labs.menuSpeed", title: "Hold menu speed (iPhone)", detail: "How quickly the hold menu draws out, in percent of the mockup's timing.",
        range: 50...200, step: 10, standard: 100, format: "%.0f %%", added: "2026-11-14", review: "2026-11-28")
    /// The edge wells for a dragged pad (board 81.4, 2026-11-15): how long they take to slide in (out takes 72 % of it),
    /// how near the pad's centre comes before a well starts to glow, and how near before it's hot (a drop lands there).
    static let wellSlide = LabItem(
        key: "labs.wellSlide", title: "Pad drag wells: slide in", detail: "How long the Clear, Edit and Duplicate wells take to slide in from the edges when a pad lifts.",
        range: 0.1...0.5, step: 0.01, standard: 0.22, format: "%.2f s", added: "2026-11-15", review: "2026-11-29")
    // (Scott, 2026-11-15: by axis) the glow starts at a share of the screen's extent along the well's axis, so the side
    // wells (a drag across the width) light sooner than the top and bottom ones; hot nearer for those, farther for the sides
    static let wellGlow = LabItem(
        key: "labs.wellGlowShare", title: "Pad drag wells: glow distance, top and bottom", detail: "How far out the dragged pad starts the top and bottom wells glowing, as a share of the screen's height; the glow grows steadily to full at the hot distance.",
        range: 20...70, step: 1, standard: 45, format: "%.0f %%", added: "2026-11-15", review: "2026-11-29")
    static let wellGlowSide = LabItem(
        key: "labs.wellGlowSideShare", title: "Pad drag wells: glow distance, sides", detail: "How far out the dragged pad starts the Edit and Duplicate wells glowing, as a share of the screen's width.",
        range: 20...70, step: 1, standard: 45, format: "%.0f %%", added: "2026-11-15", review: "2026-11-29")
    static let wellHot = LabItem(
        key: "labs.wellHot", title: "Pad drag wells: hot distance, top and bottom", detail: "How near the dragged pad comes before a top or bottom well is hot and a drop there acts.",
        range: 24...128, step: 4, standard: 64, format: "%.0f pt", added: "2026-11-15", review: "2026-11-29")
    static let wellHotSide = LabItem(
        key: "labs.wellHotSide", title: "Pad drag wells: hot distance, sides", detail: "How near the dragged pad comes before the Edit or Duplicate well is hot.",
        range: 32...192, step: 4, standard: 96, format: "%.0f pt", added: "2026-11-15", review: "2026-11-29")
    static let padPlayFade = LabItem(
        key: "labs.padPlayFade", title: "Pad colour fade on play", detail: "How gently pads light up when play starts (and go out, a little quicker, on stop). 0: at once.",
        range: 0...0.5, step: 0.05, standard: 0.2, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")

    // MARK: Touch, still being tried

    static let holdToPaint = LabItem(
        key: "labs.holdToPaint", title: "Hold before painting notes", detail: "How long you press on the piano roll before it paints or selects notes.",
        range: 0.15...0.8, step: 0.05, standard: 0.35, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")
    static let padSlideStart = LabItem(
        key: "labs.padSlideStart", title: "Pad drag: move before it lifts", detail: "How far you slide a pad before it picks up, after a hold or straight from a press.",
        range: 4...30, step: 1, standard: 8, format: "%.0f pt", added: "2026-11-10", review: "2026-11-24")
    static let padSlideDwell = LabItem(
        key: "labs.padSlideDwell", title: "Pad drag: press before sliding", detail: "A slide quicker than this after you touch is a swipe and doesn't pick the pad up.",
        range: 0.05...0.4, step: 0.01, standard: 0.15, format: "%.2f s", added: "2026-11-10", review: "2026-11-24")

    // MARK: In Settings › Touch now (kept here for their keys and ranges)

    static let holdToMenu = LabItem(
        key: "labs.holdToMenu", title: "Hold before a menu", detail: "How long you press a pad, block or track before its menu opens. Shorter is quicker but easier to set off by accident.",
        range: 0.25...0.9, step: 0.05, standard: 0.45, format: "%.2f s", added: "2026-11-09", review: "—")
    static let columnTravel = LabItem(
        key: "labs.columnTravel", title: "Slide for a full turn", detail: "How far you slide a value across its whole range.",
        range: 120...480, step: 10, standard: 240, format: "%.0f pt", added: "2026-11-09", review: "—")

    // MARK: Cut (2026-11-10), fixed at what they were

    /// The gap between a pad and its hanging controls at Max (where the controls no longer show).
    static let padControlsGap: CGFloat = 8
    /// How far one finger moves on the piano roll before it scrolls the grid.
    static let panStart: CGFloat = 10
    /// How fast a flick of the editor's tab moves it one place on.
    static let flickSpeed: CGFloat = 700

    /// (the iPhone's three only on the phone: the iPad's Labs stay as they were)
    @MainActor static var sections: [(title: String, items: [LabItem])] { [
        ("Motion", [menuOpen, songSlide, padPlayFade] + (UIDevice.current.userInterfaceIdiom == .phone ? [tabChange, menuSpring, menuSpeed] : [])),
        ("Touch", [holdToPaint, padSlideStart, padSlideDwell, wellSlide, wellGlow, wellHot, wellGlowSide, wellHotSide]),
    ] }
    @MainActor static var all: [LabItem] { sections.flatMap(\.items) }

    /// Once: values set under keys that merged carry over (the old pad-drag-after-a-hold distance into the one pad-drag
    /// distance, when only it was set). The divider's springs carry over in DividerFeel.
    static func migrate() {
        let d = UserDefaults.standard
        if d.object(forKey: padSlideStart.key) == nil, d.object(forKey: "labs.padDragStart") != nil { d.set(d.double(forKey: "labs.padDragStart"), forKey: padSlideStart.key) }
        d.removeObject(forKey: "labs.padDragStart")
        if d.object(forKey: "labs.menuClose") != nil, d.object(forKey: menuOpen.key) == nil {
            d.set(min(0.5, max(0.1, d.double(forKey: "labs.menuClose") * 1.5)), forKey: menuOpen.key)      // closing was two thirds of opening by default
        }
        d.removeObject(forKey: "labs.menuClose")
        for k in ["labs.padControlsGap", "labs.panStart", "labs.flickSpeed"] { d.removeObject(forKey: k) }
    }
}

/// The editor divider's landing, as one choice (was two sliders: its spring's speed and its bounce). Balanced is
/// Scott's own tuning (bounce 0.86, on his iPad 2026-11-10), so his setting carries over exactly.
enum DividerFeel: String, CaseIterable, Identifiable {
    case snappy, balanced, bouncy
    static let key = "dividerFeel"
    var id: String { rawValue }
    var title: String { switch self { case .snappy: "Snappy"; case .balanced: "Balanced"; case .bouncy: "Bouncy" } }
    var response: Double { switch self { case .snappy: 0.30; case .balanced: 0.38; case .bouncy: 0.46 } }
    var damping: Double { switch self { case .snappy: 1.0; case .balanced: 0.86; case .bouncy: 0.62 } }

    /// The one chosen; or, before any choice, the one nearest the old sliders (their bounce), else Balanced.
    static var current: DividerFeel {
        let d = UserDefaults.standard
        if let s = d.string(forKey: key), let f = DividerFeel(rawValue: s) { return f }
        if d.object(forKey: "labs.dividerDamping") != nil {
            let damp = d.double(forKey: "labs.dividerDamping")
            return allCases.min { abs($0.damping - damp) < abs($1.damping - damp) } ?? .balanced
        }
        return .balanced
    }
}

/// Slide for a full turn (Settings › Touch): three named lengths for the column slide.
enum SlideLength: Double, CaseIterable, Identifiable {
    case fine = 360, normal = 240, quick = 160
    var id: Double { rawValue }
    var title: String { switch self { case .fine: "Fine"; case .normal: "Normal"; case .quick: "Quick" } }
    /// The one nearest the stored length (a length set on the old slider shows as its nearest, and stays as set until
    /// one is picked).
    static func nearest(_ v: Double) -> SlideLength { allCases.min { abs($0.rawValue - v) < abs($1.rawValue - v) } ?? .normal }
}

/// Settings › Labs: each trial as a slider with its value, its default and its review date, and a reset.
struct LabsSection: View {
    @State private var tick = 0          // a slider moved: redraw (UserDefaults isn't observed)

    var body: some View {
        let _ = tick
        ForEach(Labs.sections, id: \.title) { section in
            Section {
                if section.title == "Motion" { dividerRow }
                ForEach(section.items) { item in row(item) }
            } header: {
                Text("Labs · \(section.title)")
            } footer: {
                if section.title == Labs.sections.last?.title {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try-outs: each becomes the default or goes. Changes apply the next time the thing happens.")
                        if Labs.all.contains(where: \.changed) || UserDefaults.standard.string(forKey: DividerFeel.key) != nil {
                            Button("Put every Labs value back") {
                                Labs.all.forEach { $0.reset() }; UserDefaults.standard.removeObject(forKey: DividerFeel.key); tick += 1
                            }
                        }
                    }
                }
            }
        }
    }

    /// The editor divider's landing: one picker for what was a speed and a bounce.
    private var dividerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Editor divider", selection: Binding(get: { DividerFeel.current }, set: { UserDefaults.standard.set($0.rawValue, forKey: DividerFeel.key); tick += 1 })) {
                ForEach(DividerFeel.allCases) { Text($0.title).tag($0) }
            }
            Text("How the editor divider lands when you move it.").font(.lupe(12)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func row(_ item: LabItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                Spacer()
                Text(String(format: item.format, item.value)).monospacedDigit()
                    .foregroundStyle(item.changed ? Theme.text : Theme.textSecondary)
            }
            Slider(value: Binding(get: { item.value }, set: { item.value = ($0 / item.step).rounded() * item.step; tick += 1 }),
                   in: item.range)
                .accessibilityLabel(item.title)
                .accessibilityValue(String(format: item.format, item.value))
            HStack {
                Text("\(item.detail) Default \(String(format: item.format, item.standard)).")
                    .font(.lupe(12)).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                if item.changed {
                    Button("Reset") { item.reset(); tick += 1 }.font(.lupe(13))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

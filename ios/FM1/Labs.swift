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
    // MARK: Motion

    static let dividerResponse = LabItem(
        key: "labs.dividerResponse", title: "Divider spring: speed", detail: "How long the Song tab's divider takes to settle.",
        range: 0.2...0.7, step: 0.02, standard: 0.38, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")
    static let dividerDamping = LabItem(
        key: "labs.dividerDamping", title: "Divider spring: bounce", detail: "Lower bounces more as it lands; 1 doesn't bounce.",
        range: 0.5...1, step: 0.02, standard: 0.72, format: "%.2f", added: "2026-11-09", review: "2026-11-23")
    static let menuOpen = LabItem(
        key: "labs.menuOpen", title: "Menus: opening", detail: "How long a menu takes to grow out of the finger.",
        range: 0.1...0.5, step: 0.02, standard: 0.24, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")
    static let menuClose = LabItem(
        key: "labs.menuClose", title: "Menus: closing", detail: "How long it takes to close back into it.",
        range: 0.06...0.4, step: 0.02, standard: 0.16, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")

    // MARK: Gestures

    static let holdToMenu = LabItem(
        key: "labs.holdToMenu", title: "Hold for a menu", detail: "How long a press is held before its menu opens.",
        range: 0.25...0.9, step: 0.05, standard: 0.45, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")
    static let holdToPaint = LabItem(
        key: "labs.holdToPaint", title: "Hold to paint steps", detail: "How long a press on the grid is held before it paints or lassos.",
        range: 0.15...0.8, step: 0.05, standard: 0.35, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")
    static let panStart = LabItem(
        key: "labs.panStart", title: "Grid pan starts after", detail: "How far one finger moves on the grid before it pans.",
        range: 4...24, step: 1, standard: 10, format: "%.0f pt", added: "2026-11-09", review: "2026-11-23")
    static let flickSpeed = LabItem(
        key: "labs.flickSpeed", title: "Editor divider: flick at", detail: "How fast a flick of the editor's tab has to be to move it one place on (up or down), however short the flick.",
        range: 300...2000, step: 50, standard: 700, format: "%.0f pt/s", added: "2026-11-09", review: "2026-11-23")
    static let padDragStart = LabItem(
        key: "labs.padDragStart", title: "Pad drag starts after", detail: "How far a held pad moves before it lifts to be dragged.",
        range: 4...30, step: 1, standard: 10, format: "%.0f pt", added: "2026-11-09", review: "2026-11-23")
    static let columnTravel = LabItem(
        key: "labs.columnTravel", title: "Column slide: full range in", detail: "How far a slide on a value column goes from its lowest to its highest.",
        range: 120...480, step: 10, standard: 240, format: "%.0f pt", added: "2026-11-09", review: "2026-11-23")

    // MARK: Layout

    static let padControlsGap = LabItem(
        key: "labs.padControlsGap", title: "Track controls: gap under the pad", detail: "Space between the selected pad and the track controls hanging from it, so the controls don't sit too high (Scott: the same gap the pads keep).",
        range: 0...24, step: 1, standard: 8, format: "%.0f pt", added: "2026-11-09", review: "2026-11-23")

    static let padPlayFade = LabItem(
        key: "labs.padPlayFade", title: "Pads: play colours fade in", detail: "How long the playing pads' colours take to come in when play starts; they go out on stop in 0.7 of it. 0: no fade.",
        range: 0...0.5, step: 0.05, standard: 0.2, format: "%.2f s", added: "2026-11-09", review: "2026-11-23")

    static let songSlide = LabItem(
        key: "labs.songSlide", title: "Pads and Timeline: slide", detail: "How long the Timeline takes to slide down behind the editor as the pads come in from above, and back. 0 switches at once.",
        range: 0...0.6, step: 0.02, standard: 0.3, format: "%.2f s", added: "2026-11-08", review: "2026-11-23")

    static let sections: [(title: String, items: [LabItem])] = [
        ("Motion", [dividerResponse, dividerDamping, menuOpen, menuClose, songSlide, padPlayFade]),
        ("Gestures", [holdToMenu, holdToPaint, panStart, padDragStart, columnTravel, flickSpeed]),
        ("Layout", [padControlsGap]),
    ]
    static var all: [LabItem] { sections.flatMap(\.items) }
}

/// Settings › Labs: each trial as a slider with its value, its default and its review date, and a reset.
struct LabsSection: View {
    @State private var tick = 0          // a slider moved: redraw (UserDefaults isn't observed)

    var body: some View {
        let _ = tick
        ForEach(Labs.sections, id: \.title) { section in
            Section {
                ForEach(section.items) { item in row(item) }
            } header: {
                Text("Labs · \(section.title)")
            } footer: {
                if section.title == Labs.sections.last?.title {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try-outs, each with a review date: by then it becomes the default or goes. Changes apply the next time the thing happens.")
                        if Labs.all.contains(where: \.changed) {
                            Button("Put every Labs value back") { Labs.all.forEach { $0.reset() }; tick += 1 }
                        }
                    }
                }
            }
        }
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
                Text("\(item.detail) Default \(String(format: item.format, item.standard)). Review \(item.review).")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                if item.changed {
                    Button("Reset") { item.reset(); tick += 1 }.font(.system(size: 13))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

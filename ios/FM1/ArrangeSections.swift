import SloopKit
import SwiftUI

// The song's sections over the timeline: a range of bars and the bar that shows them.

/// A bar range across the lanes: its first bar and the bar after its last, 0-based.
struct SectionRange: Equatable {
    var from: Int
    var to: Int
}

/// The section's bar (board 3): the range, two steppers to set it without a drag, Duplicate after (the
/// view's one primary) and Clear, and for each track whose passes can't meet the range, snap or leave out.
struct SectionBar: View {
    let range: SectionRange
    let songBars: Int
    let plans: [SectionTrack]
    @Binding var leftOut: Set<Int>
    let busy: Bool
    let set: (SectionRange) -> Void
    let apply: (SectionOp) -> Void
    let cancel: () -> Void

    var body: some View {
        let _ = BodyCounter.tick("SectionBar")
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Text("Bars \(range.from + 1)–\(range.to)").font(.lupe(15, .semibold)).fixedSize()
                Text("from").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                StepperKeys(label: "First bar", value: range.from + 1, range: 1...max(1, range.to), step: 1) {
                    set(SectionRange(from: $0 - 1, to: range.to))
                }
                Text("to").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                StepperKeys(label: "Last bar", value: range.to, range: (range.from + 1)...max(range.from + 1, songBars + 16), step: 1) {
                    set(SectionRange(from: range.from, to: $0))
                }
                key("Duplicate after", primary: true) { apply(.duplicateAfter) }
                key("Clear") { apply(.clear) }
                ForEach(plans.filter { !$0.exact && $0.from != nil }, id: \.track) { p in
                    HStack(spacing: 6) {
                        Text("T\(p.track + 1):").font(.lupe(13)).foregroundStyle(Theme.textSecondary)
                        SegmentedKeys(label: "Track \(p.track + 1) in this section", options: ["Snap to its passes", "Leave it out"],
                                      selected: leftOut.contains(p.track) ? 1 : 0) { k in
                            if k == 1 { leftOut.insert(p.track) } else { leftOut.remove(p.track) }
                        }
                    }
                }
                Button(action: cancel) {
                    Text("Cancel").font(.lupe(15)).foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bars \(range.from + 1) to \(range.to) on every track")
    }

    private func key(_ title: String, primary: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.lupe(15, primary ? .semibold : .regular))
                .foregroundStyle(primary ? Theme.onColour : Theme.text)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .raisedKey(9, primary: primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(busy)
    }
}

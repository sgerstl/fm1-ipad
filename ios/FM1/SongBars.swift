import SloopKit
import SwiftUI
import UIKit

// SLOOP's song: a section's bars as pills and the control that sets them.

/// One pill per bar along the bottom of a block, filling as the song plays it (the bar playing fills
/// gradually); too many to draw apart, one bar that fills. Sized from the block's width, with no
/// geometry reader, so the pills move with the block in the same animation.
struct BarPills: View {
    let count: Int
    /// Bars played, the fraction of the one playing included (2.4: two full, the third 40 % through).
    let played: Double
    let width: CGFloat

    var body: some View {
        let n = max(count, 1)
        let gap: CGFloat = count > 16 ? 2 : 3
        let pw = (width - gap * CGFloat(n - 1)) / CGFloat(n)
        Group {
            if pw >= 3 {
                HStack(spacing: gap) {
                    ForEach(0..<n, id: \.self) { k in
                        pill(width: pw, fill: min(max(played - Double(k), 0), 1))
                    }
                }
            } else {
                pill(width: width, fill: min(max(played / Double(n), 0), 1))
            }
        }
        .frame(width: max(0, width), height: 6, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func pill(width w: CGFloat, fill: Double) -> some View {
        Capsule().fill(Theme.onColour.opacity(0.22))
            .overlay(alignment: .leading) {
                if fill > 0 {
                    Capsule().fill(Theme.onColour.opacity(0.8)).frame(width: max(6, w * CGFloat(fill)))
                }
            }
            .frame(width: max(0, w))
    }
}

/// A step's bars: − and + for one bar at a time (no drag needed, WCAG 2.5.7), and a slider whose
/// stops 1, 2, 4 … 64 sit evenly apart, snapping when the finger is near one.
struct BarsControl: View {
    let bars: Int
    var enabled = true
    let set: (Int) -> Void

    static let width: CGFloat = 540
    static let stops = [1, 2, 4, 8, 16, 32, 64]

    var body: some View {
        HStack(spacing: 10) {
            key("minus", "One bar fewer") { set(max(1, bars - 1)) }
                .disabled(!enabled || bars <= 1)
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Theme.well).frame(width: w - 24, height: 6).offset(x: 12, y: 13)
                    Capsule().fill(Theme.textSecondary).frame(width: max(6, pos(bars, w) - 12), height: 6).offset(x: 12, y: 13)
                    ForEach(Self.stops, id: \.self) { s in
                        Text("\(s)").font(.lupe(11, s == bars ? .semibold : .regular)).monospacedDigit()
                            .foregroundStyle(s == bars ? Theme.text : Theme.textSecondary)
                            .position(x: pos(s, w), y: 38)
                    }
                    Circle().fill(Theme.text).frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .position(x: pos(bars, w), y: 16)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    guard enabled else { return }
                    let b = value(at: v.location.x, w)
                    if b != bars { set(b) }
                })
                .accessibilityElement()
                .accessibilityLabel("Bars")
                .accessibilityValue("\(bars)")
                .accessibilityAdjustableAction { dir in
                    guard enabled else { return }
                    set(dir == .increment ? min(64, bars + 1) : max(1, bars - 1))
                }
            }
            .frame(height: 48)
            key("plus", "One bar more") { set(min(64, bars + 1)) }
                .disabled(!enabled || bars >= 64)
            Text("\(bars) bar\(bars == 1 ? "" : "s")").font(.lupe(17, .semibold)).monospacedDigit()
                .frame(width: 76, alignment: .leading)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background {
            Color.clear.elevated(.held)
        }
    }

    private func pos(_ b: Int, _ w: CGFloat) -> CGFloat { 12 + log2(CGFloat(max(1, b))) / 6 * (w - 24) }

    private func value(at x: CGFloat, _ w: CGFloat) -> Int {
        if let near = Self.stops.first(where: { abs(pos($0, w) - x) < 10 }) { return near }
        let p = min(max((x - 12) / (w - 24), 0), 1)
        return max(1, min(64, Int(pow(2, p * 6).rounded())))
    }

    private func key(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40).raisedKey()
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(label)
    }
}

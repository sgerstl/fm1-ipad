import SloopKit
import SwiftUI

// Shape's columns, as Skiff's own pages draw their four cards (ui_draw.c draw_column): the label with the knob's
// number, the value large with its unit, a thin gauge in the track's colour. The column of the knob just turned is
// marked (Skiff's hot card, ui.hot_t: about 600 ms). A changed value rolls its digits as Skiff's do (roll_text).
// Design: canvas boards 17 and 18 (lupe/shape.py), 2026-11-05. The column turning was white all over until Scott tried
// it on the FM-1: now a 3 pt white bar along its top, its own colours kept (2026-11-05).

/// A value split as a column shows it: the figures large, the unit small after them.
func splitUnit(_ shown: String) -> (value: String, unit: String) {
    if shown.hasSuffix("%"), shown.count > 1 { return (String(shown.dropLast()), "%") }
    if let sp = shown.lastIndex(of: " ") {
        let u = String(shown[shown.index(after: sp)...])
        if ["Hz", "kHz", "ms", "s", "dB", "st", "ct", "bpm", "BPM", "/11"].contains(u) { return (String(shown[..<sp]), u) }
    }
    return (shown, "")
}

/// A knob as one of Skiff's columns.
struct ColumnFace: View {
    let spec: KnobSpec
    let number: Int
    let tint: Color
    let hot: Bool
    /// A value that doesn't turn here (MOD's fixed routes' SOURCE and DEST): dim, no gauge.
    var dim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.knobsRecording) private var recording

    var body: some View {
        let _ = BodyCounter.tick("ColumnFace")
        let (value, unit) = splitUnit(spec.shown)
        let ink = dim ? Theme.textTertiary : Theme.text
        let label = Theme.textSecondary
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(spec.label).font(.system(size: 11)).tracking(0.5).foregroundStyle(label).lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if number > 0 {       // 0: not one of the FM-1's four knobs
                    Text("\(number)").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(hot ? Theme.text : Theme.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.control))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                RollingText(text: value, size: 22).id(spec.id)
                if !unit.isEmpty { Text(unit).font(.system(size: 11, weight: .medium)).foregroundStyle(label) }
            }
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Gauge(fraction: dim ? 0 : spec.fraction, bipolar: spec.bipolar, tint: tint, track: Theme.stepEmpty)
                .frame(height: 3)
                .padding(.horizontal, -10)
                .padding(.top, 6)
        }
        .padding(.top, 8).padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.well))
        // the knob turning (here or on the FM-1, held 600 ms): a white bar along the top, the column as it is
        .overlay(alignment: .top) { Rectangle().fill(Theme.text).frame(height: 3).opacity(hot ? 1 : 0).accessibilityHidden(true) }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        // recorded: a red ring, as the REC banner says (board 16)
        .overlay { if recording, !dim { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.rec, lineWidth: 2) } }
        .accessibilityValue(recording && !dim ? "recording" : "")
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hot)
    }

    /// The gauge along the column's foot: from the left, or from the middle on a value centred on zero.
    private struct Gauge: View {
        let fraction: Double, bipolar: Bool, tint: Color, track: Color
        var body: some View {
            Canvas { ctx, sz in
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(track))
                let f = CGFloat(min(max(fraction, 0), 1)) * sz.width, from = bipolar ? sz.width / 2 : 0
                ctx.fill(Path(CGRect(x: min(from, f), y: 0, width: max(abs(f - from), bipolar ? 2 : 0), height: sz.height)), with: .color(tint))
            }
            .accessibilityHidden(true)
        }
    }
}

/// Skiff is recording knob moves into these columns' parameters (REC armed, playing, the selected track's own).
private struct KnobsRecordingKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var knobsRecording: Bool {
        get { self[KnobsRecordingKey.self] }
        set { self[KnobsRecordingKey.self] = newValue }
    }
}

/// An empty column: a slot the page doesn't use.
struct EmptyColumn: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6).fill(Theme.well)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

// MARK: Rolling digits (Skiff ui_draw.c roll_text)

/// Text whose changed digits roll like a slot machine when it changes: up, the old digit leaves upward and the
/// new one comes from below; down, the reverse. 9 frames of 15 ms on Skiff's ease (ROLL_EASE), the ones digit
/// first and each place a frame later, all ending together. Shown at once: a change within 45 ms of the last
/// (ROLL_SNAP), another shape (length, sign, a non-digit, a name), Reduce Motion (Skiff's ANIM OFF).
struct RollingText: View {
    let text: String
    var size: CGFloat = 22
    @State private var from = ""
    @State private var dir = 0
    @State private var t0 = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let frames = 9, frame = 0.015, snapFrames = 3
    static let ease: [Double] = [0, 45, 84, 118, 147, 172, 193, 210, 223, 234, 242, 247, 251, 253, 254, 255, 255]

    var body: some View {
        let font = Font.system(size: size, weight: .semibold).monospacedDigit()
        TimelineView(.animation(paused: from.isEmpty)) { tl in
            let e = Int(tl.date.timeIntervalSince(t0) / Self.frame) + 1
            HStack(spacing: 0) {
                let chars = Array(text), old = Array(from)
                let rolling = !from.isEmpty && e < Self.frames && old.count == chars.count
                // the digits to the right of each character: each place starts a frame after the one right of it
                let right = chars.indices.map { i in chars[(i + 1)...].filter(\.isNumber).count }
                ForEach(chars.indices, id: \.self) { i in
                    if rolling, chars[i] != old[i] {
                        RollDigit(old: old[i], new: chars[i], dir: dir, offset: Self.offset(e: e, places: right[i]), font: font, size: size)
                    } else {
                        Text(String(chars[i])).font(font)
                    }
                }
            }
        }
        .tracking(-0.02 * size)
        .accessibilityElement()
        .accessibilityLabel(text)
        .onChange(of: text) { a, b in note(a, b) }
    }

    /// How far (0…1 of the strip) a digit with `places` digits to its right has moved at frame e.
    static func offset(e: Int, places p: Int) -> Double {
        guard e > p, frames > p else { return 0 }
        let idx = min(16, max(1, ((e - p) * 32 / (frames - p) + 1) >> 1))
        return ease[idx] / 256
    }

    /// +1 / −1: b rolls in from a; 0: b is shown at once (roll_dir).
    static func direction(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        guard x.count == y.count, !x.isEmpty else { return 0 }
        var d = 0, neg = false
        for i in x.indices {
            if x[i].isNumber != y[i].isNumber { return 0 }
            if !x[i].isNumber, x[i] != y[i] || !"+-.−".contains(x[i]) { return 0 }
            if x[i] == "-" || x[i] == "−" { neg = true }
            if d == 0, x[i] != y[i] { d = y[i] > x[i] ? 1 : -1 }
        }
        return neg ? -d : d
    }

    private func note(_ a: String, _ b: String) {
        let now = Date()
        let el = now.timeIntervalSince(t0) / Self.frame
        let d = Self.direction(a, b)
        t0 = now
        guard d != 0, el >= Double(Self.snapFrames), !reduceMotion else { from = ""; return }
        from = a; dir = d
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Double(Self.frames) * Self.frame))
            if t0 == now { from = "" }
        }
    }
}

/// One rolling digit: the old one leaving and the new one coming, clipped to the line.
private struct RollDigit: View {
    let old: Character, new: Character
    let dir: Int, offset: Double
    let font: Font, size: CGFloat

    var body: some View {
        let h = size * 1.2
        ZStack {
            Text(String(old)).font(font).offset(y: -CGFloat(dir) * offset * h)
            Text(String(new)).font(font).offset(y: CGFloat(dir) * (1 - offset) * h)
        }
        .frame(height: h)
        .clipped()
    }
}

import SloopKit
import SwiftUI

/// The selected step, read-only in step 1. Values sit in wells, not on keys: under the brief's
/// "raised to press, recessed to read", nothing here can be pressed yet.
struct SelectedStepPanel: View {
    let session: SloopSession
    let ui: EditorUI

    var body: some View {
        let t = session.selectedTrack
        let i = ui.selectedStep[t]
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text("Step \(i + 1)").font(.system(size: 22, weight: .semibold))
            }
            .frame(width: 96, alignment: .leading)
            .accessibilityElement(children: .combine)

            if t == 3 { drumDetails(session.tracks[3].drumSteps[i]) } else { synthDetails(session.tracks[t].steps[i], track: t) }

            Spacer(minLength: 0)
            KnobRow(session: session)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected step")
    }

    @ViewBuilder private func synthDetails(_ s: SynthStep, track: Int) -> some View {
        field("Notes") {
            HStack(spacing: 8) {
                if s.time == .note && !s.notes.isEmpty {
                    ForEach(Array(s.notes.enumerated()), id: \.offset) { _, n in
                        readout(Music.noteName(n)).accessibilityLabel(Music.spokenNoteName(n))
                    }
                } else {
                    readout(s.time == .tie ? "Held" : "None", dim: true)
                }
            }
        }
        field("Velocity \(s.isOn ? "\(s.velocity)" : "–")") {
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.well).frame(height: 6)
                Capsule().fill(Theme.pad(track)).frame(width: s.isOn ? 150 * CGFloat(s.velocity) / 127 : 0, height: 6)
            }
            .frame(width: 150, height: 44)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(s.isOn ? "Velocity \(s.velocity)" : "Velocity, none")
        field("Step") {
            indicator(["Note", "Tie", "Rest"], lit: s.time.rawValue)
        }
        field("Feel") {
            HStack(spacing: 8) {
                lamp("Accent", on: s.accent && s.isOn)
                lamp("Slide", on: s.slide && s.isOn)
            }
        }
    }

    @ViewBuilder private func drumDetails(_ s: DrumStep) -> some View {
        let lane = ui.selectedLane
        field("Hits") {
            HStack(spacing: 8) {
                if s.lanes.isEmpty { readout("None", dim: true) }
                ForEach(s.lanes.prefix(5), id: \.self) { l in
                    lamp(Music.drumLanes[l], on: l == lane)
                }
                if s.lanes.count > 5 { readout("+\(s.lanes.count - 5)", dim: true) }
            }
        }
        field("\(Music.drumLanes[lane]) level") {
            indicator(Music.levelNames, lit: s.has(lane) ? s.level(lane) : -1)
        }
        field("\(Music.drumLanes[lane]) ratchet") {
            indicator(["×1", "×2", "×3", "×4"], lit: s.has(lane) ? s.ratchet(lane) : -1)
        }
    }

    // MARK: Read-outs (recessed)

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            content()
        }
        .accessibilityElement(children: .combine)
    }

    private func readout(_ text: String, dim: Bool = false) -> some View {
        Text(text)
            .foregroundStyle(dim ? Theme.textSecondary : Theme.text)
            .padding(.horizontal, 12)
            .frame(minWidth: 52, minHeight: 44)
            .recessed(9)
    }

    /// Which one of several is in force: the lit segment is bright with an LED, the rest are quiet.
    private func indicator(_ names: [String], lit: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(names.enumerated()), id: \.offset) { k, n in
                HStack(spacing: 6) {
                    if k == lit { LED(on: true) }
                    Text(n).fontWeight(k == lit ? .semibold : .regular)
                }
                .foregroundStyle(k == lit ? Theme.text : Theme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(k == lit ? 0.06 : 0)))
            }
        }
        .padding(4)
        .recessed(12)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(lit >= 0 && lit < names.count ? names[lit] : "none")
    }

    private func lamp(_ name: String, on: Bool) -> some View {
        HStack(spacing: 8) {
            LED(on: on)
            Text(name).foregroundStyle(on ? Theme.text : Theme.textSecondary).fontWeight(on ? .semibold : .regular)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .recessed(9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(on ? "on" : "off")")
    }
}

/// A read-only copy of the FM-1's four knobs on the studio home screen for the selected track
/// (firmware ui_studio.c, studio_tracks_draw): swing (the global groove), level, steps, pan.
/// Values are formatted as the device shows them.
struct KnobRow: View {
    let session: SloopSession

    var body: some View {
        let t = session.tracks[session.selectedTrack]
        let level = t.mute ? 0 : t.level * 100 / 127
        HStack(spacing: 10) {
            Knob(label: "SWING", value: "\(session.swing)", fraction: Double(session.swing) / 100, colour: Theme.knob[0])
            Knob(label: "LEVEL", value: t.mute ? "0" : "\(level)", fraction: t.mute ? 0 : Double(t.level) / 127, colour: Theme.knob[1],
                 spoken: t.mute ? "muted" : "\(level) percent")
            Knob(label: "STEPS", value: "\(t.length)", fraction: Double(t.length - 1) / 63, colour: Theme.knob[2])
            Knob(label: "PAN", value: "\(t.pan)", fraction: Double(t.pan + 64) / 127, colour: Theme.knob[3], bipolar: true,
                 spoken: t.pan == 0 ? "centre" : t.pan < 0 ? "\(-t.pan) left" : "\(t.pan) right")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .recessed(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track knobs, as on the FM-1 screen")
    }
}

struct Knob: View {
    var label: String
    var value: String
    var fraction: Double
    var colour: Color
    var bipolar = false
    var spoken: String?

    var body: some View {
        VStack(spacing: 3) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let f = min(max(fraction, 0), 1)
                func arc(_ a: Double, _ b: Double) -> Path {
                    Path { p in p.addArc(center: c, radius: 17, startAngle: .degrees(a - 90), endAngle: .degrees(b - 90), clockwise: false) }
                }
                let style = StrokeStyle(lineWidth: 4, lineCap: .round)
                ctx.stroke(arc(-135, 135), with: .color(Color(hex: 0x25252B)), style: style)
                let a = -135 + 270 * f
                let from = bipolar ? 0.0 : -135.0
                if abs(a - from) > 0.5 { ctx.stroke(arc(min(from, a), max(from, a)), with: .color(colour), style: style) }
                // the cap: raised, as a knob is
                let cap = CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22)
                ctx.fill(Path(ellipseIn: cap.offsetBy(dx: 0, dy: 1)), with: .color(.black.opacity(0.5)))
                ctx.fill(Path(ellipseIn: cap), with: .radialGradient(Gradient(colors: [Color(hex: 0x5A5A63), Color(hex: 0x1F1F24)]),
                                                                    center: CGPoint(x: cap.minX + 9, y: cap.minY + 6.6), startRadius: 0, endRadius: 16))
                ctx.stroke(Path(ellipseIn: cap.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.12)), lineWidth: 1)
                let rad = a * .pi / 180
                ctx.stroke(Path { p in p.move(to: c); p.addLine(to: CGPoint(x: c.x + 9 * sin(rad), y: c.y - 9 * cos(rad))) },
                           with: .color(Theme.text), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .frame(width: 40, height: 40)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 13, weight: .semibold))
        }
        .frame(width: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.capitalized)
        .accessibilityValue(spoken ?? value)
    }
}

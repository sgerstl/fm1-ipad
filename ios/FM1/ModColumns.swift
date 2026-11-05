import SloopKit
import SwiftUI

/// Skiff's MOD page columns (ui_draw.c, GR_MOD): ROUTE picks one of eleven, then that route's SOURCE, DEST and
/// AMOUNT. Routes 1–7 are the fixed LFO → PITCH CUT SHAPE AMP and ENV → PITCH CUT SHAPE, whose AMOUNT alone turns
/// (their SOURCE and DEST dim); routes 8–11 are the matrix's slots. With the screen link's cursor (`56 01 02`) the
/// route is the FM-1's mod_ui_route, both ways (ShapeMarks.modRoute); without it, Lupe's own.
struct ModColumns: View {
    let session: DeviceSession
    let ui: EditorUI
    let page: SoundPage
    @Binding var route: Int
    let marked: String?
    let activate: () -> Bool

    static let fixedSource = ["LFO", "LFO", "LFO", "LFO", "ENV", "ENV", "ENV"]
    static let fixedDest = ["PITCH", "CUT", "SHAPE", "AMP", "PITCH", "CUT", "SHAPE"]

    var body: some View {
        let tint = Theme.track[session.selectedTrack]
        let r = min(max(route, 0), 10)
        let ids = page.routes[safe: r] ?? []
        HStack(spacing: 4) {
            KnobControl(ui: ui, activate: activate, column: (1, tint, false)) { routeSpec }
            if r < 7 {
                ColumnFace(spec: fixed("SOURCE", Self.fixedSource[r]), number: 2, tint: tint, hot: false, dim: true)
                    .accessibilityElement().accessibilityLabel("Source, \(Self.fixedSource[r]), fixed")
                ColumnFace(spec: fixed("DEST", Self.fixedDest[r]), number: 3, tint: tint, hot: false, dim: true)
                    .accessibilityElement().accessibilityLabel("Destination, \(Self.fixedDest[r]), fixed")
                column(ids[safe: 0] ?? nil, label: "AMOUNT", number: 4, tint: tint)
            } else {
                column(ids[safe: 0] ?? nil, label: "SOURCE", number: 2, tint: tint)
                column(ids[safe: 1] ?? nil, label: "DEST", number: 3, tint: tint)
                column(ids[safe: 2] ?? nil, label: "AMOUNT", number: 4, tint: tint)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var routeSpec: KnobSpec {
        KnobSpec(id: "mod.route", colour: Theme.knob[0], label: "ROUTE", value: route, range: 0...10, stepperStep: 1,
                 shown: "\(route + 1) /11", spoken: "route \(route + 1) of 11", bipolar: false, defaultValue: 0) { v in
            route = v
        }
    }

    private func fixed(_ label: String, _ value: String) -> KnobSpec {
        KnobSpec(id: "mod.\(label)", colour: Theme.knob[0], label: label, value: 0, range: 0...0, stepperStep: 1,
                 shown: value, spoken: value, bipolar: false) { _ in }
    }

    @ViewBuilder private func column(_ id: Int?, label: String, number: Int, tint: Color) -> some View {
        if let id {
            KnobControl(ui: ui, activate: activate, column: (number, tint, marked == "s0.\(id)")) {
                KnobSpec.param(session, scope: 0, id: id, slot: number - 1).relabelled(label)
            }
        } else {
            EmptyColumn()
        }
    }
}

extension KnobSpec {
    /// The same knob under another label (MOD's SRC1 shown as SOURCE, as Skiff's cards name it).
    func relabelled(_ l: String) -> KnobSpec {
        KnobSpec(id: id, colour: colour, label: l, value: value, range: range, stepperStep: stepperStep, shown: shown,
                 spoken: spoken, bipolar: bipolar, defaultValue: defaultValue, choices: choices, set: set)
    }
}

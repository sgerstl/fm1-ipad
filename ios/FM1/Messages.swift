import SloopKit
import SwiftUI

// Messages: one component, two homes (Scott, 2026-11-17, option C; design/DESIGN.md › Messages). Every passing message
// is a MessageRow. Anything about the app or the song goes to the one AppStrip at the foot (a refusal, Undo, a
// confirmation, over one ongoing state); a message about one panel goes under that panel's header, as the same row.
// Refusals and Undo never leave on a timer; a confirmation stays 4 s; a new message replaces the old. Each is announced.

enum MessageKind: Equatable {
    case refusal, undo, confirmation, ongoing

    var icon: String? {
        switch self {
        case .refusal: "exclamationmark.circle"
        case .undo: "arrow.uturn.backward"
        case .confirmation: "checkmark"
        case .ongoing: nil
        }
    }
}

/// A key on a message: its words, and what it does. `primary` is the white key (Keep that).
struct MessageAction {
    var title: String
    var systemImage: String? = nil
    var primary = false
    var hint: String? = nil
    var run: () -> Void
}

/// The one message row: the held surface, radius 12, Barlow 14 over an optional 13 line, an icon by kind (or the
/// caller's own lead: a track chip, REC's dot), its keys, ✕ last.
struct MessageRow<Lead: View>: View {
    let kind: MessageKind
    let text: String
    var detail: String? = nil
    var actions: [MessageAction] = []
    var dismiss: (() -> Void)? = nil
    var dismissLabel = "Dismiss"
    @ViewBuilder var lead: () -> Lead

    var body: some View {
        HStack(spacing: 10) {
            if let icon = kind.icon {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).frame(width: 20).accessibilityHidden(true)
            }
            lead()
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.lupe(14)).fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised).fixedSize(horizontal: false, vertical: true)
                }
            }
            .lineLimit(3)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            ForEach(actions.indices, id: \.self) { i in key(actions[i]) }
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dismissLabel)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.leading, 12).padding(.trailing, dismiss == nil ? 6 : 0)
        .frame(minHeight: 44)
        .frame(maxWidth: 560)
        .background(RoundedRectangle(cornerRadius: 12).fill(Elevation.held.surface).elevationShadow(.held))
        .accessibilityElement(children: .contain)
    }

    private func key(_ a: MessageAction) -> some View {
        Button(action: a.run) {
            HStack(spacing: 6) {
                if let s = a.systemImage { Image(systemName: s).font(.system(size: 12, weight: .semibold)) }
                Text(a.title).font(.lupe(14, .semibold))
            }
            .foregroundStyle(a.primary ? Theme.onColour : Theme.text)
            .padding(.horizontal, 14).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(a.primary ? Theme.text : Theme.control))
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityHint(a.hint ?? "")
    }
}

extension MessageRow where Lead == EmptyView {
    init(kind: MessageKind, text: String, detail: String? = nil, actions: [MessageAction] = [],
         dismiss: (() -> Void)? = nil, dismissLabel: String = "Dismiss") {
        self.init(kind: kind, text: text, detail: detail, actions: actions, dismiss: dismiss, dismissLabel: dismissLabel) { EmptyView() }
    }
}

/// A confirmation for the app strip: only when the result isn't already on screen. 4 s.
struct AppConfirmation: Equatable {
    var text: String
    var id = UUID()
}

extension EditorUI {
    /// Says a confirmation on the app strip for 4 s (and to VoiceOver).
    func confirm(_ text: String) { confirmation = AppConfirmation(text: text) }
}

/// How a message comes and goes: in 200 ms ease-out rising 16 with a fade, out 150 ms ease-in; Reduce Motion fades, 150 ms.
enum MessageMotion {
    static func transition(_ reduce: Bool) -> AnyTransition {
        reduce ? .opacity
            : .asymmetric(insertion: .offset(y: 16).combined(with: .opacity).animation(.easeOut(duration: 0.2)),
                          removal: .offset(y: 16).combined(with: .opacity).animation(.easeIn(duration: 0.15)))
    }
    static func animation(_ reduce: Bool, coming: Bool) -> Animation {
        reduce ? .easeOut(duration: 0.15) : coming ? .easeOut(duration: 0.2) : .easeIn(duration: 0.15)
    }
    static func announce(_ text: String) { AccessibilityNotification.Announcement(text).post() }
}

/// The app strip (both layouts): one message over one ongoing state, bottom centre.
struct AppStrip: View {
    let session: DeviceSession
    let ui: EditorUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slot: Slot?

    private enum Slot: Hashable { case refusal(String), padUndo(UUID), stepUndo, confirm(UUID) }
    private enum Ongoing: Hashable { case recording, take, scene(Int), apart(String) }

    private var store: SkiffSongStore? { session.skiffSong }

    /// The slot, while what it shows still stands.
    private var shown: Slot? {
        guard let slot else { return nil }
        switch slot {
        case .refusal(let t): return store?.refusal?.text == t ? slot : nil
        case .padUndo(let id):
            guard let store, let c = ui.padClear, c.id == id, !c.stripGone, ListUndo.undoable(ui, store) else { return nil }
            return slot
        case .stepUndo: return ui.lastClear != nil ? slot : nil
        case .confirm(let id): return ui.confirmation?.id == id ? slot : nil
        }
    }

    private var ongoing: Ongoing? {
        if session.recordingKnobs { return .recording }
        if ui.songTab, session.takeOffer != nil, !session.playing, session.takePicker == nil, !ui.phone { return .take }
        guard let store, ui.page == .song else { return nil }
        if ui.songView == .pads && store.performs {
            if let s = ui.previewScene, store.scenesSeen[s] == nil { return .scene(s) }
            return nil
        }
        if !ui.phone, let w = SkiffArrangePage.loopApart(store) { return .apart(w) }
        return nil
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let s = shown {
                    message(s).id(s).transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: shown)
            .transition(MessageMotion.transition(reduceMotion))
            ZStack {
                if let o = ongoing { ongoingRow(o).id(o).transition(MessageMotion.transition(reduceMotion)) }
            }
            .animation(MessageMotion.animation(reduceMotion, coming: ongoing != nil), value: ongoing)
        }
        .animation(MessageMotion.animation(reduceMotion, coming: shown != nil), value: shown == nil)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        // a new message takes the slot, and the one it replaces goes (an Undo stays in its thing's menu)
        .onChange(of: store?.refusal?.text) { _, t in if let t { take(.refusal(t)) } }
        .onChange(of: ui.padClear?.id) { _, id in if let id { take(.padUndo(id)) } }
        .onChange(of: ui.lastClear) { _, c in if c != nil { take(.stepUndo) } }
        .onChange(of: ui.confirmation?.id) { _, id in if let id { take(.confirm(id)) } }
        // anything else changing the song ends a pad's undo: its kept patterns go (ListUndo)
        .onChange(of: store?.undoStack.count) { _, n in
            if let c = ui.padClear, let store, c.depth != n { ui.padClear = nil; ListUndo.finish(c, store, session) }
        }
        .task(id: ui.confirmation?.id) {
            guard let id = ui.confirmation?.id else { return }
            try? await Task.sleep(for: .seconds(4))
            if ui.confirmation?.id == id { ui.confirmation = nil }
        }
        .onChange(of: ongoing) { _, o in if let o { MessageMotion.announce(spoken(o)) } }
        // -messages: a refusal with Stop on the demo, then a confirmation replacing it, for captures
        .task {
            guard LaunchArgs.all.contains("-messages") else { return }
            try? await Task.sleep(for: .seconds(4))
            store?.refuse(track: 0, entry: nil, "Stop to rearrange: the FM-1 changes the song only while stopped", needsStop: true)
            try? await Task.sleep(for: .seconds(6))
            if LaunchArgs.all.contains("-messages-confirm") { ui.confirm("Playing from the start") }
        }
    }

    private func take(_ new: Slot) {
        if let old = slot, old != new { retire(old) }
        slot = new
        if let t = text(new) { MessageMotion.announce(t) }
    }

    /// The message a new one replaced: gone (an Undo stays in its thing's menu until the next change).
    private func retire(_ s: Slot) {
        switch s {
        case .refusal(let t): if store?.refusal?.text == t { store?.dismissRefusal() }
        case .padUndo(let id): if ui.padClear?.id == id { ui.padClear?.stripGone = true }
        case .stepUndo: ui.lastClear = nil
        case .confirm(let id): if ui.confirmation?.id == id { ui.confirmation = nil }
        }
    }

    private func text(_ s: Slot) -> String? {
        switch s {
        case .refusal(let t): t
        case .padUndo: ui.padClear.map { $0.title + ". Undo is available" }
        case .stepUndo: ui.lastClear.map { "Cleared track \($0.track + 1). Undo is available" }
        case .confirm: ui.confirmation?.text
        }
    }

    @ViewBuilder private func message(_ s: Slot) -> some View {
        switch s {
        case .refusal:
            if let store, let r = store.refusal {
                MessageRow(kind: .refusal, text: r.text,
                           actions: r.needsStop && session.playing
                               ? [MessageAction(title: "Stop", systemImage: "stop.fill") { session.setPlaying(false); store.dismissRefusal() }] : [],
                           dismiss: { store.dismissRefusal() })
            }
        case .padUndo:
            if let store, let c = ui.padClear {
                MessageRow(kind: .undo, text: c.title,
                           actions: [MessageAction(title: "Undo", hint: "Puts it back") { ListUndo.undo(ui, store, session) }],
                           dismiss: { ui.padClear?.stripGone = true })
            }
        case .stepUndo:
            if let c = ui.lastClear {
                MessageRow(kind: .undo, text: "Cleared track \(c.track + 1)",
                           actions: [MessageAction(title: "Undo", hint: "Puts the steps back") { StepClear.undo(session, c); ui.lastClear = nil }],
                           dismiss: { ui.lastClear = nil }) { TrackChip(track: c.track) }
            }
        case .confirm:
            if let c = ui.confirmation { MessageRow(kind: .confirmation, text: c.text) }
        }
    }

    @ViewBuilder private func ongoingRow(_ o: Ongoing) -> some View {
        switch o {
        case .recording:
            MessageRow(kind: .ongoing, text: "Recording knob moves on T\(session.selectedTrack + 1)",
                       detail: "Every change, here or on the FM-1, goes into its steps.",
                       actions: [MessageAction(title: "Stop recording") { session.toggleRec() }]) {
                Image(systemName: "record.circle").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.rec).accessibilityHidden(true)
            }
        case .take:
            if let offer = session.takeOffer {
                MessageRow(kind: .ongoing,
                           text: "You played \(offer.notes) note\(offer.notes == 1 ? "" : "s") on T\(offer.track + 1) \(Entries.trackName(offer.track, session: session))",
                           detail: offer.refused ? "The FM-1 found nothing to take; it says why on its screen"
                               : offer.canStart ? "Keep that opens Skiff's picker here" : "Press SHIFT + SAVE on the FM-1 to keep it",
                           actions: offer.canStart ? [MessageAction(title: "Keep that", primary: true) { session.startTake() }] : [],
                           dismiss: { session.dismissTakeOffer() }, dismissLabel: "Let it go") { TrackChip(track: offer.track) }
            }
        case .scene(let n):
            MessageRow(kind: .ongoing, text: "Scene \(n + 1): not seen yet", detail: "Recall it once, and holding it shows what it does.")
        case .apart(let w):
            MessageRow(kind: .ongoing, text: w) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 16, weight: .semibold)).accessibilityHidden(true)
            }
        }
    }

    private func spoken(_ o: Ongoing) -> String {
        switch o {
        case .recording: "Recording knob moves on track \(session.selectedTrack + 1)"
        case .take: session.takeOffer.map { "You played \($0.notes) notes on track \($0.track + 1). Keep that is available" } ?? ""
        case .scene(let n): "Scene \(n + 1): not seen yet"
        case .apart(let w): w
        }
    }
}

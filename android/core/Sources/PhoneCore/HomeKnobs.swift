// HOME's four knobs (decision 21, board 70): on the FM-1's HOME screen KNOB 1…4 turn the selected track's engine's four
// main parameters (Skiff ui.c home_param). The reading and the write are SloopKit's (SkiffHomeKnobs.swift:
// DeviceSession.homeKnobs and setHomeKnob), shared with the iPhone; this file is the Android wire shape. The `homeKnobs` area publishes them as the
// FM-1 draws them (the same label and value text as a sound page's columns: PageArea.control), kept current as the
// track, its engine or sound, or any of the four change, from the phone or from the FM-1's own knobs. The intent
// `setHomeKnob` turns one, as a page's setParam does. Mirrored by android/app/.../core/HomeKnobsState.kt.
import Foundation
import SloopKit

public struct HomeKnobsArea: Codable, Equatable, Sendable {
    public var track: Int                 // 1-based
    public var trackName: String
    /// The engine's name as INFO gives it ("ANALOG") and the sound's ("ACID").
    public var engine: String
    public var preset: String
    /// KNOB 1…4, in the FM-1's order.
    public var controls: [PageArea.Control]
    /// The knob last turned on the FM-1 (0…3), or -1. The FM-1 lights its card for 40 frames (ui_input.c ui.hot_t)
    /// from the turn. The link says which parameter moved (CHANGED: scope and id) but not that HOME was the screen it
    /// was turned on, so a knob is hot when its parameter changed on the FM-1, from any page; a sound loading on the
    /// FM-1 (three or more at once) lights none (Session.lastTouched). It comes 150 ms after the turn.
    public var hot: Int
    /// Changes with each turn on the FM-1 (milliseconds, wrapped): a new value starts the light again.
    public var hotSeq: Int
    /// The FM-1's screen is on HOME, where its knobs turn these four.
    public var fm1Home: Bool
}

extension PhoneCore {
    /// nil off Skiff, before the FM-1 is read, or for an engine the table doesn't know. Built from SloopKit's
    /// `DeviceSession.homeKnobs` (SkiffHomeKnobs.swift), which the iPhone reads too.
    public func homeKnobsArea() -> HomeKnobsArea? {
        guard let h = session.homeKnobs else { return nil }
        return HomeKnobsArea(track: h.track + 1, trackName: h.trackName, engine: h.engine, preset: h.preset,
                             controls: h.knobs.map { PageArea.Control($0) }, hot: h.hot ?? -1,
                             hotSeq: h.hotAt.map { Int($0.timeIntervalSinceReferenceDate * 1000) % 1_000_000_000 } ?? 0,
                             fm1Home: h.fm1Home)
    }

    private struct HomeWire: Decodable { let intent: String; let slot: Int?; let value: Int? }

    /// `{"intent":"setHomeKnob","slot":0…3,"value":raw}`: true when `json` was it. A write: refused while read-only.
    func handleHomeJSON(_ json: String) -> Bool {
        guard let w = try? JSONDecoder().decode(HomeWire.self, from: Data(json.utf8)), w.intent == "setHomeKnob" else { return false }
        guard canWrite() else { refuseReadOnly("setHomeKnob"); return true }
        guard let slot = w.slot, let value = w.value, (0..<4).contains(slot) else { log("setHomeKnob: missing slot or value"); return true }
        if !session.setHomeKnob(slot, to: value) { refuse("The FM-1 hasn't been read yet. Try again in a moment.") }
        return true
    }
}

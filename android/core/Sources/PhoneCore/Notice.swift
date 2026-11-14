// The `notice` area: every intent the core didn't carry out, said on the screen where the action was taken (Scott,
// 2026-11-14: New pattern "did nothing" on the Pixel; the FM-1 had refused it and only the log said so). Each is
// published at once, even when the words repeat: it isn't a watched state but an event. The screen numbers them
// itself (android/app/.../core/Notice.kt, CoreNotice). The log gets the same words, as before.
//
// What goes here: something the person asked for that didn't happen, with the reason and what to do. What doesn't:
// a malformed intent or one the screen should have confirmed first (the screen's own faults stay in the log).
import Foundation
import SloopKit

public struct NoticeArea: Codable, Equatable, Sendable {
    /// What happened and what to do, a sentence or two.
    public var text: String
    /// Where, when the core knows: the track 1…6 and the entry from 0.
    public var track: Int?
    public var entry: Int?
}

extension PhoneCore {
    /// The read-only guard's words. The switch is the app's, so it names it as the app does.
    static let readOnlyNotice = "Lupe is read-only, so nothing was sent to the FM-1. Turn on Allow writes to change it."

    /// An intent that wasn't carried out: into the log, and onto the screen. `track` is 1-based, `entry` 0-based.
    func refuse(_ text: String, track: Int? = nil, entry: Int? = nil) {
        log(text)
        publishNotice(NoticeArea(text: text, track: track, entry: entry))
    }

    /// The store's refusal (one op at a time, stopped only, PATTERNS FULL…), with its track and entry.
    func refuse(_ r: SkiffSongStore.Refusal) {
        log("FM-1 refused: \(r.text)")
        publishNotice(NoticeArea(text: r.text, track: r.track.map { $0 + 1 }, entry: r.entry))
    }

    /// A write while read-only. A drag sends many: the screen hears of it once every two seconds at most.
    func refuseReadOnly(_ what: String) {
        log("read-only: \(what) not sent (allow writes to send it)")
        let now = Date()
        guard now.timeIntervalSince(readOnlySaidAt) > 2 else { return }
        readOnlySaidAt = now
        publishNotice(NoticeArea(text: Self.readOnlyNotice))
    }
}

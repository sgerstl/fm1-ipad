import SloopKit
import SwiftUI

// The timeline's menus: which one is open and where, and what a block's or a lane's end's menu offers.

/// Which menu is open on the Arrange page, and where (global).
enum ArrangeMenu: Hashable {
    case block(EntryRef)
    case add(Int)
}

struct OpenMenu: Hashable {
    var kind: ArrangeMenu
    var at: CGPoint
}

/// What each Arrange menu holds.
@MainActor struct ArrangeMenus {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    /// Where a move puts the block, for the selection to follow.
    let select: (EntryRef) -> Void

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store, ui: ui) }
    private var idle: Bool { !store.busy && !store.offline }

    /// A block's menu (hold, then let go).
    func block(_ t: Int, _ b: SongBlock) -> [[MenuItem]] {
        guard let list = store.song?.tracks[safe: t] else { return [] }
        let blocks = store.blocks(t)
        var g: [[MenuItem]] = []
        if b.kind == .pattern { g.append([MenuItem(title: "Edit pattern", icon: "pencil", enabled: idle) { open(t, b) }]) }
        var copy: [MenuItem] = []
        if let p = list.entries[b.entries.lowerBound].poolIndex, !b.isChain {
            let free = (store.pool?.free ?? 0) > 0
            let n = free ? edits.copyNumber(after: p).map { " (becomes \(Entries.number($0)))" } ?? "" : ": all 64 taken"
            copy.append(MenuItem(title: "Make unique\(n)", icon: "square.on.square.dashed", enabled: free && idle) { edits.makeUnique(t, b) })
        }
        copy.append(MenuItem(title: "Duplicate after", icon: "plus.square.on.square", enabled: idle) { edits.duplicateAfter(t, b) })
        g.append(copy)
        g.append([
            MenuItem(title: "Move earlier", icon: "arrow.left", enabled: idle && b.id != blocks.first?.id) { move(t, b, -1) },
            MenuItem(title: "Move later", icon: "arrow.right", enabled: idle && b.id != blocks.last?.id) { move(t, b, 1) },
        ])
        var more: [MenuItem] = []
        if b.isChain {
            more.append(MenuItem(title: "Split the chain", icon: "scissors", enabled: idle) { edits.split(t, b) })
        } else {
            let can = b.kind != .gap && b.entries.upperBound < 15 && !list.entries[b.entries.upperBound + 1].isEmpty
            more.append(MenuItem(title: "Chain into next", icon: "link", enabled: can && idle) { edits.chainIntoNext(t, b) })
        }
        if b.kind == .pattern, store.sounds {
            // the sound panel for this entry (Scott, 2026-11-08), not a submenu
            more.append(MenuItem(title: "Select sound", icon: "waveform", enabled: idle) {
                ui.chooseSound(session, track: t, entry: SoundEntryTarget(ref: EntryRef(track: t, entry: b.entries.lowerBound), pad: false))
            })
        }
        g.append(more)
        g.append([MenuItem(title: b.isChain ? "Delete entries" : "Delete entry", icon: "trash", enabled: idle) { edits.delete(t, b) }])
        return g
    }

    /// After a lane's last block: repeat the last pattern, a new empty one, a rest, or pick one.
    func add(_ t: Int) -> [[MenuItem]] {
        guard let list = store.song?.tracks[safe: t] else { return [] }
        let last = list.span.map { list.entries[$0.upperBound] }
        var first: [MenuItem] = []
        if let last, let p = last.poolIndex {
            first.append(MenuItem(title: "Repeat \(Entries.number(p + 1)) again", icon: "repeat", enabled: idle) {
                edits.appendAtEnd(t, SongEntry(pattern: p + 1, reps: last.reps))
            })
        }
        let free = (store.pool?.free ?? 0) > 0
        first.append(MenuItem(title: free ? "New empty pattern" : "New empty pattern: all 64 taken", icon: "plus", enabled: free && idle) {
            edits.newPatternAtEnd(t)
        })
        first.append(MenuItem(title: "Rest", icon: "pause", enabled: idle) { edits.appendAtEnd(t, SongEntry(pattern: SongEntry.rest, reps: 1)) })
        let kept = (0..<64).filter { (store.pool?.patterns[$0].length ?? 0) > 0 }
        let owner = owners()
        let pick = MenuItem.submenu(title: "Pick a pattern…", icon: "square.grid.2x2", enabled: idle && !kept.isEmpty, children: {
            [kept.map { p in
                let tracks = owner[p] ?? []
                let colour = tracks.count == 1 ? Theme.track[tracks[0]] : Entries.tone(p + 1)
                let name = tracks.count == 1 ? "T\(tracks[0] + 1) \(Entries.trackName(tracks[0], session: session))"
                    : tracks.isEmpty ? "Not in this song" : tracks.map { "T\($0 + 1)" }.joined(separator: ", ")
                return MenuItem(title: name, chip: (Entries.number(p + 1), colour)) { edits.appendAtEnd(t, SongEntry(pattern: p + 1, reps: 1)) }
            }]
        })
        // all 64 taken: the sheet, where unused ones are cleared (2026-11-17)
        let manage = MenuItem(title: "Manage patterns…", icon: "square.grid.3x3") { ui.patternsSheet = .manage }
        return [first, free ? [pick] : [pick, manage]]
    }

    /// Pattern (0...63) → the tracks whose lists name it.
    private func owners() -> [Int: [Int]] {
        var m: [Int: [Int]] = [:]
        for (t, l) in (store.song?.tracks ?? []).enumerated() {
            for e in l.entries { if let p = e.poolIndex, !(m[p]?.contains(t) ?? false) { m[p, default: []].append(t) } }
        }
        return m
    }

    private func move(_ t: Int, _ b: SongBlock, _ d: Int) {
        if let i = edits.move(t, b, by: d) { select(EntryRef(track: t, entry: i)) }
    }

    /// Sequence on the entry's pattern; stopped, the track goes to the entry (LIST op 3) first.
    private func open(_ t: Int, _ b: SongBlock) {
        let e = b.entries.lowerBound
        let on = store.song?.tracks[safe: t]?.entryOn == e
        if !on && session.playing {
            store.refuse(track: t, entry: e, "Stop to open this entry's pattern: playing, the FM-1 would launch it", needsStop: true)
            return
        }
        Task {
            if !on { guard await store.send(.play(track: t, entry: e)) else { return } }
            session.select(track: t)
            ui.page = .sequencer
        }
    }
}

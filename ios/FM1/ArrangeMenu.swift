import SloopKit
import SwiftUI

// One menu style across Arrange (Scott, 2026-11-05): Jib's own at the finger (canvas board 2), not the
// system's. Rows 52 pt high, 8 pt between groups, a submenu opening in place with a Back row. A menu as the
// APG has it: ↑ ↓ move between items, → opens a submenu, ← goes back, Return picks, Escape closes.

struct MenuItem {
    var title: String
    var icon: String? = nil
    /// A pattern number's chip, in its track's colour.
    var chip: (text: String, colour: Color)? = nil
    var enabled = true
    var checked = false
    /// A line that says something (a status, a reason), not a choice: smaller, wraps, never focused.
    var note = false
    var children: (() -> [[MenuItem]])? = nil
    var action: (() -> Void)? = nil

    static func note(_ text: String) -> MenuItem { MenuItem(title: text, enabled: false, note: true) }
}

/// A Jib menu anywhere in the app (2026-11-05: every system menu becomes one): a title, its groups (built when it
/// opens, and again as it's shown, so values stay live), and where it opens (global).
struct JibMenu: Identifiable {
    let id = UUID()
    var title: String
    var groups: () -> [[MenuItem]]
    var at: CGPoint
}

/// Draws an open JibMenu over what it's put on, under its anchor (above it where it wouldn't fit), closed by a
/// tap anywhere else or Escape. The app's root has one; a sheet, which covers the root, has its own.
struct JibMenuLayer: View {
    @Binding var menu: JibMenu?
    @State private var frame: CGRect = .zero

    var body: some View {
        GeometryReader { g in
            if let m = menu {
                ZStack(alignment: .topLeading) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { menu = nil }
                        .accessibilityHidden(true)
                    MenuPanel(title: m.title, groups: m.groups(), close: { menu = nil })
                        .id(m.id)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in -min(max(12, m.at.x - frame.minX), g.size.width - d.width - 12) }
                        .alignmentGuide(.top) { d in
                            let y = m.at.y - frame.minY
                            return -(y + 8 + d.height <= g.size.height ? y + 8 : max(12, y - 8 - d.height))
                        }
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

/// Which menu is open on the Arrange page, and where (global).
enum ArrangeMenu: Hashable {
    case block(EntryRef)
    case sound(EntryRef)
    case add(Int)
}

struct OpenMenu: Hashable {
    var kind: ArrangeMenu
    var at: CGPoint
}

struct MenuPanel: View {
    let title: String
    let groups: [[MenuItem]]
    let close: () -> Void
    @State private var stack: [(title: String, groups: [[MenuItem]])] = []
    @State private var contentHeight: CGFloat = 0
    @FocusState private var focus: Int?
    @Environment(\.look) private var look

    static let rowHeight: CGFloat = 52
    static let maxRows = 9

    var body: some View {
        let level = stack.last ?? (title, groups)
        let flat = level.groups.flatMap { $0 }
        VStack(alignment: .leading, spacing: 0) {
            if stack.isEmpty {
                Text(title).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    .padding(.horizontal, 16).frame(height: 36, alignment: .bottomLeading)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Button(action: back) {
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width: 24)
                        Text(level.title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: Self.rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back, \(level.title)")
                divider
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(level.groups.indices, id: \.self) { gi in
                        if gi > 0 { divider }
                        ForEach(level.groups[gi].indices, id: \.self) { k in
                            let i = level.groups[..<gi].reduce(0) { $0 + $1.count } + k
                            if level.groups[gi][k].note { noteRow(level.groups[gi][k]) } else { row(level.groups[gi][k], index: i) }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollIndicators(.automatic)
            .frame(height: min(max(contentHeight, Self.rowHeight), CGFloat(Self.maxRows) * Self.rowHeight))
        }
        .padding(.vertical, 4)
        .frame(width: 300)
        // the one level-3 shadow, the panel's: on its shape, not the stack (which would shade every row and key)
        .background(RoundedRectangle(cornerRadius: 12).fill(look.surface(.held)).elevationShadow(.held, look))
        .focusable()
        .onKeyPress(.downArrow) { focus = next(from: focus, by: 1, flat); return .handled }
        .onKeyPress(.upArrow) { focus = next(from: focus, by: -1, flat); return .handled }
        .onKeyPress(.rightArrow) {
            if let f = focus, flat.indices.contains(f), flat[f].children != nil { pick(flat[f]); return .handled }
            return .ignored
        }
        .onKeyPress(.leftArrow) { if stack.isEmpty { return .ignored }; back(); return .handled }
        .onKeyPress(.escape) { if stack.isEmpty { close() } else { back() }; return .handled }
        .onAppear { focus = next(from: nil, by: 1, flat) }
        .background {
            // Escape from a hardware keyboard even where the rows don't hold focus
            Button("Close menu") { if stack.isEmpty { close() } else { back() } }
                .keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(level.title)
        .accessibilityAction(.escape) { if stack.isEmpty { close() } else { back() } }
    }

    private var divider: some View {
        // 8 pt between groups, a hairline in it
        Rectangle().fill(Theme.disabledOutline.opacity(0.6)).frame(height: 1).padding(.vertical, 4)
    }

    private func back() {
        _ = stack.popLast()
        focus = nil
    }

    private func pick(_ item: MenuItem) {
        if let c = item.children {
            stack.append((item.title, c()))
            focus = nil
        } else {
            close()
            item.action?()
        }
    }

    private func next(from i: Int?, by d: Int, _ items: [MenuItem]) -> Int? {
        guard !items.isEmpty else { return nil }
        var k = i ?? (d > 0 ? -1 : items.count)
        for _ in items.indices {
            k = (k + d + items.count) % items.count
            if items[k].enabled { return k }
        }
        return nil
    }

    private func noteRow(_ item: MenuItem) -> some View {
        Text(item.title).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ item: MenuItem, index: Int) -> some View {
        Button { pick(item) } label: {
            HStack(spacing: 12) {
                if let chip = item.chip {
                    Text(chip.text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.onColour)
                        .frame(width: 32, height: 26).background(RoundedRectangle(cornerRadius: 6).fill(chip.colour))
                } else if let icon = item.icon {
                    Image(systemName: icon).font(.system(size: 17)).frame(width: 24)
                }
                Text(item.title).font(.system(size: 17)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if item.checked {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).accessibilityLabel("Current")
                }
                if item.children != nil {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
                }
            }
            .foregroundStyle(item.enabled ? Theme.text : Theme.textTertiary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
            .background {
                if focus == index { RoundedRectangle(cornerRadius: 8).fill(look.surface(.selected)).padding(.horizontal, 4) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.enabled)
        .focused($focus, equals: index)
        .accessibilityAddTraits(item.checked ? .isSelected : [])
        .accessibilityHint(item.children != nil ? "Opens a submenu" : "")
    }
}

/// What each Arrange menu holds.
@MainActor struct ArrangeMenus {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    /// Where a move puts the block, for the selection to follow.
    let select: (EntryRef) -> Void

    private var edits: ArrangeEdits { ArrangeEdits(session: session, store: store) }
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
            more.append(MenuItem(title: "Set sound…", icon: "waveform", enabled: idle, children: { sound(t, b) }))
        }
        g.append(more)
        g.append([MenuItem(title: b.isChain ? "Delete entries" : "Delete entry", icon: "trash", enabled: idle) { edits.delete(t, b) }])
        return g
    }

    /// The sounds an entry can take: none, the user presets, each engine's presets the track may play.
    func sound(_ t: Int, _ b: SongBlock) -> [[MenuItem]] {
        let current = store.song?.tracks[safe: t]?.entries[safe: b.entries.lowerBound]?.sound
        var g: [[MenuItem]] = [[MenuItem(title: "No sound: keep the track's", icon: "speaker.slash", checked: current == nil) {
            edits.setSound(t, b, nil)
        }]]
        if !session.userPresets.isEmpty {
            let users = session.userPresets
            g.append([MenuItem(title: "User presets", icon: "person", checked: current?.isUser == true, children: {
                [users.map { u in
                    MenuItem(title: u.name, checked: current?.userSlot == u.slot) { edits.setSound(t, b, EntrySound(s0: 64 + u.slot, s1: 0)) }
                }]
            })])
        }
        var engines: [MenuItem] = []
        for (e, name) in (session.info?.engines ?? []).enumerated() {
            guard session.shape.canPlay(track: t, engine: e), let presets = session.namesCache[e], !presets.isEmpty else { continue }
            engines.append(MenuItem(title: name.capitalized, icon: "waveform", checked: current?.engine == e, children: {
                [presets.enumerated().map { k, p in
                    MenuItem(title: p.capitalized, checked: current?.engine == e && current?.s1 == k) { edits.setSound(t, b, EntrySound(s0: e + 1, s1: k)) }
                }]
            }))
        }
        if !engines.isEmpty { g.append(engines) }
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
        let pick = MenuItem(title: "Pick a pattern…", icon: "square.grid.2x2", enabled: idle && !kept.isEmpty, children: {
            [kept.map { p in
                let tracks = owner[p] ?? []
                let colour = tracks.count == 1 ? Theme.track[tracks[0]] : Entries.tone(p + 1)
                let name = tracks.count == 1 ? "T\(tracks[0] + 1) \(Entries.trackName(tracks[0], session: session))"
                    : tracks.isEmpty ? "Not in this song" : tracks.map { "T\($0 + 1)" }.joined(separator: ", ")
                return MenuItem(title: name, chip: (Entries.number(p + 1), colour)) { edits.appendAtEnd(t, SongEntry(pattern: p + 1, reps: 1)) }
            }]
        })
        return [first, [pick]]
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

/// A REST that opens to hold a gap: it grows from its left edge, and closes back into it. A scale, not a
/// mask: at full size it's no change at all, so nothing is ever clipped.
struct Reveal: ViewModifier {
    var amount: CGFloat
    func body(content: Content) -> some View {
        content.scaleEffect(x: max(0.001, amount), y: 1, anchor: .leading)
    }
}

extension AnyTransition {
    /// In with the rearrange's own motion; out faster (exits quicker than entrances).
    static var accordion: AnyTransition {
        .asymmetric(insertion: .modifier(active: Reveal(amount: 0), identity: Reveal(amount: 1)),
                    removal: AnyTransition.modifier(active: Reveal(amount: 0), identity: Reveal(amount: 1))
                        .animation(.easeIn(duration: 0.16)))
    }
}

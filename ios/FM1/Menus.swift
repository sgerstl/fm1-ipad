import SloopKit
import SwiftUI

// One menu style across Arrange (Scott, 2026-11-05): Lupe's own at the finger (canvas board 2), not the
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
    var action: (() -> Void)?
    var children: (() -> [[MenuItem]])?

    /// A line with nothing to do: a note, or a choice shown but not offered.
    init(title: String, icon: String? = nil, chip: (text: String, colour: Color)? = nil, enabled: Bool = true,
         checked: Bool = false, note: Bool = false) {
        self.title = title; self.icon = icon; self.chip = chip; self.enabled = enabled
        self.checked = checked; self.note = note; self.action = nil; self.children = nil
    }

    /// A choice: its trailing closure is what it does.
    init(title: String, icon: String? = nil, chip: (text: String, colour: Color)? = nil, enabled: Bool = true,
         checked: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.chip = chip; self.enabled = enabled
        self.checked = checked; self.note = false; self.action = action; self.children = nil
    }

    /// A submenu: its groups, built when it opens (a factory, so a trailing closure only ever means an action).
    static func submenu(title: String, icon: String? = nil, enabled: Bool = true, checked: Bool = false,
                        children: @escaping () -> [[MenuItem]]) -> MenuItem {
        var m = MenuItem(title: title, icon: icon, enabled: enabled, checked: checked)
        m.children = children
        return m
    }

    static func note(_ text: String) -> MenuItem { MenuItem(title: text, enabled: false, note: true) }
}

/// A Lupe menu anywhere in the app (2026-11-05: every system menu becomes one): a title, its groups (built when it
/// opens, and again as it's shown, so values stay live), and where it opens (global).
struct AppMenu: Identifiable {
    let id = UUID()
    var title: String
    var groups: () -> [[MenuItem]]
    var at: CGPoint
    /// Opened from a key (a ⋯, a header, the connection readout): `at` is the menu's top-left, below the key. Otherwise
    /// `at` is the finger, and the menu opens beside it on the side away from the playing hand (Settings › Handedness).
    var fromKey = false
}

/// Draws an open AppMenu over what it's put on, under its anchor (above it where it wouldn't fit), closed by a
/// touch anywhere else (which still reaches the page: OutsideTouch) or Escape. The app's root has one; a sheet, which covers the root, has its own.
struct AppMenuLayer: View {
    @Binding var menu: AppMenu?
    @State private var frame: CGRect = .zero
    @AppStorage(Handedness.key) private var hand = Handedness.right

    var body: some View {
        GeometryReader { g in
            if let m = menu {
                ZStack(alignment: .topLeading) {
                    Color.clear.allowsHitTesting(false)   // the layer's full size, for the placement; takes no touches
                    MenuPanel(title: m.title, groups: m.groups(), close: { menu = nil })
                        .id(m.id)
                        .fixedSize()
                        .closesOnOutsideTouch { menu = nil }
                        // beside the finger, on the side away from the playing hand (Settings › Handedness)
                        .alignmentGuide(.leading) { d in
                            let x = m.at.x - frame.minX
                            return -(m.fromKey ? min(max(12, x), g.size.width - d.width - 12)
                                              : hand.menuX(touch: x, menuWidth: d.width, in: g.size.width))
                        }
                        .alignmentGuide(.top) { d in
                            let y = m.at.y - frame.minY
                            return -(m.fromKey ? (y + 8 + d.height <= g.size.height ? y + 8 : max(12, y - 8 - d.height))
                                              : Handedness.menuY(touch: y, menuHeight: d.height, in: g.size.height))
                        }
                }
            }
        }
        .globalFrame($frame)
    }
}

struct MenuPanel: View {
    let title: String
    let groups: [[MenuItem]]
    let close: () -> Void
    @State private var stack: [(title: String, groups: [[MenuItem]])] = []
    @State private var contentHeight: CGFloat = 0
    @FocusState private var focus: Int?

    static let rowHeight: CGFloat = 52
    static let width: CGFloat = 300
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
        .frame(width: Self.width)
        // the one level-3 shadow, the panel's: on its shape, not the stack (which would shade every row and key)
        .elevated(.held, radius: 12)
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
                if focus == index { RoundedRectangle(cornerRadius: 8).fill(Elevation.selected.surface).padding(.horizontal, 4) }
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

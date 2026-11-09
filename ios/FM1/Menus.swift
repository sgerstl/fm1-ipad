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
    /// Its choices as separate floating buttons fanning out of the finger, the first by it (Scott, 2026-11-09: an empty
    /// pad's "New pattern" nine times in ten). A submenu among them opens as an ordinary menu in their place.
    var fan = false
    /// The track a fan belongs to: its buttons in the track's tint, the first outlined in its colour (Scott, 2026-11-09).
    var tint: Int? = nil
}

/// Draws an open AppMenu over what it's put on, under its anchor (above it where it wouldn't fit), closed by a
/// touch anywhere else (which still reaches the page: OutsideTouch) or Escape. The app's root has one; a sheet, which covers the root, has its own.
struct AppMenuLayer: View {
    @Binding var menu: AppMenu?
    @State private var frame: CGRect = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Color.clear.allowsHitTesting(false)   // the layer's full size, for the placement; takes no touches
                if let m = menu {
                    let at = CGPoint(x: m.at.x - frame.minX, y: m.at.y - frame.minY)
                    if m.fan {
                        FanMenu(title: m.title, items: m.groups().flatMap { $0 }.filter { !$0.note }, at: at, layer: g.size, tint: m.tint,
                                close: { menu = nil },
                                open: { item in menu = AppMenu(title: item.title, groups: item.children ?? { [] }, at: m.at) })
                            .id(m.id)
                            .transition(.opacity.animation(.easeIn(duration: Labs.menuClose.value)))
                    } else {
                        PlacedMenu(title: m.title, groups: m.groups(), at: at, fromKey: m.fromKey, layer: g.size, close: { menu = nil })
                            .id(m.id)
                            .transition(PlacedMenu.transition(at: at, layer: g.size, reduceMotion: reduceMotion))
                    }
                }
            }
        }
        .globalFrame($frame)
    }
}

/// A menu panel placed in its layer (a ZStack aligned top-leading, `layer` its size): beside the finger on the side away
/// from the playing hand (Settings › Handedness), or from a key, under it (above where it wouldn't fit); kept `margin`
/// inside the layer. Closed by a touch anywhere else, which still reaches the page (OutsideTouch).
struct PlacedMenu: View {
    let title: String
    let groups: [[MenuItem]]
    /// The finger, or the key's corner, in the layer's space.
    let at: CGPoint
    var fromKey = false
    let layer: CGSize
    var margin: CGFloat = 12
    let close: () -> Void
    @AppStorage(Handedness.key) private var hand = Handedness.right

    var body: some View {
        // the panel inside a layer-sized frame, so the open and close scale can centre on the finger itself
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            MenuPanel(title: title, groups: groups, close: close, maxHeight: layer.height - 2 * margin)
                .fixedSize()
                .closesOnOutsideTouch(close)
                .alignmentGuide(.leading) { d in
                    -(fromKey ? min(max(margin, at.x), layer.width - d.width - margin)
                              : hand.menuX(touch: at.x, menuWidth: d.width, in: layer.width, margin: margin))
                }
                .alignmentGuide(.top) { d in
                    -(fromKey ? (at.y + 8 + d.height <= layer.height ? at.y + 8 : max(margin, at.y - 8 - d.height))
                              : Handedness.menuY(touch: at.y, menuHeight: d.height, in: layer.height, margin: margin))
                }
        }
        .frame(width: layer.width, height: layer.height, alignment: .topLeading)
    }

    /// Opening out of the finger (a key's menu: out of the key's corner), eased, and closing back into it, quicker
    /// (Scott, 2026-11-09: "expand out from where you touch, slight easing, smooth"). Reduce Motion: a fade.
    static func transition(at: CGPoint, layer: CGSize, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return AnyTransition.opacity.animation(.easeOut(duration: 0.15)) }
        let from = UnitPoint(x: at.x / max(1, layer.width), y: at.y / max(1, layer.height))
        let grow = AnyTransition.scale(scale: 0.2, anchor: from).combined(with: .opacity)
        return .asymmetric(insertion: grow.animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: Labs.menuOpen.value)),
                           removal: grow.animation(.easeIn(duration: Labs.menuClose.value)))
    }
}

struct MenuPanel: View {
    let title: String
    let groups: [[MenuItem]]
    let close: () -> Void
    /// The tallest the panel may be (its layer's room): past it the rows scroll, nothing is cut off.
    var maxHeight: CGFloat = .infinity
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
                Text(title).font(.lupe(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    .padding(.horizontal, 16).frame(height: 36, alignment: .bottomLeading)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Button(action: back) {
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).frame(width: 24)
                        Text(level.title).font(.lupe(17, .semibold)).lineLimit(1)
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
            // (the title or Back row and the panel's padding take 60 of maxHeight)
            .frame(height: min(max(contentHeight, Self.rowHeight), CGFloat(Self.maxRows) * Self.rowHeight, max(Self.rowHeight, maxHeight - 60)))
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
        Text(item.title).font(.lupe(13)).foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ item: MenuItem, index: Int) -> some View {
        Button { pick(item) } label: {
            HStack(spacing: 12) {
                if let chip = item.chip {
                    Text(chip.text).font(.lupe(13, .semibold)).foregroundStyle(Theme.onColour)
                        .frame(width: 32, height: 26).background(RoundedRectangle(cornerRadius: 6).fill(chip.colour))
                } else if let icon = item.icon {
                    Image(systemName: icon).font(.system(size: 17)).frame(width: 24)
                }
                Text(item.title).font(.lupe(17)).lineLimit(1).minimumScaleFactor(0.8)
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


/// A menu as separate floating buttons fanned out of the finger: beside it on the side away from the playing hand
/// (Settings › Handedness), the first level with it, a gap between each whose half belongs to the button either side,
/// so the targets are bigger than they look (Scott, 2026-11-09). They come out of the finger one after another.
struct FanMenu: View {
    let title: String
    let items: [MenuItem]
    /// The finger, in the layer's space.
    let at: CGPoint
    let layer: CGSize
    /// The track it belongs to (its buttons in the track's tint, the first outlined in its colour); nil: neutral.
    var tint: Int? = nil
    let close: () -> Void
    /// A submenu chosen: it opens as an ordinary menu.
    let open: (MenuItem) -> Void
    @AppStorage(Handedness.key) private var hand = Handedness.right
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    static let width: CGFloat = 240, height: CGFloat = 56, gap: CGFloat = 12

    var body: some View {
        let n = CGFloat(items.count)
        let total = n * Self.height + max(0, n - 1) * Self.gap
        let x = hand.menuX(touch: at.x, menuWidth: Self.width, in: layer.width)
        let y = Handedness.menuY(touch: at.y, menuHeight: total, in: layer.height)
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { k, item in
                    let top = y + CGFloat(k) * (Self.height + Self.gap)
                    // from the finger to its place
                    let dx = at.x - (x + Self.width / 2), dy = at.y - (top + Self.height / 2)
                    button(item, first: k == 0)
                        .padding(.vertical, Self.gap / 2)
                        .contentShape(Rectangle())          // the gaps take the touch too
                        .offset(x: out || reduceMotion ? 0 : dx, y: out || reduceMotion ? 0 : dy)
                        .scaleEffect(out || reduceMotion ? 1 : 0.3)
                        .opacity(out ? 1 : 0)
                        .animation(reduceMotion ? .easeOut(duration: 0.15)
                                   : .timingCurve(0.2, 0.8, 0.2, 1, duration: Labs.menuOpen.value).delay(Double(k) * 0.03), value: out)
                }
            }
            .frame(width: Self.width)
            .closesOnOutsideTouch(close)
            .offset(x: x, y: y - Self.gap / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
        .frame(width: layer.width, height: layer.height, alignment: .topLeading)
        .onAppear { out = true }
        .onKeyPress(.escape) { close(); return .handled }
    }

    private func button(_ item: MenuItem, first: Bool) -> some View {
        Button {
            if item.children != nil { open(item) } else { close(); item.action?() }
        } label: {
            HStack(spacing: 10) {
                if let c = item.chip {
                    Text(c.text).font(.lupe(13, .bold)).foregroundStyle(Theme.onColour)
                        .padding(.horizontal, 6).frame(height: 24).background(RoundedRectangle(cornerRadius: 6).fill(c.colour))
                } else if let i = item.icon {
                    Image(systemName: i).font(.system(size: 17, weight: .semibold)).frame(width: 24)
                }
                Text(item.title).font(.lupe(17, first ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if item.children != nil { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)) }
            }
            .foregroundStyle(first && tint == nil ? Theme.onColour : Theme.text)
            .padding(.horizontal, 16)
            .frame(height: Self.height)
            .background {
                if let t = tint {
                    // the track's: every button in its tint (as its lane and selected pad), the first outlined in the
                    // full colour, as the tapped pad is (Scott, 2026-11-09)
                    RoundedRectangle(cornerRadius: 14).fill(SelectionTint.fill(t)).elevationShadow(.held)
                        .overlay { if first { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.track[t], lineWidth: 3) } }
                } else {
                    // the first the primary; each its own floating surface, the shadow of things at the finger
                    RoundedRectangle(cornerRadius: 14).fill(first ? Theme.text : Elevation.held.surface).elevationShadow(.held)
                }
            }
            .opacity(item.enabled ? 1 : 0.45)
        }
        .buttonStyle(PressSink())
        .disabled(!item.enabled)
    }
}

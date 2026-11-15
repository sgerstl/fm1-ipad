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
    /// A small second line under the title (the phone's hold menu shows it: "Takes 03 and empties it · stopped only").
    var sub: String? = nil
    var action: (() -> Void)?
    var children: (() -> [[MenuItem]])?
    /// A destructive choice's second step: tapped, the fan turns this row into a red-outlined button with these words
    /// (what goes, named), and the next into Cancel, where the finger is (Scott, 2026-11-10: no system dialog).
    var confirm: String? = nil

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

    /// A choice that loses something: it asks once more, in place (`confirm` names what goes).
    static func destructive(title: String, icon: String? = "trash", enabled: Bool = true, confirm: String,
                            action: @escaping () -> Void) -> MenuItem {
        var m = MenuItem(title: title, icon: icon, enabled: enabled, action: action)
        m.confirm = confirm
        return m
    }
}

/// A Lupe menu anywhere in the app (2026-11-05: every system menu becomes one): a title, its groups (built when it
/// opens, and again as it's shown, so values stay live), and where it opens (global).
struct AppMenu: Identifiable {
    let id = UUID()
    var title: String
    var groups: () -> [[MenuItem]]
    var at: CGPoint
    /// Opened from a key (a ⋯, a header, the connection readout): `at` is the menu's top-left, below the key. Otherwise
    /// `at` is the finger, and the menu opens beside it on the side away from the playing hand (Settings › Menus open).
    var fromKey = false
    /// Its choices as separate floating buttons fanning out of the finger, the first by it (Scott, 2026-11-09: an empty
    /// pad's "New pattern" nine times in ten). A submenu among them opens as an ordinary menu in their place.
    var fan = false
    /// The track a fan belongs to: its buttons in the track's tint, the first outlined in its colour (Scott, 2026-11-09).
    var tint: Int? = nil
    /// A fan that opens already asking: its first item's confirm (red-outlined, its words) and Cancel, for a key whose
    /// only job is the destructive thing (Clear N unused). Nothing else to pick, so no extra tap first (2026-11-10).
    var asking = false
    /// What the choice does, in a line or three over the fan (what goes, whether it comes back): the honest part a
    /// system dialog's message carried (2026-11-10, the last system dialogs converted).
    var caption: String? = nil
    /// A "Don't ask again" box under the confirm (Scott, 2026-11-10, clearing a pad): ticked when the confirm is tapped,
    /// the setting under `key` turns off. Cancel leaves it as it was. `hint` says where it comes back on.
    var optOut: OptOut? = nil
    struct OptOut { var key: String; var label = "Don't ask again"; var hint: String }

    /// One destructive thing asked once more, in place at the finger: its confirm (red-outlined, `confirm` naming what
    /// goes) and Cancel, with `caption` over them. For what used to be a system alert.
    static func confirm(_ title: String, confirm: String, caption: String? = nil, icon: String = "trash", tint: Int? = nil,
                        at: CGPoint = TouchPoint.last, optOut: OptOut? = nil, action: @escaping () -> Void) -> AppMenu {
        AppMenu(title: title, groups: { [[.destructive(title: title, icon: icon, confirm: confirm, action: action),
                                          MenuItem(title: "Cancel", icon: "xmark") {}]] },
                at: at, fan: true, tint: tint, asking: true, caption: caption, optOut: optOut)
    }
}

/// Where the last finger went down (global, the window's points): where a confirm that a gesture didn't open itself
/// (a menu's item, a store's question) opens. Read from a passive recognizer on the window (TouchPointWatch).
enum TouchPoint {
    nonisolated(unsafe) static var last: CGPoint = CGPoint(x: 600, y: 400)     // (written on the main thread only)
}

/// Records each touch-down for TouchPoint without taking part: never recognizes, cancels nothing, delays nothing.
struct TouchPointWatch: UIViewRepresentable {
    func makeUIView(context: Context) -> WatchView { let v = WatchView(); v.isUserInteractionEnabled = false; return v }
    func updateUIView(_ v: WatchView, context: Context) {}

    final class WatchView: UIView {
        private var g: Recorder?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let g { g.view?.removeGestureRecognizer(g) }
            guard let w = window else { return }
            let r = Recorder(target: nil, action: nil)
            r.cancelsTouchesInView = false; r.delaysTouchesBegan = false; r.delaysTouchesEnded = false
            w.addGestureRecognizer(r)
            g = r
        }
    }
    final class Recorder: UIGestureRecognizer {
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let t = touches.first, let w = view { TouchPoint.last = t.location(in: w) }
            state = .failed
        }
        override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
    }
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
                                asking: m.asking, caption: m.caption, optOut: m.optOut, close: { menu = nil },
                                open: { item in menu = AppMenu(title: item.title, groups: item.children ?? { [] }, at: m.at) })
                            .id(m.id)
                            .transition(.opacity.animation(.easeIn(duration: Labs.menuCloseTime)))
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
/// from the playing hand (Settings › Menus open), or from a key, under it (above where it wouldn't fit); kept `margin`
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
    @AppStorage(MenuSide.key) private var hand = MenuSide.left

    var body: some View {
        // the panel inside a layer-sized frame, so the open and close scale can centre on the finger itself
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            MenuPanel(title: title, groups: groups, close: close, maxHeight: layer.height - 2 * margin)
                .fixedSize()
                // a press menu (at the finger, not a key's): the soft black field behind it (Scott, 2026-11-15)
                .background { if !fromKey { PressMenuBacking(radius: 12) } }
                .closesOnOutsideTouch(close)
                .alignmentGuide(.leading) { d in
                    -(fromKey ? min(max(margin, at.x), layer.width - d.width - margin)
                              : hand.menuX(touch: at.x, menuWidth: d.width, in: layer.width, margin: margin))
                }
                .alignmentGuide(.top) { d in
                    -(fromKey ? (at.y + 8 + d.height <= layer.height ? at.y + 8 : max(margin, at.y - 8 - d.height))
                              : MenuSide.menuY(touch: at.y, menuHeight: d.height, in: layer.height, margin: margin))
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
                           removal: grow.animation(.easeIn(duration: Labs.menuCloseTime)))
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
                // (the raised grey: plain secondary is 4.1:1 on the menu's surface, tones[3]; this is 6.1. Audit, 2026-11-10)
                Text(title).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised).lineLimit(1)
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
                .keyboardShortcut(.cancelAction).opacity(0).modifier(ShortcutOnly())
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
        Text(item.title).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
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
/// (Settings › Menus open), the first level with it, a gap between each whose half belongs to the button either side,
/// so the targets are bigger than they look (Scott, 2026-11-09). They come out of the finger one after another.
struct FanMenu: View {
    static var phone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    let title: String
    let items: [MenuItem]
    /// The finger, in the layer's space.
    let at: CGPoint
    let layer: CGSize
    /// The track it belongs to (its buttons in the track's tint, the first outlined in its colour); nil: neutral.
    var tint: Int? = nil
    /// Opens on its first item's confirm (AppMenu.asking).
    var asking = false
    var caption: String? = nil
    var optOut: AppMenu.OptOut? = nil
    let close: () -> Void
    /// A submenu chosen: it opens as an ordinary menu.
    @State private var optedOut = false
    let open: (MenuItem) -> Void
    @AppStorage(MenuSide.key) private var hand = MenuSide.left
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false
    /// The destructive item asking to be confirmed (its row turns into the confirm, the next into Cancel).
    @State private var confirming: Int?
    /// When the confirm came up: it takes no tap for a moment, so the second tap of a quick double tap can't confirm.
    @State private var confirmShownAt = Date.distantPast
    @AccessibilityFocusState private var confirmFocused: Bool

    static let width: CGFloat = 240, height: CGFloat = 56, gap: CGFloat = 12, margin: CGFloat = 12

    /// How many buttons go in a column: all of them where they fit the layer's height; otherwise they wrap into
    /// columns side by side (the phone, 393 pt tall, fits five), balanced so the columns are as even as they can be.
    static func rows(_ n: Int, in height: CGFloat) -> Int {
        let fit = max(1, Int((height - 2 * margin + gap) / (Self.height + gap)))
        guard n > fit else { return max(1, n) }
        let cols = (n + fit - 1) / fit
        return (n + cols - 1) / cols
    }

    var body: some View {
        // the iPhone: the radial hold menu, Android's styling with these same options (decision 31). A caption or a
        // "Don't ask again" box keeps the fan, which has room for them.
        if UIDevice.current.userInterfaceIdiom == .phone, caption == nil, optOut == nil, !asking {
            RadialMenu(title: title, items: items, at: at, layer: layer, tint: tint, close: close)
        } else { fanBody }
    }

    @ViewBuilder private var fanBody: some View {
        // (merge 2026-11-11: the phone's columns, where the buttons don't fit the height, with the caption over them and
        // the "Don't ask again" box under them; the confirm in place as before)
        let capH: CGFloat = caption.map { 20 + CGFloat(Int((Double($0.count) / 28).rounded(.up))) * 18 } ?? 0
        let capTop: CGFloat = capH > 0 ? capH + Self.gap : 0
        let boxH: CGFloat = optOut != nil ? 44 + Self.gap : 0
        let rows = Self.rows(items.count, in: layer.height - capTop - boxH)
        let cols = (items.count + rows - 1) / rows
        let w = CGFloat(cols) * Self.width + CGFloat(cols - 1) * Self.gap
        let total = capTop + CGFloat(rows) * Self.height + CGFloat(max(0, rows - 1)) * Self.gap + boxH
        let x = hand.menuX(touch: at.x, menuWidth: w, in: layer.width)
        let y = MenuSide.menuY(touch: at.y, menuHeight: total, in: layer.height)
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            // the iPad's press menus: the soft black field behind the fan, 16 pt past it each side (Scott, 2026-11-15: "less
            // visually busy"); the phones' wheel has its own arced backing
            if !Self.phone {
                PressMenuBacking(radius: 14)
                    .frame(width: w, height: total + Self.gap)
                    .offset(x: x, y: y - Self.gap / 2)
                    .opacity(out ? 1 : 0)
                    .animation(.easeOut(duration: reduceMotion ? 0.15 : Labs.menuOpen.value), value: out)
            }
            VStack(alignment: .leading, spacing: 0) {
                if let caption {
                    Text(caption).font(.lupe(13)).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(width: Self.width, height: capH, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(tint.map { SelectionTint.fill($0) } ?? Elevation.held.surface).elevationShadow(.held))
                        .padding(.top, Self.gap / 2).padding(.bottom, Self.gap / 2)
                        .opacity(out ? 1 : 0)
                        .animation(.easeOut(duration: reduceMotion ? 0.15 : Labs.menuOpen.value), value: out)
                }
                HStack(alignment: .top, spacing: Self.gap) {
                    ForEach(0..<cols, id: \.self) { c in
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()).filter { $0.offset / rows == c }, id: \.offset) { k, item in
                                let left = x + CGFloat(c) * (Self.width + Self.gap)
                                let top = y + capTop + CGFloat(k % rows) * (Self.height + Self.gap)
                                // from the finger to its place
                                let dx = at.x - (left + Self.width / 2), dy = at.y - (top + Self.height / 2)
                                row(k, item)
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
                    }
                }
                if let o = optOut { optOutBox(o).opacity(out ? 1 : 0).animation(.easeOut(duration: reduceMotion ? 0.15 : Labs.menuOpen.value), value: out) }
            }
            .closesOnOutsideTouch(close)
            .offset(x: x, y: y - Self.gap / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(caption.map { "\(title). \($0)" } ?? title)
            .accessibilityAction(.escape) { close() }        // (VoiceOver's two-finger scrub)
        }
        .frame(width: layer.width, height: layer.height, alignment: .topLeading)
        .onAppear {
            out = true
            if asking, items.first?.confirm != nil {
                confirmShownAt = Date(); confirming = 0; confirmFocused = true
                UIAccessibility.post(notification: .announcement, argument: items.first?.confirm)
            }
        }
        .onKeyPress(.escape) { close(); return .handled }
    }

    /// Row k: its item, or while one is confirming, the confirm on that item's row and Cancel on the next (the row
    /// before when it's the last); the others fade away and take no touches.
    @ViewBuilder private func row(_ k: Int, _ item: MenuItem) -> some View {
        if let c = confirming {
            let cancelRow = c + 1 < items.count ? c + 1 : c - 1
            if k == c { confirmButton(items[c]) }
            else if k == cancelRow { cancelButton }
            else { button(item, first: k == 0).opacity(0).allowsHitTesting(false).accessibilityHidden(true) }
        } else {
            button(item, first: k == 0)
        }
    }

    /// The second step: the same size and place, outlined in the record red, the words naming what goes.
    private func confirmButton(_ item: MenuItem) -> some View {
        Button {
            guard Date().timeIntervalSince(confirmShownAt) > 0.4 else { return }
            if optedOut, let o = optOut { UserDefaults.standard.set(false, forKey: o.key) }
            close(); item.action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon ?? "trash").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.recText).frame(width: 24)
                Text(item.confirm ?? item.title).font(.lupe(15, .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(height: Self.height)
            .background {
                RoundedRectangle(cornerRadius: 14).fill(tint.map { SelectionTint.fill($0) } ?? Elevation.held.surface).elevationShadow(.held)
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.recText, lineWidth: 3) }   // (recText: 4.9:1 or more on every track's tint; rec fell to 2.98 on lime)
            }
        }
        .buttonStyle(PressSink())
        .accessibilityFocused($confirmFocused)
        .accessibilityHint("Can't be undone. Cancel, or tap away, keeps everything")
        .transition(.opacity)
    }

    /// "Don't ask again": a real toggle, 44 pt tall, the whole row its target. Takes effect with the confirm.
    private func optOutBox(_ o: AppMenu.OptOut) -> some View {
        Toggle(isOn: $optedOut) {
            Text(o.label).font(.lupe(15)).foregroundStyle(Theme.text)
        }
        .toggleStyle(CheckBox())
        .padding(.horizontal, 16)
        .frame(width: Self.width, height: 44)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.map { SelectionTint.fill($0) } ?? Elevation.held.surface).elevationShadow(.held))
        .padding(.top, Self.gap)
        .accessibilityHint(o.hint)
    }

    private var cancelButton: some View {
        Button { close() } label: {
            HStack(spacing: 10) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).frame(width: 24)
                Text("Cancel").font(.lupe(17))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(height: Self.height)
            .background { RoundedRectangle(cornerRadius: 14).fill(tint.map { SelectionTint.fill($0) } ?? Elevation.held.surface).elevationShadow(.held) }
        }
        .buttonStyle(PressSink())
        .transition(.opacity)
    }

    private func button(_ item: MenuItem, first: Bool) -> some View {
        Button {
            if item.children != nil { open(item) }
            else if item.confirm != nil, let k = items.firstIndex(where: { $0.title == item.title }) {
                confirmShownAt = Date()
                withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.2)) { confirming = k }
                confirmFocused = true
                UIAccessibility.post(notification: .announcement, argument: item.confirm)
            }
            else { close(); item.action?() }
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


/// A checkbox: a box that fills with a tick, its words beside it, the whole row the target (a Toggle underneath, so
/// VoiceOver says "switch button, on/off").
struct CheckBox: ToggleStyle {
    func makeBody(configuration c: Configuration) -> some View {
        Button { c.isOn.toggle() } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(c.isOn ? Theme.text : Color.clear)
                    .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.text, lineWidth: 2) }
                    .overlay { if c.isOn { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.onColour) } }
                    .frame(width: 22, height: 22)
                c.label
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: c.$isOn) { c.label } }
    }
}

/// Behind a press menu on the iPad (Scott, 2026-11-15: "on press menus, a 30 % opacity black rectangle behind them, so
/// they're less visually busy"): black at 30 %, 16 pt past the menu each side, its corners the menu's plus 16 (nested
/// radii). Not a page dim; it takes no touches (a touch there is outside the menu and closes it). Drawn in the menu's
/// own frame, so it fades and scales with the menu.
struct PressMenuBacking: View {
    let radius: CGFloat
    static let margin: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: radius + Self.margin)
            .fill(Color.black.opacity(0.3))
            .padding(-Self.margin)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

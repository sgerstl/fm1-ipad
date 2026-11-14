import SloopKit
import SwiftUI

// The preferences Settings sets, each with its UserDefaults key, read with @AppStorage wherever they apply. SettingsSheet is the screen.

/// How a column turns (KnobControl with a column face: Shape, the sound panel, the Mix cards, HOME's four in the
/// track box). Stored with @AppStorage under `key`.
enum SlideToTurn: String, CaseIterable, Identifiable {
    /// A sideways slide, right raises (the default): a vertical drag is always the panel's scroll.
    case sideways
    /// An up and down slide, up raises: a panel scrolls from the gaps between columns, not from a column.
    case vertical
    /// Whichever way the finger first goes, for that slide: up or right raises.
    case both

    static let key = "slideToTurn"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sideways: "Sideways"
        case .vertical: "Up and down"
        case .both: "Both"
        }
    }
}

/// Which hand plays (Scott, 2026-11-08): menus open beside the touch on the side away from it, so the hand doesn't
/// cover them, and the sound buttons' rail sits on its side. Right by default.
enum Handedness: String, CaseIterable, Identifiable {
    case right, left
    static let key = "handedness"
    var id: String { rawValue }
    var title: String { self == .right ? "Right-handed" : "Left-handed" }

    /// A menu's left edge beside a touch at `x` (both in the layer's space `width` wide): on the side away from the
    /// hand, the other side where it wouldn't fit, then kept on screen.
    func menuX(touch x: CGFloat, menuWidth w: CGFloat, in width: CGFloat, margin: CGFloat = 12, gap: CGFloat = 16) -> CGFloat {
        let left = x - gap - w, right = x + gap
        let fitsLeft = left >= margin, fitsRight = right + w <= width - margin
        let pick = self == .right ? (fitsLeft || !fitsRight ? left : right) : (fitsRight || !fitsLeft ? right : left)
        return min(max(margin, pick), max(margin, width - w - margin))
    }

    /// Its top: level with the touch, its first rows by the finger, kept on screen.
    static func menuY(touch y: CGFloat, menuHeight h: CGFloat, in height: CGFloat, margin: CGFloat = 12) -> CGFloat {
        min(max(margin, y - 28), max(margin, height - h - margin))
    }
}

/// Every pad's pattern drawn, not only the ones played (Scott, 2026-11-09): while stopped, Lupe reads the FM-1's
/// pattern pool for the pictures. A trial: on by default; still on at its review (2026-11-16), it stays.
enum PadPreviews {
    static let key = "padPreviews"
    static var on: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

/// Lupe's tracks in the FM-1's THEME colours (Scott, 2026-11-09): on by default; only the six track colours, Lupe's
/// own surfaces and greys stay (they're tuned for contrast).
enum ThemeColours {
    static let key = "themeTrackColours"
    static var on: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

/// The value loupe's switch (ValueLoupe.swift). On by default; off, LoupeState.show does nothing.
enum Magnifier {
    static let key = "magnifier"
    static var on: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

/// Settings' switch for the rail of FX…SEQ keys down the side. Off by default (Scott, 2026-11-08): the page gets the
/// whole width, and an open sound panel carries the FM-1's twelve buttons along its foot instead. A new key, so the
/// old default (on) doesn't carry over.
/// The phone's Settings › Show graphics (decision 30, on by default): each sound page's picture under its four dials.
enum ShowGraphics {
    static let key = "showGraphics"
    static let standard = true
}

extension EnvironmentValues {
    /// A sound card draws no picture (the phone with Show graphics off).
    @Entry var pageGraphHidden = false
    /// A sound card with no surface of its own (the phone's panel is its surface).
    @Entry var soundCardBare = false
}

enum SoundButtons {
    static let key = "soundRail.v2"
    static let standard = false
}

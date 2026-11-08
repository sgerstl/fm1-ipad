import SloopKit
import SwiftUI

// The preferences Settings sets (and a few it shows as trials), each with its UserDefaults key, read with @AppStorage
// wherever they apply. SettingsSheet is the screen.

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

/// The value loupe's switch (ValueLoupe.swift). On by default; off, LoupeState.show does nothing.
enum Magnifier {
    static let key = "magnifier"
    static var on: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

/// Settings' switch for the rail of FX…SEQ keys down the right edge. On by default.
enum SoundButtons {
    static let key = "soundRail"
}

/// The selected track's colour on the Song tab (its row and the knobs' tab): the track's colour mixed into the page,
/// opaque, so the tab covers the lane under it cleanly. How much: a trial in Settings (Scott, 2026-11-07, to pick by
/// eye on the iPad), 18, 24 or 30 %.
enum SelectionTint {
    static let key = "selectionTint"
    static let standard = 24
    static let choices = [18, 24, 30]
    static func fill(_ t: Int, _ percent: Int) -> Color {
        var a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), x: CGFloat(0)), p = a
        UIColor(Theme.track[t]).getRed(&a.r, green: &a.g, blue: &a.b, alpha: &a.x)
        UIColor(Theme.page).getRed(&p.r, green: &p.g, blue: &p.b, alpha: &p.x)
        let k = CGFloat(percent) / 100
        return Color(red: p.r + (a.r - p.r) * k, green: p.g + (a.g - p.g) * k, blue: p.b + (a.b - p.b) * k)
    }
}

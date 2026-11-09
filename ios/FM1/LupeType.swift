import SwiftUI

// Lupe's type (Scott, 2026-11-09, board 45): Barlow, the face Skiff draws the FM-1's screen in, so Lupe reads as the
// instrument's companion; Barlow Condensed for the big numbers (pads, the entry, the track's number, values), which
// also fits tight heads. Fixed sizes, as the system sizes they replace. SF Symbols keep the system font (their weight
// comes from it). Bundled under SIL OFL (Fonts/OFL.txt).

extension Font {
    /// Barlow at a size and weight: the words.
    static func lupe(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(LupeType.barlow(weight), fixedSize: size * LupeType.scale)
    }
    /// Barlow Condensed: the big numbers.
    static func lupeNumber(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(LupeType.condensed(weight), fixedSize: size)
    }
}

enum LupeType {
    /// Barlow sets smaller than SF Pro at a size (narrower, a shorter x-height): the sizes written for SF Pro are taken
    /// up this much, so the words read as they did (small lines like "×1" went tiny).
    static let scale: CGFloat = 1.07
    static func barlow(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black: "Barlow-Bold"
        case .semibold: "Barlow-SemiBold"
        case .medium: "Barlow-Medium"
        default: "Barlow-Regular"
        }
    }
    static func condensed(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black: "BarlowCondensed-Bold"
        case .semibold: "BarlowCondensed-SemiBold"
        default: "BarlowCondensed-Medium"
        }
    }
}

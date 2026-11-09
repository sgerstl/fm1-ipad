import Foundation

/// The FM-1's track colours under its THEME (Scott, 2026-11-09: Lupe's tracks in the colours the FM-1 shows them in).
/// UI_STATE (34) says which THEME is in use; CUSTOM's colours come from COLORS (39, EDITOR_PROTOCOL.md "THEME
/// CUSTOM"); the built-in THEMEs' are Skiff's own (`tools/gen_ui_palettes.py` TRACKS). HI-CON and PAPER have none
/// of their own (the device gives every track its THEME colour): nil, Lupe keeps its own.
public enum SkiffTheme {
    /// UI_PALETTES' order: SKIFF, HI-CON, PAPER, CRYPT, NEON, QUARK, then CUSTOM (6) while one is stored.
    public static let custom = 6
    static let builtIn: [Int: [UInt32]] = [
        0: [0xFF5A36, 0x22C3B4, 0xFFBF00, 0x9580FF, 0xFF6FAE, 0xA3E635],     // SKIFF: vermilion teal amber violet pink lime
        3: [0xEC6E32, 0xF2B63C, 0xDECEA6, 0xE85842, 0xACAC5C, 0xCC86B0],     // CRYPT: ember gold bone blood olive mauve
        4: [0xFF40B0, 0x30E0FF, 0xFFDE5A, 0xFF8038, 0xAA64FF, 0x50FFAA],     // NEON: pink cyan yellow orange violet mint
        5: [0xFF5460, 0x46DC82, 0x5A8CFF, 0x3CDCF0, 0xE660E6, 0xFADC50],     // QUARK: red green blue cyan magenta yellow
    ]

    /// A built-in THEME's six, or nil (HI-CON, PAPER, CUSTOM: read COLORS for that).
    public static func tracks(palette: Int) -> [UInt32]? { builtIn[palette] }

    /// COLORS' reply (rc, flags, look, pack7 of eleven RGB565 low byte first): the six tracks' as RGB.
    public static func customTracks(_ reply: [UInt8]) -> [UInt32]? {
        guard reply.count >= 4, reply[0] == 0, reply[1] & 1 == 1 else { return nil }     // (bit 0: a set stored)
        let b = Pack7.decode(Array(reply[3...]))
        guard b.count >= 22 else { return nil }
        return (0..<6).map { k in
            let v = UInt16(b[10 + 2 * k]) | UInt16(b[11 + 2 * k]) << 8
            let r = UInt32(v >> 11 & 31) * 255 / 31, g = UInt32(v >> 5 & 63) * 255 / 63, bl = UInt32(v & 31) * 255 / 31
            return r << 16 | g << 8 | bl
        }
    }

    /// Each theme colour Lupe can use as a track colour, else Lupe's own for that track: 3:1 against Lupe's page
    /// (#0D0D0F; a lane, a chip on the dark) and 4.5:1 for the dark numbers drawn on it (#101012).
    public static func guarded(_ theme: [UInt32], fallback: [UInt32]) -> [UInt32] {
        fallback.indices.map { k in
            guard k < theme.count else { return fallback[k] }
            let c = theme[k]
            return contrast(c, 0x0D0D0F) >= 3 && contrast(0x101012, c) >= 4.5 ? c : fallback[k]
        }
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func lum(_ c: UInt32) -> Double {
            func ch(_ s: UInt32) -> Double { let v = Double(c >> s & 0xFF) / 255; return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * ch(16) + 0.7152 * ch(8) + 0.0722 * ch(0)
        }
        let x = lum(a), y = lum(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

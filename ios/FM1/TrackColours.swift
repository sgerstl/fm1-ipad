import SloopKit
import SwiftUI

/// Track colours come from the connected firmware's driver (DeviceShape.trackColours): Skiff's six. Theme.track and Theme.trackTop read them here, so every view indexes the
/// same source. Repeated round to 16 entries, so an index past the palette (a view drawn while a device
/// with more tracks connects) gets a colour instead of a crash.
enum TrackColours {
    /// The app's session (RootView sets it); reading its shape inside a view body makes the view follow it.
    nonisolated(unsafe) static weak var session: DeviceSession?

    /// The last palette read on the main thread, for a renderer drawing off it.
    nonisolated(unsafe) private static var cached = DeviceShape.skiffColours

    private static var colours: [UInt32] {
        guard Thread.isMainThread else { return cached }
        let c = MainActor.assumeIsolated { session?.shape.trackColours } ?? DeviceShape.skiffColours
        let own = c.isEmpty ? DeviceShape.skiffColours : c
        // the FM-1's THEME's track colours, where it has its own and Lupe can draw on them (SkiffTheme.guarded:
        // contrast on Lupe's page and for the numbers on them); the rest Lupe's (Scott, 2026-11-09)
        if ThemeColours.on, let t = MainActor.assumeIsolated({ session?.themeTrackColours }) {
            cached = SkiffTheme.guarded(t, fallback: own)
        } else {
            cached = own
        }
        return cached
    }

    static var base: [Color] { padded(colours).map { Color(hex: $0) } }

    static var top: [Color] {
        let c = colours
        let tops = c.map { lift($0, 0.18) }     // the colours lifted 18 % towards white
        return padded(tops).map { Color(hex: $0) }
    }

    private static func padded(_ c: [UInt32]) -> [UInt32] { (0..<max(16, c.count)).map { c[$0 % c.count] } }

    private static func lift(_ rgb: UInt32, _ k: Double) -> UInt32 {
        func ch(_ s: UInt32) -> UInt32 { let v = Double(rgb >> s & 0xFF); return UInt32((v + (255 - v) * k).rounded()) << s }
        return ch(16) | ch(8) | ch(0)
    }
}

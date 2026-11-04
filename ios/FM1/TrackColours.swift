import SloopKit
import SwiftUI

/// Track colours come from the connected firmware's driver (DeviceShape.trackColours): SLOOP's four on
/// SLOOP, Skiff's six on Skiff. Theme.track and Theme.trackTop read them here, so every view indexes the
/// same source. Repeated round to 16 entries, so an index past the palette (a view drawn while a device
/// with more tracks connects) gets a colour instead of a crash.
enum TrackColours {
    /// The app's session (RootView sets it); reading its shape inside a view body makes the view follow it.
    nonisolated(unsafe) static weak var session: DeviceSession?

    /// SLOOP's tops are its own; another palette's are its colours lifted 18 % towards white.
    private static let sloopTops: [UInt32] = [0x4A93FF, 0x4ADB8C, 0xFFD54D, 0xFF8247]

    /// The last palette read on the main thread, for a renderer drawing off it.
    nonisolated(unsafe) private static var cached = DeviceShape.sloopColours

    private static var colours: [UInt32] {
        guard Thread.isMainThread else { return cached }
        let c = MainActor.assumeIsolated { session?.shape.trackColours } ?? DeviceShape.sloopColours
        cached = c.isEmpty ? DeviceShape.sloopColours : c
        return cached
    }

    static var base: [Color] { padded(colours).map { Color(hex: $0) } }

    static var top: [Color] {
        let c = colours
        let tops = c == DeviceShape.sloopColours ? sloopTops : c.map { lift($0, 0.18) }
        return padded(tops).map { Color(hex: $0) }
    }

    private static func padded(_ c: [UInt32]) -> [UInt32] { (0..<max(16, c.count)).map { c[$0 % c.count] } }

    private static func lift(_ rgb: UInt32, _ k: Double) -> UInt32 {
        func ch(_ s: UInt32) -> UInt32 { let v = Double(rgb >> s & 0xFF); return UInt32((v + (255 - v) * k).rounded()) << s }
        return ch(16) | ch(8) | ch(0)
    }
}

import Foundation

/// The launch arguments the app and its fakes read (-demo, -demo-skiff, -page, -slow-motion, … the table in ios/README.md):
/// screenshot, recording and test hooks, so Debug builds only (Scott, 2026-11-09). A Release build sees none.
public enum LaunchArgs {
    public static var all: [String] {
        #if DEBUG
        ProcessInfo.processInfo.arguments
        #else
        []
        #endif
    }
}

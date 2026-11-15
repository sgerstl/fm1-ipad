// swift-tools-version: 6.0
// SkiffDraw (spike, decision 45, 2026-11-15): Skiff-Lupe 2.5.1's own UI drawing code as a library the apps link, fed by
// a mirror of the firmware state it reads. A package of its own so the iPad's SloopKit and Xcode project don't change
// until the spike's verdict is taken (qa/scope-spike-2026-11-15.md).
import PackageDescription

let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "SkiffDraw",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SkiffDraw", targets: ["SkiffDraw"]),
        .library(name: "SkiffDrawLink", targets: ["SkiffDrawLink"]),
    ],
    dependencies: [.package(path: "../SloopKit")],
    targets: [
        // One C file: skiffdraw.c includes Skiff's tests/ui_test.c (the stubs) and through it firmware/src (excluded
        // here so SwiftPM doesn't compile each file on its own: the firmware is a single translation unit).
        .target(name: "CSkiffDraw", exclude: ["skiff"],
                cSettings: [.headerSearchPath("skiff/gen"), .headerSearchPath("skiff/firmware/src"),
                            .unsafeFlags(["-w", "-O2"])]),
        // The Swift face: a mirror and a frame. No SloopKit, no UIKit: builds for Android's Swift too.
        .target(name: "SkiffDraw", dependencies: ["CSkiffDraw"], swiftSettings: v5),
        // Filling the mirror from what the editor link already reads (SloopKit's DeviceSession).
        .target(name: "SkiffDrawLink", dependencies: ["SkiffDraw", "SloopKit"], swiftSettings: v5),
        // The renderer on its own (the Mac; Android through adb shell): GLO › DELAY and a scope to PPMs.
        .executableTarget(name: "skiffdraw-demo", dependencies: ["SkiffDraw"], swiftSettings: v5),
        .testTarget(name: "SkiffDrawTests", dependencies: ["SkiffDraw", "SkiffDrawLink", "SloopKit"], resources: [.copy("Fixtures")], swiftSettings: v5),
    ]
)

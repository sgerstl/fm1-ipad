// swift-tools-version: 6.0
// Lupe's phone core: SloopKit compiled for Android plus what only the phone needs (android/BRIDGE.md §3).
// A package of its own so the iPad's SloopKit package and Xcode project never see these targets.
import PackageDescription

let android: [Platform] = [.android]
let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "LupeCore",
    platforms: [.macOS(.v15)],
    products: [
        // libLupeNative.so: what the APK loads (System.loadLibrary("LupeNative")).
        .library(name: "LupeNative", type: .dynamic, targets: ["LupeNative"]),
    ],
    dependencies: [.package(path: "../../ios/SloopKit"),
                  .package(path: "../../ios/SkiffDraw")],          // decision 45's spike (2026-11-15)
    targets: [
        // jni.h, ALooper and the log, from the NDK's sysroot. Empty on the Mac.
        .target(name: "CAndroid",
                linkerSettings: [.linkedLibrary("android", .when(platforms: android)),
                                 .linkedLibrary("log", .when(platforms: android))]),
        // @MainActor on Android: drains the main dispatch queue from the main Looper.
        .target(name: "MainLooper", dependencies: ["CAndroid"], swiftSettings: v5),
        // AndroidTransport (SysExTransport over bytes from Kotlin) and the factory Session calls. Pure Swift.
        .target(name: "AndroidLink", dependencies: ["SloopKit"], swiftSettings: v5),
        // The façade the Compose screens read (ViewState areas as JSON) and drive (intents). Pure Swift.
        .target(name: "PhoneCore", dependencies: ["SloopKit"], swiftSettings: v5),
        // The JNI surface: six-ish functions, written by hand (BRIDGE.md §3 open question: settled for hand-written).
        .target(name: "LupeNative", dependencies: ["CAndroid", "MainLooper", "AndroidLink", "PhoneCore", "SloopKit",
                                                    .product(name: "SkiffDraw", package: "SkiffDraw"),
                                                    .product(name: "SkiffDrawLink", package: "SkiffDraw")],
                swiftSettings: v5),
        // Gate 2's proof outside the app: hops between a background thread and the main actor on a native ALooper.
        .executableTarget(name: "looper-probe", dependencies: ["CAndroid", "MainLooper"], swiftSettings: v5),
        .testTarget(name: "LupeCoreTests", dependencies: ["AndroidLink", "PhoneCore", "SloopKit"], swiftSettings: v5),
    ]
)

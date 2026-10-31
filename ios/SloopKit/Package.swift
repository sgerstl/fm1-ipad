// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SloopKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "SloopKit", targets: ["SloopKit"])],
    targets: [
        .target(name: "SloopKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "SloopKitTests", dependencies: ["SloopKit"],
                    resources: [.copy("Fixtures")], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)

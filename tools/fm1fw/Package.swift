// swift-tools-version: 6.0
// fm1fw: back up an FM-1 and install a firmware file from the Mac, with SloopKit's own backup and installer (the code
// the iPad app uses), for testing a build Lupe doesn't pin. See README.md. Nothing protocol-level is new here.
import PackageDescription

let package = Package(
    name: "fm1fw",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../ios/SloopKit")],
    targets: [
        .target(name: "FM1FWCore", dependencies: [.product(name: "SloopKit", package: "SloopKit")],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "fm1fw", dependencies: ["FM1FWCore", .product(name: "SloopKit", package: "SloopKit")],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "FM1FWTests", dependencies: ["FM1FWCore", .product(name: "SloopKit", package: "SloopKit")],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)

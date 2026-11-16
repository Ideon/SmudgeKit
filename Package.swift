// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmudgeKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SmudgeKit", targets: ["SmudgeKit"]),
    ],
    targets: [
        // SmudgeKit is for recordings and demos, never for shipping builds: in Release its
        // sources compile to nothing, so neither it nor ReplayKit ends up in the app.
        .target(
            name: "SmudgeKit",
            swiftSettings: [.define("SMUDGEKIT_ENABLED", .when(configuration: .debug))]
        ),
        .testTarget(name: "SmudgeKitTests", dependencies: ["SmudgeKit"]),
    ],
    swiftLanguageModes: [.v6]
)

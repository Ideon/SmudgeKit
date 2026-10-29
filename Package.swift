// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmudgeKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SmudgeKit", targets: ["SmudgeKit"]),
    ],
    targets: [
        .target(name: "SmudgeKit"),
        .testTarget(name: "SmudgeKitTests", dependencies: ["SmudgeKit"]),
    ],
    swiftLanguageModes: [.v6]
)

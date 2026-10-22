// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TermHintsKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TermHintsKit", targets: ["TermHintsKit"])],
    targets: [
        .target(name: "TermHintsKit"),
        .testTarget(name: "TermHintsKitTests", dependencies: ["TermHintsKit"])
    ]
)

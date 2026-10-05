// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SubmitCore", platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SubmitCore", targets: ["SubmitCore"])],
    targets: [.target(name: "SubmitCore"), .testTarget(name: "SubmitCoreTests", dependencies: ["SubmitCore"])]
)

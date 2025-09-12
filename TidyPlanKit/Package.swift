// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TidyPlanKit",
    platforms: [
        .iOS(.v15), .macOS(.v12)
    ],
    products: [
        .library(name: "TidyPlanKit", targets: ["TidyPlanKit"])
    ],
    targets: [
        .target(name: "TidyPlanKit", dependencies: [])
    ]
)


// swift-tools-version: 6.4
import PackageDescription
let package = Package(
    name: "Shelferry", platforms: [.macOS(.v14)],
    products: [.executable(name: "Shelferry", targets: ["ShelferryApp"]), .executable(name: "ShelferryCommand", targets: ["ShelferryCLI"])],
    dependencies: [
        // Matches Tooki’s supported macOS 14 and fallback-SDK dependency baseline.
        .package(url: "https://github.com/apple/swift-collections", exact: "1.2.1"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2")],
    targets: [
        .target(name: "ShelferryCore"),
        .target(name: "ShelferryProtocol"),
        .target(name: "ShelferryDesignSystem", dependencies: ["ShelferryCore"]),
        .target(name: "ShelfFeature", dependencies: ["ShelferryCore", .product(name: "ComposableArchitecture", package: "swift-composable-architecture")]),
        .executableTarget(name: "ShelferryApp", dependencies: ["ShelferryCore", "ShelferryDesignSystem", "ShelferryProtocol", "ShelfFeature", .product(name: "ComposableArchitecture", package: "swift-composable-architecture")]),
        .executableTarget(name: "ShelferryCLI", dependencies: ["ShelferryProtocol"]),
        .testTarget(name: "ShelfFeatureTests", dependencies: ["ShelfFeature"]),
        .testTarget(name: "ShelferryPreferencesTests", dependencies: ["ShelferryApp"]),
        .testTarget(name: "ShelferryProtocolTests", dependencies: ["ShelferryProtocol"])
    ]
)

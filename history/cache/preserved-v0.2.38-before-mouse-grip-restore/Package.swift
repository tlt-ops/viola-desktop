// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ViolaDesktop",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ViolaDesktop", targets: ["ViolaDesktop"]), .executable(name: "ViolaChecks", targets: ["ViolaChecks"])],
    targets: [
        .target(name: "ViolaCore"),
        .executableTarget(name: "ViolaDesktop", dependencies: ["ViolaCore"], resources: [.copy("Resources")]),
        .executableTarget(name: "ViolaChecks", dependencies: ["ViolaCore"])
    ]
)

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenLedgerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "OpenLedgerCore", targets: ["OpenLedgerCore"]),
        .executable(name: "OpenLedgerCoreCheck", targets: ["OpenLedgerCoreCheck"])
    ],
    targets: [
        .target(name: "OpenLedgerCore"),
        .executableTarget(name: "OpenLedgerCoreCheck", dependencies: ["OpenLedgerCore"]),
        .testTarget(name: "OpenLedgerCoreTests", dependencies: ["OpenLedgerCore"])
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftVehicleProtocols",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "SwiftVehicleProtocols",
            targets: ["SwiftVehicleProtocols"]
        ),
        .library(name: "VehicleCore", targets: ["VehicleCore"]),
        .library(name: "VehicleISOTP", targets: ["VehicleISOTP"]),
        .library(name: "VehicleDiagnostic", targets: ["VehicleDiagnostic"]),
        .library(name: "VehicleTransport", targets: ["VehicleTransport"]),
        .library(name: "VehicleTransportPanda", targets: ["VehicleTransportPanda"]),
        .library(name: "VehicleAnalytics", targets: ["VehicleAnalytics"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VehicleCore",
            dependencies: [],
            path: "Sources/VehicleCore"
        ),
        .target(
            name: "VehicleISOTP",
            dependencies: ["VehicleCore"],
            path: "Sources/VehicleISOTP"
        ),
        .target(
            name: "VehicleDiagnostic",
            dependencies: ["VehicleCore", "VehicleISOTP"],
            path: "Sources/VehicleDiagnostic"
        ),
        .target(
            name: "VehicleTransport",
            dependencies: ["VehicleCore"],
            path: "Sources/VehicleTransport"
        ),
        .target(
            name: "VehicleTransportPanda",
            dependencies: ["VehicleTransport", "VehicleCore"],
            path: "Sources/VehicleTransportPanda"
        ),
        .target(
            name: "VehicleAnalytics",
            dependencies: ["VehicleCore"],
            path: "Sources/VehicleAnalytics"
        ),
        .target(
            name: "SwiftVehicleProtocols",
            dependencies: [
                "VehicleCore",
                "VehicleISOTP",
                "VehicleDiagnostic",
                "VehicleTransport",
                "VehicleTransportPanda",
                "VehicleAnalytics"
            ],
            path: "Sources/SwiftVehicleProtocols"
        ),
        .testTarget(
            name: "SwiftVehicleProtocolsTests",
            dependencies: ["SwiftVehicleProtocols"],
            path: "Tests/SwiftVehicleProtocolsTests"
        )
    ]
)

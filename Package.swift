// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "PowerFlowLite",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "PowerFlowLite", targets: ["PowerFlowLite"]),
    .executable(name: "PowerFlowChecks", targets: ["PowerFlowChecks"]),
  ],
  targets: [
    .target(
      name: "PowerFlowCore",
      linkerSettings: [
        .linkedFramework("IOKit")
      ]
    ),
    .target(
      name: "PowerFlowUI",
      dependencies: ["PowerFlowCore"],
      path: "Sources/PowerFlowLite"
    ),
    .executableTarget(
      name: "PowerFlowLite",
      dependencies: ["PowerFlowUI"],
      path: "Sources/PowerFlowLiteApp"
    ),
    .executableTarget(
      name: "PowerFlowChecks",
      dependencies: ["PowerFlowCore"]
    ),
    .executableTarget(
      name: "PowerFlowPreviewRenderer",
      dependencies: ["PowerFlowCore", "PowerFlowUI"]
    ),
  ]
)

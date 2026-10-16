// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Fancy",
  platforms: [
    .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.60.0")
  ],
  targets: [
    .executableTarget(
      name: "Fancy",
      dependencies: [
        "FancyCore",
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self)
      ]
    ),
    .target(
      name: "FancyCore",
      swiftSettings: [
        .defaultIsolation(MainActor.self)
      ]
    ),
    .testTarget(
      name: "FancyCoreTests",
      dependencies: [
        "FancyCore"
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self)
      ]
    ),
  ]
)

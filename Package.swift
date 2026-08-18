// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Textboard",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Textboard", targets: ["Textboard"])
  ],
  targets: [
    .executableTarget(
      name: "Textboard",
      path: "Sources/Textboard"
    )
  ]
)

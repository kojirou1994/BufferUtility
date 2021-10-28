// swift-tools-version:5.4

import PackageDescription

let package = Package(
  name: "BufferUtility",
  platforms: [
    .macOS(.v10_13)
  ],
  products: [
    .library(name: "BufferUtility", targets: ["BufferUtility"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-system.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "BufferUtility",
      dependencies: [
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]),
    .testTarget(
      name: "BufferUtilityTests",
      dependencies: ["BufferUtility"]),
  ]
)

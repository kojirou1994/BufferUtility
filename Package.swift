// swift-tools-version:5.4

import PackageDescription

let package = Package(
  name: "BufferUtility",
  platforms: [
    .macOS(.v10_13)
  ],
  products: [
    .library(
      name: "BufferUtility",
      targets: ["BufferUtility"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-system.git", from: "0.0.1"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "0.0.1"),
  ],
  targets: [
    .target(
      name: "BufferUtility",
      dependencies: [
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]),
    .executableTarget(
      name: "BufferUtilityExample",
      dependencies: ["BufferUtility"]),
    .executableTarget(
      name: "SlowCopy",
      dependencies: ["BufferUtility"]),
    .executableTarget(
      name: "FastCopy",
      dependencies: ["BufferUtility"]),
    .testTarget(
      name: "BufferUtilityTests",
      dependencies: ["BufferUtility"]),
  ]
)

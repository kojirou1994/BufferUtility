// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "BufferUtility",
  products: [
    .library(
      name: "BufferUtility",
      targets: ["BufferUtility"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-system", from: "0.0.1"),
  ],
  targets: [
    .target(
      name: "BufferUtility",
      dependencies: [
        ._productItem(name: "SystemPackage", package: "swift-system", condition: .when(platforms: [.linux]))
      ]),
    .target(
      name: "BufferUtilityExample",
      dependencies: ["BufferUtility"]),
    .target(
      name: "SlowCopy",
      dependencies: ["BufferUtility"]),
    .testTarget(
      name: "BufferUtilityTests",
      dependencies: ["BufferUtility"]),
  ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "BufferUtility",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(name: "BufferUtility", targets: ["BufferUtility"]),
    .library(name: "BufferUtilityDarwin", targets: ["BufferUtilityDarwin"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/SystemUp.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "BufferUtility",
      dependencies: [
        .product(name: "SystemUp", package: "SystemUp"),
        .product(name: "DequeModule", package: "swift-collections"),
      ]),
    .target(
      name: "BufferUtilityDarwin",
      dependencies: [
        "BufferUtility"
      ]),
    .testTarget(
      name: "BufferUtilityTests",
      dependencies: ["BufferUtility"]),
  ]
)

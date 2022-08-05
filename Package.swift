// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "WSTagsField",
  platforms: [
    .iOS(.v9)
  ],
  products: [
    .library(name: "WSTagsField", targets: ["WSTagsField"])
  ],
  targets: [
    .target(name: "WSTagsField", exclude: ["Info.plist", "WSTagsField.h"]),
    .testTarget(name: "WSTagsFieldTests", dependencies: ["WSTagsField"], exclude: ["Info.plist"])
  ]
)

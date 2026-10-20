// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MLKEMNative",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MLKEMNative",
            targets: ["MLKEMNative"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "CMLKEMNative",
            path: "bindings/xcframework/CMLKEMNative.xcframework"
        ),
        .target(
            name: "MLKEMNative",
            dependencies: ["CMLKEMNative"],
            path: "Sources"
        ),
        .testTarget(
            name: "MLKEMNativeTests",
            dependencies: ["MLKEMNative"],
            path: "Tests"
        )
    ]
)

// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TgoRTCSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        // SDK 产品，暴露给外部使用
        .library(
            name: "TgoRTCSDK",
            targets: ["TgoRTCSDK"]
        ),
    ],
    dependencies: [
        // LiveKit 依赖
        .package(url: "https://github.com/livekit/client-sdk-swift.git", from: "2.11.0"),
    ],
    targets: [
        // SDK 主要 Target
        .target(
            name: "TgoRTCSDK",
            dependencies: [
                .product(name: "LiveKit", package: "client-sdk-swift"),
            ],
            path: "TgoRTCSDK"
        ),
        // 测试 Target（可选）
        .testTarget(
            name: "TgoRTCSDKTests",
            dependencies: ["TgoRTCSDK"],
            path: "TgoRTCSDKTests"
        ),
    ]
)

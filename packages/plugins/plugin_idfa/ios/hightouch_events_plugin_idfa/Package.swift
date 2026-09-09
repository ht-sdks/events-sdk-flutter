// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hightouch_events_plugin_idfa",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "hightouch-events-plugin-idfa", type: .static, targets: ["hightouch_events_plugin_idfa"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "hightouch_events_plugin_idfa",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            linkerSettings: [
                .linkedFramework("AdSupport", .when(platforms: [.iOS])),
                .linkedFramework("AppTrackingTransparency", .when(platforms: [.iOS])),
            ]
        ),
    ]
)

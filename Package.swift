// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

//
//  Package.swift
//  Ventus package
//
//  Created by Javier Fuchs on 07/26/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "VentusPackage",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26),
        .watchOS(.v26)
    ], products: [
        .library(
            name: "Ventus",
            targets: ["Ventus"]),
        .library(
            name: "VentusWidgets",
            targets: ["VentusWidgets"]),
        // Firebase stays outside the UI package.  This keeps Xcode previews
        // for individual Ventus views from JIT-linking Analytics,
        // Crashlytics, and all of their transitive dependencies.
        .library(
            name: "VentusFirebase",
            targets: ["VentusFirebase"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.6.1"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
        .package(url: "https://github.com/heirloomlogic/AstronomyKit.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "VentusGraph",
            path: "Sources/VentusGraph"),
        .target(
            name: "Ventus",
            dependencies: [
                "VentusGraph",
                .product(
                    name: "Lottie",
                    package: "lottie-spm",
                    condition: .when(platforms: [.iOS, .tvOS, .visionOS])
                ),
                .product(name: "AstronomyKit", package: "AstronomyKit"),
            ],
            path: "Sources/Ventus",
            resources: [.process("Resources")]),
        .target(
            name: "VentusWidgets",
            dependencies: ["Ventus"],
            path: "Sources/VentusWidgets"),
        .target(
            name: "VentusFirebase",
            dependencies: [
                "Ventus",
                .product(
                    name: "FirebaseAnalytics",
                    package: "firebase-ios-sdk",
                    condition: .when(platforms: [.iOS, .macOS, .tvOS])
                ),
                .product(
                    name: "FirebaseCrashlytics",
                    package: "firebase-ios-sdk",
                    condition: .when(platforms: [.iOS, .macOS, .tvOS, .watchOS])
                ),
            ],
            path: "Sources/VentusFirebase"),
        .testTarget(
            name: "VentusTests",
            dependencies: ["Ventus"],
            path: "Tests/VentusTests"),
    ]
)

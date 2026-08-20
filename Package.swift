// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

//
//  Package.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 07/26/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "ForescoopPackage",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26),
        .watchOS(.v26)
    ], products: [
        .library(
            name: "Forescoop",
            targets: ["Forescoop"]),
        .library(
            name: "ForescoopWidgets",
            targets: ["ForescoopWidgets"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.6.1"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "ForescoopGraph",
            path: "Sources/ForescoopGraph"),
        .target(
            name: "Forescoop",
            dependencies: [
                "ForescoopGraph",
                .product(
                    name: "Lottie",
                    package: "lottie-spm",
                    condition: .when(platforms: [.iOS, .tvOS, .visionOS])
                ),
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
            path: "Sources/Forescoop",
            resources: [.process("Resources")]),
        .target(
            name: "ForescoopWidgets",
            dependencies: ["Forescoop"],
            path: "Sources/ForescoopWidgets"),
        .testTarget(
            name: "ForescoopTests",
            dependencies: ["Forescoop"],
            path: "Tests/ForescoopTests"),
    ]
)

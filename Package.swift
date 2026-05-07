// swift-tools-version: 6.3.1

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-linter-rules",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "Linter Rule Unchecked",
            targets: ["Linter Rule Unchecked"]
        ),
        .library(
            name: "Linter Rule Cardinal",
            targets: ["Linter Rule Cardinal"]
        ),
        .library(
            name: "Linter Rule RawValue",
            targets: ["Linter Rule RawValue"]
        ),
        .library(
            name: "Linter Rule ResultBuilder",
            targets: ["Linter Rule ResultBuilder"]
        ),

        // Wave 1 — AI-harness rule encoding (Phase 4).
        .library(
            name: "Linter Rule Try",
            targets: ["Linter Rule Try"]
        ),
        .library(
            name: "Linter Rule Throws",
            targets: ["Linter Rule Throws"]
        ),
        .library(
            name: "Linter Rule Naming",
            targets: ["Linter Rule Naming"]
        ),
        .library(
            name: "Linter Rules Test Support",
            targets: ["Linter Rules Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-linter-primitives"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        // MARK: - Linter Rule Unchecked
        .target(
            name: "Linter Rule Unchecked",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Linter Rule Cardinal
        .target(
            name: "Linter Rule Cardinal",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ]
        ),

        // MARK: - Linter Rule RawValue
        .target(
            name: "Linter Rule RawValue",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Linter Rule ResultBuilder
        .target(
            name: "Linter Rule ResultBuilder",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 1 — AI-harness rules (Phase 4)

        // MARK: - Linter Rule Try
        .target(
            name: "Linter Rule Try",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Linter Rule Throws
        .target(
            name: "Linter Rule Throws",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Linter Rule Naming
        .target(
            name: "Linter Rule Naming",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Linter Rules Test Support",
            dependencies: [
                "Linter Rule Cardinal",
                "Linter Rule Naming",
                "Linter Rule RawValue",
                "Linter Rule ResultBuilder",
                "Linter Rule Throws",
                "Linter Rule Try",
                "Linter Rule Unchecked",
                .product(name: "Linter Primitives Test Support", package: "swift-linter-primitives"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Linter Rule Unchecked Tests",
            dependencies: [
                "Linter Rule Unchecked",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Cardinal Tests",
            dependencies: [
                "Linter Rule Cardinal",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule RawValue Tests",
            dependencies: [
                "Linter Rule RawValue",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule ResultBuilder Tests",
            dependencies: [
                "Linter Rule ResultBuilder",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 1 Tests (Phase 4)

        .testTarget(
            name: "Linter Rule Try Tests",
            dependencies: [
                "Linter Rule Try",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Throws Tests",
            dependencies: [
                "Linter Rule Throws",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Naming Tests",
            dependencies: [
                "Linter Rule Naming",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}

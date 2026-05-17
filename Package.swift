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
            name: "Linter Rule ResultBuilder",
            targets: ["Linter Rule ResultBuilder"]
        ),

        // Wave 2b finalization (2026-05-10) — file-structure rules.
        .library(
            name: "Linter Rule Structure",
            targets: ["Linter Rule Structure"]
        ),

        // Wave 2b finalization (2026-05-10) — memory-safety rules.
        .library(
            name: "Linter Rule Memory",
            targets: ["Linter Rule Memory"]
        ),

        // Wave 2b finalization (2026-05-10) — testing-shape rules.
        .library(
            name: "Linter Rule Testing",
            targets: ["Linter Rule Testing"]
        ),

        // Wave 3 mechanization (2026-05-11) — implementation-idiom rules.
        .library(
            name: "Linter Rule Idiom",
            targets: ["Linter Rule Idiom"]
        ),

        .library(
            name: "Linter Rules Test Support",
            targets: ["Linter Rules Test Support"]
        ),

        // Aggregate bundle — re-exports every pack in this package and
        // publishes `Lint.Rule.Bundle.universal` for consumers that
        // want the full universal-tier rule set without enumerating
        // individual rules. See
        // `swift-institute/Research/three-tier-linter-rules-partition.md`.
        .library(
            name: "Linter Rules",
            targets: ["Linter Rules"]
        ),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-linter-primitives"),
        .package(path: "../../swift-primitives/swift-cardinal-primitives"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        // MARK: - Linter Rule ResultBuilder
        .target(
            name: "Linter Rule ResultBuilder",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 2b Finalization — Linter Rule Structure
        .target(
            name: "Linter Rule Structure",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 2b Finalization — Linter Rule Memory
        .target(
            name: "Linter Rule Memory",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 2b Finalization — Linter Rule Testing
        .target(
            name: "Linter Rule Testing",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 3 Mechanization — Linter Rule Idiom
        .target(
            name: "Linter Rule Idiom",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        // MARK: - Universal Bundle (aggregate)
        .target(
            name: "Linter Rules",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                "Linter Rule Idiom",
                "Linter Rule Memory",
                "Linter Rule ResultBuilder",
                "Linter Rule Structure",
                "Linter Rule Testing",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Linter Rules Test Support",
            dependencies: [
                // Test support only provides the parsed-source factory; it
                // does not depend on any rule pack. Per-pack test targets
                // depend on their own pack + this support module.
                .product(name: "Linter Primitives Test Support", package: "swift-linter-primitives"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Linter Rule ResultBuilder Tests",
            dependencies: [
                "Linter Rule ResultBuilder",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        // MARK: - Wave 2b Finalization Tests
        .testTarget(
            name: "Linter Rule Structure Tests",
            dependencies: [
                "Linter Rule Structure",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Memory Tests",
            dependencies: [
                "Linter Rule Memory",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Testing Tests",
            dependencies: [
                "Linter Rule Testing",
                "Linter Rules Test Support",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // MARK: - Wave 3 Mechanization Tests
        .testTarget(
            name: "Linter Rule Idiom Tests",
            dependencies: [
                "Linter Rule Idiom",
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

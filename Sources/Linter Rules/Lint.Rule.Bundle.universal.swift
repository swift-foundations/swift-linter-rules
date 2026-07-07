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

public import Linter_Primitives
public import Linter_Rule_Idiom
public import Linter_Rule_Memory
public import Linter_Rule_ResultBuilder
public import Linter_Rule_Structure
public import Linter_Rule_Suppression
public import Linter_Rule_Testing

/// Universal-tier rule bundle.
///
/// After Wave 3 (2026-05-15) the universal bundle contains the strict T1
/// set — rules whose kernel is a Swift compiler invariant, a Swift
/// Evolution-documented performance/safety recommendation, or a
/// universal type-system hygiene rule that bites any Swift project
/// regardless of architecture or naming convention. All T2 (institute)
/// and T3 (primitives) rules have been relocated per
/// `swift-institute/Research/three-tier-linter-rules-partition.md`.
///
/// A consumer pulls this bundle by name rather than enumerating
/// individual rules:
///
/// ```swift
/// let configuration = Lint.Configuration {
///     Lint.Rule.Bundle.universal
/// }
/// ```
extension Lint.Rule.Bundle {
    public static let universal: [Lint.Rule.Configuration] = [
        // Idiom pack
        .enable(.`redundant refinement`),
        // Memory pack
        .enable(.`unchecked sendable categorization`),
        .enable(.`unchecked sendable noncopyable`),
        .enable(.`unsafe storage visibility`),
        // ResultBuilder pack
        .enable(.`for loop in result builder`),
        // Structure pack
        .enable(.`inlinable internal access`),
        .enable(.`usable from inline internal import`),
        // Suppression pack (rules-pass tail 2026-07-07) — [LINT-SUPPRESS-001]
        .enable(.`malformed suppression directive`),
        // Testing pack
        .enable(.`mock factory zero collision`),
    ]
}

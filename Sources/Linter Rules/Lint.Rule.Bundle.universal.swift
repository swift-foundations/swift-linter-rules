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
public import Linter_Rule_Cardinal
public import Linter_Rule_Closure
public import Linter_Rule_Idiom
public import Linter_Rule_Memory
public import Linter_Rule_Platform
public import Linter_Rule_ResultBuilder
public import Linter_Rule_Structure
public import Linter_Rule_Testing
public import Linter_Rule_Throws
public import Linter_Rule_Try
public import Linter_Rule_Unchecked

/// Universal-tier rule bundle.
///
/// Every rule that currently lives in `swift-linter-rules`, enabled at
/// each rule's `defaultSeverity`. A consumer pulls this bundle by name
/// rather than enumerating individual rules:
///
/// ```swift
/// let configuration = Lint.Configuration {
///     Lint.Rule.Bundle.universal
/// }
/// ```
///
/// The bundle currently includes universal hygiene rules plus mixed
/// packs that have not yet been split into tier-specific subpacks per
/// `swift-institute/Research/three-tier-linter-rules-partition.md`.
/// As mixed packs are split, the universal bundle's content sharpens
/// to the strict T1 set; consumers continue to reference
/// `Lint.Rule.Bundle.universal` and pick up the narrowed set
/// automatically.
extension Lint.Rule.Bundle {
    public static let universal: [Lint.Rule.Configuration] = [
        // Cardinal pack
        .enable(.`zero or one literal`),
        .enable(.`count minus one`),
        // Closure pack
        .enable(.`configuration before content`),
        .enable(.`lifecycle order`),
        .enable(.`unlabeled lifecycle closure`),
        .enable(.`parameter position`),
        // Idiom pack
        .enable(.`bounded index static capacity`),
        .enable(.`enumerated with subscript`),
        .enable(.`intermediate binding then return`),
        .enable(.`counter loop iteration`),
        .enable(.`string utf8 scanning`),
        // Memory pack
        .enable(.`borrowing self short circuit`),
        .enable(.`noncopyable error`),
        .enable(.`extension noncopyable constraint`),
        .enable(.`nonisolated unsafe without invariant`),
        .enable(.`safe attribute forbidden`),
        .enable(.`pointer advanced by`),
        .enable(.`unsafe storage visibility`),
        .enable(.`sendable struct with class member`),
        .enable(.`unchecked sendable categorization`),
        .enable(.`unchecked sendable noncopyable`),
        .enable(.`unsafe assignment granularity`),
        // Platform pack
        .enable(.`c type in public api`),
        .enable(.`convention c representability`),
        .enable(.`dead case per platform`),
        .enable(.`compound platform namespace root`),
        .enable(.`optionset shell pattern`),
        .enable(.`canimport conditional`),
        .enable(.`swift protocol qualification`),
        .enable(.`system subdomain`),
        .enable(.`typealiased namespace bridge`),
        // ResultBuilder pack
        .enable(.`for loop in result builder`),
        // Structure pack
        .enable(.`hoisted protocol alias`),
        .enable(.`inlinable internal access`),
        .enable(.`minimal type body`),
        .enable(.`raw value access`),
        .enable(.`single type per file`),
        .enable(.`throwing wrapper init`),
        .enable(.`type transform placement`),
        .enable(.`usable from inline internal import`),
        .enable(.`wrapper backing exposed`),
        // Testing pack
        .enable(.`benchmark timed required`),
        .enable(.`compound suite name`),
        .enable(.`test function naming`),
        .enable(.`mock factory zero collision`),
        .enable(.`performance suite serialized`),
        // Throws pack
        .enable(.`closure typed throws annotation`),
        .enable(.`do throws for typed catch`),
        .enable(.`do throws for typed catch with throw`),
        .enable(.`existential throws`),
        .enable(.`generic throws missing never`),
        .enable(.`hoisted error in public throws`),
        .enable(.`lifecycle typealias review`),
        .enable(.`callback result over throws thunk`),
        .enable(.`result wrapper for rethrows shim`),
        .enable(.`typed throws cannot use self error`),
        .enable(.`untyped throws`),
        // Try pack
        .enable(.`try optional`),
        // Unchecked pack
        .enable(.`unchecked call site`),
    ]
}

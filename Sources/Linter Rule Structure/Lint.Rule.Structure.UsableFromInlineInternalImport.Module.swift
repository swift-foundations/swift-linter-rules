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

internal import SwiftSyntax

/// Carries an internal-import's diagnostic site (the `import` keyword
/// position) and the imported module's leaf name.
///
/// The leaf name is the
/// reach-target the rule uses to test whether any `@usableFromInline`
/// decl syntactically references the module — without a name match,
/// there's no co-firing condition and the rule must not fire.
///
/// Citation: tightening per A6 in
/// `Research/2026-05-12-thread-b-rule-pack-dogfeed-triage.md`.
internal struct StructureUsableFromInlineInternalImportModule {
    let position: AbsolutePosition
    let leafName: Swift.String
}

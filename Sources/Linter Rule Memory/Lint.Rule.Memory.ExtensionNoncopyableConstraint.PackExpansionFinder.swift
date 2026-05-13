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

/// Detects parameter-pack usage (`each T`, `repeat each T`) anywhere
/// in an extension's member block. Swift 6.x does not support
/// `~Copyable each T` at the language level — extensions on
/// parameter-pack types cannot express the `where Element: ~Copyable`
/// clause the rule otherwise requires. Treat presence of pack syntax
/// as an authoritative signal that the rule's normal demand is
/// inexpressible and exempt the extension.
///
/// Sunset: when Swift adopts `~Copyable each T` (swift-evolution; not
/// imminent as of 2026-05-11), re-examine. Parameter-pack extensions
/// will then have an expressible constraint and the exemption should
/// retire so the rule fires legitimately.
internal final class MemoryExtensionPackExpansionFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: PackExpansionTypeSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_ node: PackElementTypeSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
}

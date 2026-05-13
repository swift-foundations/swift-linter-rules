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

/// Walks a closure body searching for `try` expressions that are NOT
/// materialized into a Result-shape return via an enclosing
/// `do { ... } catch { return ... }`. A `try` inside such a do-catch
/// has its error captured into the catch's return value (the
/// [IMPL-109] Result-materialization pattern) — the closure remains
/// non-throwing by construction and doesn't need an explicit
/// `throws(E)` annotation. A `try` NOT inside such a materializing
/// do-catch escapes the closure and DOES need annotation.
///
/// The walker stops at nested closure boundaries (a try inside a
/// nested closure is the nested closure's concern, not this one's).
internal final class ThrowsClosureTryFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        if !throwsClosureTryIsInsideMaterializingDoCatch(Syntax(node)) {
            found = true
        }
        return .skipChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
}

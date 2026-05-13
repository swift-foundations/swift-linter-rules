// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

internal import SwiftSyntax

/// Detects a `ForInStmt` in a syntax subtree, treating nested closures
/// as opaque (a `for` inside a nested closure is in a different
/// builder context, not the one we're inspecting).
internal final class ResultBuilderForLoopForInDetector: SyntaxVisitor {
    var found = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        // Don't descend into nested closures — they may have their
        // own builder context, or be regular Swift closures.
        .skipChildren
    }
}

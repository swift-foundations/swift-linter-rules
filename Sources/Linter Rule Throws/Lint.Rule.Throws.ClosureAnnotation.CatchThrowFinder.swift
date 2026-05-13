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

internal final class ThrowsClosureCatchThrowFinder: SyntaxVisitor {
    var foundThrow = false
    override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
        foundThrow = true
        return .skipChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        // Nested closures have their own boundary.
        return .skipChildren
    }
}

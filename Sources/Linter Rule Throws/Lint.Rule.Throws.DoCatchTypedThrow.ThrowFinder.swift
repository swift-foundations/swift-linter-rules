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

internal final class ThrowsDoCatchThrowFinder: SyntaxVisitor {
    var found = false
    override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}

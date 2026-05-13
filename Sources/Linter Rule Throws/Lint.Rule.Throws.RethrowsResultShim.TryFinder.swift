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

internal final class ThrowsRethrowsTryFinder: SyntaxVisitor {
    var positions: [AbsolutePosition] = []
    var closureDepth: Swift.Int = -1
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.questionOrExclamationMark == nil else {
            return .visitChildren
        }
        // Admit `try` inside `do { ... } catch { ... }` whose catch
        // materializes the error (the [IMPL-109] Result-shim
        // remediation): the closure remains non-throwing by
        // construction, so the rule's own prescribed fix shape MUST
        // NOT re-fire. Helper lives in `Lint.Rule.Throws.ClosureAnnotation.swift`
        // (API-ERR-004) and stops the walk at the closure boundary.
        if throwsClosureTryIsInsideMaterializingDoCatch(Syntax(node)) {
            return .visitChildren
        }
        positions.append(node.tryKeyword.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        closureDepth += 1
        if closureDepth > 0 { return .skipChildren }
        return .visitChildren
    }
    override func visitPost(_: ClosureExprSyntax) { closureDepth -= 1 }
    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}

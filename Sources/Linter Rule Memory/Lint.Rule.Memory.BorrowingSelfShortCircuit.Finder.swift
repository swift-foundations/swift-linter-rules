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

internal final class MemoryBorrowingSelfShortCircuitFinder: SyntaxVisitor {
    let borrowingSelfNames: Swift.Set<Swift.String>
    var positions: [AbsolutePosition] = []

    init(viewMode: SyntaxTreeViewMode, borrowingSelfNames: Swift.Set<Swift.String>) {
        self.borrowingSelfNames = borrowingSelfNames
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        // Collect short-circuit operator positions in this sequence.
        var shortCircuitPositions: [AbsolutePosition] = []
        for element in node.elements {
            guard let op = element.as(BinaryOperatorExprSyntax.self) else { continue }
            if op.operator.text == "&&" || op.operator.text == "||" {
                shortCircuitPositions.append(op.operator.positionAfterSkippingLeadingTrivia)
            }
        }
        guard !shortCircuitPositions.isEmpty else { return .visitChildren }
        // Check whether any non-operator element in the sequence roots
        // to a borrowing-Self parameter. The rule's documented
        // recommendation is to use local `let` bindings (e.g.,
        // `let lhsCopy = copy lhs`) and short-circuit on those — that
        // shape should not fire. Only fire if the short-circuit
        // operands directly reference the borrowed self.
        var anyOperandIsBorrowingSelf = false
        for element in node.elements {
            if element.is(BinaryOperatorExprSyntax.self) { continue }
            if rootIdentifierIsBorrowingSelf(element) {
                anyOperandIsBorrowingSelf = true
                break
            }
        }
        if anyOperandIsBorrowingSelf {
            positions.append(contentsOf: shortCircuitPositions)
        }
        return .visitChildren
    }

    private func rootIdentifierIsBorrowingSelf(_ node: some SyntaxProtocol) -> Swift.Bool {
        if let decl = node.as(DeclReferenceExprSyntax.self) {
            return borrowingSelfNames.contains(decl.baseName.text)
        }
        if let member = node.as(MemberAccessExprSyntax.self) {
            if let base = member.base {
                return rootIdentifierIsBorrowingSelf(base)
            }
            return false
        }
        if let call = node.as(FunctionCallExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(call.calledExpression)
        }
        if let subscriptCall = node.as(SubscriptCallExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(subscriptCall.calledExpression)
        }
        if let prefix = node.as(PrefixOperatorExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(prefix.expression)
        }
        if let force = node.as(ForceUnwrapExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(force.expression)
        }
        if let chain = node.as(OptionalChainingExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(chain.expression)
        }
        if let tuple = node.as(TupleExprSyntax.self) {
            for element in tuple.elements {
                if rootIdentifierIsBorrowingSelf(element.expression) {
                    return true
                }
            }
            return false
        }
        if let sequence = node.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                if element.is(BinaryOperatorExprSyntax.self) { continue }
                if rootIdentifierIsBorrowingSelf(element) {
                    return true
                }
            }
            return false
        }
        if let paren = node.as(InfixOperatorExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(paren.leftOperand)
                || rootIdentifierIsBorrowingSelf(paren.rightOperand)
        }
        return false
    }

    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        // Closures are their own scope — skip.
        return .skipChildren
    }
}

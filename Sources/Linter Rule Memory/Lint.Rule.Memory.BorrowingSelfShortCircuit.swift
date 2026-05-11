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
internal import SwiftSyntax

/// Wave 3 (mechanization-program) — operator overloads with `borrowing
/// Self` parameters MUST NOT use `&&` / `||` short-circuit operators in
/// their body. Swift 6.3 rejects chained property access across the
/// short-circuit boundary as "borrowed value escapes its borrow scope".
///
/// Citation: `[IMPL-094]` (implementation skill — chained property
/// access on `borrowing Self` parameters).
///
/// The Swift 6.3 compiler's borrow analysis treats chained property
/// reads across `||` / `&&` as separate borrow scopes that cannot
/// share the initial borrow. The institute alternatives are:
///   1. Tuple comparison — `(lhs.a, lhs.b) < (rhs.a, rhs.b)` —
///      collapses the reads into one borrow.
///   2. Local `let` bindings — `let la = lhs.a; let lb = lhs.b; …` —
///      materializes the needed values before the short-circuit.
///
/// AST shape: walk operator `FunctionDeclSyntax` (name token kind
/// `.binaryOperator`) whose parameter list contains a `borrowing Self`
/// parameter. If the body contains a binary operator expression using
/// `&&` or `||`, flag the operator position. The rule is compiler-
/// enforced, not stylistic; the diagnostic surfaces the violation at
/// authoring time rather than after the compile error.
extension Lint.Rule {
    public static let `borrowing self short circuit` = Lint.Rule(
        id: "borrowing_self_short_circuit",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryBorrowingSelfShortCircuitVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let memoryBorrowingSelfShortCircuitMessage: Swift.String =
    "[borrowing_self_short_circuit] [IMPL-094]: operator overload "
    + "with `borrowing Self` parameters uses `&&` / `||` in its body — "
    + "Swift 6.3 rejects chained property access across the short-"
    + "circuit boundary as `borrowed value escapes its borrow scope`. "
    + "Use tuple comparison `(lhs.a, lhs.b) < (rhs.a, rhs.b)` or local "
    + "`let` bindings materialising the values before the short-"
    + "circuit."

internal func memoryBorrowingSelfShortCircuitIsBorrowingSelf(
    _ parameter: FunctionParameterSyntax
) -> Swift.Bool {
    var current = parameter.type
    guard let attributed = current.as(AttributedTypeSyntax.self) else {
        return false
    }
    var hasBorrowing = false
    for specifier in attributed.specifiers {
        if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
            if case .keyword(.borrowing) = simple.specifier.tokenKind {
                hasBorrowing = true
                break
            }
        }
    }
    guard hasBorrowing else { return false }
    current = attributed.baseType
    if let identifier = current.as(IdentifierTypeSyntax.self),
       identifier.name.tokenKind == .keyword(.Self) || identifier.name.text == "Self"
    {
        return true
    }
    return false
}

private final class MemoryBorrowingSelfShortCircuitFinder: SyntaxVisitor {
    var positions: [AbsolutePosition] = []
    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if node.operator.text == "&&" || node.operator.text == "||" {
            positions.append(node.operator.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        // Closures are their own scope — skip.
        return .skipChildren
    }
}

internal final class MemoryBorrowingSelfShortCircuitVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Operator detection: name token kind is .binaryOperator.
        guard node.name.tokenKind == .binaryOperator(node.name.text) else {
            return .visitChildren
        }
        // Check for at least one `borrowing Self` parameter.
        var hasBorrowingSelf = false
        for parameter in node.signature.parameterClause.parameters {
            if memoryBorrowingSelfShortCircuitIsBorrowingSelf(parameter) {
                hasBorrowingSelf = true
                break
            }
        }
        guard hasBorrowingSelf else { return .visitChildren }
        // Walk body for && / || operators.
        guard let body = node.body else { return .visitChildren }
        let finder = MemoryBorrowingSelfShortCircuitFinder(viewMode: .sourceAccurate)
        finder.walk(body)
        for position in finder.positions {
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "borrowing_self_short_circuit",
                message: memoryBorrowingSelfShortCircuitMessage
            ))
        }
        return .visitChildren
    }
}

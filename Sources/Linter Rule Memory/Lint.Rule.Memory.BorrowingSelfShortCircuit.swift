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
///
/// Worked examples (flagged):
///   - `public static func < (lhs: borrowing Self, rhs: borrowing Self)
///     -> Bool { lhs.a < rhs.a || lhs.b < rhs.b }` — `||` short-
///     circuit.
///   - `public static func == (...) -> Bool { lhs.x == rhs.x && lhs.y
///     == rhs.y }` — `&&` short-circuit.
///
/// Worked examples (NOT flagged):
///   - Same operator using tuple comparison: `(lhs.a, lhs.b) < (rhs.a,
///     rhs.b)`.
///   - Same operator using local let-bindings (no `||`/`&&` in body).
///   - Non-operator function with `borrowing Self` parameter; rule
///     scopes to operator overloads where the failure mode is observed.
///   - Operator on non-`borrowing Self` parameters (e.g., `Int` operator
///     overload); out of scope.
extension Lint.Rule.Memory {
    public struct BorrowingSelfShortCircuit: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "borrowing_self_short_circuit"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Diagnostic.Record] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.Memory.BorrowingSelfShortCircuit {
    @usableFromInline
    static let message: Swift.String =
        "[borrowing_self_short_circuit] [IMPL-094]: operator overload "
        + "with `borrowing Self` parameters uses `&&` / `||` in its body — "
        + "Swift 6.3 rejects chained property access across the short-"
        + "circuit boundary as `borrowed value escapes its borrow scope`. "
        + "Use tuple comparison `(lhs.a, lhs.b) < (rhs.a, rhs.b)` or local "
        + "`let` bindings materialising the values before the short-"
        + "circuit."

    static func isBorrowingSelf(_ parameter: FunctionParameterSyntax) -> Swift.Bool {
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

    private final class ShortCircuitFinder: SyntaxVisitor {
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

    final class Visitor: SyntaxVisitor {
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
                if Lint.Rule.Memory.BorrowingSelfShortCircuit.isBorrowingSelf(parameter) {
                    hasBorrowingSelf = true
                    break
                }
            }
            guard hasBorrowingSelf else { return .visitChildren }
            // Walk body for && / || operators.
            guard let body = node.body else { return .visitChildren }
            let finder = ShortCircuitFinder(viewMode: .sourceAccurate)
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
                    identifier: Lint.Rule.Memory.BorrowingSelfShortCircuit.id.underlying,
                    message: Lint.Rule.Memory.BorrowingSelfShortCircuit.message
                ))
            }
            return .visitChildren
        }
    }
}

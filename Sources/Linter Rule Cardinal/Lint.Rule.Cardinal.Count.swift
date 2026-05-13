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

public import Linter_Primitives
internal import SwiftSyntax
internal import SwiftOperators

/// R1 — `<expr>.count - 1` and its semantically-equivalent rewrites.
///
/// Subsumes the regex pair `cardinal_count_minus_one_anti_pattern` +
/// `cardinal_count_minus_one_evasion`. After operator folding the four
/// surface-text variants collapse to two AST predicates:
///
/// 1. **Subtraction with literal `1`** — an `InfixOperatorExprSyntax`
///    whose operator is `-`, whose right operand is the integer literal
///    `1`, and whose left operand contains a member-access expression
///    of shape `<expr>.count` (`MemberAccessExprSyntax` with
///    `declName.baseName.text == "count"`). Catches member-access
///    `seq.count - 1`, paren-wrapped `(seq.count) - 1`, cast-outside
///    `Double(seq.count) - 1`, and operand-reorder `seq.count - i - 1`
///    (left-associativity makes the outer `- 1` binary-bind to a left
///    subtree that contains `seq.count`).
///
/// 2. **Algebraic-flip via comparison** — an `InfixOperatorExprSyntax`
///    whose operator is one of `<`, `<=`, `==`, `!=`, `>=`, `>`, where
///    one side has the shape `<expr> + 1` (commutative) and the other
///    side contains a member-access expression `<expr>.count`. Catches
///    `i + 1 < seq.count`, `1 + i < seq.count`, `seq.count == i + 1`, etc.
///
/// Bare-identifier `count` in scope (loop variable, local binding
/// `let count = ...`, function parameter named `count`) is intentionally
/// out-of-scope: the [INFRA-200] typed-cardinal rationale concerns
/// Collection-shaped `count`, and member-access form is the access
/// pattern for `Collection.count`. Bare-token analysis cannot
/// distinguish a Collection.count escape from an in-scope local that
/// happens to share the name.
///
/// Operand-reorder `(seq.count - i - 1)` — uncatchable by regex — is
/// caught by predicate 1: left-associativity parses the subexpression
/// as `((seq.count - i) - 1)`, whose outer `-` has RHS `1` and LHS
/// `seq.count - i` (which contains the member-access `seq.count`).
///
/// Comments-as-code is a non-issue at the AST level: comments are
/// `Trivia`, not part of the expression grammar; the visitor never
/// reaches them.
///
/// References:
/// - `swift-institute/Research/cardinal-ordinal-vector-enforcement-design.md`
///   §"R1. `count - 1` and family"
/// - `swift-institute/Research/swiftsyntax-based-custom-linter-investigation.md`
///   §"Q3 — Deferred AST-rule unblocking matrix"
extension Lint.Rule {
    public static let `count minus one` = Lint.Rule(
        id: "count minus one",
        default: .warning,
        findings: { source, severity in
            let folded = OperatorTable.standardOperators.foldAll(source.tree, errorHandler: { _ in })
            let visitor = CardinalCountVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(folded)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let cardinalCountMinusOneMessage: Swift.String =
    "[count minus one] [INFRA-200]: `<expr>.count - 1` (or syntactic "
    + "equivalents — paren-wrap `(seq.count) - 1`, cast-outside `Double(seq.count) - 1`, "
    + "algebraic-flip `+ 1 [<=] seq.count`, operand-reorder `seq.count - i - 1`) "
    + "indicates `count: Int` not `count: Cardinal` (the typed form would not compile). "
    + "Use `.subtract.saturating(.one)` / `.subtract.exact(.one)` / typed `count - .one` "
    + "per [INFRA-025], or for stdlib-Int sites where no typed surface is available "
    + "either (α) use the stdlib's named idiom for the concept (`indices.dropLast()`, "
    + "`.last`, `endIndex - 1`) or (β) escalate to supervisor and apply "
    + "`// swift-linter:disable:next count minus one` with a "
    + "`// REASON: <citation>` continuation."

internal final class CardinalCountVisitor: SyntaxVisitor {
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

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        guard let binOp = node.operator.as(BinaryOperatorExprSyntax.self) else {
            return .visitChildren
        }
        let opText = binOp.operator.text

        if opText == "-",
           Self.isLiteralOne(node.rightOperand),
           Self.containsCountMemberAccess(node.leftOperand) {
            report(at: binOp.operator)
            return .visitChildren
        }

        if Self.isComparisonOperator(opText) {
            if Self.isPlusOne(node.leftOperand), Self.containsCountMemberAccess(node.rightOperand) {
                report(at: binOp.operator)
            } else if Self.isPlusOne(node.rightOperand), Self.containsCountMemberAccess(node.leftOperand) {
                report(at: binOp.operator)
            }
        }

        return .visitChildren
    }

    func report(at token: TokenSyntax) {
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "count minus one",
            message: cardinalCountMinusOneMessage
        ))
    }

    static func isLiteralOne(_ expr: ExprSyntax) -> Bool {
        guard let lit = expr.as(IntegerLiteralExprSyntax.self) else { return false }
        return lit.literal.text == "1"
    }

    static func isComparisonOperator(_ text: Swift.String) -> Bool {
        switch text {
        case "<", "<=", "==", "!=", ">=", ">": return true
        default: return false
        }
    }

    static func isPlusOne(_ expr: ExprSyntax) -> Bool {
        guard let infix = expr.as(InfixOperatorExprSyntax.self),
              let binOp = infix.operator.as(BinaryOperatorExprSyntax.self),
              binOp.operator.text == "+"
        else { return false }
        return isLiteralOne(infix.leftOperand) || isLiteralOne(infix.rightOperand)
    }

    static func containsCountMemberAccess(_ expr: ExprSyntax) -> Bool {
        final class Finder: SyntaxVisitor {
            var found = false
            override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
                if node.declName.baseName.text == "count" {
                    found = true
                    return .skipChildren
                }
                return .visitChildren
            }
        }
        let finder = Finder(viewMode: .sourceAccurate)
        finder.walk(expr)
        return finder.found
    }
}

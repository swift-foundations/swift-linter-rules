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

/// Wave 3 (mechanization-program) — `for index in 0..<n` index-counted
/// iteration is mechanism, not intent.
///
/// Citation: `[IMPL-033]` (implementation skill — iteration: intent
/// over mechanism).
///
/// The institute iteration ladder climbs from bulk operations through
/// iteration infrastructure (`.forEach`, `.reduce.into`) to typed
/// while loops INSIDE iteration infrastructure. Raw counter loops
/// (`for i in 0..<count`) are mechanism: they expose the index when
/// the consumer cares about the elements. When the loop body uses
/// only `array[i]` style accesses, the iteration should be
/// `array.forEach { element in ... }` or `array.indices.forEach { ... }`
/// (when the index is itself needed) — both express intent rather
/// than counter mechanics.
///
/// AST shape: walk `ForStmtSyntax`. If the iterated sequence is a
/// range expression `0..<<expr>` or `<expr>..<<expr>` and the loop's
/// pattern is a simple identifier (`for i in 0..<n`), flag the
/// `for`-keyword position. Counted iteration is the most common form
/// of the "mechanism over intent" pattern; other shapes (custom
/// iterators, mapped sequences) are out of mechanical scope.
///
/// Worked examples (flagged):
///   - `for i in 0..<count { handle(items[i]) }` — counter loop;
///     suggest `items.forEach { handle($0) }` or `items.indices
///     .forEach { handle(items[$0]) }`.
///   - `for index in 1..<n { … }` — same shape, non-zero start.
///
/// Worked examples (NOT flagged):
///   - `for element in items { … }` — direct iteration, intent.
///   - `for (offset, element) in items.enumerated() { … }` — when both
///     index and element are needed.
///   - `for batch in stride(from: 0, to: total, by: 8) { … }` — bulk
///     stride, not a counter loop.
///   - `items.forEach { … }` — already at infrastructure level.
extension Lint.Rule.Idiom {
    public struct IterationIntent: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "iteration_intent_counter_loop"
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

extension Lint.Rule.Idiom.IterationIntent {
    @usableFromInline
    static let message: Swift.String =
        "[iteration_intent_counter_loop] [IMPL-033]: `for <i> in <a>..<<b>` "
        + "counter loop is mechanism, not intent. Climb the iteration "
        + "ladder: `items.forEach { … }` (per-element), `items.indices."
        + "forEach { … }` (when the index is needed), or a typed-while "
        + "inside iteration infrastructure if you're authoring the "
        + "infrastructure itself. Raw counter loops belong only inside "
        + "iteration infrastructure, not at the consumer call site."

    static func isRangeExpression(_ expression: ExprSyntax) -> Swift.Bool {
        // SwiftParser may produce SequenceExpr(elements: [lhs, BinaryOperator("..<"), rhs])
        // or InfixOperatorExpr after operator-folding.
        if let sequence = expression.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                if let binary = element.as(BinaryOperatorExprSyntax.self) {
                    let text = binary.operator.text
                    if text == "..<" || text == "..." {
                        return true
                    }
                }
            }
            return false
        }
        if let infix = expression.as(InfixOperatorExprSyntax.self) {
            if let binary = infix.operator.as(BinaryOperatorExprSyntax.self) {
                let text = binary.operator.text
                if text == "..<" || text == "..." {
                    return true
                }
            }
        }
        return false
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

        override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
            // Pattern: must be a simple identifier binding (counter form).
            guard node.pattern.is(IdentifierPatternSyntax.self) else {
                return .visitChildren
            }
            guard Lint.Rule.Idiom.IterationIntent.isRangeExpression(node.sequence) else {
                return .visitChildren
            }
            let location = converter.location(for: node.forKeyword.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Idiom.IterationIntent.id.underlying,
                message: Lint.Rule.Idiom.IterationIntent.message
            ))
            return .visitChildren
        }
    }
}

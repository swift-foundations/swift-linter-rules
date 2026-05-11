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

/// `for index in 0..<n` index-counted iteration is mechanism, not
/// intent. Citation: `[IMPL-033]`.
extension Lint.Rule {
    public static let `counter loop iteration` = Lint.Rule(
        id: "iteration_intent_counter_loop",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = IdiomIterationIntentVisitor(
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
internal let idiomIterationIntentMessage: Swift.String =
    "[iteration_intent_counter_loop] [IMPL-033]: `for <i> in <a>..<<b>` "
    + "counter loop is mechanism, not intent. Climb the iteration "
    + "ladder: `items.forEach { … }` (per-element), `items.indices."
    + "forEach { … }` (when the index is needed), or a typed-while "
    + "inside iteration infrastructure if you're authoring the "
    + "infrastructure itself."

internal func idiomIsRangeExpression(_ expression: ExprSyntax) -> Swift.Bool {
    if let sequence = expression.as(SequenceExprSyntax.self) {
        for element in sequence.elements {
            if let binary = element.as(BinaryOperatorExprSyntax.self) {
                let text = binary.operator.text
                if text == "..<" || text == "..." { return true }
            }
        }
        return false
    }
    if let infix = expression.as(InfixOperatorExprSyntax.self) {
        if let binary = infix.operator.as(BinaryOperatorExprSyntax.self) {
            let text = binary.operator.text
            if text == "..<" || text == "..." { return true }
        }
    }
    return false
}

internal final class IdiomIterationIntentVisitor: SyntaxVisitor {
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
        guard node.pattern.is(IdentifierPatternSyntax.self) else { return .visitChildren }
        guard idiomIsRangeExpression(node.sequence) else { return .visitChildren }
        let location = converter.location(for: node.forKeyword.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "iteration_intent_counter_loop",
            message: idiomIterationIntentMessage
        ))
        return .visitChildren
    }
}

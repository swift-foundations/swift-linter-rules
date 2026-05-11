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

/// Wave 4 (mechanization-program) — throwing wrapper `init` whose body
/// is `try base.init(...)` and nothing else MUST also validate the
/// wrapper's stricter invariant.
///
/// Citation: `[PATTERN-020]` (implementation skill, patterns.md —
/// throwing init on wrapper MUST NOT validate only base invariant).
extension Lint.Rule {
    public static let `throwing wrapper init` = Lint.Rule(
        id: "throwing_wrapper_init_no_validation",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureThrowingWrapperInitVisitor(
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
internal let structureThrowingWrapperInitMessage: Swift.String =
    "[throwing_wrapper_init_no_validation] [PATTERN-020]: throwing init body "
    + "is a single `try base.init(...)` forward with no additional validation. "
    + "If the wrapper specializes to a stricter invariant than its base, the "
    + "wrapper's invariant is silently violable. Add the wrapper's validation "
    + "after the base-init call, or rewrite the init to validate the wrapper "
    + "invariant directly."

internal final class StructureThrowingWrapperInitVisitor: SyntaxVisitor {
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

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.signature.effectSpecifiers?.throwsClause != nil else {
            return .visitChildren
        }
        guard let body = node.body else { return .visitChildren }
        let statements = body.statements
        guard statements.count == 1 else { return .visitChildren }
        guard let only = statements.first?.item else { return .visitChildren }
        guard isTryExpression(Syntax(only)) else { return .visitChildren }
        let location = converter.location(
            for: node.initKeyword.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "throwing_wrapper_init_no_validation",
            message: structureThrowingWrapperInitMessage
        ))
        return .visitChildren
    }

    private func isTryExpression(_ syntax: Syntax) -> Swift.Bool {
        if syntax.is(TryExprSyntax.self) {
            return true
        }
        if let expression = syntax.as(ExprSyntax.self),
           expression.is(TryExprSyntax.self) {
            return true
        }
        if let sequence = syntax.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                if element.is(TryExprSyntax.self) {
                    return true
                }
            }
        }
        return false
    }
}

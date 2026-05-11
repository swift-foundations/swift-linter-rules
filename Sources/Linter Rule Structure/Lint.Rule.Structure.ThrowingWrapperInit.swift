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
///
/// When a wrapper type specializes to a stricter invariant than its
/// base (e.g., `NonEmptyArray` over `Array`), its throwing `init`
/// MUST validate the stricter invariant before constructing. An init
/// body that only forwards to `base.init(...)` validates only the
/// base's invariant — the wrapper's contract is silently violable.
///
/// AST shape: an `InitializerDeclSyntax` whose `throws` clause is
/// present AND whose body's statements are EXACTLY one `try` /
/// `try?` / `try!` of a base-init call (or sequence-init expression)
/// followed at most by a single assignment / member initialization
/// from the base's result. The narrow heuristic targets the canonical
/// "forward-only" pattern; inits with additional validation are not
/// flagged. The wrapper vs. non-wrapper classification is implicit —
/// any throwing init with a forward-only body is suspect.
extension Lint.Rule.Structure {
    public struct ThrowingWrapperInit: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "throwing_wrapper_init_no_validation"
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

extension Lint.Rule.Structure.ThrowingWrapperInit {
    @usableFromInline
    static let message: Swift.String =
        "[throwing_wrapper_init_no_validation] [PATTERN-020]: throwing init body "
        + "is a single `try base.init(...)` forward with no additional validation. "
        + "If the wrapper specializes to a stricter invariant than its base, the "
        + "wrapper's invariant is silently violable. Add the wrapper's validation "
        + "after the base-init call, or rewrite the init to validate the wrapper "
        + "invariant directly."

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

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.signature.effectSpecifiers?.throwsClause != nil else {
                return .visitChildren
            }
            guard let body = node.body else { return .visitChildren }
            // Forward-only heuristic: body has exactly ONE statement, and that
            // statement is `try ...`. The body's single try indicates no
            // surrounding validation logic.
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
                identifier: Lint.Rule.Structure.ThrowingWrapperInit.id.underlying,
                message: Lint.Rule.Structure.ThrowingWrapperInit.message
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
            // Wrapped in a `self.x = try base.init(...)` assignment shape —
            // SwiftParser produces a SequenceExprSyntax for `a = b` until
            // operator folding runs. Detect by descending into descendants.
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
}

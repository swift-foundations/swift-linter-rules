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

/// Wave 2b finalization (2026-05-10) — mock factories on
/// pointer-wrapping `BitwiseCopyable` types MUST offset tag input by
/// at least 1.
///
/// Citation: `[TEST-028]` (testing skill).
///
/// `Optional<T>` for pointer-like `T` (e.g., `UnownedJob`,
/// `Unmanaged<X>`) uses the all-zeros bit pattern as `.none`. A
/// `mock(_ tag: Int)` that calls `unsafeBitCast(tag, to: T.self)`
/// produces a `T` that any `Optional<T>` path will read as `.none`
/// when `tag == 0` — silently breaking distinguishability tests.
/// The institute pattern offsets the input: `unsafeBitCast(tag &+ 1,
/// to: T.self)`.
///
/// AST shape (heuristic): `FunctionCallExprSyntax` whose called
/// expression is `unsafeBitCast` AND whose first argument is a bare
/// identifier (not an arithmetic expression involving `&+ 1` /
/// `&+ N`). The call site is flagged.
extension Lint.Rule.Testing {
    public struct MockFactoryZeroCollision: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "mock_factory_zero_collision"
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

extension Lint.Rule.Testing.MockFactoryZeroCollision {
    @usableFromInline
    static let message: Swift.String =
        "[mock_factory_zero_collision] [TEST-028]: `unsafeBitCast(tag, to: T.self)` "
        + "for pointer-wrapping `BitwiseCopyable` `T` collides with `Optional<T>.none` "
        + "(all-zeros bit pattern) when `tag == 0`. Offset the input: "
        + "`unsafeBitCast(tag &+ 1, to: T.self)` so tag 0 produces a non-`.none` value."

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

        private func isUnsafeBitCast(_ expr: ExprSyntax) -> Bool {
            if let identifier = expr.as(DeclReferenceExprSyntax.self) {
                return identifier.baseName.text == "unsafeBitCast"
            }
            return false
        }

        private func firstArgumentLooksRaw(_ argument: LabeledExprSyntax) -> Bool {
            // "Raw" = bare identifier OR any expression NOT containing
            // a `&+ 1`-style offset (heuristic: descriptions match the
            // arithmetic-tag pattern).
            let text = argument.expression.trimmedDescription
            // The mitigated pattern includes `&+`, `+ 1`, `+ N` etc.
            // adjusted past zero. Treat any wrapping-add or plain `+`
            // with a positive numeric literal as adjusted.
            if text.contains("&+") || text.contains("+ 1") || text.contains(" + ") {
                return false
            }
            return true
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard isUnsafeBitCast(node.calledExpression) else {
                return .visitChildren
            }
            guard let firstArgument = node.arguments.first else {
                return .visitChildren
            }
            guard firstArgumentLooksRaw(firstArgument) else {
                return .visitChildren
            }
            let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Testing.MockFactoryZeroCollision.id.underlying,
                message: Lint.Rule.Testing.MockFactoryZeroCollision.message
            ))
            return .visitChildren
        }
    }
}

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

/// Wave 3 (mechanization-program) — closures inside a `throws(E)` context
/// MUST carry an explicit `throws(E)` annotation when they contain `try`.
///
/// Citation: `[API-ERR-004]` (code-surface skill).
///
/// When calling a stdlib `rethrows` function from a `throws(E)` context,
/// the closure MUST include an explicit `throws(E)` annotation; otherwise
/// Swift 6.2 infers `any Error` for the closure's thrown type, erasing
/// the typed throw. The institute typed-throws discipline carries
/// through to the closure surface — every `try` inside a typed-throws
/// function should preserve the concrete error type.
///
/// AST shape: walk function/initializer declarations whose
/// `signature.effectSpecifiers?.throwsClause` carries a typed-throws
/// type (`clause.type != nil`). Inside the typed-throws context, any
/// `ClosureExprSyntax` whose body contains a `try` AND whose own
/// signature lacks a typed `throws(...)` annotation is flagged.
///
/// Worked examples (flagged):
///   - `func f<E: Swift.Error>() throws(E) { _ = items.map { try g($0) } }` —
///     closure has `try` but no `throws(E)`.
///   - `init() throws(MyError) { values.forEach { _ in try work() } }` —
///     same pattern, initializer scope.
///
/// Worked examples (NOT flagged):
///   - `func f<E: Swift.Error>() throws(E) { _ = items.map { (x: Int) throws(E) -> T in try g(x) } }` —
///     closure carries explicit `throws(E)`.
///   - `func f() throws { _ = items.map { try g($0) } }` — outer is
///     untyped `throws`; closure infers `any Error` is fine.
///   - `func f<E: Swift.Error>() throws(E) { items.forEach { item in
///     // no try here // } }` — no `try` inside closure → not flagged.
///   - Non-throwing outer functions — closure-throws inference is moot.
extension Lint.Rule.Throws {
    public struct ClosureAnnotation: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "closure_typed_throws_annotation"
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

extension Lint.Rule.Throws.ClosureAnnotation {
    @usableFromInline
    static let message: Swift.String =
        "[closure_typed_throws_annotation] [API-ERR-004]: closure inside a "
        + "`throws(E)` context contains `try` but lacks an explicit "
        + "`throws(E)` annotation — Swift 6.2 infers `any Error` and erases "
        + "the typed throw. Annotate the closure parameter list explicitly: "
        + "`{ (x: T) throws(E) -> U in try f(x) }`."

    /// Returns true when the throws clause is typed (`throws(E)`), false
    /// for untyped `throws` or absence of a clause.
    static func isTypedThrows(_ clause: ThrowsClauseSyntax?) -> Bool {
        guard let clause else { return false }
        return clause.type != nil
    }

    /// Looks for a `try` expression in a closure body, NOT descending
    /// into nested closures (whose tries belong to their own scope).
    private final class TryFinder: SyntaxVisitor {
        var found = false
        override func visit(_: TryExprSyntax) -> SyntaxVisitorContinueKind {
            found = true
            return .skipChildren
        }
        override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            return .skipChildren
        }
    }

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        /// Depth counter — incremented on entry to a typed-throws
        /// function / initializer / accessor, decremented on exit.
        var typedThrowsDepth: Swift.Int = 0

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        private func emit(at position: AbsolutePosition) {
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Throws.ClosureAnnotation.id.underlying,
                message: Lint.Rule.Throws.ClosureAnnotation.message
            ))
        }

        // MARK: - Typed-throws context tracking

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Rule.Throws.ClosureAnnotation.isTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
                typedThrowsDepth += 1
            }
            return .visitChildren
        }
        override func visitPost(_ node: FunctionDeclSyntax) {
            if Lint.Rule.Throws.ClosureAnnotation.isTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
                typedThrowsDepth -= 1
            }
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Rule.Throws.ClosureAnnotation.isTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
                typedThrowsDepth += 1
            }
            return .visitChildren
        }
        override func visitPost(_ node: InitializerDeclSyntax) {
            if Lint.Rule.Throws.ClosureAnnotation.isTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
                typedThrowsDepth -= 1
            }
        }

        // MARK: - Closure check

        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            guard typedThrowsDepth > 0 else { return .visitChildren }
            // Closure with its own typed-throws annotation — compliant.
            if let signature = node.signature,
               Lint.Rule.Throws.ClosureAnnotation.isTypedThrows(signature.effectSpecifiers?.throwsClause)
            {
                return .visitChildren
            }
            // Body must contain a `try` to be a candidate.
            let finder = TryFinder(viewMode: .sourceAccurate)
            for statement in node.statements {
                finder.walk(statement)
                if finder.found { break }
            }
            guard finder.found else { return .visitChildren }
            // Anchor: the closure signature's `in` keyword if present,
            // else the opening brace.
            let position: AbsolutePosition
            if let signature = node.signature {
                position = signature.positionAfterSkippingLeadingTrivia
            } else {
                position = node.leftBrace.positionAfterSkippingLeadingTrivia
            }
            emit(at: position)
            return .visitChildren
        }
    }
}

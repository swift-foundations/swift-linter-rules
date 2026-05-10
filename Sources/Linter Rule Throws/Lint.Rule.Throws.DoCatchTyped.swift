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

/// Wave 2b finalization (2026-05-10) — `do { try ... } catch` MUST use
/// typed-throws specifier `do throws(E) { try ... } catch { }`.
///
/// Citation: `[IMPL-075]` (implementation skill).
///
/// Bare `do { try x() } catch { ... }` makes the catch-bound error
/// `any Error`, erasing the concrete error type that callers / readers
/// would otherwise see. The institute typed-throws discipline carries
/// through to local handling: pin the error type at the `do` so the
/// catch clause's binding has the concrete type for switch
/// exhaustiveness, propagation, and conversion.
///
/// AST shape: a `DoStmtSyntax` whose `throwsClause` is `nil` AND which
/// has at least one `catch` clause AND whose body contains a `try`
/// expression. The first matching `do` keyword is flagged.
extension Lint.Rule.Throws {
    public struct DoCatchTyped: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "do_throws_e_for_typed_catch"
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

extension Lint.Rule.Throws.DoCatchTyped {
    @usableFromInline
    static let message: Swift.String =
        "[do_throws_e_for_typed_catch] [IMPL-075]: bare `do { try ... } catch { }` "
        + "erases the concrete error type — the catch binding becomes `any Error`. "
        + "Use `do throws(E) { try ... } catch { }` to preserve `E` in the catch "
        + "binding for exhaustive switch, typed propagation, and `Either`-style "
        + "conversion. If E is `Never`, no catch clause is needed."

    private final class TryFinder: SyntaxVisitor {
        var found = false
        override func visit(_: TryExprSyntax) -> SyntaxVisitorContinueKind {
            found = true
            return .skipChildren
        }
        override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind {
            // Don't recurse into nested do/catch — its tries belong to it.
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

        override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
            // Already typed — fine.
            if node.throwsClause != nil {
                return .visitChildren
            }
            // Must have at least one catch clause to be in scope.
            guard !node.catchClauses.isEmpty else {
                return .visitChildren
            }
            // Body must contain a `try`.
            let finder = TryFinder(viewMode: .sourceAccurate)
            finder.walk(node.body)
            guard finder.found else {
                return .visitChildren
            }
            let location = converter.location(for: node.doKeyword.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Throws.DoCatchTyped.id.underlying,
                message: Lint.Rule.Throws.DoCatchTyped.message
            ))
            return .visitChildren
        }
    }
}

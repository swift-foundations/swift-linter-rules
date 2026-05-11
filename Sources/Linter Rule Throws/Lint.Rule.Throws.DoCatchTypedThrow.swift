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

/// Wave 3 (mechanization-program) — `do { throw … } catch { … }` blocks
/// MUST use the typed-throws specifier `do throws(E) { throw … } catch { … }`.
///
/// Citation: `[IMPL-075]` (implementation skill — `do throws(E)` for typed
/// catch blocks).
///
/// Companion to `Lint.Rule.Throws.DoCatchTyped`: that Wave 2b rule flags
/// `do { try … } catch { … }`. This rule covers the additional pattern
/// the existing rule misses — `do { throw … } catch { … }` blocks whose
/// body has NO `try` expression but DOES contain a `throw` statement.
/// Without the typed-throws clause the catch-bound implicit `error` is
/// `any Error`, erasing the concrete error type and blocking exhaustive
/// switch / typed propagation downstream.
///
/// AST shape: a `DoStmtSyntax` whose `throwsClause` is `nil`, with at
/// least one `catch` clause, whose body contains a `ThrowStmtSyntax`
/// AND no `TryExprSyntax` (the `TryExprSyntax` case is already covered
/// by `Lint.Rule.Throws.DoCatchTyped` — overlap avoided to keep
/// diagnostics tight).
///
/// Worked examples (flagged):
///   - `do { throw MyError.bar } catch { handle(error) }` — throw inside
///     bare `do/catch`, no typed throws clause.
///
/// Worked examples (NOT flagged):
///   - `do throws(MyError) { throw .bar } catch { handle(error) }` —
///     already typed.
///   - `do { try foo() } catch { … }` — handled by `DoCatchTyped`.
///   - `do { throw MyError.bar }` (no catch) — out of scope.
extension Lint.Rule.Throws {
    public struct DoCatchTypedThrow: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "do_throws_e_for_typed_catch_throw"
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

extension Lint.Rule.Throws.DoCatchTypedThrow {
    @usableFromInline
    static let message: Swift.String =
        "[do_throws_e_for_typed_catch_throw] [IMPL-075]: bare `do { throw … } "
        + "catch { … }` erases the concrete error type — the catch binding "
        + "becomes `any Error`. Use `do throws(E) { throw … } catch { … }` to "
        + "preserve `E` in the catch binding for exhaustive switch, typed "
        + "propagation, and `Either`-style conversion. Companion to the "
        + "Wave 2b `Lint.Rule.Throws.DoCatchTyped` which covers the `try` form."

    /// Looks for a `throw` statement inside a do block, NOT descending
    /// into nested do statements or closures (whose throws belong to
    /// their own scope).
    private final class ThrowFinder: SyntaxVisitor {
        var found = false
        override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
            found = true
            return .skipChildren
        }
        override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind {
            return .skipChildren
        }
        override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            return .skipChildren
        }
    }

    /// Same scope rules as ThrowFinder; used to detect whether the
    /// existing `DoCatchTyped` rule would already cover this block.
    private final class TryFinder: SyntaxVisitor {
        var found = false
        override func visit(_: TryExprSyntax) -> SyntaxVisitorContinueKind {
            found = true
            return .skipChildren
        }
        override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind {
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

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
            if node.throwsClause != nil { return .visitChildren }
            guard !node.catchClauses.isEmpty else { return .visitChildren }
            let throwFinder = ThrowFinder(viewMode: .sourceAccurate)
            throwFinder.walk(node.body)
            guard throwFinder.found else { return .visitChildren }
            // If a try is present too, defer to DoCatchTyped to avoid
            // double-flagging at the same anchor.
            let tryFinder = TryFinder(viewMode: .sourceAccurate)
            tryFinder.walk(node.body)
            guard !tryFinder.found else { return .visitChildren }
            let location = converter.location(for: node.doKeyword.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Throws.DoCatchTypedThrow.id.underlying,
                message: Lint.Rule.Throws.DoCatchTypedThrow.message
            ))
            return .visitChildren
        }
    }
}

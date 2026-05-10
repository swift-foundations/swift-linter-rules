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

/// Wave 2b finalization (2026-05-10) — `try` inside stdlib `rethrows`
/// higher-order methods MUST be adapted via the `Result<T, E>` shim.
///
/// Citation: `[IMPL-109]` (implementation skill).
///
/// Stdlib `rethrows` higher-order methods (`map`, `compactMap`, `filter`,
/// `flatMap`, `forEach`, `reduce`, `first(where:)`, etc.) do not accept
/// typed-throws closures. A typed-throws closure containing `try` cannot
/// be passed directly without erasing the error to `any Error` at the
/// call site. The institute pattern materialises `Result<T, E>` inside
/// the closure, returns it, and unwraps with `try result.get()` outside
/// — preserving `E` through the rethrows-erased boundary.
///
/// AST shape: `FunctionCallExprSyntax` whose called member name matches
/// the stdlib rethrows allowlist below, AND whose closure argument
/// (trailing or labelled) body contains a `try` expression. The `try`
/// position is flagged.
extension Lint.Rule.Throws {
    public struct RethrowsResultShim: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "result_wrapper_for_rethrows_shim"
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

extension Lint.Rule.Throws.RethrowsResultShim {
    @usableFromInline
    static let message: Swift.String =
        "[result_wrapper_for_rethrows_shim] [IMPL-109]: stdlib `rethrows` higher-order "
        + "methods (`map`, `compactMap`, `filter`, `flatMap`, `forEach`, `reduce`, "
        + "`first(where:)`) erase typed-throws to `any Error`. Materialise `Result<T, E>` "
        + "inside the closure, return it, and `try result.get()` outside — preserves `E` "
        + "through the rethrows boundary. Pair with `do throws(E) { } catch { }` per "
        + "[IMPL-075] for exhaustive local handling."

    @usableFromInline
    static let rethrowsMethodNames: Swift.Set<Swift.String> = [
        "map",
        "compactMap",
        "flatMap",
        "filter",
        "forEach",
        "reduce",
        "first",
        "contains",
        "allSatisfy",
        "min",
        "max",
        "drop",
        "prefix",
        "suffix",
        "split",
        "sorted",
    ]

    private final class TryFinder: SyntaxVisitor {
        var positions: [AbsolutePosition] = []
        // Depth: walk(closure) starts at the outer ClosureExprSyntax,
        // which we treat as depth 0 — descend into its statements but
        // skip *nested* closures (depth > 0). Their tries belong to
        // their own surrounding rethrows call (or are out of scope).
        var closureDepth: Int = -1
        override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
            // `try?` and `try!` already discard or trap the error type;
            // they don't need the Result-shim discipline.
            if node.questionOrExclamationMark == nil {
                positions.append(node.tryKeyword.positionAfterSkippingLeadingTrivia)
            }
            return .visitChildren
        }
        override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            closureDepth += 1
            if closureDepth > 0 {
                return .skipChildren
            }
            return .visitChildren
        }
        override func visitPost(_: ClosureExprSyntax) {
            closureDepth -= 1
        }
        override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
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

        private func calledMemberName(_ called: ExprSyntax) -> Swift.String? {
            if let memberAccess = called.as(MemberAccessExprSyntax.self) {
                return memberAccess.declName.baseName.text
            }
            return nil
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let name = calledMemberName(node.calledExpression) else {
                return .visitChildren
            }
            guard Lint.Rule.Throws.RethrowsResultShim.rethrowsMethodNames.contains(name) else {
                return .visitChildren
            }
            // Find a closure argument: trailing closure, additional trailing
            // closures, or any argument expression that's a closure literal.
            var closures: [ClosureExprSyntax] = []
            if let trailing = node.trailingClosure {
                closures.append(trailing)
            }
            for additional in node.additionalTrailingClosures {
                closures.append(additional.closure)
            }
            for argument in node.arguments {
                if let closure = argument.expression.as(ClosureExprSyntax.self) {
                    closures.append(closure)
                }
            }
            for closure in closures {
                let finder = TryFinder(viewMode: .sourceAccurate)
                finder.walk(closure)
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
                        identifier: Lint.Rule.Throws.RethrowsResultShim.id.underlying,
                        message: Lint.Rule.Throws.RethrowsResultShim.message
                    ))
                }
            }
            return .visitChildren
        }
    }
}

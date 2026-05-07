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

/// Wave-1 — `try?` swallows typed errors.
///
/// Citation: `feedback_prefer_typed_throws_over_try_optional`.
///
/// `try?` converts a thrown error into a `nil` Optional, erasing both the
/// error type and the error instance. The institute convention prefers
/// typed throws (`throws(E)`) so the error path remains explicit and
/// recoverable. Past failure mode: `try? input.advance()` swallowed
/// `EAGAIN` causing the Linux hot-spin in the IO Notification.wait()
/// site (see `feedback_prefer_typed_throws_over_try_optional`).
///
/// AST shape: `TryExprSyntax` whose `questionOrExclamationMark.tokenKind`
/// is `.postfixQuestionMark`.
extension Lint.Rule {
    public struct Try: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "try_optional"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.Try {
    @usableFromInline
    static let message: Swift.String =
        "[try_optional] feedback_prefer_typed_throws_over_try_optional: "
        + "`try?` swallows the thrown error and returns `nil`, erasing both the error type "
        + "and the error instance. Prefer typed throws (`throws(E)`) so the error path stays "
        + "explicit and recoverable. Past incident: `try? input.advance()` swallowed `EAGAIN` "
        + "causing the Linux hot-spin in the IO Notification.wait() site. If you genuinely "
        + "want to discard the error, use `do { ... } catch { }` so the discard is local "
        + "and visible."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Lint.Finding] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
            guard let mark = node.questionOrExclamationMark,
                  mark.tokenKind == .postfixQuestionMark
            else {
                return .visitChildren
            }
            let location = converter.location(for: mark.positionAfterSkippingLeadingTrivia)
            matches.append(Lint.Finding(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Try.id.underlying,
                message: Lint.Rule.Try.message
            ))
            return .visitChildren
        }
    }
}

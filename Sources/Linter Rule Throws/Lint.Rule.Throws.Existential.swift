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

/// Wave-1 — `throws(any Error)` boxes the error existentially.
///
/// Citation: `feedback_no_existential_throws`.
///
/// `throws(any Error)` (and `throws(any Swift.Error)`) defeats the
/// purpose of typed throws — the error type IS `any Error`, which is
/// what untyped `throws` already produces. Use a concrete error type
/// instead, or make the container generic over the error type
/// (`throws(E)` with `E: Swift.Error`).
///
/// AST shape: a `ThrowsClauseSyntax` whose `type` is a
/// `SomeOrAnyTypeSyntax` with the `any` specifier and constraint type
/// `Error` or `Swift.Error`.
extension Lint.Rule.Throws {
    public struct Existential: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "existential_throws"
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

extension Lint.Rule.Throws.Existential {
    @usableFromInline
    static let message: Swift.String =
        "[existential_throws] feedback_no_existential_throws: `throws(any Error)` boxes "
        + "the error as an existential — it is semantically identical to untyped `throws` "
        + "but harder to read. Use a concrete error type (`throws(IO.Error)`) or make the "
        + "container generic over the error type (`<E: Swift.Error>(... throws(E) ...)`). "
        + "Existential throws is never the right answer."

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

        override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
            guard let typed = node.type else {
                return .visitChildren
            }
            guard isAnyError(typed) else {
                return .visitChildren
            }
            let location = converter.location(for: typed.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Throws.Existential.id.underlying,
                message: Lint.Rule.Throws.Existential.message
            ))
            return .visitChildren
        }

        private func isAnyError(_ type: TypeSyntax) -> Bool {
            guard let some = type.as(SomeOrAnyTypeSyntax.self),
                  some.someOrAnySpecifier.tokenKind == .keyword(.any)
            else {
                return false
            }
            return isErrorType(some.constraint)
        }

        private func isErrorType(_ type: TypeSyntax) -> Bool {
            if let identifier = type.as(IdentifierTypeSyntax.self),
               identifier.name.text == "Error"
            {
                return true
            }
            if let member = type.as(MemberTypeSyntax.self),
               member.name.text == "Error",
               let base = member.baseType.as(IdentifierTypeSyntax.self),
               base.name.text == "Swift"
            {
                return true
            }
            return false
        }
    }
}

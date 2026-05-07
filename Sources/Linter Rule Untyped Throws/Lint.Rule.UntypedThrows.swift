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

/// Wave-1 — `throws` without a typed-throws specifier.
///
/// Citation: [API-ERR-001].
///
/// Untyped `throws` erases the error type — the function's signature
/// loses information about which errors callers must handle. The
/// institute convention is `throws(SpecificError)` so the error path
/// is exhaustive at compile time and `any Error` boxing is avoided.
///
/// AST shape: a `ThrowsClauseSyntax` whose `type` field (the typed-throws
/// specifier appearing inside parentheses) is `nil`. This catches both
/// `func f() throws` and `func g() async throws -> T`.
extension Lint.Rule {
    public struct UntypedThrows: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "untyped_throws"
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

extension Lint.Rule.UntypedThrows {
    @usableFromInline
    static let message: Swift.String =
        "[untyped_throws] [API-ERR-001]: bare `throws` erases the error type. Use "
        + "`throws(SpecificError)` so callers know which errors are possible at compile "
        + "time and the error path stays exhaustive. Untyped throws boxes the error as "
        + "`any Error`, which the institute convention forbids."

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

        override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
            guard node.throwsSpecifier.tokenKind == .keyword(.throws) else {
                return .visitChildren
            }
            guard node.type == nil else {
                return .visitChildren
            }
            let location = converter.location(for: node.throwsSpecifier.positionAfterSkippingLeadingTrivia)
            matches.append(Lint.Finding(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.UntypedThrows.id.underlying,
                message: Lint.Rule.UntypedThrows.message
            ))
            return .visitChildren
        }
    }
}

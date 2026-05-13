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
extension Lint.Rule {
    public static let `untyped throws` = Lint.Rule(
        id: "untyped throws",
        default: .warning,
        findings: { source, severity in
            let visitor = ThrowsUntypedVisitor(
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
internal let throwsUntypedMessage: Swift.String =
    "[untyped throws] [API-ERR-001]: bare `throws` erases the error type. Use "
    + "`throws(SpecificError)` so callers know which errors are possible at compile "
    + "time and the error path stays exhaustive. Untyped throws boxes the error as "
    + "`any Error`, which the institute convention forbids."

internal final class ThrowsUntypedVisitor: SyntaxVisitor {
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
        guard node.throwsSpecifier.tokenKind == .keyword(.throws) else {
            return .visitChildren
        }
        guard node.type == nil else {
            return .visitChildren
        }
        let location = converter.location(for: node.throwsSpecifier.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "untyped throws",
            message: throwsUntypedMessage
        ))
        return .visitChildren
    }
}

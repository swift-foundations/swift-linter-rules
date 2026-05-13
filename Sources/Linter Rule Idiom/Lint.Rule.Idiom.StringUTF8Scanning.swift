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

/// Foundation-free string scanning at L1 / L2 MUST default to the UTF-8
/// byte view, not `unicodeScalars`. Citation: `[IMPL-089]`.
extension Lint.Rule {
    public static let `string utf8 scanning` = Lint.Rule(
        id: "string utf8 scanning",
        default: .warning,
        findings: { source, severity in
            let visitor = IdiomStringUTF8ScanningVisitor(
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
internal let idiomStringUTF8ScanningMessage: Swift.String =
    "[string utf8 scanning] [IMPL-089]: `.unicodeScalars` access is "
    + "the wrong code-unit view for Foundation-free string scanning. "
    + "Use `.utf8` — byte-literal matching is O(n), no Unicode table "
    + "dependency, and the correct semantics for newline discovery, "
    + "substring search, percent decoding, path component splitting."

internal final class IdiomStringUTF8ScanningVisitor: SyntaxVisitor {
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

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.declName.baseName.text == "unicodeScalars" else { return .visitChildren }
        let location = converter.location(
            for: node.declName.baseName.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "string utf8 scanning",
            message: idiomStringUTF8ScanningMessage
        ))
        return .visitChildren
    }
}

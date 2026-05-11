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

/// Wave 4 (mechanization-program) — file pairs `@usableFromInline` with
/// `internal import` of a module whose types the inline body references.
///
/// Citation: `[PATTERN-055]` (implementation skill, patterns.md).
extension Lint.Rule {
    public static let `usable from inline internal import` = Lint.Rule(
        id: "usable from inline internal import",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureUsableFromInlineInternalImportVisitor(
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
internal let structureUsableFromInlineInternalImportMessage: Swift.String =
    "[usable from inline internal import] [PATTERN-055]: file pairs "
    + "`@usableFromInline` with `internal import` of a referenced module. "
    + "Swift rejects `@usableFromInline` bodies that reach identifiers in "
    + "internally-imported modules at compile time. Either downgrade the "
    + "decl's visibility or upgrade the import to `public` / `package`."

internal final class StructureUsableFromInlineInternalImportVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var hasUsableFromInline: Swift.Bool = false
    var internalImports: [AbsolutePosition] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        if let identifier = node.attributeName.as(IdentifierTypeSyntax.self),
           identifier.name.text == "usableFromInline" {
            hasUsableFromInline = true
        }
        return .visitChildren
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        for modifier in node.modifiers {
            if case .keyword(.internal) = modifier.name.tokenKind {
                internalImports.append(
                    node.importKeyword.positionAfterSkippingLeadingTrivia
                )
            }
        }
        return .visitChildren
    }

    func finalize() {
        guard hasUsableFromInline else { return }
        for position in internalImports {
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "usable from inline internal import",
                message: structureUsableFromInlineInternalImportMessage
            ))
        }
    }

    override func visitPost(_: SourceFileSyntax) {
        finalize()
    }
}

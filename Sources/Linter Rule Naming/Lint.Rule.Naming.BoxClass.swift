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

/// Wave 4 (mechanization-program) — ad-hoc `_Box` (or `Box` / `_Storage`)
/// reference wrappers reach for ecosystem primitives that already exist.
///
/// Citation: `[IMPL-107]` (implementation skill, ownership.md).
extension Lint.Rule {
    public static let `ad hoc box class` = Lint.Rule(
        id: "ad_hoc_box_class",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingBoxClassVisitor(
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
internal let namingBoxClassMessage: Swift.String =
    "[ad_hoc_box_class] [IMPL-107]: ad-hoc `_Box` / `_Storage` reference "
    + "wrapper duplicates ecosystem primitives. Prefer `Reference<T>` "
    + "(shared mutable indirection) or `Owned<T>` (unique-owner indirection) "
    + "from `swift-ownership-primitives` so the wrapper's ownership story "
    + "is checked by the type system, not ad-hoc."

@usableFromInline
internal let namingBoxClassFlaggedNames: Swift.Set<Swift.String> = [
    "Box", "Storage", "Wrap", "Wrapper", "Cell",
]

internal func namingBoxClassIsFlaggedName(_ name: Swift.String) -> Swift.Bool {
    var trimmed = name
    if trimmed.hasPrefix("_") {
        trimmed.removeFirst()
    }
    return namingBoxClassFlaggedNames.contains(trimmed)
}

internal final class NamingBoxClassVisitor: SyntaxVisitor {
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

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        // Free-standing wrappers only — skip declarations with an
        // inheritance clause (frameworks, ManagedBuffer-derived types).
        if node.inheritanceClause != nil {
            return .visitChildren
        }
        let name = node.name.text
        if !namingBoxClassIsFlaggedName(name) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.name.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "ad_hoc_box_class",
            message: namingBoxClassMessage
        ))
        return .visitChildren
    }
}

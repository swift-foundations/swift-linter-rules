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

/// `typealias X = Y.Z` (with X != Z) is a rename-bridge anti-pattern.
/// Citation: `[API-NAME-004]`.
extension Lint.Rule {
    public static let `unification typealias` = Lint.Rule(
        id: "unification_bridge_typealias",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingUnificationTypealiasVisitor(
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
internal let namingUnificationTypealiasMessage: Swift.String =
    "[unification_bridge_typealias] [API-NAME-004]: typealias renames a "
    + "member type to a different local name. Type unification MUST use the "
    + "canonical type at all call sites; a typealias bridge adds indirection "
    + "without domain value."

internal final class NamingUnificationTypealiasVisitor: SyntaxVisitor {
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

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let lhsName = node.name.text
        guard let member = node.initializer.value.as(MemberTypeSyntax.self) else {
            return .visitChildren
        }
        if member.genericArgumentClause != nil { return .visitChildren }
        let rhsLeaf = member.name.text
        guard rhsLeaf != lhsName else { return .visitChildren }
        let location = converter.location(
            for: node.typealiasKeyword.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "unification_bridge_typealias",
            message: namingUnificationTypealiasMessage
        ))
        return .visitChildren
    }
}

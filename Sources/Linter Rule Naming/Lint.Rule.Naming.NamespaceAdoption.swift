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

/// Wave 4 (mechanization-program) — `typealias X = Y.X` is the
/// namespace-adoption shape: the higher-layer namespace adopts a
/// lower-layer concept under the same leaf name.
///
/// Citation: `[API-NAME-004a]` (code-surface skill, naming).
extension Lint.Rule {
    public static let `namespace adoption typealias` = Lint.Rule(
        id: "namespace_adoption_typealias",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingNamespaceAdoptionVisitor(
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
internal let namingNamespaceAdoptionMessage: Swift.String =
    "[namespace_adoption_typealias] [API-NAME-004a]: same-leaf typealias is "
    + "the namespace-adoption shape. Confirm the higher-layer namespace "
    + "declares ≥ 5 sibling types / extensions / methods on the adopted "
    + "concept — otherwise this is a rename bridge per [API-NAME-004]. "
    + "Surfaced as a review prompt."

internal final class NamingNamespaceAdoptionVisitor: SyntaxVisitor {
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
        let rhsLeaf = member.name.text
        guard rhsLeaf == lhsName else { return .visitChildren }
        // Exempt typealiases declared inside a context that introduces
        // protocol conformance — `extension Tagged: Collection where ...
        // { typealias Index = Underlying.Index }`. The same-leaf typealias
        // is satisfying an associatedtype requirement of the adopted
        // protocol, not a discretionary namespace-adoption choice. The
        // structural signal is a non-empty inheritance clause on the
        // enclosing extension or type declaration.
        if namingIsInsideConformingContext(Syntax(node)) {
            return .visitChildren
        }
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
            identifier: "namespace_adoption_typealias",
            message: namingNamespaceAdoptionMessage
        ))
        return .visitChildren
    }
}

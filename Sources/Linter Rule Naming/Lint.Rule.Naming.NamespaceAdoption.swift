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
///
/// Namespace adoption is PERMITTED when the higher layer builds at
/// least 5 types / extensions / methods on the adopted concept; a
/// standalone same-leaf typealias with no surrounding domain behavior
/// is a rename-bridge anti-pattern flagged separately by [API-NAME-004].
/// This rule surfaces the adoption shape as a review prompt: the writer
/// SHOULD confirm the higher-layer scope justifies the adoption.
///
/// AST shape: `TypeAliasDeclSyntax` whose name equals the RHS leaf
/// component. Acceptable RHS shapes:
///   - `Foo.Bar` (member-type, leaf match)
///   - `Foo.Bar.Baz` (any depth, last component matches LHS)
/// Generic instantiation RHS (`Foo.Bar<Int>`) and non-member-type RHS
/// (`Foo`, `Self`) are out of scope.
extension Lint.Rule.Naming {
    public struct NamespaceAdoption: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "namespace_adoption_typealias"
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

extension Lint.Rule.Naming.NamespaceAdoption {
    @usableFromInline
    static let message: Swift.String =
        "[namespace_adoption_typealias] [API-NAME-004a]: same-leaf typealias is "
        + "the namespace-adoption shape. Confirm the higher-layer namespace "
        + "declares ≥ 5 sibling types / extensions / methods on the adopted "
        + "concept — otherwise this is a rename bridge per [API-NAME-004]. "
        + "Surfaced as a review prompt."

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

        override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
            let lhsName = node.name.text
            guard let member = node.initializer.value.as(MemberTypeSyntax.self) else {
                return .visitChildren
            }
            let rhsLeaf = member.name.text
            guard rhsLeaf == lhsName else { return .visitChildren }
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
                identifier: Lint.Rule.Naming.NamespaceAdoption.id.underlying,
                message: Lint.Rule.Naming.NamespaceAdoption.message
            ))
            return .visitChildren
        }
    }
}

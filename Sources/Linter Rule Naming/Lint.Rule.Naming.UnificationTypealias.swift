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

/// Wave 4 (mechanization-program) — `typealias X = Y.Z` (with X != Z)
/// is a rename-bridge anti-pattern.
///
/// Citation: `[API-NAME-004]` (code-surface skill, naming).
///
/// Type-unification typealiases that rename a member type into a
/// different local name add an indirection layer that complicates
/// navigation and diagnostics. Use the canonical type directly at call
/// sites. The exception is typealiases for generic instantiations
/// (`typealias IntArray = Array<Int>`) which localize a specialization
/// decision, not a unification bridge — those are NOT flagged.
///
/// AST shape: top-level `TypeAliasDeclSyntax` whose RHS is a
/// `MemberTypeSyntax` AND whose LHS local name differs from the RHS
/// leaf component, AND whose RHS does NOT carry a generic argument
/// clause. The companion `[API-NAME-004a]` namespace-adoption rule
/// matches LHS-equals-RHS-leaf (those are permitted when domain
/// behavior surrounds them); this rule matches the strict
/// rename-bridge shape.
extension Lint.Rule.Naming {
    public struct UnificationTypealias: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "unification_bridge_typealias"
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

extension Lint.Rule.Naming.UnificationTypealias {
    @usableFromInline
    static let message: Swift.String =
        "[unification_bridge_typealias] [API-NAME-004]: typealias renames a "
        + "member type to a different local name. Type unification MUST use the "
        + "canonical type at all call sites; a typealias bridge adds indirection "
        + "without domain value. Generic-instantiation typealiases (`= Array<Int>`) "
        + "are exempt — those localize a specialization decision."

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
            // Generic instantiations on the RHS exempt the bridge form.
            if member.genericArgumentClause != nil {
                return .visitChildren
            }
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
                identifier: Lint.Rule.Naming.UnificationTypealias.id.underlying,
                message: Lint.Rule.Naming.UnificationTypealias.message
            ))
            return .visitChildren
        }
    }
}

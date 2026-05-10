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

/// Wave 2b finalization (2026-05-10) — performance suites MUST carry
/// the `.serialized` trait.
///
/// Citation: `[SWIFT-TEST-004]` (testing-swiftlang skill).
///
/// Parallel test execution causes timing-measurement variance.
/// Performance test suites MUST opt in to serial execution via
/// `@Suite(.serialized)`. This rule flags `@Suite` declarations on
/// types named `Performance` (the canonical name in the institute's
/// nested-suite pattern, e.g., `extension Foo.Test { @Suite struct
/// Performance {} }`) when the attribute lacks `.serialized`.
///
/// AST shape: `StructDeclSyntax` whose name is `Performance` AND
/// whose attributes contain `@Suite`. The `Suite` attribute's argument
/// list is checked for any expression matching `.serialized`. If
/// absent, the type name is flagged.
extension Lint.Rule.Testing {
    public struct PerformanceSuiteSerialized: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "performance_suite_serialized"
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

extension Lint.Rule.Testing.PerformanceSuiteSerialized {
    @usableFromInline
    static let message: Swift.String =
        "[performance_suite_serialized] [SWIFT-TEST-004]: performance suites MUST "
        + "carry `.serialized` to prevent parallel execution variance from polluting "
        + "timing measurements. Change `@Suite struct Performance {}` to "
        + "`@Suite(.serialized) struct Performance {}`."

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

        private func suiteAttribute(_ attributes: AttributeListSyntax) -> AttributeSyntax? {
            for attribute in attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "Suite" {
                    return attr
                }
            }
            return nil
        }

        private func mentionsSerialized(_ attribute: AttributeSyntax) -> Bool {
            // Walk attribute argument tokens for `.serialized`. The text
            // appears as `serialized` after the dot in `.serialized`.
            return attribute.trimmedDescription.contains(".serialized")
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.name.text == "Performance" else {
                return .visitChildren
            }
            guard let attribute = suiteAttribute(node.attributes) else {
                return .visitChildren
            }
            guard !mentionsSerialized(attribute) else {
                return .visitChildren
            }
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Testing.PerformanceSuiteSerialized.id.underlying,
                message: Lint.Rule.Testing.PerformanceSuiteSerialized.message
            ))
            return .visitChildren
        }
    }
}

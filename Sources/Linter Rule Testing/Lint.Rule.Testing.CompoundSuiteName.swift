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

/// Wave 2b finalization (2026-05-10) — `@Suite` types MUST follow the
/// extension-pattern naming, not compound names.
///
/// Citation: `[SWIFT-TEST-002]` (testing-swiftlang skill).
///
/// The institute's testing convention nests test suites inside the
/// type they test (`extension Memory.Buffer { @Suite struct Test {} }`)
/// rather than using compound names like `MemoryBufferTests`. Compound
/// suite names break the type-hierarchy mirroring established by
/// `[API-NAME-001]` and conflict with `[API-NAME-002]`.
///
/// AST shape: `StructDeclSyntax` whose attributes contain `@Suite` AND
/// whose name is a compound camelCase identifier — defined here as a
/// name with at least two uppercase-led tokens (e.g., `FooTests`,
/// `MemoryBufferTests`, `MyAPIChecks`). Single-token names (`Test`,
/// `Performance`, `Unit`, `Integration`) are not compound and are the
/// canonical shape.
extension Lint.Rule.Testing {
    public struct CompoundSuiteName: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "compound_test_suite_name"
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

extension Lint.Rule.Testing.CompoundSuiteName {
    @usableFromInline
    static let message: Swift.String =
        "[compound_test_suite_name] [SWIFT-TEST-002]: `@Suite` types MUST use the "
        + "extension-pattern nested name (`extension Foo { @Suite struct Test {} }`), "
        + "not a compound name like `FooTests`. Compound suite names break the type-"
        + "hierarchy mirroring established by [API-NAME-001] and conflict with "
        + "[API-NAME-002]. Move the suite into an extension of the tested type."

    static func hasSuiteAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "Suite" {
                return true
            }
        }
        return false
    }

    static func isCompoundIdentifier(_ name: Swift.String) -> Bool {
        // Compound = two or more uppercase-led "tokens" inside the
        // identifier, where a token starts at any uppercase character
        // (and the identifier starts uppercase, since these are types).
        var uppercaseRuns = 0
        var prevWasLower = false
        for (offset, character) in name.enumerated() {
            if offset == 0 {
                guard character.isUppercase else { return false }
                uppercaseRuns = 1
                continue
            }
            if character.isUppercase, prevWasLower {
                uppercaseRuns += 1
            }
            prevWasLower = character.isLowercase
        }
        return uppercaseRuns >= 2
    }

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

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Testing.CompoundSuiteName.hasSuiteAttribute(node.attributes) else {
                return .visitChildren
            }
            let name = node.name.text
            guard Lint.Rule.Testing.CompoundSuiteName.isCompoundIdentifier(name) else {
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
                identifier: Lint.Rule.Testing.CompoundSuiteName.id.underlying,
                message: Lint.Rule.Testing.CompoundSuiteName.message
            ))
            return .visitChildren
        }
    }
}

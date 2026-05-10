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

/// Wave 2b finalization (2026-05-10) — `@Test` functions MUST use
/// backticked descriptive names, not camelCase identifiers.
///
/// Citation: `[SWIFT-TEST-005]` (testing-swiftlang skill).
///
/// The institute test convention names test functions with a backticked
/// sentence describing the behaviour under test, e.g., `func \`Memory.
/// Address from UnsafeRawPointer preserves identity\`() {}`. CamelCase
/// names like `testMemoryAddress()` are the legacy XCTest pattern and
/// don't read as documentation in test reports. The `@Test` attribute
/// also MUST NOT carry a string argument — the function name IS the
/// description.
///
/// AST shape: `FunctionDeclSyntax` whose attributes contain `@Test`
/// (with or without arguments) AND whose name token's text does NOT
/// contain a space (the simplest signal that backticks-with-sentence
/// was used). Backticked Swift identifiers permit spaces; camelCase
/// identifiers cannot. The function name position is flagged.
extension Lint.Rule.Testing {
    public struct FunctionNaming: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "test_function_naming"
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

extension Lint.Rule.Testing.FunctionNaming {
    @usableFromInline
    static let message: Swift.String =
        "[test_function_naming] [SWIFT-TEST-005]: `@Test` functions MUST use a "
        + "backticked descriptive sentence as the name, e.g., "
        + "``func `init creates empty buffer`() {}``. CamelCase names like "
        + "`testInitCreatesEmptyBuffer()` are the legacy XCTest pattern and don't "
        + "read as documentation in test reports."

    static func hasTestAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "Test" {
                return true
            }
        }
        return false
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

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Testing.FunctionNaming.hasTestAttribute(node.attributes) else {
                return .visitChildren
            }
            // Backticked names contain spaces; camelCase names don't.
            let name = node.name.text
            if !name.contains(" ") {
                let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Testing.FunctionNaming.id.underlying,
                    message: Lint.Rule.Testing.FunctionNaming.message
                ))
            }
            return .visitChildren
        }
    }
}

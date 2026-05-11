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

/// `@Test` functions MUST use backticked descriptive names, not camelCase
/// identifiers. Citation: `[SWIFT-TEST-005]`.
extension Lint.Rule {
    public static let `test function naming` = Lint.Rule(
        id: "test_function_naming",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = TestingFunctionNamingVisitor(
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
internal let testingFunctionNamingMessage: Swift.String =
    "[test_function_naming] [SWIFT-TEST-005]: `@Test` functions MUST use a "
    + "backticked descriptive sentence as the name. CamelCase names are the "
    + "legacy XCTest pattern and don't read as documentation in test reports."

private func functionNamingHasTestAttribute(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "Test" { return true }
    }
    return false
}

internal final class TestingFunctionNamingVisitor: SyntaxVisitor {
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
        guard functionNamingHasTestAttribute(node.attributes) else { return .visitChildren }
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
                identifier: "test_function_naming",
                message: testingFunctionNamingMessage
            ))
        }
        return .visitChildren
    }
}

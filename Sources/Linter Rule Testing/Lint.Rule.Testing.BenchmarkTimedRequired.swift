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

/// Performance-suite `@Test` functions MUST carry the `.timed()` trait.
/// Citation: `[BENCH-003]`.
extension Lint.Rule {
    public static let `benchmark timed required` = Lint.Rule(
        id: "benchmark timed required",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = TestingBenchmarkTimedRequiredVisitor(
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
internal let testingBenchmarkTimedRequiredMessage: Swift.String =
    "[benchmark timed required] [BENCH-003]: `@Test` functions inside a "
    + "`Performance` suite MUST carry the `.timed()` trait. Without it, the "
    + "performance test runs once with no measurement structure."

internal final class TestingBenchmarkTimedRequiredVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var inPerformanceStructDepth: Swift.Int = 0

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func testAttribute(_ attributes: AttributeListSyntax) -> AttributeSyntax? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "Test" { return attr }
        }
        return nil
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == "Performance" { inPerformanceStructDepth += 1 }
        return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) {
        if node.name.text == "Performance" { inPerformanceStructDepth -= 1 }
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let last = node.extendedType.trimmedDescription.split(separator: ".").last,
           Swift.String(last) == "Performance"
        { inPerformanceStructDepth += 1 }
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) {
        if let last = node.extendedType.trimmedDescription.split(separator: ".").last,
           Swift.String(last) == "Performance"
        { inPerformanceStructDepth -= 1 }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard inPerformanceStructDepth > 0 else { return .visitChildren }
        guard let attribute = testAttribute(node.attributes) else { return .visitChildren }
        if !attribute.trimmedDescription.contains(".timed") {
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "benchmark timed required",
                message: testingBenchmarkTimedRequiredMessage
            ))
        }
        return .visitChildren
    }
}

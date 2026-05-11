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

/// Performance suites MUST carry the `.serialized` trait.
/// Citation: `[SWIFT-TEST-004]`.
extension Lint.Rule {
    public static let `performance suite serialized` = Lint.Rule(
        id: "performance_suite_serialized",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = TestingPerformanceSuiteSerializedVisitor(
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
internal let testingPerformanceSuiteSerializedMessage: Swift.String =
    "[performance_suite_serialized] [SWIFT-TEST-004]: performance suites MUST "
    + "carry `.serialized` to prevent parallel execution variance from polluting "
    + "timing measurements."

internal final class TestingPerformanceSuiteSerializedVisitor: SyntaxVisitor {
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
            if attr.attributeName.trimmedDescription == "Suite" { return attr }
        }
        return nil
    }

    private func mentionsSerialized(_ attribute: AttributeSyntax) -> Swift.Bool {
        return attribute.trimmedDescription.contains(".serialized")
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "Performance" else { return .visitChildren }
        guard let attribute = suiteAttribute(node.attributes) else { return .visitChildren }
        guard !mentionsSerialized(attribute) else { return .visitChildren }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "performance_suite_serialized",
            message: testingPerformanceSuiteSerializedMessage
        ))
        return .visitChildren
    }
}

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

/// `@Suite` types MUST follow the extension-pattern naming, not compound
/// names. Citation: `[SWIFT-TEST-002]`.
extension Lint.Rule {
    public static let `compound suite name` = Lint.Rule(
        id: "compound_test_suite_name",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = TestingCompoundSuiteNameVisitor(
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
internal let testingCompoundSuiteNameMessage: Swift.String =
    "[compound_test_suite_name] [SWIFT-TEST-002]: `@Suite` types MUST use the "
    + "extension-pattern nested name (`extension Foo { @Suite struct Test {} }`), "
    + "not a compound name like `FooTests`."

private func suiteHasSuiteAttribute(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "Suite" { return true }
    }
    return false
}

private func suiteIsCompoundIdentifier(_ name: Swift.String) -> Swift.Bool {
    var uppercaseRuns = 0
    var prevWasLower = false
    for (offset, character) in name.enumerated() {
        if offset == 0 {
            guard character.isUppercase else { return false }
            uppercaseRuns = 1
            continue
        }
        if character.isUppercase, prevWasLower { uppercaseRuns += 1 }
        prevWasLower = character.isLowercase
    }
    return uppercaseRuns >= 2
}

internal final class TestingCompoundSuiteNameVisitor: SyntaxVisitor {
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
        guard suiteHasSuiteAttribute(node.attributes) else { return .visitChildren }
        let name = node.name.text
        guard suiteIsCompoundIdentifier(name) else { return .visitChildren }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "compound_test_suite_name",
            message: testingCompoundSuiteNameMessage
        ))
        return .visitChildren
    }
}

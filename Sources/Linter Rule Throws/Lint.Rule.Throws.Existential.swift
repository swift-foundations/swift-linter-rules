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

/// `throws(any Error)` boxes the error existentially — semantically
/// identical to untyped `throws`. Citation: `feedback_no_existential_throws`.
extension Lint.Rule {
    public static let `existential throws` = Lint.Rule(
        id: "existential_throws",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = ThrowsExistentialVisitor(
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
internal let throwsExistentialMessage: Swift.String =
    "[existential_throws] feedback_no_existential_throws: `throws(any Error)` boxes "
    + "the error as an existential — semantically identical to untyped `throws`. "
    + "Use a concrete error type or make the container generic over the error type."

internal final class ThrowsExistentialVisitor: SyntaxVisitor {
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

    override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
        guard let typed = node.type else { return .visitChildren }
        guard isAnyError(typed) else { return .visitChildren }
        let location = converter.location(for: typed.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "existential_throws",
            message: throwsExistentialMessage
        ))
        return .visitChildren
    }

    private func isAnyError(_ type: TypeSyntax) -> Swift.Bool {
        guard let some = type.as(SomeOrAnyTypeSyntax.self),
              some.someOrAnySpecifier.tokenKind == .keyword(.any)
        else { return false }
        return isErrorType(some.constraint)
    }

    private func isErrorType(_ type: TypeSyntax) -> Swift.Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self),
           identifier.name.text == "Error"
        { return true }
        if let member = type.as(MemberTypeSyntax.self),
           member.name.text == "Error",
           let base = member.baseType.as(IdentifierTypeSyntax.self),
           base.name.text == "Swift"
        { return true }
        return false
    }
}

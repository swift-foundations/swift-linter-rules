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

/// Callback APIs MUST express outcomes as `() throws(E) -> T` thunk
/// parameters, not as `Result<T, E>` values. Citation: `[IMPL-092]`.
extension Lint.Rule {
    public static let `callback result over throws thunk` = Lint.Rule(
        id: "callback_result_over_throws_thunk",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = ThrowsResultCallbackVisitor(
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
internal let throwsResultCallbackMessage: Swift.String =
    "[callback_result_over_throws_thunk] [IMPL-092]: callback closure "
    + "parameters MUST deliver outcomes via a `() throws(E) -> T` thunk, "
    + "not a `Result<T, E>` value."

private func resultCallbackTokenPosition(in type: TypeSyntax) -> AbsolutePosition? {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) { current = optional.wrappedType }
    while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) { current = iuo.wrappedType }
    while let attributed = current.as(AttributedTypeSyntax.self) { current = attributed.baseType }
    if let identifier = current.as(IdentifierTypeSyntax.self),
       identifier.name.text == "Result"
    { return identifier.name.positionAfterSkippingLeadingTrivia }
    if let member = current.as(MemberTypeSyntax.self),
       member.name.text == "Result",
       let base = member.baseType.as(IdentifierTypeSyntax.self),
       base.name.text == "Swift"
    { return member.name.positionAfterSkippingLeadingTrivia }
    return nil
}

internal final class ThrowsResultCallbackVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        for parameter in node.parameters {
            if let position = resultCallbackTokenPosition(in: parameter.type) {
                let location = converter.location(for: position)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "callback_result_over_throws_thunk",
                    message: throwsResultCallbackMessage
                ))
            }
        }
        return .visitChildren
    }
}

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

/// Closure parameters trail the signature. Citation: `[API-IMPL-012]`.
///
/// All closure parameters MUST occupy the final positions of a function
/// or initializer signature. A non-closure parameter MUST NOT appear
/// after a closure parameter. Typed-throws thunks per `[IMPL-092]` —
/// `() throws(E) -> T` — count as closures for this rule.
extension Lint.Rule {
    public static let `parameter position` = Lint.Rule(
        id: "parameter position",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = ClosureParameterPositionVisitor(
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
internal let closureParameterPositionMessage: Swift.String =
    "[parameter position] [API-IMPL-012]: closure parameters MUST occupy the "
    + "final positions of the signature. A non-closure parameter MUST NOT appear "
    + "after a closure parameter — moves the trailing-closure call site. Reorder "
    + "non-closure parameters before all closure parameters; typed-throws thunks "
    + "(`() throws(E) -> T`) count as closures per [IMPL-092]."

/// Shared closure-shape helper used by every rule in the Closure pack.
/// Returns true when the type position resolves to a function type,
/// after stripping optional / IUO / attribute / paren wrappers.
internal func isClosureType(_ type: TypeSyntax) -> Swift.Bool {
    var current = type
    while let optional = current.as(OptionalTypeSyntax.self) {
        current = optional.wrappedType
    }
    while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        current = iuo.wrappedType
    }
    while let attributed = current.as(AttributedTypeSyntax.self) {
        current = attributed.baseType
    }
    while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
        current = tuple.elements.first!.type
    }
    return current.is(FunctionTypeSyntax.self)
}

internal final class ClosureParameterPositionVisitor: SyntaxVisitor {
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

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "parameter position",
            message: closureParameterPositionMessage
        ))
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var sawClosure = false
        for parameter in parameters {
            let isClosure = isClosureType(parameter.type)
            if sawClosure, !isClosure {
                emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
            }
            if isClosure {
                sawClosure = true
            }
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }
}

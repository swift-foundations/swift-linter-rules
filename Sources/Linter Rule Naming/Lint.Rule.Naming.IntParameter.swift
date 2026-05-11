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

/// Wave 1 (mechanization-program) — `Int` parameter or return type in
/// public-API signatures.
///
/// Citation: `[IMPL-010]` (implementation skill — Push Int to the Edge).
extension Lint.Rule {
    public static let `int public parameter` = Lint.Rule(
        id: "int_parameter_public",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingIntParameterVisitor(
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
internal let namingIntParameterMessageParameter: Swift.String =
    "[int_parameter_public] [IMPL-010]: public function/initializer "
    + "signature has a bare `Int` parameter. Push the stdlib boundary "
    + "out — use a typed wrapper (`Index<T>`, `Ordinal`, `Cardinal`, "
    + "`Count<T>`, `Offset<T>`) at the public surface; convert via a "
    + "boundary overload internally. `Int(bitPattern:)` lives in one "
    + "place, once, forever (per [IMPL-010])."

@usableFromInline
internal let namingIntParameterMessageReturn: Swift.String =
    "[int_parameter_public] [IMPL-010]: public function returns a bare "
    + "`Int`. Push the stdlib boundary out — return a typed wrapper "
    + "(`Cardinal`, `Count<T>`, `Offset<T>`) so consumers see typed "
    + "intent rather than a raw machine integer."

internal func namingIntParameterIsPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open):
            return true
        default:
            continue
        }
    }
    return false
}

/// Strips optionals + attributed type wrappers and asks: is the
/// underlying type the bare `Int` or `Swift.Int`?
internal func namingIntParameterIsBareInt(_ type: TypeSyntax) -> Bool {
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
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return identifier.name.text == "Int"
    }
    if let member = current.as(MemberTypeSyntax.self) {
        if member.name.text == "Int",
           let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
           baseIdentifier.name.text == "Swift" {
            return true
        }
    }
    return false
}

internal final class NamingIntParameterVisitor: SyntaxVisitor {
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
        guard namingIntParameterIsPublicOrOpen(node.modifiers) else {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        // Return type.
        if let returnClause = node.signature.returnClause,
           namingIntParameterIsBareInt(returnClause.type) {
            emit(at: returnClause.type.positionAfterSkippingLeadingTrivia, message: namingIntParameterMessageReturn)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard namingIntParameterIsPublicOrOpen(node.modifiers) else {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        for parameter in parameters {
            guard namingIntParameterIsBareInt(parameter.type) else {
                continue
            }
            emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia, message: namingIntParameterMessageParameter)
        }
    }

    private func emit(at position: AbsolutePosition, message: Swift.String) {
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "int_parameter_public",
            message: message
        ))
    }
}

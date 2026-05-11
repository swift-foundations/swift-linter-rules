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

/// Wave 1 (mechanization-program) — Bool parameter in public-API signature.
///
/// Citation: `[API-IMPL-003]` (code-surface skill — Enum Over Boolean).
///
/// Use enums instead of boolean flags when state can expand. The
/// mechanical signal: a parameter of type `Bool` (or `Swift.Bool`) on
/// a `public` / `open` function or initializer is the lowest-friction
/// indication of the anti-pattern. Boolean parameters in public APIs
/// are particularly painful because they (a) read as call-site
/// noise (`open(create: true, truncate: true, …)`) and (b) cannot
/// extend to a third state without an API break.
extension Lint.Rule {
    public static let `bool public parameter` = Lint.Rule(
        id: "bool_parameter_public",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingBoolParameterVisitor(
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
internal let namingBoolParameterMessage: Swift.String =
    "[bool_parameter_public] [API-IMPL-003]: public function/initializer "
    + "signature has a `Bool` parameter. Use an enum (or named-options "
    + "struct) so additional states can be added without an API break "
    + "and so call sites read as intent (`mode: .strict`) rather than "
    + "magic flags (`strict: true`). `package`-scope and non-public "
    + "declarations are exempt; closure-typed parameters with internal "
    + "Bool arguments are exempt."

internal func namingBoolParameterIsPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
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
/// underlying type an identifier `Bool` or `Swift.Bool`?
internal func namingBoolParameterIsBoolType(_ type: TypeSyntax) -> Bool {
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
    // Also unwrap single-element parenthesised forms (`(Bool)`).
    while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
        current = tuple.elements.first!.type
    }
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return identifier.name.text == "Bool"
    }
    if let member = current.as(MemberTypeSyntax.self) {
        // `Swift.Bool`: base is `Swift`, name is `Bool`.
        if member.name.text == "Bool",
           let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
           baseIdentifier.name.text == "Swift" {
            return true
        }
    }
    return false
}

internal final class NamingBoolParameterVisitor: SyntaxVisitor {
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
        guard namingBoolParameterIsPublicOrOpen(node.modifiers) else {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard namingBoolParameterIsPublicOrOpen(node.modifiers) else {
            return .visitChildren
        }
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        for parameter in parameters {
            guard namingBoolParameterIsBoolType(parameter.type) else {
                continue
            }
            let location = converter.location(for: parameter.firstName.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "bool_parameter_public",
                message: namingBoolParameterMessage
            ))
        }
    }
}

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

/// Public generic APIs throwing a generic-parameter-typed error should
/// consider a non-throwing specialization. Citation: `[IMPL-042]`.
extension Lint.Rule {
    public static let `generic throws missing never` = Lint.Rule(
        id: "generic throws missing never",
        default: .warning,
        findings: { source, severity in
            let visitor = ThrowsGenericNeverSpecializationVisitor(
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
internal let throwsGenericNeverSpecializationMessage: Swift.String =
    "[generic throws missing never] [IMPL-042]: public "
    + "generic API throws a generic-parameter-typed error. Even when "
    + "callers bind the parameter to `Never`, the generic outer type "
    + "hides the binding from codegen. Consider adding a non-throwing "
    + "specialization under `extension Owner where G.Sub == Never { … }`."

private func gnsIsPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open): return true
        default: continue
        }
    }
    return false
}

private func gnsCollectGenericParamNames(_ clause: GenericParameterClauseSyntax?) -> Swift.Set<Swift.String> {
    guard let clause else { return [] }
    var names: Swift.Set<Swift.String> = []
    for parameter in clause.parameters { names.insert(parameter.name.text) }
    return names
}

private func gnsGenericFailureTypePosition(
    in clause: ThrowsClauseSyntax?,
    availableGenerics: Swift.Set<Swift.String>
) -> AbsolutePosition? {
    guard let clause, let type = clause.type else { return nil }
    guard let member = type.as(MemberTypeSyntax.self) else { return nil }
    guard let base = member.baseType.as(IdentifierTypeSyntax.self) else { return nil }
    guard availableGenerics.contains(base.name.text) else { return nil }
    return member.positionAfterSkippingLeadingTrivia
}

private func gnsCollectExtendedGenericNames(_ type: TypeSyntax) -> Swift.Set<Swift.String> {
    var names: Swift.Set<Swift.String> = []
    if let identifier = type.as(IdentifierTypeSyntax.self),
       let genericArgs = identifier.genericArgumentClause
    {
        for argument in genericArgs.arguments {
            if let ident = argument.argument.as(IdentifierTypeSyntax.self) {
                names.insert(ident.name.text)
            }
        }
    }
    return names
}

internal final class ThrowsGenericNeverSpecializationVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var genericsStack: [Swift.Set<Swift.String>] = []

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
            identifier: "generic throws missing never",
            message: throwsGenericNeverSpecializationMessage
        ))
    }

    private func currentAvailable(_ funcGenerics: Swift.Set<Swift.String>) -> Swift.Set<Swift.String> {
        var result: Swift.Set<Swift.String> = funcGenerics
        for set in genericsStack { result.formUnion(set) }
        return result
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: EnumDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectGenericParamNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(gnsCollectExtendedGenericNames(node.extendedType))
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) { genericsStack.removeLast() }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard gnsIsPublicOrOpen(node.modifiers) else { return .visitChildren }
        let funcGenerics = gnsCollectGenericParamNames(node.genericParameterClause)
        let available = currentAvailable(funcGenerics)
        if let position = gnsGenericFailureTypePosition(
            in: node.signature.effectSpecifiers?.throwsClause,
            availableGenerics: available
        ) {
            emit(at: position)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard gnsIsPublicOrOpen(node.modifiers) else { return .visitChildren }
        let funcGenerics = gnsCollectGenericParamNames(node.genericParameterClause)
        let available = currentAvailable(funcGenerics)
        if let position = gnsGenericFailureTypePosition(
            in: node.signature.effectSpecifiers?.throwsClause,
            availableGenerics: available
        ) {
            emit(at: position)
        }
        return .visitChildren
    }
}

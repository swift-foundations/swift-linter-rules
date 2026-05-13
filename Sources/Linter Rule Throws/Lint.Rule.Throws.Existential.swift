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
        id: "existential throws",
        default: .warning,
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
    "[existential throws] feedback_no_existential_throws: `throws(any Error)` boxes "
    + "the error as an existential — semantically identical to untyped `throws`. "
    + "Use a concrete error type or make the container generic over the error type."

/// Stdlib-protocol witnesses whose untyped-throws signature is dictated
/// by the protocol requirement itself — the conformer cannot narrow the
/// throws set because downstream stdlib calls propagate `any Error`.
/// Citation key required at write time.
///
/// Gated on conformance context: the function name must match an entry
/// AND the enclosing extension's inheritance clause must name the
/// corresponding stdlib protocol. Outside that context, the same
/// signature has no structural justification and still fires.
@usableFromInline
internal let throwsExistentialStdlibProtocolWitnessCitations: [Swift.String: (witness: Swift.String, protocols: [Swift.String])] = [
    "init(from:)": (
        witness: "Swift.Decodable.init(from:) throws — protocol requirement is untyped",
        protocols: ["Decodable", "Codable"]
    ),
    "encode(to:)": (
        witness: "Swift.Encodable.encode(to:) throws — protocol requirement is untyped",
        protocols: ["Encodable", "Codable"]
    ),
]

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
        // Exempt per [RULE-EXEMPT-2] (protocol-witness-citation-dict):
        // walk up to the enclosing function / init decl, build the
        // witness-key string, and check whether it matches a known
        // stdlib-protocol untyped-throws requirement AND the enclosing
        // extension conforms to the corresponding stdlib protocol. The
        // protocol IS the gate — the typed-throws constraint is
        // structurally inexpressible. Tuple-valued dict form lets one
        // witness key satisfy multiple protocols (Decodable, Codable).
        // Skill: swift-institute/Skills/rule-exemptions/SKILL.md.
        if isStdlibProtocolWitnessThrows(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(for: typed.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "existential throws",
            message: throwsExistentialMessage
        ))
        return .visitChildren
    }

    private func isStdlibProtocolWitnessThrows(_ node: Syntax) -> Swift.Bool {
        // Walk up to enclosing function or initializer decl.
        var current: Syntax? = node.parent
        var witnessKey: Swift.String?
        var enclosingExtension: ExtensionDeclSyntax?
        while let candidate = current {
            if let fn = candidate.as(FunctionDeclSyntax.self) {
                witnessKey = throwsWitnessKey(name: fn.name.text, parameterClause: fn.signature.parameterClause)
                current = candidate.parent
                continue
            }
            if let initDecl = candidate.as(InitializerDeclSyntax.self) {
                witnessKey = throwsWitnessKey(name: "init", parameterClause: initDecl.signature.parameterClause)
                current = candidate.parent
                continue
            }
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                enclosingExtension = ext
                break
            }
            if candidate.is(StructDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self)
                || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ActorDeclSyntax.self) {
                break
            }
            current = candidate.parent
        }
        guard let key = witnessKey,
              let entry = throwsExistentialStdlibProtocolWitnessCitations[key],
              let ext = enclosingExtension,
              let inheritance = ext.inheritanceClause
        else { return false }
        for inherited in inheritance.inheritedTypes {
            let leaf: Swift.String?
            if let identifier = inherited.type.as(IdentifierTypeSyntax.self) {
                leaf = identifier.name.text
            } else if let member = inherited.type.as(MemberTypeSyntax.self) {
                leaf = member.name.text
            } else {
                leaf = nil
            }
            if let leaf, entry.protocols.contains(leaf) {
                return true
            }
        }
        return false
    }

    private func throwsWitnessKey(name: Swift.String, parameterClause: FunctionParameterClauseSyntax) -> Swift.String {
        var key = name + "("
        for parameter in parameterClause.parameters {
            key += parameter.firstName.text + ":"
        }
        key += ")"
        return key
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

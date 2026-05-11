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

/// Caseless-enum namespaces containing exactly one nested type are
/// variant labels, not namespaces. Citation: `[API-NAME-001a]`.
extension Lint.Rule {
    public static let `single type namespace` = Lint.Rule(
        id: "single type namespace",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingSingleTypeNamespaceVisitor(
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
internal let namingSingleTypeNamespaceMessage: Swift.String =
    "[single type namespace] [API-NAME-001a]: caseless-enum namespace "
    + "contains exactly one nested type — that's a *variant label*, "
    + "not a namespace. Promote the inner type and nest the label "
    + "under its parent: `extension <InnerType> { public struct <Label> "
    + "{ ... } }`."

private enum SingleTypeMemberCategory {
    case enumCase
    case typeDecl
    case typealiasDecl
    case other
}

private func singleTypeCategorize(_ decl: DeclSyntax) -> SingleTypeMemberCategory {
    if decl.is(EnumCaseDeclSyntax.self) { return .enumCase }
    if decl.is(StructDeclSyntax.self) { return .typeDecl }
    if decl.is(ClassDeclSyntax.self) { return .typeDecl }
    if decl.is(EnumDeclSyntax.self) { return .typeDecl }
    if decl.is(ActorDeclSyntax.self) { return .typeDecl }
    if decl.is(ProtocolDeclSyntax.self) { return .typeDecl }
    if decl.is(TypeAliasDeclSyntax.self) { return .typealiasDecl }
    return .other
}

internal final class NamingSingleTypeNamespaceVisitor: SyntaxVisitor {
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

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        var typeCount = 0
        var hasOther = false
        for member in node.memberBlock.members {
            let category = singleTypeCategorize(member.decl)
            switch category {
            case .enumCase:
                return .visitChildren
            case .typeDecl:
                typeCount += 1
            case .typealiasDecl:
                continue
            case .other:
                hasOther = true
            }
        }
        guard !hasOther else { return .visitChildren }
        guard typeCount == 1 else { return .visitChildren }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "single type namespace",
            message: namingSingleTypeNamespaceMessage
        ))
        return .visitChildren
    }
}

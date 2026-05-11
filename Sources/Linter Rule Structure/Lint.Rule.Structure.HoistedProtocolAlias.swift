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

/// Wave 3 (mechanization-program) — declaring-module conformance for a
/// hoisted-protocol typealias pattern MUST use the hoisted name, not
/// the typealias path (self-referential conformance cycle).
///
/// Citation: `[API-IMPL-009]` (code-surface skill — hoisted protocol
/// with nested typealias).
extension Lint.Rule {
    public static let `hoisted protocol alias` = Lint.Rule(
        id: "hoisted protocol alias",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureHoistedProtocolAliasVisitor(
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
internal let structureHoistedProtocolAliasMessage: Swift.String =
    "[hoisted protocol alias] [API-IMPL-009]: declaring-"
    + "module conformance via the `.Protocol` typealias path is a "
    + "self-referential cycle. Use the hoisted protocol name "
    + "(`_FooProtocol`) directly in the declaring module. The "
    + "typealias path (`Owner.Inner.Protocol`) is for CONSUMER "
    + "modules — different type, no cycle."

internal func structureHoistedProtocolAliasDottedName(of type: TypeSyntax) -> Swift.String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
        guard let baseName = structureHoistedProtocolAliasDottedName(of: member.baseType) else {
            return nil
        }
        return "\(baseName).\(member.name.text)"
    }
    if let metatype = type.as(MetatypeTypeSyntax.self) {
        guard let baseName = structureHoistedProtocolAliasDottedName(of: metatype.baseType) else {
            return nil
        }
        return "\(baseName).\(metatype.metatypeSpecifier.text)"
    }
    return nil
}

internal func structureHoistedProtocolAliasIsSelfProtocolConformance(
    extendedName: Swift.String,
    inheritedName: Swift.String
) -> Swift.Bool {
    return inheritedName == "\(extendedName).Protocol"
}

internal final class StructureHoistedProtocolAliasVisitor: SyntaxVisitor {
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

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let extendedName = structureHoistedProtocolAliasDottedName(
            of: node.extendedType
        ) else {
            return .visitChildren
        }
        guard let inheritance = node.inheritanceClause else {
            return .visitChildren
        }
        for inherited in inheritance.inheritedTypes {
            guard let inheritedName = structureHoistedProtocolAliasDottedName(
                of: inherited.type
            ) else { continue }
            guard structureHoistedProtocolAliasIsSelfProtocolConformance(
                extendedName: extendedName,
                inheritedName: inheritedName
            ) else { continue }
            let location = converter.location(
                for: inherited.type.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "hoisted protocol alias",
                message: structureHoistedProtocolAliasMessage
            ))
        }
        return .visitChildren
    }
}

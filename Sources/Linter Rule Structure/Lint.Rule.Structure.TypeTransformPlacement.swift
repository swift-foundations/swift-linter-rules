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

/// Wave 4 (mechanization-program) — type-transformation methods belong
/// in initializers or static methods on the target type, not as
/// instance methods on the source.
///
/// Citation: `[PATTERN-012]` (implementation skill, patterns.md).
extension Lint.Rule {
    public static let `type transform placement` = Lint.Rule(
        id: "type_transform_placement",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureTypeTransformPlacementVisitor(
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
internal let structureTypeTransformPlacementMessage: Swift.String =
    "[type_transform_placement] [PATTERN-012]: instance method `to<Type>()` "
    + "/ `as<Type>()` returning the matching type is the type-transformation "
    + "anti-pattern. Move the conversion to an `init(_ source: Source)` on the "
    + "target type or a static method (`Target.from(_ source: Source)`) so the "
    + "canonical conversion site lives with the target."

internal let structureTypeTransformPlacementPrefixes: [Swift.String] = ["to", "as"]

internal func structureTypeTransformPlacementTransformSuffix(of name: Swift.String) -> Swift.String? {
    for prefix in structureTypeTransformPlacementPrefixes {
        guard name.hasPrefix(prefix) else { continue }
        let suffix = String(name.dropFirst(prefix.count))
        guard let first = suffix.first, first.isUppercase else { continue }
        return suffix
    }
    return nil
}

internal func structureTypeTransformPlacementReturnTypeLeafName(_ type: TypeSyntax) -> Swift.String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return member.name.text
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return structureTypeTransformPlacementReturnTypeLeafName(optional.wrappedType)
    }
    return nil
}

internal func structureTypeTransformPlacementHasStaticOrClassModifier(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.static), .keyword(.class):
            return true
        default:
            continue
        }
    }
    return false
}

internal final class StructureTypeTransformPlacementVisitor: SyntaxVisitor {
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
        if structureTypeTransformPlacementHasStaticOrClassModifier(node.modifiers) {
            return .visitChildren
        }
        let name = node.name.text
        guard let suffix = structureTypeTransformPlacementTransformSuffix(of: name) else {
            return .visitChildren
        }
        guard let returnType = node.signature.returnClause?.type else {
            return .visitChildren
        }
        guard let returnLeaf = structureTypeTransformPlacementReturnTypeLeafName(returnType) else {
            return .visitChildren
        }
        guard returnLeaf == suffix else { return .visitChildren }
        let location = converter.location(
            for: node.funcKeyword.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "type_transform_placement",
            message: structureTypeTransformPlacementMessage
        ))
        return .visitChildren
    }
}

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

/// Wave 3 (mechanization-program) — wrapper types whose `_backing` /
/// `_wrapped` / `_underlying` property is non-private signal an
/// incomplete-wrapper violation.
///
/// Citation: `[API-IMPL-011]` (code-surface skill — wrapper completeness).
extension Lint.Rule {
    public static let `wrapper backing exposed` = Lint.Rule(
        id: "wrapper backing exposed",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureWrapperBackingExposedVisitor(
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
internal let structureWrapperBackingExposedMessage: Swift.String =
    "[wrapper backing exposed] [API-IMPL-011]: wrapper backing property "
    + "(`_backing` / `_wrapped` / `_underlying`) is exposed at non-private "
    + "visibility — consumers will reach through (`wrapper._backing.run { … }`) "
    + "for any operation the wrapper itself doesn't surface, and the wrapper "
    + "looks fake. Make the property `private` (or `fileprivate`), and own the "
    + "primary operation on the wrapper directly. `@usableFromInline` is exempt."

internal let structureWrapperBackingExposedTrackedNames: Swift.Set<Swift.String> = [
    "_backing",
    "_wrapped",
    "_underlying",
]

internal func structureWrapperBackingExposedHasPrivateOrFilePrivate(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.private), .keyword(.fileprivate):
            return true
        default:
            continue
        }
    }
    return false
}

internal func structureWrapperBackingExposedHasUsableFromInline(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "usableFromInline" {
            return true
        }
    }
    return false
}

internal final class StructureWrapperBackingExposedVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var typeDepth: Swift.Int = 0

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: StructDeclSyntax) { typeDepth -= 1 }

    override func visit(_: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ClassDeclSyntax) { typeDepth -= 1 }

    override func visit(_: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        typeDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ActorDeclSyntax) { typeDepth -= 1 }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard typeDepth > 0 else { return .visitChildren }
        if structureWrapperBackingExposedHasPrivateOrFilePrivate(node.modifiers) {
            return .visitChildren
        }
        if structureWrapperBackingExposedHasUsableFromInline(node.attributes) {
            return .visitChildren
        }
        for binding in node.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            guard structureWrapperBackingExposedTrackedNames.contains(
                identifier.identifier.text
            ) else { continue }
            let location = converter.location(
                for: node.bindingSpecifier.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "wrapper backing exposed",
                message: structureWrapperBackingExposedMessage
            ))
            break
        }
        return .visitChildren
    }
}

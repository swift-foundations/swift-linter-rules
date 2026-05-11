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

/// Wave 2b finalization (2026-05-10) — public stored properties of
/// unsafe pointer types MUST be `private` / `internal`, or annotated
/// `@unsafe` to mark them as deliberate escape hatches.
///
/// Citation: `[MEM-SAFE-023]` (memory-safety skill, safety-isolation.md).
extension Lint.Rule {
    public static let `unsafe storage visibility` = Lint.Rule(
        id: "unsafe storage visibility",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryPrivateUnsafeStorageVisitor(
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
internal let memoryPrivateUnsafeStorageMessage: Swift.String =
    "[unsafe storage visibility] [MEM-SAFE-023]: public stored properties of unsafe "
    + "pointer types MUST be `private` / `internal`, or annotated `@unsafe` to "
    + "signal a deliberate escape hatch. Public pointer storage on an Escapable "
    + "wrapper leaks dangling-pointer risk past the wrapper's lifetime. Prefer "
    + "exposing a `Span` view; reserve `@unsafe` for explicit escape hatches."

@usableFromInline
internal let memoryPrivateUnsafeStorageUnsafePointerTypeNames: Swift.Set<Swift.String> = [
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
    "UnsafeRawBufferPointer",
    "UnsafeMutableRawBufferPointer",
]

internal func memoryPrivateUnsafeStorageIsUnsafePointerType(_ type: TypeSyntax) -> Bool {
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
    if let identifier = current.as(IdentifierTypeSyntax.self) {
        return memoryPrivateUnsafeStorageUnsafePointerTypeNames.contains(identifier.name.text)
    }
    if let member = current.as(MemberTypeSyntax.self) {
        return memoryPrivateUnsafeStorageUnsafePointerTypeNames.contains(member.name.text)
    }
    return false
}

internal final class MemoryPrivateUnsafeStorageVisitor: SyntaxVisitor {
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

    private func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
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

    private func hasUnsafeAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "unsafe" {
                return true
            }
        }
        return false
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicModifier(node.modifiers) else {
            return .visitChildren
        }
        guard !hasUnsafeAttribute(node.attributes) else {
            return .visitChildren
        }
        for binding in node.bindings {
            guard let typeAnnotation = binding.typeAnnotation else { continue }
            if memoryPrivateUnsafeStorageIsUnsafePointerType(typeAnnotation.type) {
                let location = converter.location(for: binding.pattern.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "unsafe storage visibility",
                    message: memoryPrivateUnsafeStorageMessage
                ))
            }
        }
        return .visitChildren
    }
}

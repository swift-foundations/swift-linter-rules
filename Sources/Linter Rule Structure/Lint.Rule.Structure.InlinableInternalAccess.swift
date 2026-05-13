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

/// Wave 2b finalization (2026-05-10) — `@inlinable` decls require non-`internal` access.
///
/// Citation: `[PATTERN-052]` (implementation skill, patterns.md).
extension Lint.Rule {
    public static let `inlinable internal access` = Lint.Rule(
        id: "inlinable internal access",
        default: .warning,
        findings: { source, severity in
            let visitor = StructureInlinableInternalAccessVisitor(
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
internal let structureInlinableInternalAccessMessage: Swift.String =
    "[inlinable internal access] [PATTERN-052]: `@inlinable` cross-module access "
    + "requires `@usableFromInline` (or `public` / `package`), not bare `internal`. "
    + "An `@inlinable` decl whose body references an `internal` identifier fails to "
    + "compile across the module boundary; pair the attribute with `@usableFromInline` "
    + "(preferred for impl-only surface) or upgrade to `package` / `public`."

/// Initializer-specific message: Swift rejects `@usableFromInline` on
/// `@inlinable init` as `has no effect`, so the func/var advice doesn't
/// apply. The canonical fix for `@inlinable internal init` is `package
/// init` (without `@usableFromInline`), which satisfies both the lint
/// rule and Swift's redundancy check while keeping the init bounded to
/// the package's inline-into-consumer surface.
@usableFromInline
internal let structureInlinableInternalAccessInitializerMessage: Swift.String =
    "[inlinable internal access] [PATTERN-052]: `@inlinable` cross-module access "
    + "requires non-`internal` visibility. For initializers, prefer `package init` "
    + "— Swift rejects `@usableFromInline` on `@inlinable init` as `has no "
    + "effect` (the func/var pairing does not apply here). Use `package init` "
    + "for impl-only surface, or upgrade to `public init`."

internal final class StructureInlinableInternalAccessVisitor: SyntaxVisitor {
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

    private func hasInlinableAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "inlinable" {
                return true
            }
        }
        return false
    }

    private func hasNonInternalAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.package), .keyword(.open):
                return true
            default:
                continue
            }
        }
        return false
    }

    private func hasUsableFromInline(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "usableFromInline" {
                return true
            }
        }
        return false
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
            identifier: "inlinable internal access",
            message: message
        ))
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasInlinableAttribute(node.attributes),
           !hasNonInternalAccess(node.modifiers),
           !hasUsableFromInline(node.attributes)
        {
            emit(
                at: node.name.positionAfterSkippingLeadingTrivia,
                message: structureInlinableInternalAccessMessage
            )
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasInlinableAttribute(node.attributes),
           !hasNonInternalAccess(node.modifiers),
           !hasUsableFromInline(node.attributes)
        {
            emit(
                at: node.bindingSpecifier.positionAfterSkippingLeadingTrivia,
                message: structureInlinableInternalAccessMessage
            )
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasInlinableAttribute(node.attributes),
           !hasNonInternalAccess(node.modifiers),
           !hasUsableFromInline(node.attributes)
        {
            emit(
                at: node.initKeyword.positionAfterSkippingLeadingTrivia,
                message: structureInlinableInternalAccessInitializerMessage
            )
        }
        return .visitChildren
    }
}

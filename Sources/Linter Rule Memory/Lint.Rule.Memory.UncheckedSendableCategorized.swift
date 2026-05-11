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

/// Wave 2b finalization (2026-05-10) — `@unchecked Sendable`
/// conformances MUST be `@unsafe @unchecked Sendable` (categories A,
/// B, D per `[MEM-SAFE-024]`).
///
/// Citation: `[MEM-SAFE-024]` (memory-safety skill, safety-isolation.md).
extension Lint.Rule {
    public static let `unchecked sendable categorization` = Lint.Rule(
        id: "unchecked_sendable_categorized",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryUncheckedSendableCategorizedVisitor(
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
internal let memoryUncheckedSendableCategorizedMessage: Swift.String =
    "[unchecked_sendable_categorized] [MEM-SAFE-024]: `@unchecked Sendable` MUST "
    + "be classified into category A (synchronized), B (~Copyable ownership), or D "
    + "(structural workaround) AND paired with `@unsafe` plus a doc-comment safety "
    + "invariant. Category C (thread-confined) should migrate to `~Sendable` per "
    + "SE-0518. A fifth category requires explicit conversation per Wave 2b "
    + "Decision 8 — do not add it silently."

internal final class MemoryUncheckedSendableCategorizedVisitor: SyntaxVisitor {
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

    private func hasUnsafeAttributeOnInherited(_ inherited: InheritedTypeSyntax) -> Bool {
        // Per current Swift syntax, inherited types in the conformance
        // list don't carry attribute lists individually — attributes on
        // the conformance live at the AttributedTypeSyntax wrapping the
        // type. Check that.
        if let attributed = inherited.type.as(AttributedTypeSyntax.self) {
            for attribute in attributed.attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "unsafe" {
                    return true
                }
            }
        }
        return false
    }

    private func hasUncheckedAttribute(_ inherited: InheritedTypeSyntax) -> Bool {
        if let attributed = inherited.type.as(AttributedTypeSyntax.self) {
            for attribute in attributed.attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "unchecked" {
                    return true
                }
            }
        }
        return false
    }

    private func isSendableInherited(_ inherited: InheritedTypeSyntax) -> Bool {
        var current = inherited.type
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Sendable"
        }
        if let member = current.as(MemberTypeSyntax.self) {
            return member.name.text == "Sendable"
        }
        return false
    }

    private func check(_ inheritanceClause: InheritanceClauseSyntax?) {
        guard let inheritanceClause else { return }
        for inherited in inheritanceClause.inheritedTypes {
            guard isSendableInherited(inherited) else { continue }
            guard hasUncheckedAttribute(inherited) else { continue }
            guard !hasUnsafeAttributeOnInherited(inherited) else { continue }
            let location = converter.location(for: inherited.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "unchecked_sendable_categorized",
                message: memoryUncheckedSendableCategorizedMessage
            ))
        }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        check(node.inheritanceClause)
        return .visitChildren
    }
}

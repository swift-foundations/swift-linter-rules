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

/// 2026-05-13 BREAKING revision — flags `@unchecked Sendable`
/// conformances that pair `@unsafe` on the same conformance clause
/// (a deviation from Swift convention per SE-0458). The Sendable
/// conformance carries `@unchecked` alone; `@unsafe` lives on the
/// type/extension declaration when memory-safety unsafety is fundamental
/// to the type's identity, or on individual methods/properties per
/// SE-0458 — never on the Sendable protocol slot.
///
/// Citation: `[MEM-SAFE-024]` (memory-safety skill, safety-isolation.md);
/// `swift-institute/Research/safe-unsafe-attribute-and-unchecked-sendable-best-practices.md`
/// v1.1.0.
///
/// Originally added 2026-05-10 (Wave 2b finalization Batch 4) flagging
/// `@unchecked Sendable` WITHOUT `@unsafe`; inverted 2026-05-13 to flag
/// `@unchecked Sendable` WITH `@unsafe` on the same conformance clause.
extension Lint.Rule {
    public static let `unchecked sendable categorization` = Lint.Rule(
        id: "unchecked sendable categorization",
        default: .warning,
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
    "[unchecked sendable categorization] [MEM-SAFE-024]: `@unchecked Sendable` "
    + "MUST NOT be paired with `@unsafe` on the same conformance clause. Per "
    + "SE-0458, `@unsafe` is scoped to the four memory-safety dimensions "
    + "(lifetime/bounds/type/initialization); thread safety is the separate "
    + "fifth dimension carried by `@unchecked Sendable` alone. Drop the "
    + "`@unsafe` from the conformance clause. If memory-safety unsafety is "
    + "fundamental to the type, apply `@unsafe` on the type or extension "
    + "declaration (a different syntactic position) instead. The Category "
    + "(A/B/C/D) is documentation discipline carried in a `## Safety Invariant` "
    + "doc-comment or adjacent `// SAFETY:` / `// WHY:` block, NOT a trigger "
    + "for `@unsafe`."

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
            // Inverted 2026-05-13: flag when @unsafe IS paired with @unchecked
            // on the same conformance clause (deviation from Swift convention
            // per SE-0458). Previously: flag when @unsafe was absent.
            guard hasUnsafeAttributeOnInherited(inherited) else { continue }
            let location = converter.location(for: inherited.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "unchecked sendable categorization",
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

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

/// Wave 4 (mechanization-program) — file pairs `@usableFromInline` with
/// `internal import` of a module whose types the inline body references.
///
/// Citation: `[PATTERN-055]` (implementation skill, patterns.md).
extension Lint.Rule {
    public static let `usable from inline internal import` = Lint.Rule(
        id: "usable from inline internal import",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureUsableFromInlineInternalImportVisitor(
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
internal let structureUsableFromInlineInternalImportMessage: Swift.String =
    "[usable from inline internal import] [PATTERN-055]: file pairs "
    + "`@usableFromInline` with `internal import` of a referenced module. "
    + "Swift rejects `@usableFromInline` bodies that reach identifiers in "
    + "internally-imported modules at compile time. Either downgrade the "
    + "decl's visibility or upgrade the import to `public` / `package`."

/// Carries an internal-import's diagnostic site (the `import` keyword
/// position) and the imported module's leaf name. The leaf name is the
/// reach-target the rule uses to test whether any `@usableFromInline`
/// decl syntactically references the module — without a name match,
/// there's no co-firing condition and the rule must not fire.
///
/// Citation: tightening per A6 in
/// `Research/2026-05-12-thread-b-rule-pack-dogfeed-triage.md`.
internal struct StructureUsableFromInlineInternalImportModule {
    let position: AbsolutePosition
    let leafName: Swift.String
}

internal final class StructureUsableFromInlineInternalImportVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    /// Token texts collected from every `@usableFromInline`-annotated
    /// declaration's subtree. The collection happens at the
    /// declaration level (not the attribute level) so that the type
    /// annotation, initializer, and body all contribute their
    /// identifier references — the rule's principled scope is
    /// "@usableFromInline body actually reaches into the
    /// internally-imported module," which means any identifier
    /// anywhere in the annotated decl that matches the imported
    /// module's leaf name.
    var usableFromInlineReferencedNames: Swift.Set<Swift.String> = []
    var internalImportModules: [StructureUsableFromInlineInternalImportModule] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    /// Returns true if `attributes` carries the `@usableFromInline`
    /// attribute. Walks the attribute list looking for an attribute
    /// whose identifier name (or its trimmed description) is
    /// `usableFromInline`.
    private func hasUsableFromInlineAttribute(_ attributes: AttributeListSyntax) -> Swift.Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
               identifier.name.text == "usableFromInline" {
                return true
            }
            if attr.attributeName.trimmedDescription == "usableFromInline" {
                return true
            }
        }
        return false
    }

    /// Walks `node`'s subtree and collects every identifier-shaped
    /// token text into `usableFromInlineReferencedNames`. Used to
    /// build the syntactic-reach set: the rule fires per
    /// internal-import only when the imported module's leaf name is
    /// present in this set (i.e., the `@usableFromInline` body
    /// syntactically references the module, qualified or as a leaf
    /// identifier coincidentally matching the module name).
    ///
    /// Token-kind filter: `.identifier` covers type names, decl
    /// references, member-access bases, and function names. Keyword
    /// tokens and operator tokens are skipped (they cannot resolve
    /// to module-imported identifiers).
    private func collectIdentifierTexts(in node: some SyntaxProtocol) {
        for token in node.tokens(viewMode: .sourceAccurate) {
            if case .identifier(let text) = token.tokenKind {
                usableFromInlineReferencedNames.insert(text)
            }
        }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasUsableFromInlineAttribute(node.attributes) {
            collectIdentifierTexts(in: node)
        }
        return .visitChildren
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        var isInternal: Swift.Bool = false
        for modifier in node.modifiers {
            if case .keyword(.internal) = modifier.name.tokenKind {
                isInternal = true
                break
            }
        }
        guard isInternal else { return .visitChildren }
        let leafName = importDeclLeafModuleName(node)
        internalImportModules.append(.init(
            position: node.importKeyword.positionAfterSkippingLeadingTrivia,
            leafName: leafName
        ))
        return .visitChildren
    }

    /// Returns the leaf module name of an `import M` (or
    /// `import A.B.M`) declaration. Submodule imports are uncommon
    /// in the ecosystem but the leaf-name semantics match the
    /// inheritance-clause walk used elsewhere — both bare and
    /// dotted forms collapse to the trailing component, which is
    /// the name a consumer would write to reach into the module.
    private func importDeclLeafModuleName(_ node: ImportDeclSyntax) -> Swift.String {
        let path = node.path
        guard let last = path.last else { return "" }
        return last.name.text
    }

    /// Tightened recognizer (Thread C, A6): fires per
    /// `internal import` only when its leaf module name appears in
    /// the `@usableFromInline` decls' identifier-reference set.
    /// The prior recognizer fired on co-presence of any
    /// `@usableFromInline` annotation + any `internal import`,
    /// which over-fires on rule-pack files whose `@usableFromInline`
    /// constants are plain `Swift.String` messages with no
    /// SwiftSyntax reach.
    func finalize() {
        for module in internalImportModules {
            guard usableFromInlineReferencedNames.contains(module.leafName) else {
                continue
            }
            let location = converter.location(for: module.position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "usable from inline internal import",
                message: structureUsableFromInlineInternalImportMessage
            ))
        }
    }

    override func visitPost(_: SourceFileSyntax) {
        finalize()
    }
}

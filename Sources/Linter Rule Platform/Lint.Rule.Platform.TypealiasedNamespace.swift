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

/// Wave 3 (mechanization-program) — namespace-bridging typealias that
/// preserves the leaf name silently re-points new nested-type
/// declarations to a foreign module's namespace.
///
/// Citation: `[PLAT-ARCH-018]` (platform skill — typealiased namespace-
/// path conflict rule).
extension Lint.Rule {
    public static let `typealiased namespace bridge` = Lint.Rule(
        id: "typealiased namespace bridge",
        default: .warning,
        findings: { source, severity in
            let visitor = PlatformTypealiasedNamespaceVisitor(
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
internal let platformTypealiasedNamespaceMessage: Swift.String =
    "[typealiased namespace bridge] [PLAT-ARCH-018]: typealias whose "
    + "LHS name matches its RHS member-type leaf silently bridges a "
    + "foreign namespace into the local one. New-type declarations at "
    + "`<local>.<aliased>.<NewName>` resolve to the foreign module — "
    + "any existing type at the same foreign path conflicts silently. "
    + "Before adding sub-types via this aliased path, grep the foreign "
    + "module for collisions and choose a non-conflicting sub-path, a "
    + "non-typealiased namespace entry, or relocate the foreign type."

internal final class PlatformTypealiasedNamespaceVisitor: SyntaxVisitor {
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

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let aliasName = node.name.text
        guard let member = node.initializer.value.as(MemberTypeSyntax.self) else {
            return .visitChildren
        }
        guard member.name.text == aliasName else { return .visitChildren }
        // Exempt per [RULE-EXEMPT-3] (conformance-context): a typealias
        // inside an extension whose inheritance clause names a protocol
        // satisfies the protocol's associatedtype requirement, not a
        // foreign-namespace bridge. The shape `typealias Index =
        // Underlying.Index` inside `extension Tagged: Collection`
        // provides `Collection.Index`, not silent namespace re-pointing.
        // Parallels Wave 1 TIGHTEN on unification_typealias /
        // namespace_adoption_typealias. Pack-local `isInsideConformingExtension`
        // duplicates the institute Naming.Shared helper because
        // cross-pack visibility isn't available; semantics match.
        if isInsideConformingExtension(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "typealiased namespace bridge",
            message: platformTypealiasedNamespaceMessage
        ))
        return .visitChildren
    }

    private func isInsideConformingExtension(_ node: Syntax) -> Swift.Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                return ext.inheritanceClause != nil
            }
            if candidate.is(StructDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self)
                || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ActorDeclSyntax.self)
                || candidate.is(ProtocolDeclSyntax.self) {
                return false
            }
            current = candidate.parent
        }
        return false
    }
}

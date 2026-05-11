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

/// Wave 2b finalization (2026-05-10) — extensions on `~Copyable`-aware
/// generic types MUST include explicit `where ... ~Copyable`
/// constraints.
///
/// Citation: `[MEM-COPY-004]` (memory-safety skill, ownership.md).
///
/// Without an explicit `where Element: ~Copyable` clause, an extension
/// is implicitly constrained to `where Element: Copyable` — silently
/// shrinking the surface to copyable elements only. The institute
/// pattern adds explicit `~Copyable` constraints for any extension
/// that should apply to noncopyable element types.
extension Lint.Rule {
    public static let `extension noncopyable constraint` = Lint.Rule(
        id: "extension noncopyable constraint",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryExtensionNoncopyableConstraintVisitor(
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
internal let memoryExtensionNoncopyableConstraintMessage: Swift.String =
    "[extension noncopyable constraint] [MEM-COPY-004]: extensions on `~Copyable`-"
    + "aware generic types MUST include explicit `where ... ~Copyable` constraints. "
    + "Without it, the extension is implicitly `where Element: Copyable` and the "
    + "surface silently shrinks. Add `where Element: ~Copyable` (or the matching "
    + "constraint name for your type's generic parameter)."

private final class MemoryExtensionNoncopyableOwnershipFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        // Look for `consuming` / `borrowing` modifier on the type.
        if let attributed = node.type.as(AttributedTypeSyntax.self) {
            for specifier in attributed.specifiers {
                if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
                    let kind = simple.specifier.tokenKind
                    if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
                        found = true
                        return .skipChildren
                    }
                }
            }
        }
        return .visitChildren
    }
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // `consuming func` / `borrowing func` modifiers on the func itself
        // (i.e., consuming-self / borrowing-self).
        for modifier in node.modifiers {
            let kind = modifier.name.tokenKind
            if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
                found = true
                return .skipChildren
            }
        }
        return .visitChildren
    }
}

/// Detects parameter-pack usage (`each T`, `repeat each T`) anywhere
/// in an extension's member block. Swift 6.x does not support
/// `~Copyable each T` at the language level — extensions on
/// parameter-pack types cannot express the `where Element: ~Copyable`
/// clause the rule otherwise requires. Treat presence of pack syntax
/// as an authoritative signal that the rule's normal demand is
/// inexpressible and exempt the extension.
///
/// Sunset: when Swift adopts `~Copyable each T` (swift-evolution; not
/// imminent as of 2026-05-11), re-examine. Parameter-pack extensions
/// will then have an expressible constraint and the exemption should
/// retire so the rule fires legitimately.
private final class MemoryExtensionPackExpansionFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: PackExpansionTypeSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_ node: PackElementTypeSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
}

internal final class MemoryExtensionNoncopyableConstraintVisitor: SyntaxVisitor {
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

    private func whereClauseHasNoncopyable(_ clause: GenericWhereClauseSyntax?) -> Bool {
        guard let clause else { return false }
        for requirement in clause.requirements {
            if requirement.requirement.trimmedDescription.contains("~Copyable") {
                return true
            }
        }
        return false
    }

    /// Returns true if `clause` carries an explicit positive `Copyable`
    /// conformance requirement on any generic parameter. The author has
    /// deliberately scoped the extension to copyable element types — the
    /// rule's "implicit shrink to Copyable" warning is the opposite of
    /// the author's intent and should not fire.
    ///
    /// Matches `where Base: Copyable` (and any name on the LHS).
    /// Tilde-prefixed `~Copyable` is excluded by the substring check on
    /// the right-side trim.
    private func whereClauseHasPositiveCopyable(_ clause: GenericWhereClauseSyntax?) -> Bool {
        guard let clause else { return false }
        for requirement in clause.requirements {
            guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
                continue
            }
            let rhs = conformance.rightType.trimmedDescription
            if rhs == "Copyable" || rhs == "Swift.Copyable" {
                return true
            }
        }
        return false
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Filename-pattern exemption: `* where *.swift` files use the
        // [API-IMPL-007] where-clause-discriminator naming convention.
        // The author has enumerated quadrants via filenames; absence of
        // a constraint in any one quadrant file is deliberate within
        // the family. The rule's warning structurally inverts the
        // author's intent here.
        if source.filePath.contains(" where ") {
            return .visitChildren
        }
        // Walk the extension body for ownership signals.
        let finder = MemoryExtensionNoncopyableOwnershipFinder(viewMode: .sourceAccurate)
        finder.walk(node.memberBlock)
        guard finder.found else {
            return .visitChildren
        }
        // Parameter-pack exemption: `~Copyable each T` is not language-
        // expressible in Swift 6.x. If the extension uses pack syntax
        // anywhere (where clause, body signatures, generic constraints),
        // the where clause the rule asks for cannot be written.
        let packFinder = MemoryExtensionPackExpansionFinder(viewMode: .sourceAccurate)
        packFinder.walk(node)
        guard !packFinder.found else {
            return .visitChildren
        }
        guard !whereClauseHasNoncopyable(node.genericWhereClause) else {
            return .visitChildren
        }
        // Positive-Copyable exemption: author has explicitly scoped to
        // a Copyable surface; the rule's "silent shrink" premise is
        // inverted by the explicit conformance.
        guard !whereClauseHasPositiveCopyable(node.genericWhereClause) else {
            return .visitChildren
        }
        let location = converter.location(for: node.extendedType.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "extension noncopyable constraint",
            message: memoryExtensionNoncopyableConstraintMessage
        ))
        return .visitChildren
    }
}

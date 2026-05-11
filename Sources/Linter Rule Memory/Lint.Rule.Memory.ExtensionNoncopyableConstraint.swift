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
        id: "extension_noncopyable_constraint",
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
    "[extension_noncopyable_constraint] [MEM-COPY-004]: extensions on `~Copyable`-"
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

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Walk the extension body for ownership signals.
        let finder = MemoryExtensionNoncopyableOwnershipFinder(viewMode: .sourceAccurate)
        finder.walk(node.memberBlock)
        guard finder.found else {
            return .visitChildren
        }
        guard !whereClauseHasNoncopyable(node.genericWhereClause) else {
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
            identifier: "extension_noncopyable_constraint",
            message: memoryExtensionNoncopyableConstraintMessage
        ))
        return .visitChildren
    }
}

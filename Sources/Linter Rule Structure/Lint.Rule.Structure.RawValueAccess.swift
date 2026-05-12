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

/// Wave 4 (mechanization-program) — `.rawValue` and `.position` accesses
/// at consumer call sites bypass typed-conversion ladders.
///
/// Citation: `[PATTERN-017]` (implementation skill, patterns.md).
///
/// ## Package-scoped admission (numerics rule-recognizer, 2026-05-12)
///
/// When the linted file's owning SwiftPM package declares brand-newtype
/// names via `.swift-linter.json` (`brandTypes`), the rule admits
/// `.rawValue` access in two cases:
///
/// 1. **Direct case**: the access base is a type-name in the declared
///    `brandTypes` set (e.g., `Cardinal.rawValue` where the package
///    declares `["Cardinal"]`).
/// 2. **Package-scope fallback**: the access base is a variable / chain
///    that the AST can't resolve to a type-name, AND the package has
///    declared at least one brand. The file is inside a brand-newtype's
///    own implementation; per the rule prose, the access is reserved
///    for that role.
///
/// Cross-package consumers (whose own package's `.swift-linter.json`
/// either does not exist or declares no brands) continue to fire as
/// today, preserving strict-superset.
///
/// See `swift-linter-rules/Research/numerics-rule-recognizer-2026-05-12.md`.
extension Lint.Rule {
    public static let `raw value access` = Lint.Rule(
        id: "raw value access",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureRawValueAccessVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                brandTypes: source.brandTypes
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let structureRawValueAccessMessage: Swift.String =
    "[raw value access] [PATTERN-017]: `.rawValue` / `.position` at a "
    + "consumer call site bypasses the typed-conversion ladder. These "
    + "accessors are reserved for extension initializers (the brand-newtype's "
    + "own boundary) and same-package implementations. Prefer the typed "
    + "operation; suppress with `// swift-linter:disable:next raw value access` "
    + "and a `// REASON:` continuation for legitimate same-package use."

internal let structureRawValueAccessFlaggedAccessors: Swift.Set<Swift.String> = ["rawValue", "position"]

internal final class StructureRawValueAccessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    /// Brand-newtype names declared by the consumer for this run.
    /// Empty when the consumer declares no brands. See the package-
    /// scoped admission notes on ``Lint/Rule/raw value access``.
    let brandTypes: Swift.Set<Lint.Brand>
    var matches: [Diagnostic.Record] = []
    var bodyDepth: Swift.Int = 0

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        brandTypes: Swift.Set<Lint.Brand> = []
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.brandTypes = brandTypes
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: FunctionDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: InitializerDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ClosureExprSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: AccessorDeclSyntax) {
        bodyDepth -= 1
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard bodyDepth > 0 else { return .visitChildren }
        let name = node.declName.baseName.text
        guard structureRawValueAccessFlaggedAccessors.contains(name) else {
            return .visitChildren
        }
        if structureRawValueAccessIsAdmitted(node: node, brandTypes: brandTypes) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.declName.baseName.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "raw value access",
            message: structureRawValueAccessMessage
        ))
        return .visitChildren
    }
}

/// Returns `true` when the `.rawValue` access at `node` is admitted by
/// the consumer's declared brand-types set.
///
/// Two admission paths:
///
/// 1. **Type-name match (direct)**: the access base resolves
///    syntactically to a brand-newtype name in `brandTypes`. Examples:
///    - `Ordinal.rawValue` (bare identifier) — base = `Ordinal`.
///    - `Affine.Discrete.Vector.rawValue` (nested) — base =
///      `Affine.Discrete.Vector`.
///    The dotted name is reassembled from the `MemberAccessExprSyntax`
///    chain and wrapped as a ``Lint/Brand`` at the AST boundary so
///    consumers can declare nested brand-newtypes verbatim in
///    `Lint.swift`'s `brands:` kwarg.
/// 2. **Package-scope fallback**: the base is a variable / chain (no
///    syntactic type-name to extract — e.g., `lhs.rawValue`), AND the
///    consumer declares at least one brand. The file is inside a
///    brand-newtype's own implementation; per the rule prose's
///    "same-package implementations" clause, the access is admitted.
///
/// Returns `false` (and the rule fires as today) when `brandTypes` is
/// empty — preserving strict-superset for cross-package consumers.
internal func structureRawValueAccessIsAdmitted(
    node: MemberAccessExprSyntax,
    brandTypes: Swift.Set<Lint.Brand>
) -> Swift.Bool {
    guard !brandTypes.isEmpty else { return false }
    if let baseName = structureRawValueAccessExtractTypeName(base: node.base) {
        return brandTypes.contains(Lint.Brand(baseName))
    }
    // Base is a variable / chain — package-scope fallback admits.
    return true
}

/// Reassembles a dotted type-name from a `MemberAccessExprSyntax`
/// chain when the leftmost token is an UPPERCASE-leading
/// `DeclReferenceExprSyntax` (Swift type-naming convention).
///
/// Examples of what extracts:
///   - `Ordinal` (base is a `DeclReferenceExprSyntax`) → `"Ordinal"`.
///   - `Affine.Discrete.Vector` (chain ending in
///     `DeclReferenceExprSyntax` whose leftmost token is `Affine`)
///     → `"Affine.Discrete.Vector"`.
///
/// Returns `nil` when:
///   - the leftmost identifier starts with a lowercase letter
///     (variable, function name) — `lhs.rawValue` returns `nil`,
///     `position.foo.rawValue` returns `nil`. These cases are
///     handled by the package-scope fallback in
///     ``structureRawValueAccessIsAdmitted``.
///   - the chain bottoms out in `self.`-prefix, a function call, a
///     tuple, or another non-identifier expression.
///
/// The uppercase-leading heuristic is the standard Swift convention
/// for types (per `[CODE-NAME-*]`). Edge cases (`_PrivateType`,
/// lowercase-leading types from third-party code) are not in scope —
/// the package-scope fallback catches them.
internal func structureRawValueAccessExtractTypeName(base: ExprSyntax?) -> Swift.String? {
    guard let base else { return nil }
    if let identifier = base.as(DeclReferenceExprSyntax.self) {
        let text = identifier.baseName.text
        guard structureRawValueAccessLooksLikeType(text) else { return nil }
        return text
    }
    if let memberAccess = base.as(MemberAccessExprSyntax.self) {
        guard let lower = structureRawValueAccessExtractTypeName(base: memberAccess.base) else {
            return nil
        }
        return lower + "." + memberAccess.declName.baseName.text
    }
    return nil
}

/// `true` when `text` begins with an uppercase letter — the standard
/// Swift convention for type identifiers. Empty strings return false.
internal func structureRawValueAccessLooksLikeType(_ text: Swift.String) -> Swift.Bool {
    guard let first = text.first else { return false }
    return first.isUppercase
}

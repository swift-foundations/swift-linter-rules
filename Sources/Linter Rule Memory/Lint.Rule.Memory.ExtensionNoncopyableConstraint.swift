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
        default: .warning,
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

/// Types where the `where ... ~Copyable` constraint is either
/// structurally inexpressible or vacuous:
///
/// - **Stdlib generic types language-bounded to Copyable**: stdlib type
///   declarations like `UnsafePointer<Pointee>` and `Array<Element>`
///   don't suppress Copyable on their parameter; `where Pointee: ~Copyable`
///   is rejected at type-check.
/// - **Non-generic institute types**: types with no generic parameters
///   at all (e.g., `Comparison`, the institute comparison-result enum)
///   have nothing to constrain. `consuming Self` is fine without any
///   where clause.
///
/// Curated allowlist — adding entries requires verifying that the type
/// either (a) genuinely rejects `~Copyable` on its parameter at type-check
/// or (b) has no generic parameter at all.
@usableFromInline
internal let memoryExtensionConstraintInexpressibleTypes: Swift.Set<Swift.String> = [
    // Stdlib generic types whose parameter is Copyable-bounded by the
    // stdlib declaration.
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
    "Array",
    "ArraySlice",
    "ContiguousArray",
    "CollectionOfOne",
    "EmptyCollection",
    "KeyValuePairs",
    "ReversedCollection",
    "Range",
    "ClosedRange",
    "PartialRangeFrom",
    "PartialRangeThrough",
    "PartialRangeUpTo",
    "Optional",
    "Dictionary",
    "Set",
    "String",
    "Substring",
    "Result",
    // Institute non-generic types — no generic parameter exists to
    // constrain. Extensions with `consuming`/`borrowing` are valid
    // without any where clause.
    "Comparison",
    "Equation",
    "Hash",
    "Ordinal",
    "Cardinal",
]

/// Curated allowlist for nested institute types whose leaf names are
/// shared by generic types elsewhere in the ecosystem (so the bare leaf
/// cannot safely admit). Matched against the full qualified path of the
/// extension target (e.g. `Affine.Discrete.Vector`). `Vector` deliberately
/// does NOT appear in `memoryExtensionConstraintInexpressibleTypes`
/// because generic `Vector` types exist in `swift-dimension-primitives`
/// (`Displacement.Vector<let N: Int, Space>`, `Coordinate.Vector`,
/// `Extent.Vector`) and `swift-index-primitives` (`Vector<Element, N>`),
/// and silently admitting all of them would mask legitimate
/// `~Copyable`-constraint omissions.
@usableFromInline
internal let memoryExtensionConstraintInexpressibleQualifiedTypes: Swift.Set<Swift.String> = [
    // Non-generic — the institute discrete-affine vector. Lives in
    // `swift-affine-primitives/Sources/Affine Primitives Core/`.
    "Affine.Discrete.Vector",
]

@usableFromInline
internal let memoryExtensionNoncopyableConstraintMessage: Swift.String =
    "[extension noncopyable constraint] [MEM-COPY-004]: extensions on `~Copyable`-"
    + "aware generic types MUST include explicit `where ... ~Copyable` constraints. "
    + "Without it, the extension is implicitly `where Element: Copyable` and the "
    + "surface silently shrinks. Add `where Element: ~Copyable` (or the matching "
    + "constraint name for your type's generic parameter)."

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

    private func extendedTypeLeafName(_ type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

    private func extendedTypeQualifiedName(_ type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            guard let base = extendedTypeQualifiedName(member.baseType) else {
                return nil
            }
            return "\(base).\(member.name.text)"
        }
        return nil
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
        // Filename-pattern exemption: `* where *.swift` files use the
        // [API-IMPL-007] where-clause-discriminator naming convention.
        // The author has enumerated quadrants via filenames; absence of
        // a constraint in any one quadrant file is deliberate within
        // the family. The rule's warning structurally inverts the
        // author's intent here.
        if source.filePath.contains(" where ") {
            return .visitChildren
        }
        // Constraint-inexpressible exemption: the extended type either
        // rejects `~Copyable` at type-check (stdlib Copyable-bounded
        // generic) or has no generic parameter at all (non-generic
        // institute type). The rule's premise doesn't apply.
        //
        // The qualified-name lookup runs first for nested institute types
        // whose bare leaf name collides with generic types elsewhere in
        // the ecosystem (see comment on
        // `memoryExtensionConstraintInexpressibleQualifiedTypes`). The
        // leaf lookup remains for stdlib types and unambiguous institute
        // leaves.
        if let qualified = extendedTypeQualifiedName(node.extendedType),
           memoryExtensionConstraintInexpressibleQualifiedTypes.contains(qualified) {
            return .visitChildren
        }
        if let leaf = extendedTypeLeafName(node.extendedType),
           memoryExtensionConstraintInexpressibleTypes.contains(leaf) {
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
        // Exempt per [RULE-EXEMPT-1] (positive-Copyable): author has
        // explicitly scoped to a Copyable surface; the rule's "silent
        // shrink" premise is inverted by the explicit conformance.
        // Helper lives in `Lint.Rule.Memory.Shared.swift`.
        guard !memoryWhereClauseHasPositiveCopyable(node.genericWhereClause) else {
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

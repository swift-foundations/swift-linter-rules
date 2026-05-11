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

@usableFromInline
internal let memoryExtensionNoncopyableConstraintMessage: Swift.String =
    "[extension noncopyable constraint] [MEM-COPY-004]: extensions on `~Copyable`-"
    + "aware generic types MUST include explicit `where ... ~Copyable` constraints. "
    + "Without it, the extension is implicitly `where Element: Copyable` and the "
    + "surface silently shrinks. Add `where Element: ~Copyable` (or the matching "
    + "constraint name for your type's generic parameter)."

private final class MemoryExtensionNoncopyableOwnershipFinder: SyntaxVisitor {
    var found = false
    /// Stack of method-local generic parameter names for the current
    /// function / initializer / subscript context. Parameters whose
    /// type is a single identifier matching a method-local generic
    /// carry method-scoped ownership, not type-scoped — the rule's
    /// "add `where Element: ~Copyable` to the extension" requirement
    /// does not apply when the consumed type is not a type-level
    /// generic of the extended type.
    private var genericsStack: [Swift.Set<Swift.String>] = []
    // Skip nested type declarations: ownership modifiers on a nested
    // type's members belong to that nested type, not to the enclosing
    // extension's namespace. Without this skip, an extension on a
    // non-generic namespace (e.g., `extension Ownership { struct
    // Indirect<Value: ~Copyable> { init(consuming Value) } }`) is
    // mis-flagged as needing `where ... ~Copyable` on `Ownership`,
    // which has no generic parameter to constrain.
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        // Look for `consuming` / `borrowing` modifier on the type.
        if let attributed = node.type.as(AttributedTypeSyntax.self) {
            for specifier in attributed.specifiers {
                if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
                    let kind = simple.specifier.tokenKind
                    if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
                        // Method-local-generic exemption: a `consuming T`
                        // parameter where T is a method-local generic
                        // (declared by the enclosing function / init /
                        // subscript, not by the extended type) is
                        // method-scoped ownership. The rule's premise —
                        // that the extension needs a `where Element:
                        // ~Copyable` constraint — does not apply: there
                        // is no type-level generic to constrain.
                        if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
                           identifier.genericArgumentClause == nil,
                           let top = genericsStack.last,
                           top.contains(identifier.name.text) {
                            return .skipChildren
                        }
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
        genericsStack.append(MemoryExtensionNoncopyableOwnershipFinder.genericNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_ node: FunctionDeclSyntax) {
        if !genericsStack.isEmpty { genericsStack.removeLast() }
    }
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(MemoryExtensionNoncopyableOwnershipFinder.genericNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_ node: InitializerDeclSyntax) {
        if !genericsStack.isEmpty { genericsStack.removeLast() }
    }
    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        genericsStack.append(MemoryExtensionNoncopyableOwnershipFinder.genericNames(node.genericParameterClause))
        return .visitChildren
    }
    override func visitPost(_ node: SubscriptDeclSyntax) {
        if !genericsStack.isEmpty { genericsStack.removeLast() }
    }
    private static func genericNames(_ clause: GenericParameterClauseSyntax?) -> Swift.Set<Swift.String> {
        guard let clause else { return [] }
        var names: Swift.Set<Swift.String> = []
        for parameter in clause.parameters {
            names.insert(parameter.name.text)
        }
        return names
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

    private func extendedTypeLeafName(_ type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
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
            if typeMentionsPositiveCopyable(conformance.rightType) {
                return true
            }
        }
        return false
    }

    /// Detects positive Copyable in either standalone (`Wrapped: Copyable`)
    /// or composition (`Element: Comparison.Protocol & Copyable`) form.
    /// Walks into CompositionTypeSyntax members so the constraint is
    /// recognized regardless of how the author wrote it.
    private func typeMentionsPositiveCopyable(_ type: TypeSyntax) -> Bool {
        if let identifier = type.as(IdentifierTypeSyntax.self),
           identifier.name.text == "Copyable" {
            return true
        }
        if let member = type.as(MemberTypeSyntax.self),
           member.name.text == "Copyable",
           let base = member.baseType.as(IdentifierTypeSyntax.self),
           base.name.text == "Swift" {
            return true
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            for element in composition.elements {
                if typeMentionsPositiveCopyable(element.type) {
                    return true
                }
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

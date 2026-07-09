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
    /// Flags an `@inlinable` decl whose body references a bare-`internal` identifier.
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

/// Suffix shared by every message: the compiler-illegal exemption and
/// the suppress-with-REASON escape hatch.
///
/// Amendment §A6 (2026-07-09): the rule no longer fires when the
/// prescribed `package` upgrade is compiler-illegal — i.e. when an
/// enclosing nominal type is itself below `package` access
/// (internal-default or `@usableFromInline`), or (for initializers)
/// when a parameter's type resolves in the same file to such a
/// declaration. Where a legitimate site still fires, the
/// suppress-with-REASON channel remains the escape hatch.
@usableFromInline
internal let structureInlinableInternalAccessExemptionSuffix: Swift.String =
    " (The rule does not fire when the enclosing type is itself below "
    + "`package` access, since there the `package` upgrade is "
    + "compiler-illegal.) For a legitimate remaining site, suppress with "
    + "`// swift-linter:disable:next inlinable internal access` plus a "
    + "`// REASON:` continuation."

/// Func/var message.
///
/// Amendment §A6 (2026-07-09): aligned with the initializer message —
/// prescribes the `package` upgrade and drops the former
/// `@usableFromInline`-preferred guidance, which Swift rejects on an
/// `@inlinable` decl as `has no effect` (a warning on the 6.3.2 target;
/// see `FINDING-pattern052-package-fix-2026-07-07.md`).
@usableFromInline
internal let structureInlinableInternalAccessMessage: Swift.String =
    "[inlinable internal access] [PATTERN-052]: `@inlinable` cross-module access "
    + "requires non-`internal` visibility. Upgrade to `package` (preferred for "
    + "impl-only surface) or `public` — do NOT add `@usableFromInline`, which "
    + "Swift rejects on an `@inlinable` decl as `has no effect`."
    + structureInlinableInternalAccessExemptionSuffix

/// Initializer-specific message: Swift rejects `@usableFromInline` on
/// `@inlinable init` as `has no effect`, so the func/var advice doesn't
/// apply.
///
/// The canonical fix for `@inlinable internal init` is `package
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
    + structureInlinableInternalAccessExemptionSuffix

/// Returns `true` when a type declaration's modifier list carries
/// `public` / `package` / `open`. A type without one of these is
/// internal-default (or `@usableFromInline`-internal) — a member inside
/// it cannot be widened to `package` because a member's access cannot
/// exceed its enclosing type's, so the rule's prescribed `package`
/// upgrade would be compiler-illegal (amendment §A6, variant A).
private func structureTypeIsPackageUpgradable(_ modifiers: DeclModifierListSyntax) -> Bool {
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

/// The simple (leaf) name of a type reference — the base identifier with
/// `Optional` / IUO wrappers stripped. Used to resolve an extension's
/// extended type and an initializer parameter's type against same-file
/// declarations. Returns `nil` for shapes we do not resolve (tuples,
/// functions, composed generics), which conservatively keep firing.
private func structureSimpleTypeName(_ type: TypeSyntax) -> Swift.String? {
    if let optional = type.as(OptionalTypeSyntax.self) {
        return structureSimpleTypeName(optional.wrappedType)
    }
    if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return structureSimpleTypeName(iuo.wrappedType)
    }
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
        return member.name.text
    }
    return nil
}

/// Collects the names of every type declaration in the file whose access
/// is below `package` (internal-default, `@usableFromInline`-internal,
/// `private`, `fileprivate`). A name lands in the set if *any* same-file
/// declaration of it is below `package`. This is the same-file symbol
/// table amendment §A6 consults for variant A (extension resolution) and
/// variant B (initializer parameter resolution).
private func structureCollectNonUpgradableTypeNames(
    _ node: Syntax,
    into names: inout Swift.Set<Swift.String>
) {
    func record(_ identifier: TokenSyntax, _ modifiers: DeclModifierListSyntax) {
        if !structureTypeIsPackageUpgradable(modifiers) {
            names.insert(identifier.text)
        }
    }
    if let decl = node.as(StructDeclSyntax.self) { record(decl.name, decl.modifiers) }
    else if let decl = node.as(ClassDeclSyntax.self) { record(decl.name, decl.modifiers) }
    else if let decl = node.as(EnumDeclSyntax.self) { record(decl.name, decl.modifiers) }
    else if let decl = node.as(ActorDeclSyntax.self) { record(decl.name, decl.modifiers) }
    else if let decl = node.as(ProtocolDeclSyntax.self) { record(decl.name, decl.modifiers) }
    else if let decl = node.as(TypeAliasDeclSyntax.self) { record(decl.name, decl.modifiers) }
    for child in node.children(viewMode: .sourceAccurate) {
        structureCollectNonUpgradableTypeNames(child, into: &names)
    }
}

internal final class StructureInlinableInternalAccessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    /// Same-file type declarations whose access is below `package`
    /// (amendment §A6). Populated lazily on first exemption query so the
    /// whole-file scan happens at most once per visitor.
    private var nonUpgradableTypeNames: Swift.Set<Swift.String>?

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func nonUpgradableNames(from node: some SyntaxProtocol) -> Swift.Set<Swift.String> {
        if let cached = nonUpgradableTypeNames { return cached }
        var names: Swift.Set<Swift.String> = []
        structureCollectNonUpgradableTypeNames(node.root, into: &names)
        nonUpgradableTypeNames = names
        return names
    }

    /// Variant A: walk the enclosing declaration chain. The member is
    /// exempt if any enclosing nominal type is below `package` access, or
    /// if an enclosing extension extends a same-file type that is below
    /// `package`. There the prescribed `package` upgrade is
    /// compiler-illegal, so the rule must not fire.
    private func enclosingChainForbidsPackageUpgrade(_ node: some SyntaxProtocol) -> Bool {
        var current = node.parent
        while let ancestor = current {
            if let decl = ancestor.as(StructDeclSyntax.self) {
                if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
            } else if let decl = ancestor.as(ClassDeclSyntax.self) {
                if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
            } else if let decl = ancestor.as(EnumDeclSyntax.self) {
                if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
            } else if let decl = ancestor.as(ActorDeclSyntax.self) {
                if !structureTypeIsPackageUpgradable(decl.modifiers) { return true }
            } else if let decl = ancestor.as(ExtensionDeclSyntax.self) {
                if let name = structureSimpleTypeName(decl.extendedType),
                    nonUpgradableNames(from: node).contains(name) {
                    return true
                }
            }
            current = ancestor.parent
        }
        return false
    }

    /// Variant B: an `@inlinable init` is exempt when any parameter's
    /// type resolves in the same file to a declaration below `package`
    /// access. Cross-file parameter types keep firing (they cannot be
    /// resolved here, so the conservative default is to fire).
    private func initializerParameterForbidsPackageUpgrade(_ node: InitializerDeclSyntax) -> Bool {
        let names = nonUpgradableNames(from: node)
        for parameter in node.signature.parameterClause.parameters {
            if let name = structureSimpleTypeName(parameter.type), names.contains(name) {
                return true
            }
        }
        return false
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
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "inlinable internal access",
                message: message
            )
        )
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasInlinableAttribute(node.attributes),
            !hasNonInternalAccess(node.modifiers),
            !hasUsableFromInline(node.attributes),
            !enclosingChainForbidsPackageUpgrade(node)
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
            !hasUsableFromInline(node.attributes),
            !enclosingChainForbidsPackageUpgrade(node)
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
            !hasUsableFromInline(node.attributes),
            !enclosingChainForbidsPackageUpgrade(node),
            !initializerParameterForbidsPackageUpgrade(node)
        {
            emit(
                at: node.initKeyword.positionAfterSkippingLeadingTrivia,
                message: structureInlinableInternalAccessInitializerMessage
            )
        }
        return .visitChildren
    }
}

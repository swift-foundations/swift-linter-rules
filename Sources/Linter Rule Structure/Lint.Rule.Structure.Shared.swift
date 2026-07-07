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

internal import SwiftSyntax

/// Returns true if `name` is the institute `Protocol` sentinel — a
/// member name reserved for the hoisted-protocol pattern per
/// [API-IMPL-009] / [PKG-NAME-001].
///
/// The sentinel can appear either
/// raw (`Protocol`) or backtick-escaped (`` `Protocol` ``); both forms
/// signal the same intent.
///
/// Citation: [RULE-EXEMPT-5] (Protocol-sentinel) in
/// `swift-institute/Skills/rule-exemptions/SKILL.md`.
///
/// Pack-local duplicate of `namingIsProtocolSentinelName` from
/// `Lint.Rule.Naming.Shared.swift` (institute pack) — cross-pack
/// visibility isn't available across the universal/institute tier
/// boundary, so the helper is duplicated; semantics match. Used by
/// `Lint.Rule.Structure.MinimalTypeBody` to skip the typealias-name
/// check on `Protocol`-named members.
internal func structureIsProtocolSentinelName(_ name: Swift.String) -> Swift.Bool {
    return name == "Protocol" || name == "`Protocol`"
}

/// The SwiftSyntax visitor-family base classes whose subclasses are
/// exempt from the structure-pack rules per [RULE-EXEMPT-7]
/// (syntax-visitor-subclass). The set covers the open base classes a
/// rule-pack visitor legitimately extends:
///
/// - `SyntaxVisitor` — most common; per-syntax-kind visit hooks.
/// - `SyntaxAnyVisitor` — any-syntax visit hook (catch-all dispatch).
/// - `SyntaxRewriter` — visit + rewrite (returns replacement syntax).
///
/// Leaf-name semantics: both bare (`SyntaxVisitor`) and qualified
/// (`SwiftSyntax.SyntaxVisitor`) inheritance forms resolve to the
/// same leaf string in the inheritance clause walk.
@usableFromInline
internal let structureSyntaxVisitorFamilyNames: Swift.Set<Swift.String> = [
    "SyntaxVisitor",
    "SyntaxAnyVisitor",
    "SyntaxRewriter",
]

/// Returns true if `clause` lists any member of the SwiftSyntax
/// visitor family (`SyntaxVisitor`, `SyntaxAnyVisitor`,
/// `SyntaxRewriter`) as an inherited type.
///
/// Used by
/// `Lint.Rule.Structure.MinimalTypeBody` to skip the type-body check
/// on rule-pack visitor subclasses, whose `override func visit(_:)`
/// hooks are protocol-shaped members dictated by the base class.
///
/// Citation: [RULE-EXEMPT-7] (syntax-visitor-subclass) in
/// `swift-institute/Skills/rule-exemptions/SKILL.md`.
///
/// Leaf-name lookup mirrors `namingInheritanceLeafNames` semantics —
/// both `IdentifierTypeSyntax` (bare `SyntaxVisitor`) and
/// `MemberTypeSyntax` (qualified `SwiftSyntax.SyntaxVisitor`) resolve
/// to the visitor's name.
internal func structureExtendsSyntaxVisitor(_ clause: InheritanceClauseSyntax?) -> Swift.Bool {
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
        let type = inherited.type
        let leaf: Swift.String?
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            leaf = identifier.name.text
        } else if let member = type.as(MemberTypeSyntax.self) {
            leaf = member.name.text
        } else {
            leaf = nil
        }
        if let leaf, structureSyntaxVisitorFamilyNames.contains(leaf) {
            return true
        }
    }
    return false
}

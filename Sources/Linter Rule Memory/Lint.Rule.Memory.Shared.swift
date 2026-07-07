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

/// Returns true if `clause` carries an explicit positive `Copyable`
/// conformance requirement on any generic parameter.
///
/// The author has
/// deliberately scoped the surface to copyable element types — rules
/// that fire on absence of `~Copyable`-related signals MUST treat this
/// as an authoritative opt-in, not silent shrinkage.
///
/// Citation: [RULE-EXEMPT-1] (positive-Copyable) in
/// `swift-institute/Skills/rule-exemptions/SKILL.md`.
///
/// Matches both:
///   - Standalone form: `where Base: Copyable`
///   - Composition form: `where Element: Comparison.Protocol & Copyable`
///
/// Tilde-prefixed `~Copyable` is excluded — only the *positive* form
/// trips this predicate. The `Swift.Copyable` qualified form is
/// recognized when the base identifier is the bare token `Swift`.
internal func memoryWhereClauseHasPositiveCopyable(_ clause: GenericWhereClauseSyntax?) -> Swift.Bool {
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        if memoryTypeMentionsPositiveCopyable(conformance.rightType) {
            return true
        }
    }
    return false
}

/// Walks a type syntax for any positive `Copyable` mention.
///
/// Composition
/// types (`Element: Comparison.Protocol & Copyable`) are descended into
/// so the constraint is recognized regardless of how the author wrote it.
///
/// Internal helper — call `memoryWhereClauseHasPositiveCopyable(_:)`
/// from rule visitors.
internal func memoryTypeMentionsPositiveCopyable(_ type: TypeSyntax) -> Swift.Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Copyable"
    {
        return true
    }
    if let member = type.as(MemberTypeSyntax.self),
        member.name.text == "Copyable",
        let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text == "Swift"
    {
        return true
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if memoryTypeMentionsPositiveCopyable(element.type) {
                return true
            }
        }
    }
    return false
}

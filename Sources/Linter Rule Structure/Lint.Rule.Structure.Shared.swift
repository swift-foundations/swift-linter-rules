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
/// [API-IMPL-009] / [PKG-NAME-001]. The sentinel can appear either
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

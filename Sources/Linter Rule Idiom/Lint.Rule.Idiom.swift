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

/// Implementation-idiom rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Idiom.X` and target implementation
/// idioms from the institute's `[IMPL-*]` requirements — iteration
/// shape ([IMPL-033]), bounded-index conventions for static-capacity
/// types ([IMPL-050]), Foundation-free string scanning ([IMPL-089]).
/// These are not error-mode rules (covered by `Lint.Rule.Throws`) nor
/// structure rules (covered by `Lint.Rule.Structure`) — they are
/// statement-level expression shapes that climb the abstraction ladder
/// from raw mechanism to intent.
extension Lint.Rule {
    public enum Idiom {}
}

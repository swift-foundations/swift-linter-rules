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

/// Naming-domain rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Naming.X` and target naming
/// conventions defined by the institute's [API-NAME-*] requirements:
/// no compound identifiers, options-not-flags vocabulary, no `*Tag`
/// suffix on phantom-type tags, no `impl` shorthand.
extension Lint.Rule {
    public enum Naming {}
}

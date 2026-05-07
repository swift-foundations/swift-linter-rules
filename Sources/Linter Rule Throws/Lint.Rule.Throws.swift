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

/// Throws-domain rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Throws.X` and target drift away
/// from the typed-throws discipline ([API-ERR-001]). The institute
/// convention prefers `throws(SpecificError)` over the bare `throws`
/// (untyped) and `throws(any Error)` (existential) forms — both erase
/// the error type, blocking exhaustive caller-side handling.
extension Lint.Rule {
    public enum Throws {}
}

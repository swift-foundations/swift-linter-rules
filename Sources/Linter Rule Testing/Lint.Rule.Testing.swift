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

/// Testing-shape rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Testing.X` and target the
/// institute's testing conventions: extension-based test suites
/// (`[SWIFT-TEST-002]`), per-suite serialisation for performance
/// (`[SWIFT-TEST-004]`), function-naming conventions (`[SWIFT-TEST-005]`),
/// mock-factory zero-collision invariants (`[TEST-028]`), and the
/// `.timed()` requirement on benchmark closures (`[BENCH-003]`).
extension Lint.Rule {
    public enum Testing {}
}

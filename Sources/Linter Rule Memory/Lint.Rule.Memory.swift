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

/// Memory-safety rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Memory.X` and target the
/// memory-safety / ownership / sendable invariants from the institute's
/// `[MEM-*]` requirements: bounded `nonisolated(unsafe)`, encapsulated
/// unsafe storage, categorised `@unchecked Sendable`, `~Copyable`-aware
/// error and extension constraints, and Sendable-redundancy detection
/// for `~Copyable` types.
extension Lint.Rule {
    public enum Memory {}
}

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

/// Platform-architecture rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Platform.X` and target drift away
/// from the platform-stack architecture per the `platform` skill
/// ([PLAT-ARCH-*]). Rules in this module typically close gaps that
/// SwiftLint regex-only enforcement cannot cover (e.g., AST-level
/// detection of stdlib-protocol shadowing, layered type references,
/// platform-specific naming).
extension Lint.Rule {
    public enum Platform {}
}

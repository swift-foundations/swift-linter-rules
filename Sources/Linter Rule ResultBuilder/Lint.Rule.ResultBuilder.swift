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

/// `@resultBuilder`-domain rule namespace.
///
/// Concrete rules nest as `Lint.Rule.ResultBuilder.X` and target
/// patterns inside `@resultBuilder`-annotated types. Builder bodies
/// have specific composition rules that diverge from regular Swift
/// expression contexts (e.g., `for` loops require an explicit
/// `buildArray` overload), so misuse benefits from dedicated
/// AST-shaped detection.
extension Lint.Rule {
    public enum ResultBuilder {}
}

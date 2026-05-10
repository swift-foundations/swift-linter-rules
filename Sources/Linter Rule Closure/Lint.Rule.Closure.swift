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

/// Closure-parameter-shape rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Closure.X` and target the
/// closure-parameter conventions from `[API-IMPL-012]` (closures trail
/// the signature) and `[API-IMPL-013]` (multi-closure lifecycle order
/// + labels). The ordering and labelling rules sit at the institute's
/// signature-shape boundary: callers read the type before they read
/// the body, and the signature should mirror the lifecycle of the
/// operation it parameterises.
extension Lint.Rule {
    public enum Closure {}
}

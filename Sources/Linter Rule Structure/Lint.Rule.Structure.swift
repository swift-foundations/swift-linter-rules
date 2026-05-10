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

/// File-structure rule namespace.
///
/// Concrete rules nest as `Lint.Rule.Structure.X` and target file-level
/// invariants from the institute's [API-IMPL-*] requirements: one type
/// declaration per file, file-naming convention mirroring the type's
/// nested path, extension-file `+` suffix shape.
extension Lint.Rule {
    public enum Structure {}
}

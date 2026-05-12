// swift-linter-tools-version: 0.1
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

// Foundation-up dogfeed continuation (Thread B). swift-linter-rules is
// the universal-rules pack — its own Bundle.universal defines the
// broadest applicable rule set for any package in the ecosystem.
// Self-lint via path: "." pulls the pack's own product so the bundle is
// the consumer-facing single source of truth.

import Linter
import Linter_Rules

Lint.run(dependencies: [
    .package(
        path: ".",
        products: ["Linter Rules"]
    ),
]) {
    Lint.Rule.Bundle.universal
}

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

import Testing
import SwiftSyntax
import SwiftParser
import Linter_Primitives
import Linter_Rules_Test_Support
@testable import Linter_Rule_Testing

extension Lint.Rule {
    @Suite
    struct `mock factory zero collision Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`mock factory zero collision Tests` {
    // The `mock factory zero collision` rule is scope-limited to file paths
    // containing `/Tests/` (mock-factory hygiene only matters in test code).
    // Test fixtures must therefore live under a `/Tests/` path or the rule
    // short-circuits before inspecting the AST. The leading slash is
    // required: the visitor checks `filePath.contains("/Tests/")`.
    static func findings(in source: String, file: String = "/Tests/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`mock factory zero collision`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`mock factory zero collision Tests`.Unit {
    @Test
    func `unsafeBitCast with bare tag is flagged`() {
        let source = """
        let value = unsafeBitCast(tag, to: UnownedJob.self)
        """
        let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unsafeBitCast with tag offset is permitted`() {
        let source = """
        let value = unsafeBitCast(tag &+ 1, to: UnownedJob.self)
        """
        let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unsafeBitCast with regular plus offset is permitted`() {
        let source = """
        let value = unsafeBitCast(tag + 1, to: UnownedJob.self)
        """
        let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated function call is not flagged`() {
        let source = """
        let value = makeValue(tag, to: UnownedJob.self)
        """
        let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `mock factory body with bare tag is flagged`() {
        let source = """
        extension UnownedJob {
            public static func mock(_ tag: Int = 0) -> UnownedJob {
                unsafeBitCast(tag, to: UnownedJob.self)
            }
        }
        """
        let findings = Lint.Rule.`mock factory zero collision Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

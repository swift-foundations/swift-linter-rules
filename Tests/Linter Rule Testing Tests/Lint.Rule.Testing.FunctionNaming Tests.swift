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
    struct `test function naming Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`test function naming Tests` {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`test function naming`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`test function naming Tests`.Unit {
    @Test
    func `Test func with backticked descriptive name is permitted`() {
        let source = """
        @Test
        func `init creates empty buffer`() {}
        """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test func with camelCase name is flagged`() {
        let source = """
        @Test
        func testInitCreatesEmptyBuffer() {}
        """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-Test func with camelCase name is not flagged`() {
        let source = """
        func helperFunction() {}
        """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test func with multi-word backticked name is permitted`() {
        let source = """
        @Test
        func `Memory.Address from UnsafeRawPointer preserves identity`() {}
        """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test with arguments and camelCase name is flagged`() {
        let source = """
        @Test(.tags(.fast))
        func runStuff() {}
        """
        let findings = Lint.Rule.`test function naming Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

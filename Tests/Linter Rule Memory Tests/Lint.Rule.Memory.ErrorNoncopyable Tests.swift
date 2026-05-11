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
@testable import Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `noncopyable error Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`noncopyable error Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`noncopyable error`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`noncopyable error Tests`.Unit {
    @Test
    func `Error and noncopyable struct is flagged`() {
        let source = """
        struct MyError: Error, ~Copyable {}
        """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Error without noncopyable is permitted`() {
        let source = """
        struct MyError: Error {}
        """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable without Error is permitted`() {
        let source = """
        struct Token: ~Copyable {}
        """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Error and noncopyable enum is flagged`() {
        let source = """
        enum MyError: Error, ~Copyable {
            case oops
        }
        """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift Error fully qualified is flagged`() {
        let source = """
        struct MyError: Swift.Error, ~Copyable {}
        """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with non-Error protocol is permitted`() {
        let source = """
        struct Token: Sendable, ~Copyable {}
        """
        let findings = Lint.Rule.`noncopyable error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

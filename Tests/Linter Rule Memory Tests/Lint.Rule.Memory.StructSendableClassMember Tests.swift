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
    struct `sendable struct with class member Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`sendable struct with class member Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`sendable struct with class member`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`sendable struct with class member Tests`.Unit {
    @Test
    func `struct unchecked Sendable with NSObject member is flagged`() {
        let source = """
        struct Wrapper: @unchecked Sendable {
            var inner: NSObject
        }
        """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "sendable struct with class member")
        }
    }

    @Test
    func `struct unchecked Sendable with Class-suffix member is flagged`() {
        let source = """
        struct Wrapper: @unchecked Sendable {
            var inner: PayloadClass
        }
        """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`sendable struct with class member Tests`.`Edge Case` {
    @Test
    func `plain Sendable struct is NOT flagged`() {
        let source = """
        struct Wrapper: Sendable {
            var inner: NSObject
        }
        """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct without Sendable is NOT flagged`() {
        let source = """
        struct Wrapper {
            var inner: NSObject
        }
        """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with value-typed member is NOT flagged`() {
        let source = """
        struct Wrapper: @unchecked Sendable {
            var count: Int
            var name: String
        }
        """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

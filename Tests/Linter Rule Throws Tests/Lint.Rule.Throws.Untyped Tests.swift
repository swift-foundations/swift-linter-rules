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
@testable import Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `untyped throws Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`untyped throws Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`untyped throws`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`untyped throws Tests`.Unit {
    @Test
    func `bare throws is flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "untyped throws")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `async throws is flagged`() {
        let source = "func f() async throws -> Int { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws inside protocol declaration is flagged`() {
        let source = """
        protocol P {
            func f() throws -> Int
        }
        """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple untyped throws are all flagged`() {
        let source = """
        func a() throws {}
        func b() throws -> Int { 0 }
        func c() async throws -> String { "" }
        """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `init throws is flagged`() {
        let source = """
        struct S {
            init() throws {}
        }
        """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure type with bare throws is flagged`() {
        let source = "let f: () throws -> Int = { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`untyped throws Tests`.`Edge Case` {
    @Test
    func `throws(SomeError) is NOT flagged`() {
        let source = """
        struct E: Swift.Error {}
        func f() throws(E) -> Int { 0 }
        """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `rethrows is NOT flagged`() {
        let source = "func map<T>(_ f: () throws -> T) rethrows -> T { try f() }"
        // The rule targets `throws` clauses only; the `rethrows` keyword is a different
        // syntax node. The argument-position `() throws -> T` is itself a bare-throws
        // closure type, however, which the rule DOES flag.
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws keyword in a string literal is NOT flagged`() {
        let source = "let s = \"func f() throws -> Int\""
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `extension method with throws is flagged`() {
        let source = """
        extension Int {
            func compute() throws -> Int { self }
        }
        """
        let findings = Lint.Rule.`untyped throws Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

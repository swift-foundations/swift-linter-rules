// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter project authors
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
@testable import Linter_Rule_RawValue

extension Lint.Rule {
    @Suite
    struct `chained rawvalue access Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Evasion {}
        @Suite struct Negative {}
    }
}

extension Lint.Rule.`chained rawvalue access Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`chained rawvalue access`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.Unit {
    @Test
    func `x.rawValue.foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = x.rawValue.foo")
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "chained rawvalue access")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `x.rawValue.foo() is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = x.rawValue.foo()")
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.Evasion {
    @Test
    func `Paren-wrapped (x.rawValue).foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = (x.rawValue).foo")
        #expect(findings.count == 1)
    }

    @Test
    func `Double-paren ((x.rawValue)).foo is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = ((x.rawValue)).foo")
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.Negative {
    @Test
    func `Bare x.rawValue (terminal access) is NOT flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = x.rawValue")
        #expect(findings.isEmpty)
    }

    @Test
    func `x.rawValue inside string literal is NOT flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: #"let s = "x.rawValue.foo""#)
        #expect(findings.isEmpty)
    }

    @Test
    func `x.foo.rawValue (rawValue at end of chain) is NOT flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = x.foo.rawValue")
        #expect(findings.isEmpty)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`chained rawvalue access Tests`.`Edge Case` {
    @Test
    func `x.rawValue in comment is NOT flagged`() {
        let source = """
        // x.rawValue.foo is the canonical anti-pattern
        let y = 42
        """
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Nested chain a.b.rawValue.c is flagged`() {
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: "let n = a.b.rawValue.c")
        #expect(findings.count == 1)
    }

    @Test
    func `Multiple chained accesses each flagged`() {
        let source = """
        let a = x.rawValue.foo
        let b = y.rawValue.bar
        """
        let findings = Lint.Rule.`chained rawvalue access Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let n = x.rawValue.foo"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`chained rawvalue access`.findings(parsed, .error)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

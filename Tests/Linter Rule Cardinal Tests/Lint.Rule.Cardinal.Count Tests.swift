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
@testable import Linter_Rule_Cardinal

extension Lint.Rule {
    @Suite
    struct `count minus one Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Evasion {}
        @Suite struct Negative {}
    }
}

extension Lint.Rule.`count minus one Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`count minus one`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`count minus one Tests`.Unit {
    @Test
    func `Member-access seq.count - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count - 1")
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "cardinal_count_minus_one")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Member-access on local arr.count - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = arr.count - 1")
        #expect(findings.count == 1)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let n = seq.count - 1"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`count minus one`.findings(parsed, .error)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

extension Lint.Rule.`count minus one Tests`.Evasion {
    @Test
    func `Paren-wrapped (seq.count - 1) is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = (seq.count - 1)")
        #expect(findings.count == 1)
    }

    @Test
    func `Cast-outside Double(seq.count) - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = Double(seq.count) - 1")
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip i + 1 less-than seq.count is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if i + 1 < seq.count { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip distance + 1 equals seq.count is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if distance + 1 == seq.count { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip seq.count greater-than i + 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if seq.count > i + 1 { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Algebraic-flip with 1 + i (commutative) is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if 1 + i < seq.count { }")
        #expect(findings.count == 1)
    }

    @Test
    func `Operand-reorder seq.count - i - 1 is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count - i - 1")
        #expect(findings.count >= 1)
    }

    @Test
    func `Comments-as-code is NOT flagged`() {
        let source = """
        // seq.count - 1 is the canonical anti-pattern (this is just prose)
        let x = 42
        """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`count minus one Tests`.Negative {
    @Test
    func `seq.count - 2 is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count - 2")
        #expect(findings.isEmpty)
    }

    @Test
    func `accountCount - 1 (non-count identifier) is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = accountCount - 1")
        #expect(findings.isEmpty)
    }

    @Test
    func `seq.count + 1 is NOT flagged outside comparison context`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = seq.count + 1")
        #expect(findings.isEmpty)
    }

    @Test
    func `i + 1 < limit is NOT flagged when count absent`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "if i + 1 < limit { }")
        #expect(findings.isEmpty)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `Bare count - 1 (non-member-access) is NOT flagged`() {
        // Pre-narrowing the rule walked tokens for any identifier `count`;
        // post-narrowing only `<expr>.count` member-access form fires.
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = count - 1")
        #expect(findings.isEmpty)
    }

    @Test
    func `Local binding let count = i; count - 1 is NOT flagged`() {
        let source = """
        let count = i
        let last = count - 1
        """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Loop variable for count in 0..<n; count - 1 is NOT flagged`() {
        let source = """
        for count in 0..<n {
            _ = count - 1
        }
        """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`count minus one Tests`.`Edge Case` {
    @Test
    func `seq.count - 1 inside string literal is NOT flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: #"let s = "seq.count - 1""#)
        #expect(findings.isEmpty)
    }

    @Test
    func `Nested expression let n = (a + b) + (seq.count - 1) is flagged`() {
        let findings = Lint.Rule.`count minus one Tests`.findings(in: "let n = (a + b) + (seq.count - 1)")
        #expect(findings.count == 1)
    }

    @Test
    func `Multi-line nested algebraic-flip is flagged`() {
        let source = """
        if i + 1
            < seq.count {
            doSomething()
        }
        """
        let findings = Lint.Rule.`count minus one Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

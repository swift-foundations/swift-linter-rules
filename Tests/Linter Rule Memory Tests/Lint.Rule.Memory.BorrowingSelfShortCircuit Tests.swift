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
@testable import Linter_Rule_Memory

extension Lint.Rule.Memory.BorrowingSelfShortCircuit {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Memory.BorrowingSelfShortCircuit.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.BorrowingSelfShortCircuit().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.Unit {
    @Test
    func `less-than operator with borrowing Self and OR is flagged`() {
        let source = """
        public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
            lhs.priority < rhs.priority || (lhs.priority == rhs.priority && lhs.sequence < rhs.sequence)
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        // Two operators in the body: `||` and `&&` — both flagged.
        #expect(findings.count == 2)
        if findings.count >= 1 {
            #expect(findings[0].identifier == "borrowing_self_short_circuit")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `equality operator with borrowing Self and AND is flagged`() {
        let source = """
        public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
            lhs.x == rhs.x && lhs.y == rhs.y
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.`Edge Case` {
    @Test
    func `tuple comparison alternative is NOT flagged`() {
        let source = """
        public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
            (lhs.a, lhs.b) < (rhs.a, rhs.b)
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `local let bindings alternative is NOT flagged`() {
        let source = """
        public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
            let la = lhs.a
            let lb = lhs.b
            let ra = rhs.a
            let rb = rhs.b
            if la < ra { return true }
            if la > ra { return false }
            return lb < rb
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-operator function with borrowing Self is NOT flagged`() {
        let source = """
        public func compare(_ rhs: borrowing Self) -> Bool {
            self.a < rhs.a || self.b < rhs.b
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `operator on non-borrowing parameters is NOT flagged`() {
        let source = """
        public static func + (lhs: Int, rhs: Int) -> Int {
            lhs > 0 && rhs > 0 ? lhs + rhs : 0
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `operator with borrowing Self but no short-circuit body is NOT flagged`() {
        let source = """
        public static func + (lhs: borrowing Self, rhs: borrowing Self) -> Self {
            Self(rawValue: lhs.rawValue + rhs.rawValue)
        }
        """
        let findings = Lint.Rule.Memory.BorrowingSelfShortCircuit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

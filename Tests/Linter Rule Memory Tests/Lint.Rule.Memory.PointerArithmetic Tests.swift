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
    struct `pointer advanced by Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`pointer advanced by Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`pointer advanced by`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`pointer advanced by Tests`.Unit {
    @Test
    func `advanced by call is flagged`() {
        let source = """
        func op(_ ptr: UnsafePointer<Int>, offset: Int) {
            let next = ptr.advanced(by: offset)
            use(next)
        }
        """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "pointer advanced by")
        }
    }

    @Test
    func `multiple advanced by calls each flagged`() {
        let source = """
        func op(_ ptr: UnsafePointer<Int>, a: Int, b: Int) {
            let p1 = ptr.advanced(by: a)
            let p2 = ptr.advanced(by: b)
            use(p1, p2)
        }
        """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`pointer advanced by Tests`.`Edge Case` {
    @Test
    func `unrelated method named advance is NOT flagged`() {
        let source = """
        func op(_ x: Foo) {
            let next = x.advance(by: 1)
            use(next)
        }
        """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `pointer at typed primitive call is NOT flagged`() {
        let source = """
        func op(_ storage: Storage, slot: Int) {
            let p = storage.pointer(at: slot)
            use(p)
        }
        """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `advanced without by label is NOT flagged`() {
        let source = """
        func op(_ x: Foo) {
            let next = x.advanced(2)
            use(next)
        }
        """
        let findings = Lint.Rule.`pointer advanced by Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

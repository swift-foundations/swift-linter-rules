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

import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `inlinable internal access Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`inlinable internal access Tests` {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`inlinable internal access`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`inlinable internal access Tests`.Unit {
    @Test
    func `inlinable internal func is flagged`() {
        let source = """
            @inlinable
            func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `inlinable public func is permitted`() {
        let source = """
            @inlinable
            public func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable package func is permitted`() {
        let source = """
            @inlinable
            package func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable usableFromInline func is permitted`() {
        let source = """
            @inlinable @usableFromInline
            func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable internal var is flagged`() {
        let source = """
            @inlinable
            var x: Int { 1 }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `inlinable public var is permitted`() {
        let source = """
            @inlinable
            public var x: Int { 1 }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable internal init is flagged`() {
        let source = """
            struct S {
                @inlinable
                init() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`inlinable internal access Tests`.`Edge Case` {
    @Test
    func `non-inlinable internal func is not flagged`() {
        let source = "func foo() {}"
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable open func is permitted`() {
        let source = """
            @inlinable
            open func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable init flagged message recommends package init not usableFromInline`() {
        let source = """
            struct S {
                @inlinable
                init() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            let message = findings[0].message
            #expect(message.contains("`package init`"))
            #expect(message.contains("has no effect"))
            #expect(!message.contains("pair the attribute with `@usableFromInline`"))
        }
    }

    @Test
    func `inlinable func flagged message recommends usableFromInline pairing`() {
        let source = """
            @inlinable
            func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            let message = findings[0].message
            #expect(message.contains("`@usableFromInline`"))
            #expect(!message.contains("`package init`"))
        }
    }

    @Test
    func `package init satisfies the rule`() {
        let source = """
            struct S {
                @inlinable
                package init() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

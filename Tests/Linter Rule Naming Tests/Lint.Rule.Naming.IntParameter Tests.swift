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
@testable import Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `int public parameter Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`int public parameter Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`int public parameter`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`int public parameter Tests`.Unit {
    @Test
    func `public func with Int parameter is flagged`() {
        let source = "public func read(count: Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "int_parameter_public")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `public func with Int return type is flagged`() {
        let source = "public func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with Int param and Int return has two findings`() {
        let source = "public func foo(n: Int) -> Int { n }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `public init with Int parameter is flagged`() {
        let source = """
        public struct Foo {
            public init(count: Int) {}
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `optional Int parameter is flagged`() {
        let source = "public func read(count: Int?) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift-qualified Int is flagged`() {
        let source = "public func tag(value: Swift.Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `open func with Int return is flagged`() {
        let source = """
        public class Base {
            open func size() -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple public functions independently flagged`() {
        let source = """
        public func a(x: Int) {}
        public func b() -> Int { 0 }
        public func c(s: String) -> String { s }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`int public parameter Tests`.`Edge Case` {
    @Test
    func `internal func with Int parameter is NOT flagged`() {
        let source = "func read(count: Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private func with Int return is NOT flagged`() {
        let source = "private func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package func with Int parameter is NOT flagged`() {
        let source = "package func read(count: Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal typed parameter is NOT flagged`() {
        let source = "public func read(count: Cardinal) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Index parameter is NOT flagged`() {
        let source = "public func at(index: Index<UInt8>) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `sized integer Int32 is NOT flagged`() {
        // Sized integers (Int8/16/32/64, UInt*, ...) are valid domain types
        // (e.g., Int32 for fd, UInt8 for byte). Rule scopes to bare `Int`.
        let source = "public func tag(fd: Int32) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `sized integer UInt8 is NOT flagged`() {
        let source = "public func encode(_ b: UInt8) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure with internal Int parameter is NOT flagged`() {
        // The Int is inside a closure type, not the outer signature.
        let source = "public func op(_ body: (Int) -> Void) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `tuple with Int member is NOT flagged`() {
        let source = "public func tag(values: (Int, String)) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested public function inside public type is flagged`() {
        let source = """
        public struct Buffer {
            public func read(count: Int) {}
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `String return is NOT flagged`() {
        let source = "public func describe() -> String { \"\" }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression Int return inside @resultBuilder is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Count {
            public static func buildExpression(_ expression: Bool) -> Int {
                expression ? 1 : 0
            }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock Int param inside @resultBuilder is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Count {
            public static func buildPartialBlock(first: Int) -> Int { first }
            public static func buildPartialBlock(accumulated: Int, next: Int) -> Int {
                accumulated + next
            }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression with Int return OUTSIDE @resultBuilder IS flagged`() {
        let source = """
        public enum NotABuilder {
            public static func buildExpression(_ expression: String) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-protocol Int-taking method inside @resultBuilder IS flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func helper(_ x: Int) -> Int { x }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

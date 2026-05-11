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
    struct `bool public parameter Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`bool public parameter Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`bool public parameter`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`bool public parameter Tests`.Unit {
    @Test
    func `public func with single Bool parameter is flagged`() {
        let source = "public func open(create: Bool) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "bool_parameter_public")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `public func with two Bool parameters has two findings`() {
        let source = "public func open(create: Bool, truncate: Bool) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `public init with Bool parameter is flagged`() {
        let source = """
        public struct Config {
            public init(verbose: Bool) {}
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `optional Bool parameter is flagged`() {
        let source = "public func read(strict: Bool?) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift-qualified Bool is flagged`() {
        let source = "public func tag(value: Swift.Bool) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `open func with Bool parameter is flagged`() {
        let source = """
        public class Base {
            open func customize(reset: Bool) {}
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple public functions are independently flagged`() {
        let source = """
        public func a(b: Bool) {}
        public func c(d: Bool) {}
        public func e(f: Int) {}
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`bool public parameter Tests`.`Edge Case` {
    @Test
    func `internal func with Bool parameter is NOT flagged`() {
        let source = "func open(create: Bool) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private func with Bool parameter is NOT flagged`() {
        let source = "private func open(create: Bool) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package func with Bool parameter is NOT flagged`() {
        let source = "package func open(create: Bool) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure-typed parameter with internal Bool is NOT flagged`() {
        let source = "public func update(body: (Bool) -> Void) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-Bool typed parameter is NOT flagged`() {
        let source = "public func tag(value: Int) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `BoolContainer (compound name) is NOT flagged here`() {
        // Compound name belongs to API-NAME-001's domain; this rule
        // checks only the literal `Bool` token.
        let source = "public func tag(value: BoolContainer) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public function returning Bool is NOT flagged`() {
        // The rule scopes to PARAMETERS, not return types.
        let source = "public func isReady() -> Bool { false }"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested public function inside public type is flagged`() {
        let source = """
        public struct Config {
            public func reset(force: Bool) {}
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `tuple-typed parameter with Bool member is NOT flagged`() {
        // Tuple-typed parameters are out of mechanical scope; the user
        // would already have to think hard to land on a tuple param.
        let source = "public func tag(values: (Bool, Int)) {}"
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression Bool param inside @resultBuilder is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum All {
            public static func buildExpression(_ expression: Bool) -> Bool { expression }
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock Bool params inside @resultBuilder is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum All {
            public static func buildPartialBlock(first: Bool) -> Bool { first }
            public static func buildPartialBlock(accumulated: Bool, next: Bool) -> Bool {
                accumulated && next
            }
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression with Bool param OUTSIDE @resultBuilder IS flagged`() {
        let source = """
        public enum NotABuilder {
            public static func buildExpression(_ expression: Bool) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-protocol Bool-taking method inside @resultBuilder IS flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func configure(strict: Bool) {}
        }
        """
        let findings = Lint.Rule.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

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
    struct `compound identifier Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`compound identifier Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`compound identifier`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`compound identifier Tests`.Unit {
    @Test
    func `func openWrite is flagged`() {
        let source = "func openWrite() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "compound identifier")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `func walkFiles is flagged`() {
        let source = "func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `var firstName is flagged`() {
        let source = "var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let lastError is flagged`() {
        let source = "let lastError: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multi-camel name parseManifestFile is flagged`() {
        let source = "func parseManifestFile() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending decls are all flagged`() {
        let source = """
        func openWrite() {}
        func walkFiles() {}
        var firstName: String = ""
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`compound identifier Tests`.`Edge Case` {
    @Test
    func `func open is NOT flagged`() {
        let source = "func open() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean isEmpty is NOT flagged`() {
        let source = "var isEmpty: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean hasValue is NOT flagged`() {
        let source = "var hasValue: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean shouldRetry is NOT flagged`() {
        let source = "var shouldRetry: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib idiom rawValue is NOT flagged`() {
        let source = "var rawValue: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `CustomStringConvertible description is NOT flagged`() {
        let source = """
        struct X: CustomStringConvertible {
            var description: String { "x" }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package-scoped compound is NOT flagged`() {
        let source = "package func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package-scoped var is NOT flagged`() {
        let source = "package var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `function parameter labels are NOT flagged`() {
        let source = "func read(atOffset: Int) {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        // The rule visits decl names, not parameter labels. The decl name `read`
        // is not compound. Parameter `atOffset` is exempt per scope choice.
        #expect(findings.isEmpty)
    }

    @Test
    func `single underscore name is NOT flagged`() {
        let source = "var _x: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression inside @resultBuilder enum is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func buildExpression(_ x: Int) -> [Int] { [x] }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock inside @resultBuilder enum is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func buildPartialBlock(first: Int) -> [Int] { [first] }
            public static func buildPartialBlock(accumulated: [Int], next: Int) -> [Int] {
                accumulated + [next]
            }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression OUTSIDE @resultBuilder IS flagged`() {
        let source = """
        public enum NotABuilder {
            public static func buildExpression(_ x: Int) -> [Int] { [x] }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-protocol compound method inside @resultBuilder IS flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func openWrite() {}
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

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
@testable import Linter_Rule_Untyped_Throws

extension Lint.Rule.UntypedThrows {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.UntypedThrows.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Lint.Finding] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.UntypedThrows().findings(in: parsed)
    }
}

extension Lint.Rule.UntypedThrows.Test.Unit {
    @Test
    func `bare throws is flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "untyped_throws")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `async throws is flagged`() {
        let source = "func f() async throws -> Int { 0 }"
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws inside protocol declaration is flagged`() {
        let source = """
        protocol P {
            func f() throws -> Int
        }
        """
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple untyped throws are all flagged`() {
        let source = """
        func a() throws {}
        func b() throws -> Int { 0 }
        func c() async throws -> String { "" }
        """
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `init throws is flagged`() {
        let source = """
        struct S {
            init() throws {}
        }
        """
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure type with bare throws is flagged`() {
        let source = "let f: () throws -> Int = { 0 }"
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.UntypedThrows.Test.`Edge Case` {
    @Test
    func `throws(SomeError) is NOT flagged`() {
        let source = """
        struct E: Swift.Error {}
        func f() throws(E) -> Int { 0 }
        """
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `rethrows is NOT flagged`() {
        let source = "func map<T>(_ f: () throws -> T) rethrows -> T { try f() }"
        // The rule targets `throws` clauses only; the `rethrows` keyword is a different
        // syntax node. The argument-position `() throws -> T` is itself a bare-throws
        // closure type, however, which the rule DOES flag.
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws keyword in a string literal is NOT flagged`() {
        let source = "let s = \"func f() throws -> Int\""
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `extension method with throws is flagged`() {
        let source = """
        extension Int {
            func compute() throws -> Int { self }
        }
        """
        let findings = Lint.Rule.UntypedThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

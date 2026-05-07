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
@testable import Linter_Rule_Existential_Throws

extension Lint.Rule.ExistentialThrows {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.ExistentialThrows.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Lint.Finding] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.ExistentialThrows().findings(in: parsed)
    }
}

extension Lint.Rule.ExistentialThrows.Test.Unit {
    @Test
    func `throws any Error is flagged`() {
        let source = "func f() throws(any Error) -> Int { 0 }"
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "existential_throws")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `throws any Swift dot Error is flagged`() {
        let source = "func f() throws(any Swift.Error) -> Int { 0 }"
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple existential throws are all flagged`() {
        let source = """
        func a() throws(any Error) {}
        func b() throws(any Swift.Error) {}
        """
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `async throws any Error is flagged`() {
        let source = "func f() async throws(any Error) -> Int { 0 }"
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `init throws any Error is flagged`() {
        let source = """
        struct S {
            init() throws(any Error) {}
        }
        """
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `closure type with throws any Error is flagged`() {
        let source = "let f: () throws(any Error) -> Int = { 0 }"
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.ExistentialThrows.Test.`Edge Case` {
    @Test
    func `throws(SpecificError) is NOT flagged`() {
        let source = """
        struct E: Swift.Error {}
        func f() throws(E) -> Int { 0 }
        """
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare throws is NOT flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws(any OtherProtocol) is NOT flagged`() {
        let source = """
        protocol P {}
        func f() throws(any P) -> Int { 0 }
        """
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `existential throws in a string literal is NOT flagged`() {
        let source = "let s = \"throws(any Error)\""
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.ExistentialThrows.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

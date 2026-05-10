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
@testable import Linter_Rule_Testing

extension Lint.Rule.Testing.FunctionNaming {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Testing.FunctionNaming.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Testing.FunctionNaming().findings(in: parsed)
    }
}

extension Lint.Rule.Testing.FunctionNaming.Test.Unit {
    @Test
    func `Test func with backticked descriptive name is permitted`() {
        let source = """
        @Test
        func `init creates empty buffer`() {}
        """
        let findings = Lint.Rule.Testing.FunctionNaming.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test func with camelCase name is flagged`() {
        let source = """
        @Test
        func testInitCreatesEmptyBuffer() {}
        """
        let findings = Lint.Rule.Testing.FunctionNaming.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-Test func with camelCase name is not flagged`() {
        let source = """
        func helperFunction() {}
        """
        let findings = Lint.Rule.Testing.FunctionNaming.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test func with multi-word backticked name is permitted`() {
        let source = """
        @Test
        func `Memory.Address from UnsafeRawPointer preserves identity`() {}
        """
        let findings = Lint.Rule.Testing.FunctionNaming.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test with arguments and camelCase name is flagged`() {
        let source = """
        @Test(.tags(.fast))
        func runStuff() {}
        """
        let findings = Lint.Rule.Testing.FunctionNaming.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

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

extension Lint.Rule.Testing.CompoundSuiteName {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Testing.CompoundSuiteName.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Testing.CompoundSuiteName().findings(in: parsed)
    }
}

extension Lint.Rule.Testing.CompoundSuiteName.Test.Unit {
    @Test
    func `Suite with compound name FooTests is flagged`() {
        let source = """
        @Suite struct MemoryBufferTests {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Suite named Test is permitted`() {
        let source = """
        @Suite struct Test {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite named Performance is permitted`() {
        let source = """
        @Suite struct Performance {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite named Unit is permitted`() {
        let source = """
        @Suite struct Unit {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-Suite compound struct is not flagged here`() {
        let source = """
        struct MemoryBufferTests {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite named Integration is permitted`() {
        let source = """
        @Suite struct Integration {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite with three-token compound name is flagged`() {
        let source = """
        @Suite struct MyAPIChecks {}
        """
        let findings = Lint.Rule.Testing.CompoundSuiteName.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

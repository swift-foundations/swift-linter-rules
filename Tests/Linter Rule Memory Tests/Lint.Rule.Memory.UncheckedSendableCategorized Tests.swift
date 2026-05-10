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

extension Lint.Rule.Memory.UncheckedSendableCategorized {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Memory.UncheckedSendableCategorized.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.UncheckedSendableCategorized().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.UncheckedSendableCategorized.Test.Unit {
    @Test
    func `unchecked Sendable without unsafe is flagged`() {
        let source = """
        final class Foo: @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UncheckedSendableCategorized.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unsafe unchecked Sendable is permitted`() {
        let source = """
        final class Foo: @unsafe @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UncheckedSendableCategorized.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain Sendable is not flagged`() {
        let source = """
        struct Foo: Sendable {}
        """
        let findings = Lint.Rule.Memory.UncheckedSendableCategorized.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with unchecked Sendable without unsafe is flagged`() {
        let source = """
        extension Bar: @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UncheckedSendableCategorized.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with unsafe unchecked Sendable is permitted`() {
        let source = """
        extension Bar: @unsafe @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UncheckedSendableCategorized.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `actor with unchecked Sendable without unsafe is flagged`() {
        let source = """
        actor Foo: @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UncheckedSendableCategorized.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

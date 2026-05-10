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

extension Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.Unit {
    @Test
    func `noncopyable struct with unchecked Sendable is flagged`() {
        let source = """
        struct Reader: ~Copyable, @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with plain Sendable is permitted`() {
        let source = """
        struct Reader: ~Copyable, Sendable {}
        """
        let findings = Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `copyable struct with unchecked Sendable is not flagged here`() {
        // Out of scope for this rule — covered by UncheckedSendableCategorized.
        let source = """
        final class Foo: @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct without Sendable is not flagged`() {
        let source = """
        struct Reader: ~Copyable {}
        """
        let findings = Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct with unsafe unchecked Sendable is still flagged (drop unchecked)`() {
        // The rule's signal is "noncopyable struct + unchecked Sendable"
        // — even with @unsafe, the @unchecked is unnecessary because the
        // compiler synthesizes Sendable for noncopyable structs.
        let source = """
        struct Arena: ~Copyable, @unsafe @unchecked Sendable {}
        """
        let findings = Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `regular copyable struct with Sendable is not flagged`() {
        let source = """
        struct Foo: Sendable {}
        """
        let findings = Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

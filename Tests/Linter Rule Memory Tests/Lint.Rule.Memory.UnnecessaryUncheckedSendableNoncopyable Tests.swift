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
@testable import Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `unchecked sendable noncopyable Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`unchecked sendable noncopyable Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unchecked sendable noncopyable`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`unchecked sendable noncopyable Tests`.Unit {
    @Test
    func `noncopyable struct with unchecked Sendable is flagged`() {
        let source = """
        struct Reader: ~Copyable, @unchecked Sendable {}
        """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with plain Sendable is permitted`() {
        let source = """
        struct Reader: ~Copyable, Sendable {}
        """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `copyable struct with unchecked Sendable is not flagged here`() {
        // Out of scope for this rule — covered by UncheckedSendableCategorized.
        let source = """
        final class Foo: @unchecked Sendable {}
        """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable struct without Sendable is not flagged`() {
        let source = """
        struct Reader: ~Copyable {}
        """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
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
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `regular copyable struct with Sendable is not flagged`() {
        let source = """
        struct Foo: Sendable {}
        """
        let findings = Lint.Rule.`unchecked sendable noncopyable Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

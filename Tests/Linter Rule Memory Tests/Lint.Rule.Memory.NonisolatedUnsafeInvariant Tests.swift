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
    struct `nonisolated unsafe without invariant Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`nonisolated unsafe without invariant Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`nonisolated unsafe without invariant`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`nonisolated unsafe without invariant Tests`.Unit {
    @Test
    func `nonisolated unsafe without comment is flagged`() {
        let source = """
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated unsafe with adjacent SAFETY comment is permitted`() {
        let source = """
        // SAFETY: Allocated once at module init; pointee never mutated.
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe with adjacent WHY comment is permitted`() {
        let source = """
        // WHY: Category D (SP-5) — UnsafeRawPointer blocks structural Sendable.
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe with multi-line SAFETY block is permitted`() {
        let source = """
        // SAFETY: Allocated once at module init; pointee never mutated post-init.
        // SAFETY: Used as sentinel for empty-buffer comparison only.
        @usableFromInline
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-adjacent SAFETY comment is flagged`() {
        let source = """
        // SAFETY: Allocated once at module init.

        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-SAFETY comment adjacent is flagged`() {
        let source = """
        // This is a sentinel value used by the empty buffer check.
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated without unsafe is not flagged`() {
        let source = """
        nonisolated let value: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `regular let is not flagged`() {
        let source = """
        let value: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe var without comment is flagged`() {
        let source = """
        nonisolated(unsafe) var counter: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated unsafe var with SAFETY comment is permitted`() {
        let source = """
        // SAFETY: Mutated only on the main thread under MainActor isolation.
        nonisolated(unsafe) var counter: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `doc comment alone does not satisfy adjacency`() {
        // Doc comments are for API surface; the institute uses `// SAFETY:` / `// WHY:`
        // for the encapsulation invariant. A doc comment alone fires.
        let source = """
        /// Module-level sentinel used by Memory.Buffer empty-state checks.
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without invariant Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

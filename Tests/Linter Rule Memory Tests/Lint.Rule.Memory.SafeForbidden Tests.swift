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
    struct `safe attribute forbidden Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`safe attribute forbidden Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`safe attribute forbidden`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`safe attribute forbidden Tests`.Unit {
    @Test
    func `safe attribute on struct is flagged`() {
        let source = """
        @safe
        public struct Padded {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on class is flagged`() {
        let source = """
        @safe
        final class _Storage {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on variable declaration is flagged`() {
        let source = """
        @safe @usableFromInline
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on enum is flagged`() {
        let source = """
        @safe @usableFromInline
        enum Work {
            case action
        }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on extension is flagged`() {
        let source = """
        @safe
        extension MyType {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe attribute on function is flagged`() {
        let source = """
        @safe
        func doWork() {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `no safe attribute is not flagged`() {
        let source = """
        public struct Padded {}
        final class _Storage {}
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unsafe attribute is not flagged`() {
        // `@unsafe` is governed separately ([MEM-SAFE-022]); this rule
        // only flags `@safe`.
        let source = """
        @unsafe
        public func raw() -> UnsafeMutablePointer<UInt8> { fatalError() }
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multiple safe attributes are each flagged`() {
        let source = """
        @safe
        public struct A {}

        @safe
        public struct B {}
        """
        let findings = Lint.Rule.`safe attribute forbidden Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

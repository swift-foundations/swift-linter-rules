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
    struct `nonisolated unsafe without safe Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`nonisolated unsafe without safe Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`nonisolated unsafe without safe`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`nonisolated unsafe without safe Tests`.Unit {
    @Test
    func `nonisolated unsafe without safe is flagged`() {
        let source = """
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without safe Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated unsafe with safe is permitted`() {
        let source = """
        @safe nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.`nonisolated unsafe without safe Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated without unsafe is not flagged`() {
        let source = """
        nonisolated let value: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without safe Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `regular let is not flagged`() {
        let source = """
        let value: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without safe Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe var is also flagged`() {
        let source = """
        nonisolated(unsafe) var counter: Int = 0
        """
        let findings = Lint.Rule.`nonisolated unsafe without safe Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe with usableFromInline pattern is permitted`() {
        let source = """
        @safe @usableFromInline
        nonisolated(unsafe) let _table: UnsafePointer<UInt8> = .init(bitPattern: 0)!
        """
        let findings = Lint.Rule.`nonisolated unsafe without safe Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

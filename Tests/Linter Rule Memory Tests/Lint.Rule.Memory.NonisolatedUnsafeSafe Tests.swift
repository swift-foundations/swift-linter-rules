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

extension Lint.Rule.Memory.NonisolatedUnsafeSafe {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Memory.NonisolatedUnsafeSafe.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.NonisolatedUnsafeSafe().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.Unit {
    @Test
    func `nonisolated unsafe without safe is flagged`() {
        let source = """
        nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nonisolated unsafe with safe is permitted`() {
        let source = """
        @safe nonisolated(unsafe) let _sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)
        """
        let findings = Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated without unsafe is not flagged`() {
        let source = """
        nonisolated let value: Int = 0
        """
        let findings = Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `regular let is not flagged`() {
        let source = """
        let value: Int = 0
        """
        let findings = Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nonisolated unsafe var is also flagged`() {
        let source = """
        nonisolated(unsafe) var counter: Int = 0
        """
        let findings = Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `safe with usableFromInline pattern is permitted`() {
        let source = """
        @safe @usableFromInline
        nonisolated(unsafe) let _table: UnsafePointer<UInt8> = .init(bitPattern: 0)!
        """
        let findings = Lint.Rule.Memory.NonisolatedUnsafeSafe.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

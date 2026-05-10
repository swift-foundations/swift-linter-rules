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

extension Lint.Rule.Memory.ErrorNoncopyable {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Memory.ErrorNoncopyable.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.ErrorNoncopyable().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.ErrorNoncopyable.Test.Unit {
    @Test
    func `Error and noncopyable struct is flagged`() {
        let source = """
        struct MyError: Error, ~Copyable {}
        """
        let findings = Lint.Rule.Memory.ErrorNoncopyable.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Error without noncopyable is permitted`() {
        let source = """
        struct MyError: Error {}
        """
        let findings = Lint.Rule.Memory.ErrorNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `noncopyable without Error is permitted`() {
        let source = """
        struct Token: ~Copyable {}
        """
        let findings = Lint.Rule.Memory.ErrorNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Error and noncopyable enum is flagged`() {
        let source = """
        enum MyError: Error, ~Copyable {
            case oops
        }
        """
        let findings = Lint.Rule.Memory.ErrorNoncopyable.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift Error fully qualified is flagged`() {
        let source = """
        struct MyError: Swift.Error, ~Copyable {}
        """
        let findings = Lint.Rule.Memory.ErrorNoncopyable.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable struct with non-Error protocol is permitted`() {
        let source = """
        struct Token: Sendable, ~Copyable {}
        """
        let findings = Lint.Rule.Memory.ErrorNoncopyable.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

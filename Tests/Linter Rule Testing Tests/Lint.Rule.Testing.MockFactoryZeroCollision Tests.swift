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

extension Lint.Rule.Testing.MockFactoryZeroCollision {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Testing.MockFactoryZeroCollision.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Testing.MockFactoryZeroCollision().findings(in: parsed)
    }
}

extension Lint.Rule.Testing.MockFactoryZeroCollision.Test.Unit {
    @Test
    func `unsafeBitCast with bare tag is flagged`() {
        let source = """
        let value = unsafeBitCast(tag, to: UnownedJob.self)
        """
        let findings = Lint.Rule.Testing.MockFactoryZeroCollision.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unsafeBitCast with tag offset is permitted`() {
        let source = """
        let value = unsafeBitCast(tag &+ 1, to: UnownedJob.self)
        """
        let findings = Lint.Rule.Testing.MockFactoryZeroCollision.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unsafeBitCast with regular plus offset is permitted`() {
        let source = """
        let value = unsafeBitCast(tag + 1, to: UnownedJob.self)
        """
        let findings = Lint.Rule.Testing.MockFactoryZeroCollision.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated function call is not flagged`() {
        let source = """
        let value = makeValue(tag, to: UnownedJob.self)
        """
        let findings = Lint.Rule.Testing.MockFactoryZeroCollision.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `mock factory body with bare tag is flagged`() {
        let source = """
        extension UnownedJob {
            public static func mock(_ tag: Int = 0) -> UnownedJob {
                unsafeBitCast(tag, to: UnownedJob.self)
            }
        }
        """
        let findings = Lint.Rule.Testing.MockFactoryZeroCollision.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

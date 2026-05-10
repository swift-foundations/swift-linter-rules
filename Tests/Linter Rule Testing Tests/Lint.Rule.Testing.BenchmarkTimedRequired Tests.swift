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

extension Lint.Rule.Testing.BenchmarkTimedRequired {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Testing.BenchmarkTimedRequired.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Testing.BenchmarkTimedRequired().findings(in: parsed)
    }
}

extension Lint.Rule.Testing.BenchmarkTimedRequired.Test.Unit {
    @Test
    func `Test inside Performance suite without timed is flagged`() {
        let source = """
        @Suite(.serialized) struct Performance {
            @Test
            func `runs fast`() {}
        }
        """
        let findings = Lint.Rule.Testing.BenchmarkTimedRequired.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test inside Performance suite with timed is permitted`() {
        let source = """
        @Suite(.serialized) struct Performance {
            @Test(.timed())
            func `runs fast`() {}
        }
        """
        let findings = Lint.Rule.Testing.BenchmarkTimedRequired.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test outside Performance suite is not flagged`() {
        let source = """
        @Suite struct Unit {
            @Test
            func `something`() {}
        }
        """
        let findings = Lint.Rule.Testing.BenchmarkTimedRequired.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test inside Performance extension without timed is flagged`() {
        let source = """
        extension Foo.Test.Performance {
            @Test
            func `runs fast`() {}
        }
        """
        let findings = Lint.Rule.Testing.BenchmarkTimedRequired.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test with timed threshold is permitted`() {
        let source = """
        @Suite(.serialized) struct Performance {
            @Test(.timed(threshold: .milliseconds(50)))
            func `meets budget`() {}
        }
        """
        let findings = Lint.Rule.Testing.BenchmarkTimedRequired.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

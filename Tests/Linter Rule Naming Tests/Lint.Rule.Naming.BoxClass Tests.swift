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
@testable import Linter_Rule_Naming

extension Lint.Rule.Naming.BoxClass {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Naming.BoxClass.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Naming.BoxClass().findings(in: parsed)
    }
}

extension Lint.Rule.Naming.BoxClass.Test.Unit {
    @Test
    func `_Box class is flagged`() {
        let source = """
        final class _Box<T> {
            var value: T
            init(_ value: T) { self.value = value }
        }
        """
        let findings = Lint.Rule.Naming.BoxClass.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "ad_hoc_box_class")
        }
    }

    @Test
    func `Storage class is flagged`() {
        let source = """
        final class Storage {
            var buffer: [Int] = []
        }
        """
        let findings = Lint.Rule.Naming.BoxClass.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Naming.BoxClass.Test.`Edge Case` {
    @Test
    func `class with inheritance is NOT flagged`() {
        let source = """
        final class _Storage: ManagedBuffer<Int, Element> { }
        """
        let findings = Lint.Rule.Naming.BoxClass.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated class name is NOT flagged`() {
        let source = """
        final class Inventory {
            var items: [Int] = []
        }
        """
        let findings = Lint.Rule.Naming.BoxClass.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

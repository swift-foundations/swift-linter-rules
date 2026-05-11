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

extension Lint.Rule.Naming.NamespaceAdoption {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Naming.NamespaceAdoption.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Naming.NamespaceAdoption().findings(in: parsed)
    }
}

extension Lint.Rule.Naming.NamespaceAdoption.Test.Unit {
    @Test
    func `same-leaf typealias is flagged for review`() {
        let source = """
        public typealias Event = Kernel.Event
        """
        let findings = Lint.Rule.Naming.NamespaceAdoption.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "namespace_adoption_typealias")
        }
    }

    @Test
    func `deeper same-leaf typealias is flagged`() {
        let source = """
        public typealias Channel = Kernel.IO.Channel
        """
        let findings = Lint.Rule.Naming.NamespaceAdoption.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Naming.NamespaceAdoption.Test.`Edge Case` {
    @Test
    func `different-leaf typealias is NOT flagged`() {
        let source = """
        public typealias SourceLocation = Text.Location
        """
        let findings = Lint.Rule.Naming.NamespaceAdoption.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-member-type RHS is NOT flagged`() {
        let source = """
        public typealias Foo = Int
        """
        let findings = Lint.Rule.Naming.NamespaceAdoption.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

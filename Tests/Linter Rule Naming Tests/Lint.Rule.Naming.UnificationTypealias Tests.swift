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

extension Lint.Rule.Naming.UnificationTypealias {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Naming.UnificationTypealias.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Naming.UnificationTypealias().findings(in: parsed)
    }
}

extension Lint.Rule.Naming.UnificationTypealias.Test.Unit {
    @Test
    func `rename-bridge typealias is flagged`() {
        let source = """
        public typealias SourceLocation = Text.Location
        """
        let findings = Lint.Rule.Naming.UnificationTypealias.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "unification_bridge_typealias")
        }
    }
}

extension Lint.Rule.Naming.UnificationTypealias.Test.`Edge Case` {
    @Test
    func `same-leaf typealias is NOT flagged`() {
        // Handled by [API-NAME-004a] NamespaceAdoption instead.
        let source = """
        public typealias Event = Kernel.Event
        """
        let findings = Lint.Rule.Naming.UnificationTypealias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `generic instantiation typealias is NOT flagged`() {
        let source = """
        public typealias IntArray = Array<Int>
        """
        let findings = Lint.Rule.Naming.UnificationTypealias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-member-type RHS is NOT flagged`() {
        let source = """
        public typealias Counter = Int
        """
        let findings = Lint.Rule.Naming.UnificationTypealias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

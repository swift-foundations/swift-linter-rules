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
@testable import Linter_Rule_Structure

extension Lint.Rule.Structure.UsableFromInlineInternalImport {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.UsableFromInlineInternalImport.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.UsableFromInlineInternalImport().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.UsableFromInlineInternalImport.Test.Unit {
    @Test
    func `usableFromInline plus internal import is flagged`() {
        let source = """
        internal import OtherModule

        @usableFromInline
        func helper() -> Int { 0 }
        """
        let findings = Lint.Rule.Structure.UsableFromInlineInternalImport.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "usable_from_inline_internal_import")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `multiple internal imports each flagged when usableFromInline present`() {
        let source = """
        internal import ModuleA
        internal import ModuleB

        @usableFromInline
        let x: Int = 0
        """
        let findings = Lint.Rule.Structure.UsableFromInlineInternalImport.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Structure.UsableFromInlineInternalImport.Test.`Edge Case` {
    @Test
    func `usableFromInline alone is NOT flagged`() {
        let source = """
        @usableFromInline
        func helper() -> Int { 0 }
        """
        let findings = Lint.Rule.Structure.UsableFromInlineInternalImport.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal import alone is NOT flagged`() {
        let source = """
        internal import OtherModule

        func helper() -> Int { 0 }
        """
        let findings = Lint.Rule.Structure.UsableFromInlineInternalImport.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public import plus usableFromInline is NOT flagged`() {
        let source = """
        public import OtherModule

        @usableFromInline
        func helper() -> Int { 0 }
        """
        let findings = Lint.Rule.Structure.UsableFromInlineInternalImport.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

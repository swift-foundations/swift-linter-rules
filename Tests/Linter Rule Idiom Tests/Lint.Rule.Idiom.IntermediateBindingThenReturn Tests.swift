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
@testable import Linter_Rule_Idiom

extension Lint.Rule.Idiom.IntermediateBindingThenReturn {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Idiom.IntermediateBindingThenReturn.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Idiom.IntermediateBindingThenReturn().findings(in: parsed)
    }
}

extension Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.Unit {
    @Test
    func `let then return same identifier is flagged`() {
        let source = """
        func op() -> Int {
            let result = compute()
            return result
        }
        """
        let findings = Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "intermediate_binding_then_return")
        }
    }
}

extension Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.`Edge Case` {
    @Test
    func `var binding is NOT flagged`() {
        let source = """
        func op() -> Int {
            var result = compute()
            result.mutate()
            return result
        }
        """
        let findings = Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `explicit type annotation is NOT flagged`() {
        let source = """
        func op() -> Foo {
            let result: Foo = compute()
            return result
        }
        """
        let findings = Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multi-use binding is NOT flagged`() {
        let source = """
        func op() -> Int {
            let result = compute()
            use(result)
            return result
        }
        """
        let findings = Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `return of different expression is NOT flagged`() {
        let source = """
        func op() -> Int {
            let local = compute()
            return other(local)
        }
        """
        let findings = Lint.Rule.Idiom.IntermediateBindingThenReturn.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

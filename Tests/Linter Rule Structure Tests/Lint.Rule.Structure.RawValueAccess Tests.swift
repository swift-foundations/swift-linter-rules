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

extension Lint.Rule.Structure.RawValueAccess {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.RawValueAccess.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.RawValueAccess().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.RawValueAccess.Test.Unit {
    @Test
    func `rawValue access inside function body is flagged`() {
        let source = """
        func op(tag: MyTag) {
            let raw = tag.rawValue
            use(raw)
        }
        """
        let findings = Lint.Rule.Structure.RawValueAccess.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "raw_value_access")
        }
    }

    @Test
    func `position access inside function body is flagged`() {
        let source = """
        func op(index: MyIndex) {
            let p = index.position
            use(p)
        }
        """
        let findings = Lint.Rule.Structure.RawValueAccess.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Structure.RawValueAccess.Test.`Edge Case` {
    @Test
    func `rawValue at top-level type scope is NOT flagged`() {
        let source = """
        struct Foo {
            static let max = MyTag.maxRawValue
        }
        """
        let findings = Lint.Rule.Structure.RawValueAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated member access is NOT flagged`() {
        let source = """
        func op(tag: MyTag) {
            let n = tag.name
            use(n)
        }
        """
        let findings = Lint.Rule.Structure.RawValueAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

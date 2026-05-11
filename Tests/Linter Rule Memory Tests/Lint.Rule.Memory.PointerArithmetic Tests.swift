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

extension Lint.Rule.Memory.PointerArithmetic {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Memory.PointerArithmetic.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.PointerArithmetic().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.PointerArithmetic.Test.Unit {
    @Test
    func `advanced by call is flagged`() {
        let source = """
        func op(_ ptr: UnsafePointer<Int>, offset: Int) {
            let next = ptr.advanced(by: offset)
            use(next)
        }
        """
        let findings = Lint.Rule.Memory.PointerArithmetic.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "pointer_advanced_by")
        }
    }

    @Test
    func `multiple advanced by calls each flagged`() {
        let source = """
        func op(_ ptr: UnsafePointer<Int>, a: Int, b: Int) {
            let p1 = ptr.advanced(by: a)
            let p2 = ptr.advanced(by: b)
            use(p1, p2)
        }
        """
        let findings = Lint.Rule.Memory.PointerArithmetic.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Memory.PointerArithmetic.Test.`Edge Case` {
    @Test
    func `unrelated method named advance is NOT flagged`() {
        let source = """
        func op(_ x: Foo) {
            let next = x.advance(by: 1)
            use(next)
        }
        """
        let findings = Lint.Rule.Memory.PointerArithmetic.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `pointer at typed primitive call is NOT flagged`() {
        let source = """
        func op(_ storage: Storage, slot: Int) {
            let p = storage.pointer(at: slot)
            use(p)
        }
        """
        let findings = Lint.Rule.Memory.PointerArithmetic.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `advanced without by label is NOT flagged`() {
        let source = """
        func op(_ x: Foo) {
            let next = x.advanced(2)
            use(next)
        }
        """
        let findings = Lint.Rule.Memory.PointerArithmetic.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

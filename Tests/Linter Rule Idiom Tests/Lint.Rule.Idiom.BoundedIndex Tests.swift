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

extension Lint.Rule.Idiom.BoundedIndex {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Idiom.BoundedIndex.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Idiom.BoundedIndex().findings(in: parsed)
    }
}

extension Lint.Rule.Idiom.BoundedIndex.Test.Unit {
    @Test
    func `Int subscript on value-generic struct is flagged`() {
        let source = """
        struct Buffer<let N: Int> {
            subscript(index: Int) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "bounded_index_static_capacity")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Swift dot Int subscript on value-generic is flagged`() {
        let source = """
        struct Buffer<let N: Int> {
            subscript(i: Swift.Int) -> Element { fatalError() }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `value-generic with mixed Element + N parameter is flagged`() {
        let source = """
        struct FixedArray<Element, let Count: Int> {
            subscript(i: Int) -> Element { fatalError() }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Int subscript on value-generic actor is flagged`() {
        let source = """
        actor Pool<let N: Int> {
            subscript(i: Int) -> Job { fatalError() }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Idiom.BoundedIndex.Test.`Edge Case` {
    @Test
    func `Bounded subscript on value-generic is NOT flagged`() {
        let source = """
        struct Buffer<let N: Int> {
            subscript(i: Index<Element>.Bounded<N>) -> Element { fatalError() }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Int subscript on non-value-generic struct is NOT flagged`() {
        let source = """
        struct DynamicArray<Element> {
            subscript(i: Int) -> Element { fatalError() }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Int subscript on non-generic struct is NOT flagged`() {
        let source = """
        struct Pile {
            subscript(i: Int) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Int subscript in extension out of per-file scope is NOT flagged`() {
        // Extension's bound visibility is opaque per-file (no `<let N>`
        // in the extension syntax). Rule conservatively skips.
        let source = """
        extension Buffer {
            subscript(i: Int) -> Element { fatalError() }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multiple subscripts mixed types each evaluated`() {
        let source = """
        struct Buffer<let N: Int> {
            subscript(raw: Int) -> Element { fatalError() }
            subscript(bounded: Index<Element>.Bounded<N>) -> Element { fatalError() }
            subscript(other: Int) -> Bool { false }
        }
        """
        let findings = Lint.Rule.Idiom.BoundedIndex.Test.findings(in: source)
        // Two raw-Int subscripts flagged; the bounded one not.
        #expect(findings.count == 2)
    }
}

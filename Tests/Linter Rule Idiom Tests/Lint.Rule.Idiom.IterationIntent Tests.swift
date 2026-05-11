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

extension Lint.Rule.Idiom.IterationIntent {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Idiom.IterationIntent.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Idiom.IterationIntent().findings(in: parsed)
    }
}

extension Lint.Rule.Idiom.IterationIntent.Test.Unit {
    @Test
    func `counter loop with 0 to n is flagged`() {
        let source = """
        func op(_ items: [Int]) {
            for i in 0..<items.count {
                handle(items[i])
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "iteration_intent_counter_loop")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `counter loop with non-zero start is flagged`() {
        let source = """
        func op(_ n: Int) {
            for index in 1..<n {
                process(index)
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `counter loop with closed range is flagged`() {
        let source = """
        func op(_ n: Int) {
            for i in 0...n {
                use(i)
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple counter loops each flagged`() {
        let source = """
        func op() {
            for i in 0..<10 { use(i) }
            for j in 0..<20 { use(j) }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Idiom.IterationIntent.Test.`Edge Case` {
    @Test
    func `direct iteration over collection is NOT flagged`() {
        let source = """
        func op(_ items: [Int]) {
            for element in items {
                handle(element)
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `enumerated iteration is NOT flagged`() {
        let source = """
        func op(_ items: [Int]) {
            for (offset, element) in items.enumerated() {
                handle(offset, element)
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stride iteration is NOT flagged`() {
        let source = """
        func op(_ total: Int) {
            for batch in stride(from: 0, to: total, by: 8) {
                process(batch)
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `forEach call is NOT flagged`() {
        let source = """
        func op(_ items: [Int]) {
            items.forEach { handle($0) }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `tuple pattern with range is NOT flagged - destructured form`() {
        // Tuple pattern doesn't fit the counter shape.
        let source = """
        func op() {
            for (a, b) in zip(0..<3, ["a", "b", "c"]) {
                handle(a, b)
            }
        }
        """
        let findings = Lint.Rule.Idiom.IterationIntent.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

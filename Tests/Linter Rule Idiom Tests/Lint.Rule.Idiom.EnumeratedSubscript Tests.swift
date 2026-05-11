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
import Linter_Rules_Test_Support
@testable import Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `enumerated with subscript Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`enumerated with subscript Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`enumerated with subscript`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`enumerated with subscript Tests`.Unit {
    @Test
    func `enumerated subscript pattern is flagged`() {
        let source = """
        func op(components: Path.Components) {
            for (i, _) in components.enumerated() {
                use(components[i])
            }
        }
        """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "enumerated_subscript_collection")
        }
    }
}

extension Lint.Rule.`enumerated with subscript Tests`.`Edge Case` {
    @Test
    func `enumerated without subscript-by-i is NOT flagged`() {
        let source = """
        func op(items: [Int]) {
            for (i, e) in items.enumerated() {
                use(i, e)
            }
        }
        """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `subscript by different identifier is NOT flagged`() {
        let source = """
        func op(items: [Int], j: Int) {
            for (i, _) in items.enumerated() {
                use(items[j])
            }
        }
        """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `forEach without enumerated is NOT flagged`() {
        let source = """
        func op(items: [Int]) {
            items.forEach { use($0) }
        }
        """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

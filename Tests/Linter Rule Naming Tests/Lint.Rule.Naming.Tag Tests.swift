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
@testable import Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `tag suffix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`tag suffix Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`tag suffix`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`tag suffix Tests`.Unit {
    @Test
    func `empty struct ending in Tag is flagged`() {
        let source = "struct CardinalTag {}"
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "tag suffix")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `empty enum ending in Tag is flagged`() {
        let source = "enum MillimeterTag {}"
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multi-word phantom XYZTag is flagged`() {
        let source = "struct ConsumerATag {}"
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple phantom tags are all flagged`() {
        let source = """
        struct ATag {}
        struct BTag {}
        enum CTag {}
        """
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `struct with only computed property ending in Tag is flagged`() {
        // Computed properties don't disqualify (still phantom-type-like — no storage).
        let source = """
        struct CardinalTag {
            static var description: String { "Cardinal" }
        }
        """
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested phantom tag inside type is flagged`() {
        let source = """
        enum Outer {
            struct InnerTag {}
        }
        """
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`tag suffix Tests`.`Edge Case` {
    @Test
    func `struct ending in Tag with stored property is NOT flagged`() {
        let source = """
        struct XMLTag {
            let name: String
            let attributes: [String: String]
        }
        """
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `enum ending in Tag with cases is NOT flagged`() {
        let source = """
        enum HTMLTag {
            case div
            case span
            case p
        }
        """
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct named Tag (no prefix) is NOT flagged`() {
        let source = "struct Tag {}"
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct not ending in Tag is NOT flagged`() {
        let source = """
        struct Cardinal {}
        struct Millimeter {}
        """
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `class ending in Tag is NOT flagged`() {
        // The rule visits StructDeclSyntax / EnumDeclSyntax; classes are not
        // phantom-type carriers.
        let source = "class CardinalTag {}"
        let findings = Lint.Rule.`tag suffix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

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
@testable import Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `type transform placement Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`type transform placement Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`type transform placement`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`type transform placement Tests`.Unit {
    @Test
    func `toFoo returning Foo is flagged`() {
        let source = """
        extension Source {
            public func toFoo() -> Foo { fatalError() }
        }
        """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "type_transform_placement")
        }
    }

    @Test
    func `asBar returning Bar is flagged`() {
        let source = """
        extension Source {
            public func asBar() -> Bar { fatalError() }
        }
        """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`type transform placement Tests`.`Edge Case` {
    @Test
    func `static method is NOT flagged`() {
        let source = """
        extension Foo {
            public static func from(_ source: Source) -> Foo { fatalError() }
        }
        """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `toString convention method is NOT flagged when return is different`() {
        let source = """
        extension Foo {
            public func toRepresentation() -> Bar { fatalError() }
        }
        """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `method without to or as prefix is NOT flagged`() {
        let source = """
        extension Foo {
            public func describe() -> Bar { fatalError() }
        }
        """
        let findings = Lint.Rule.`type transform placement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

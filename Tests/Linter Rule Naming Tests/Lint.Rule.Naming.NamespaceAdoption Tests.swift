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
    struct `namespace adoption typealias Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`namespace adoption typealias Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`namespace adoption typealias`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`namespace adoption typealias Tests`.Unit {
    @Test
    func `same-leaf typealias is flagged for review`() {
        let source = """
        public typealias Event = Kernel.Event
        """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "namespace_adoption_typealias")
        }
    }

    @Test
    func `deeper same-leaf typealias is flagged`() {
        let source = """
        public typealias Channel = Kernel.IO.Channel
        """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`namespace adoption typealias Tests`.`Edge Case` {
    @Test
    func `different-leaf typealias is NOT flagged`() {
        let source = """
        public typealias SourceLocation = Text.Location
        """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-member-type RHS is NOT flagged`() {
        let source = """
        public typealias Foo = Int
        """
        let findings = Lint.Rule.`namespace adoption typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

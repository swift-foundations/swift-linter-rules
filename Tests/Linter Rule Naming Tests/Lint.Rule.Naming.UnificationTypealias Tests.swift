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
    struct `unification typealias Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`unification typealias Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unification typealias`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`unification typealias Tests`.Unit {
    @Test
    func `rename-bridge typealias is flagged`() {
        let source = """
        public typealias SourceLocation = Text.Location
        """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "unification_bridge_typealias")
        }
    }
}

extension Lint.Rule.`unification typealias Tests`.`Edge Case` {
    @Test
    func `same-leaf typealias is NOT flagged`() {
        // Handled by [API-NAME-004a] NamespaceAdoption instead.
        let source = """
        public typealias Event = Kernel.Event
        """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `generic instantiation typealias is NOT flagged`() {
        let source = """
        public typealias IntArray = Array<Int>
        """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-member-type RHS is NOT flagged`() {
        let source = """
        public typealias Counter = Int
        """
        let findings = Lint.Rule.`unification typealias Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

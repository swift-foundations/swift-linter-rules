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
@testable import Linter_Rule_Closure

extension Lint.Rule {
    @Suite
    struct `lifecycle order Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`lifecycle order Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`lifecycle order`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`lifecycle order Tests`.Unit {
    @Test
    func `completion before unlabelled body is flagged`() {
        let source = """
        func perform(completion: @escaping (Result) -> Void, _ body: @escaping () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "multi_closure_lifecycle_order")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `onError before unlabelled body is flagged`() {
        let source = """
        func op(onError: () -> Void, _ body: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `cleanup before labelled body is flagged`() {
        let source = """
        func op(cleanup: () -> Void, body: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `two completion-tier closures before body each flagged`() {
        let source = """
        func op(onError: () -> Void, cleanup: () -> Void, _ body: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`lifecycle order Tests`.`Edge Case` {
    @Test
    func `body before completion is NOT flagged`() {
        let source = """
        func perform(_ body: () -> Void, completion: (Result) -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `setup before body before completion is NOT flagged`() {
        let source = """
        func op(setup: () -> Void, _ body: () -> Void, completion: (Result) -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `both labelled non-body and non-completion is NOT flagged`() {
        // progress / metric are domain labels, neither body nor completion;
        // rule can't disambiguate intent without an anchor.
        let source = """
        func op(progress: () -> Void, metric: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single closure is NOT flagged`() {
        let source = """
        func op(_ body: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `completion without any body is NOT flagged`() {
        let source = """
        func op(completion: () -> Void, cleanup: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        // No body-tier anchor — completion-tier closures alone are
        // out of scope here (could be intentional, e.g., a tear-down API).
        #expect(findings.isEmpty)
    }

    @Test
    func `non-closure parameters between closures do not confuse ordering`() {
        let source = """
        func op(completion: () -> Void, count: Int, _ body: () -> Void) {}
        """
        let findings = Lint.Rule.`lifecycle order Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

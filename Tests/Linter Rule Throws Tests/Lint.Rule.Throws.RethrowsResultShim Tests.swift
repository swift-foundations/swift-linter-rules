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
@testable import Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `result wrapper for rethrows shim Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`result wrapper for rethrows shim Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`result wrapper for rethrows shim`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`result wrapper for rethrows shim Tests`.Unit {
    @Test
    func `try inside map closure is flagged`() {
        let source = """
        let result = items.map { try transform($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `try inside compactMap closure is flagged`() {
        let source = """
        let result = items.compactMap { try transform($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `try inside filter closure is flagged`() {
        let source = """
        let result = items.filter { try predicate($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `map without try is not flagged`() {
        let source = """
        let result = items.map { transform($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try with question mark is not flagged`() {
        let source = """
        let result = items.map { try? transform($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try with bang is not flagged`() {
        let source = """
        let result = items.map { try! transform($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `result-wrapper pattern is permitted (no try inside closure)`() {
        let source = """
        let results = items.map { input -> Result<T, E> in
            Result { try transform(input) }
        }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        // The `try` is inside the inner Result init's closure (nested), our
        // visitor skips into nested closures so the inner `try` belongs to
        // the inner closure (which is not a known rethrows method on `Result`).
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`result wrapper for rethrows shim Tests`.`Edge Case` {
    @Test
    func `non-stdlib rethrows method (custom name) is not flagged`() {
        let source = """
        let result = builder.processEach { try op($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `forEach with try is flagged`() {
        let source = """
        items.forEach { try doIt($0) }
        """
        let findings = Lint.Rule.`result wrapper for rethrows shim Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

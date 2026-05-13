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
    struct `redundant refinement Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`redundant refinement Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`redundant refinement`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`redundant refinement Tests`.Unit {
    @Test
    func `Error ampersand Sendable in generic constraint is flagged`() {
        let source = "func f<E: Error & Sendable>(_ e: E) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "redundant refinement")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Swift dot Error ampersand Sendable is flagged via leaf name`() {
        let source = "func f<E: Swift.Error & Sendable>(_ e: E) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Sendable ampersand Error reverse order is flagged`() {
        let source = "func f<E: Sendable & Error>(_ e: E) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Hashable ampersand Equatable is flagged`() {
        let source = "func f<T: Hashable & Equatable>(_ t: T) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Comparable ampersand Equatable is flagged`() {
        let source = "func f<T: Comparable & Equatable>(_ t: T) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Strideable ampersand Comparable is flagged`() {
        let source = "func f<T: Strideable & Comparable>(_ t: T) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `BidirectionalCollection ampersand Collection is flagged`() {
        let source = "func f<C: BidirectionalCollection & Collection>(_ c: C) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `any Error ampersand Sendable existential is flagged`() {
        let source = "func f(_ e: any Error & Sendable) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `where clause Failure Error ampersand Sendable is flagged`() {
        let source = """
        func f<E>(_ e: E) where E: Error & Sendable {}
        """
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple redundant compositions in one file all flagged`() {
        let source = """
        func a<E: Error & Sendable>(_ e: E) {}
        func b<T: Hashable & Equatable>(_ t: T) {}
        """
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    // MARK: - Expanded-table coverage (sourced from symbol-graph-conformance-oracle)
    //
    // The 110 additional refinements added in the 2026-05-13 table
    // expansion cover protocol families the hand-curated table omitted.
    // The tests below sample five of those families.

    @Test
    func `OptionSet ampersand SetAlgebra is flagged via expanded table`() {
        let source = "struct S: OptionSet & SetAlgebra { var rawValue: Int = 0 }"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `StringProtocol ampersand Collection is flagged via expanded table`() {
        let source = "func f<S: StringProtocol & Collection>(_ s: S) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `SIMD ampersand Hashable is flagged via expanded table`() {
        let source = "func f<V: SIMD & Hashable>(_ v: V) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `FixedWidthInteger ampersand Numeric is flagged via expanded table`() {
        // FixedWidthInteger refines Numeric transitively via BinaryInteger.
        let source = "func f<I: FixedWidthInteger & Numeric>(_ i: I) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `ExpressibleByStringLiteral ampersand ExpressibleByUnicodeScalarLiteral is flagged`() {
        let source = """
        func f<S: ExpressibleByStringLiteral & ExpressibleByUnicodeScalarLiteral>(_ s: S) {}
        """
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`redundant refinement Tests`.`Edge Case` {
    @Test
    func `unrelated composition Error ampersand Hashable is NOT flagged`() {
        // Neither Error→Hashable nor Hashable→Error is in the table.
        let source = "func f<T: Error & Hashable>(_ t: T) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-Copyable suppression with Sendable is NOT flagged`() {
        // ~Copyable is a suppression marker, not a protocol — must not
        // shadow a refinement table entry.
        let source = "struct S: ~Copyable & Sendable {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare single conformance is NOT flagged`() {
        let source = "func f<E: Error>(_ e: E) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `composition in a string literal is NOT flagged`() {
        let source = "let s = \"Error & Sendable\""
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `three-way composition with one redundant pair flags once`() {
        // Comparable refines Equatable. Hashable refines Equatable. The
        // redundant member is Equatable; it should be reported exactly
        // once even though two pairs of refinement-table entries match
        // its position.
        let source = "func f<T: Comparable & Hashable & Equatable>(_ t: T) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unrelated composition Sendable ampersand Hashable is NOT flagged`() {
        let source = "func f<T: Sendable & Hashable>(_ t: T) {}"
        let findings = Lint.Rule.`redundant refinement Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

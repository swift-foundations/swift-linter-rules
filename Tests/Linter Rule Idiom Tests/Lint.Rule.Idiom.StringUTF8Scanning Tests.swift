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
    struct `string utf8 scanning Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`string utf8 scanning Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`string utf8 scanning`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`string utf8 scanning Tests`.Unit {
    @Test
    func `unicodeScalars firstIndex is flagged`() {
        let source = """
        func find(in content: String) -> String.Index? {
            content.unicodeScalars.firstIndex(of: "\\n")
        }
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "string_utf8_scanning")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `for in unicodeScalars is flagged`() {
        let source = """
        func op(_ content: String) {
            for scalar in content.unicodeScalars {
                handle(scalar)
            }
        }
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple unicodeScalars accesses each flagged`() {
        let source = """
        func op(_ a: String, _ b: String) -> Bool {
            a.unicodeScalars.count == b.unicodeScalars.count
        }
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`string utf8 scanning Tests`.`Edge Case` {
    @Test
    func `utf8 access is NOT flagged`() {
        let source = """
        func find(in content: String) -> String.Index? {
            content.utf8.firstIndex(of: 0x0A)
        }
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `direct character access is NOT flagged`() {
        let source = """
        func op(_ content: String) -> Character? {
            content.first
        }
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `utf16 access is NOT flagged - rule scopes to unicodeScalars only`() {
        // Rule scopes narrowly. Other views are not flagged by this rule.
        let source = """
        func op(_ content: String) -> String.UTF16View {
            content.utf16
        }
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated member named unicodeScalars on non-String is still flagged`() {
        // The rule cannot resolve type info per-file; it flags by member
        // name. Authors silence with a // swiftlint:disable if the
        // context is unambiguous.
        let source = """
        struct Custom {
            var unicodeScalars: Int { 0 }
        }
        let x = Custom().unicodeScalars
        """
        let findings = Lint.Rule.`string utf8 scanning Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

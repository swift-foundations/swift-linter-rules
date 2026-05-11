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
    struct `throwing wrapper init Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`throwing wrapper init Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`throwing wrapper init`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`throwing wrapper init Tests`.Unit {
    @Test
    func `throwing init with try-only body is flagged`() {
        let source = """
        struct NonEmpty {
            init(_ raw: [Int]) throws {
                try self.base = Base(raw)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "throwing_wrapper_init_no_validation")
        }
    }
}

extension Lint.Rule.`throwing wrapper init Tests`.`Edge Case` {
    @Test
    func `throwing init with additional validation is NOT flagged`() {
        let source = """
        struct NonEmpty {
            init(_ raw: [Int]) throws {
                guard !raw.isEmpty else { throw Error.empty }
                try self.base = Base(raw)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing init is NOT flagged`() {
        let source = """
        struct Wrapper {
            init(_ raw: [Int]) {
                self.base = raw
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

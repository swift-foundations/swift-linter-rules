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
@testable import Linter_Rule_Testing

extension Lint.Rule {
    @Suite
    struct `benchmark timed required Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`benchmark timed required Tests` {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`benchmark timed required`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`benchmark timed required Tests`.Unit {
    @Test
    func `Test inside Performance suite without timed is flagged`() {
        let source = """
        @Suite(.serialized) struct Performance {
            @Test
            func `runs fast`() {}
        }
        """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test inside Performance suite with timed is permitted`() {
        let source = """
        @Suite(.serialized) struct Performance {
            @Test(.timed())
            func `runs fast`() {}
        }
        """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test outside Performance suite is not flagged`() {
        let source = """
        @Suite struct Unit {
            @Test
            func `something`() {}
        }
        """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Test inside Performance extension without timed is flagged`() {
        let source = """
        extension Foo.Test.Performance {
            @Test
            func `runs fast`() {}
        }
        """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Test with timed threshold is permitted`() {
        let source = """
        @Suite(.serialized) struct Performance {
            @Test(.timed(threshold: .milliseconds(50)))
            func `meets budget`() {}
        }
        """
        let findings = Lint.Rule.`benchmark timed required Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

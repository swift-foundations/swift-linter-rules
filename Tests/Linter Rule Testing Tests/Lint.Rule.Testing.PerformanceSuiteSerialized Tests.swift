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
    struct `performance suite serialized Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`performance suite serialized Tests` {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`performance suite serialized`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`performance suite serialized Tests`.Unit {
    @Test
    func `Performance suite without serialized is flagged`() {
        let source = """
        @Suite struct Performance {}
        """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Performance suite with serialized is permitted`() {
        let source = """
        @Suite(.serialized) struct Performance {}
        """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Performance struct without Suite attr is not flagged`() {
        let source = """
        struct Performance {}
        """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Suite on non-Performance type is not flagged`() {
        let source = """
        @Suite struct Unit {}
        """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Performance suite with multiple traits including serialized is permitted`() {
        let source = """
        @Suite(.tags(.benchmark), .serialized) struct Performance {}
        """
        let findings = Lint.Rule.`performance suite serialized Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

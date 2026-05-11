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
@testable import Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `dead case per platform Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`dead case per platform Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`dead case per platform`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`dead case per platform Tests`.Unit {
    @Test
    func `posix windows enum is flagged`() {
        let source = """
        public enum RawEncoding {
            case posix
            case windows
        }
        """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "dead_case_per_platform_enum")
        }
    }

    @Test
    func `utf8 utf16 enum is flagged`() {
        let source = """
        public enum Encoding {
            case utf8
            case utf16
        }
        """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`dead case per platform Tests`.`Edge Case` {
    @Test
    func `domain alternatives enum is NOT flagged`() {
        let source = """
        public enum URLScheme {
            case http
            case https
            case ftp
        }
        """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal enum is NOT flagged`() {
        let source = """
        internal enum RawEncoding {
            case posix
            case windows
        }
        """
        let findings = Lint.Rule.`dead case per platform Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

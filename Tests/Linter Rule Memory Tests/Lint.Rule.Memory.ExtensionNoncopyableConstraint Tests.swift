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
@testable import Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `extension noncopyable constraint Tests` {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.`extension noncopyable constraint Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`extension noncopyable constraint`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`extension noncopyable constraint Tests`.Unit {
    @Test
    func `extension with consuming method but no constraint is flagged`() {
        let source = """
        extension Container {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming method and noncopyable constraint is permitted`() {
        let source = """
        extension Container where Element: ~Copyable {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with no ownership-affecting members is not flagged`() {
        let source = """
        extension Container {
            func describe() -> String { "" }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with borrowing method but no constraint is flagged`() {
        let source = """
        extension Container {
            borrowing func peek() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming parameter but no constraint is flagged`() {
        let source = """
        extension Pipe {
            func push(_ token: consuming Token) {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with where clause containing noncopyable on a different generic param is permitted`() {
        let source = """
        extension Pair where Left: ~Copyable {
            consuming func split() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

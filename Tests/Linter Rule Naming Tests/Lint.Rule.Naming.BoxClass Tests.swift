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
    struct `ad hoc box class Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`ad hoc box class Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`ad hoc box class`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`ad hoc box class Tests`.Unit {
    @Test
    func `_Box class is flagged`() {
        let source = """
        final class _Box<T> {
            var value: T
            init(_ value: T) { self.value = value }
        }
        """
        let findings = Lint.Rule.`ad hoc box class Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "ad hoc box class")
        }
    }

    @Test
    func `Storage class is flagged`() {
        let source = """
        final class Storage {
            var buffer: [Int] = []
        }
        """
        let findings = Lint.Rule.`ad hoc box class Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`ad hoc box class Tests`.`Edge Case` {
    @Test
    func `class with inheritance is NOT flagged`() {
        let source = """
        final class _Storage: ManagedBuffer<Int, Element> { }
        """
        let findings = Lint.Rule.`ad hoc box class Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated class name is NOT flagged`() {
        let source = """
        final class Inventory {
            var items: [Int] = []
        }
        """
        let findings = Lint.Rule.`ad hoc box class Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

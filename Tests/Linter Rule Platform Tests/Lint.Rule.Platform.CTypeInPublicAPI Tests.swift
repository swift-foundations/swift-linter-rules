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
    struct `c type in public api Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`c type in public api Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`c type in public api`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`c type in public api Tests`.Unit {
    @Test
    func `public func with kevent parameter is flagged`() {
        let source = """
        public func register(events: [kevent]) -> Int { 0 }
        """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "c type in public api")
        }
    }

    @Test
    func `public func with HANDLE return type is flagged`() {
        let source = """
        public func open() -> HANDLE { fatalError() }
        """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public init with epoll_event parameter is flagged`() {
        let source = """
        public struct Foo {
            public init(event: epoll_event) {}
        }
        """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`c type in public api Tests`.`Edge Case` {
    @Test
    func `internal func with C type is NOT flagged`() {
        let source = """
        internal func raw(event: kevent) {}
        """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public func with ecosystem types is NOT flagged`() {
        let source = """
        public func register(events: [Kernel.Kqueue.Event]) {}
        """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

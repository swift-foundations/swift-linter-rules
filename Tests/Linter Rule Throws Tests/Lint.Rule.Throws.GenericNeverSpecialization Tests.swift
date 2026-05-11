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
    struct `generic throws missing never Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`generic throws missing never Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`generic throws missing never`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`generic throws missing never Tests`.Unit {
    @Test
    func `public method on generic struct throwing G dot Failure is flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            public mutating func parse() throws(Sink.Failure) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "generic throws missing never")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `public init on generic class throwing G dot Failure is flagged`() {
        let source = """
        public class Loader<Source: Reader> {
            public init() throws(Source.Failure) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension short form picks up generic parameter`() {
        let source = """
        extension Parser<Sink> {
            public func consume() throws(Sink.Failure) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function-level generic param is flagged`() {
        let source = """
        public func op<E: Handler>() throws(E.Failure) { }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`generic throws missing never Tests`.`Edge Case` {
    @Test
    func `concrete throw type is NOT flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            public mutating func parse() throws(MyError) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `untyped throws is NOT flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            public mutating func parse() throws { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-public function is NOT flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            internal func parse() throws(Sink.Failure) { }
            func also() throws(Sink.Failure) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension without short-form generic clause does not flag`() {
        // Extensions without the short-form `extension Type<G>` syntax
        // can't infer generic params per-file; rule conservatively
        // skips them — false negatives over false positives.
        let source = """
        extension Parser {
            public func consume() throws(Sink.Failure) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-generic struct method throws non-generic type is NOT flagged`() {
        let source = """
        public struct Concrete {
            public func parse() throws(MyError) { }
        }
        """
        let findings = Lint.Rule.`generic throws missing never Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

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
@testable import Linter_Rule_Throws

extension Lint.Rule.Throws.GenericNeverSpecialization {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Throws.GenericNeverSpecialization.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Throws.GenericNeverSpecialization().findings(in: parsed)
    }
}

extension Lint.Rule.Throws.GenericNeverSpecialization.Test.Unit {
    @Test
    func `public method on generic struct throwing G dot Failure is flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            public mutating func parse() throws(Sink.Failure) { }
        }
        """
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "generic_throws_missing_never_specialization")
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
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension short form picks up generic parameter`() {
        let source = """
        extension Parser<Sink> {
            public func consume() throws(Sink.Failure) { }
        }
        """
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function-level generic param is flagged`() {
        let source = """
        public func op<E: Handler>() throws(E.Failure) { }
        """
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Throws.GenericNeverSpecialization.Test.`Edge Case` {
    @Test
    func `concrete throw type is NOT flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            public mutating func parse() throws(MyError) { }
        }
        """
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `untyped throws is NOT flagged`() {
        let source = """
        public struct Parser<Sink: Handler> {
            public mutating func parse() throws { }
        }
        """
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
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
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
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
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-generic struct method throws non-generic type is NOT flagged`() {
        let source = """
        public struct Concrete {
            public func parse() throws(MyError) { }
        }
        """
        let findings = Lint.Rule.Throws.GenericNeverSpecialization.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

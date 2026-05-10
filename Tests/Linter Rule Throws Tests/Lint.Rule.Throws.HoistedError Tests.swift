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

extension Lint.Rule.Throws.HoistedError {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Throws.HoistedError.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Throws.HoistedError().findings(in: parsed)
    }
}

extension Lint.Rule.Throws.HoistedError.Test.Unit {
    @Test
    func `public func with hoisted error type is flagged`() {
        let source = "public func op() throws(__FooError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "hoisted_error_in_public_throws")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `public func with generic hoisted error is flagged`() {
        let source = "public func insert<K, V>() throws(__DictionaryError<K, V>) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public init with hoisted error is flagged`() {
        let source = """
        public struct Foo {
            public init() throws(__InitError) {}
        }
        """
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `qualified hoisted error A_B___FooError is flagged`() {
        // Member-type access where the leaf is hoisted: A.B.__FooError.
        let source = "public func op() throws(A.B.__FooError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `open func with hoisted error is flagged`() {
        let source = """
        public class Base {
            open func op() throws(__BaseError) {}
        }
        """
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple public functions with hoisted errors all flagged`() {
        let source = """
        public func a() throws(__AError) {}
        public func b() throws(__BError) {}
        public func c() throws(MyError) {}
        """
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Throws.HoistedError.Test.`Edge Case` {
    @Test
    func `public func with public error path is NOT flagged`() {
        let source = "public func op() throws(MyDomain.Error) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public func with bare Error name is NOT flagged`() {
        let source = "public func op() throws(MyError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal func with hoisted error is NOT flagged`() {
        let source = "func op() throws(__InternalError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private func with hoisted error is NOT flagged`() {
        let source = "private func op() throws(__PrivateError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package func with hoisted error is NOT flagged`() {
        let source = "package func op() throws(__PackageError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public func without throws clause is NOT flagged`() {
        let source = "public func op() {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public func with untyped throws is NOT flagged`() {
        // Untyped throws is its own anti-pattern (API-ERR-001) but does
        // not have a hoisted-type leaf to flag here.
        let source = "public func op() throws {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single underscore prefix is NOT flagged`() {
        // Single-underscore is a different SPI convention, not hoisted.
        let source = "public func op() throws(_FooError) {}"
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throws clause with hoisted-name body call is NOT flagged`() {
        // Body invocations are out of scope — only the throws-type matters.
        let source = """
        public func op() {
            try? __internalHelper()
        }
        """
        let findings = Lint.Rule.Throws.HoistedError.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

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
    struct `typed throws cannot use self error Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`typed throws cannot use self error Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`typed throws cannot use self error`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`typed throws cannot use self error Tests`.Unit {
    @Test
    func `throws Self dot Error in extension on concrete type is flagged`() {
        let source = """
        extension Random {
            func generate() throws(Self.Error) -> UInt64 { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "typed_throws_cannot_use_self_error")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `throws Self dot Error in struct body is flagged`() {
        let source = """
        struct S {
            func f() throws(Self.Error) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws Self dot Error in class body is flagged`() {
        let source = """
        class C {
            func f() throws(Self.Error) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws Self dot Error in enum body is flagged`() {
        let source = """
        enum E {
            func f() throws(Self.Error) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple Self dot Error throws are all flagged`() {
        let source = """
        struct S {
            func a() throws(Self.Error) {}
            func b() throws(Self.Error) {}
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `async throws Self dot Error is flagged`() {
        let source = """
        struct S {
            func f() async throws(Self.Error) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `init throws Self dot Error is flagged`() {
        let source = """
        struct S {
            init() throws(Self.Error) {}
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `noncopyable consuming method with Self dot Error throws is flagged`() {
        let source = """
        extension Storage.Pool {
            consuming func release() throws(Self.Error) { }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`typed throws cannot use self error Tests`.`Edge Case` {
    @Test
    func `throws Self dot Error inside protocol declaring associatedtype Error is NOT flagged`() {
        let source = """
        protocol P {
            associatedtype Error: Swift.Error
            func f() throws(Self.Error)
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot Error inside protocol WITHOUT associatedtype Error is flagged`() {
        let source = """
        protocol P {
            func f() throws(Self.Error)
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throws fully nested error is NOT flagged`() {
        let source = """
        extension Random {
            func generate() throws(Random.Error) -> UInt64 { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws three level nested error is NOT flagged`() {
        let source = """
        extension Storage.Pool {
            func acquire() throws(Storage.Pool.Error) { }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare throws is NOT flagged`() {
        let source = "func f() throws -> Int { 0 }"
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing function is NOT flagged`() {
        let source = "func f() -> Int { 0 }"
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws any Error is NOT flagged by this rule`() {
        let source = "func f() throws(any Error) -> Int { 0 }"
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws Self dot OtherError is NOT flagged`() {
        let source = """
        struct S {
            func f() throws(Self.OtherError) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws domain dot Error is NOT flagged`() {
        let source = """
        struct S {
            func f() throws(Foo.Error) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Self dot Error in a string literal is NOT flagged`() {
        let source = "let s = \"throws(Self.Error)\""
        let findings = Lint.Rule.`typed throws cannot use self error Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

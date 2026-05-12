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
@testable import Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `minimal type body Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`minimal type body Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`minimal type body`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`minimal type body Tests`.Unit {
    @Test
    func `method in type body is flagged`() {
        let source = """
        struct Buffer {
            var x: Int
            func append(_ value: Int) {}
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "minimal type body")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `computed property in type body is flagged`() {
        let source = """
        struct State {
            var raw: Int
            var isEmpty: Bool { raw == 0 }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `static member is flagged`() {
        let source = """
        struct Foo {
            var x: Int
            static let shared = Foo(x: 0)
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested struct in type body is flagged`() {
        let source = """
        struct Outer {
            var x: Int
            struct Inner {}
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `typealias in type body is flagged`() {
        let source = """
        struct Foo {
            var x: Int
            typealias Element = Int
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending members each flagged`() {
        let source = """
        struct Foo {
            var x: Int
            func a() {}
            var computed: Int { x }
            static let shared = 0
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`minimal type body Tests`.`Edge Case` {
    @Test
    func `stored properties and init only - NOT flagged`() {
        let source = """
        struct Buffer {
            @usableFromInline
            var storage: Storage

            @usableFromInline
            var count: Int

            @inlinable
            public init() {
                self.storage = Storage()
                self.count = 0
            }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `class with deinit - NOT flagged`() {
        let source = """
        class Box {
            var x: Int
            init() { self.x = 0 }
            deinit {}
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property with willSet observer - NOT flagged`() {
        let source = """
        struct S {
            var x: Int {
                willSet { print(newValue) }
            }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property with didSet observer - NOT flagged`() {
        let source = """
        struct S {
            var x: Int {
                didSet { print(oldValue) }
            }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `enum case is NOT flagged`() {
        let source = """
        enum E {
            case foo
            case bar
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `protocol requirements are out of scope - NOT flagged`() {
        let source = """
        protocol P {
            func op()
            var name: String { get }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `methods in extension are NOT flagged`() {
        let source = """
        struct Buffer {
            var x: Int
        }
        extension Buffer {
            func op() {}
            var doubled: Int { x * 2 }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-4] (@resultBuilder). Types marked
    // `@resultBuilder` carry static methods dictated by Swift's
    // `@resultBuilder` informal protocol contract per SE-0289. Forcing
    // extraction yields empty-body + extension-with-only-witnesses for
    // zero semantic gain.

    @Test
    func `@resultBuilder enum with buildBlock is exempt per RULE-EXEMPT-4`() {
        let source = """
        @resultBuilder
        enum MyBuilder {
            static func buildBlock(_ x: Int) -> Int { x }
            static func buildExpression(_ x: Int) -> Int { x }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested @resultBuilder struct is exempt per RULE-EXEMPT-4`() {
        // The nested-type's @resultBuilder attribute is checked at the
        // parent's checkMembers walk; the nested type is exempt even
        // though it's a nested type-decl, which the rule normally flags.
        let source = """
        struct Outer {
            var x: Int
            @resultBuilder
            struct InnerBuilder {
                static func buildBlock(_ x: Int) -> Int { x }
            }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-resultBuilder struct with static method is still flagged`() {
        let source = """
        struct PlainType {
            var x: Int
            static func make() -> PlainType { PlainType(x: 0) }
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-4] broadened to extension-pattern
    // attribute. swift-testing's `@Suite` legitimately holds nested
    // `@Suite` substructures per [SWIFT-TEST-002]; the attribute IS the
    // spec, mirroring the @resultBuilder rationale.

    @Test
    func `@Suite struct holding nested @Suite struct is exempt per RULE-EXEMPT-4`() {
        let source = """
        @Suite
        struct OuterSuite {
            @Suite struct Unit {}
            @Suite struct EdgeCase {}
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested @Suite struct inside non-@Suite parent is exempt per RULE-EXEMPT-4`() {
        // Mirrors the existing @resultBuilder nested-type test. The
        // nested @Suite is recognized at the parent's checkMembers walk
        // and skipped without firing the nested-type-in-body branch.
        let source = """
        struct Outer {
            var x: Int
            @Suite
            struct InnerSuite {}
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-@Suite nested type inside non-@Suite parent is still flagged`() {
        // Negative case: the @Suite recognition is narrow — a plain
        // nested struct inside a plain parent still fires (no spurious
        // @Suite exemption from the broadened helper).
        let source = """
        struct Outer {
            var x: Int
            struct Helper {}
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-5] (Protocol-sentinel). The
    // institute hoisted-protocol pattern per [API-IMPL-009] /
    // [PKG-NAME-001] places a `typealias Protocol = _FooProtocol`
    // inside the type body intentionally; extraction yields empty-body
    // + extension-with-one-typealias for zero semantic gain.

    @Test
    func `typealias Protocol in type body is exempt per RULE-EXEMPT-5`() {
        let source = """
        enum Carrier {
            typealias Protocol = _CarrierProtocol
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias backtick-Protocol in type body is exempt per RULE-EXEMPT-5`() {
        let source = """
        enum Carrier {
            public typealias `Protocol` = Swift.Equatable
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias with other name in type body is still flagged`() {
        // Negative case — the sentinel exemption is name-narrow, not a
        // typealias-blanket exemption.
        let source = """
        enum Carrier {
            typealias Underlying = SomeOtherType
        }
        """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

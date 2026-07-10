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

import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `inlinable internal access Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`inlinable internal access Tests` {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`inlinable internal access`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`inlinable internal access Tests`.Unit {
    @Test
    func `inlinable internal func is flagged`() {
        let source = """
            @inlinable
            func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `inlinable public func is permitted`() {
        let source = """
            @inlinable
            public func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable package func is permitted`() {
        let source = """
            @inlinable
            package func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable usableFromInline func is permitted`() {
        let source = """
            @inlinable @usableFromInline
            func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable internal var is flagged`() {
        let source = """
            @inlinable
            var x: Int { 1 }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `inlinable public var is permitted`() {
        let source = """
            @inlinable
            public var x: Int { 1 }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable internal init in public type is flagged`() {
        // Amendment §A6: the enclosing type must be `public` (or
        // `package`) for the `package` init upgrade to be legal, so the
        // rule fires here; an internal enclosing type is now exempt (see
        // the §A6 Edge Case suite).
        let source = """
            public struct S {
                @inlinable
                init() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`inlinable internal access Tests`.`Edge Case` {
    @Test
    func `non-inlinable internal func is not flagged`() {
        let source = "func foo() {}"
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable open func is permitted`() {
        let source = """
            @inlinable
            open func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable init flagged message recommends package init not usableFromInline`() {
        let source = """
            public struct S {
                @inlinable
                init() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            let message = findings[0].message
            #expect(message.contains("`package init`"))
            #expect(message.contains("has no effect"))
            #expect(!message.contains("pair the attribute with `@usableFromInline`"))
        }
    }

    @Test
    func `inlinable func flagged message prescribes package not usableFromInline pairing`() {
        // Amendment §A6 verdict 2: the func/var message is aligned with
        // the init message — it prescribes the `package` upgrade and
        // drops the former "@usableFromInline (preferred...)" guidance
        // (which Swift rejects on an `@inlinable` decl as "has no
        // effect"). It must NOT tell the author to pair with
        // `@usableFromInline`.
        let source = """
            @inlinable
            func foo() {}
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            let message = findings[0].message
            #expect(message.contains("`package`"))
            #expect(message.contains("has no effect"))
            #expect(!message.contains("pair the attribute with `@usableFromInline`"))
            // The compiler-illegal exemption and suppress channel are named.
            #expect(message.contains("compiler-illegal"))
            #expect(message.contains("swift-linter:disable:next"))
        }
    }

    @Test
    func `package init satisfies the rule`() {
        let source = """
            struct S {
                @inlinable
                package init() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

// MARK: - Amendment §A6 (2026-07-09) — compiler-illegal-upgrade exemption

extension Lint.Rule.`inlinable internal access Tests`.`Edge Case` {
    /// Variant A, `@usableFromInline` enclosing type — the
    /// swift-async-primitives shape.
    ///
    /// A member cannot be widened past its
    /// enclosing type's access, so `package` is compiler-illegal here.
    @Test
    func `A6 variant A: member in usableFromInline struct is exempt`() {
        let source = """
            @usableFromInline
            struct S {
                @inlinable
                func foo() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// Variant A, internal-default enclosing type.
    @Test
    func `A6 variant A: member in internal struct is exempt`() {
        let source = """
            struct S {
                @inlinable
                func foo() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// Variant A, internal-default enclosing type — property variant.
    @Test
    func `A6 variant A: var in internal struct is exempt`() {
        let source = """
            struct S {
                @inlinable
                var x: Int { 1 }
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// Variant B — the memory-small shape: an `@inlinable init` in a
    /// `public` type whose parameter type resolves in the same file to a
    /// `@usableFromInline` (below-`package`) declaration.
    @Test
    func `A6 variant B: init with same-file usableFromInline param type is exempt`() {
        let source = """
            @usableFromInline
            struct Storage {}

            public struct Small {
                @inlinable
                init(storage: Storage) {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// Variant B, internal-default same-file param type.
    @Test
    func `A6 variant B: init with same-file internal param type is exempt`() {
        let source = """
            struct Storage {}

            public struct Small {
                @inlinable
                init(storage: Storage?) {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`inlinable internal access Tests`.Unit {
    /// Still fires: a member of a `public` type — the `package` upgrade
    /// is legal, so the exemption does not apply.
    @Test
    func `A6 still fires: member in public struct`() {
        let source = """
            public struct S {
                @inlinable
                func foo() {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    /// Still fires: an `@inlinable init` in a `public` type whose
    /// parameter type is NOT declared in this file (cross-file), so it
    /// cannot be resolved as below-`package` and the conservative
    /// default is to fire.
    @Test
    func `A6 still fires: init with cross-file param type`() {
        let source = """
            public struct S {
                @inlinable
                init(value: ExternalThing) {}
            }
            """
        let findings = Lint.Rule.`inlinable internal access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

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
        extension Container<Element> {
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
        extension Container<Element> {
            func describe() -> String { "" }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with borrowing method but no constraint is flagged`() {
        let source = """
        extension Container<Element> {
            borrowing func peek() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming parameter but no constraint is flagged`() {
        let source = """
        extension Pipe<Token> {
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

    @Test
    func `extension on namespace containing nested type with consuming init is not flagged`() {
        let source = """
        extension Ownership {
            struct Indirect<Value: ~Copyable>: ~Copyable {
                init(consuming value: consuming Value) {}
            }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on namespace containing nested type with consuming method is not flagged`() {
        let source = """
        extension Ownership {
            struct Latch<Value: ~Copyable>: ~Copyable {
                consuming func take() -> Value { fatalError() }
            }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on namespace with both nested type and own consuming method flags only the latter`() {
        let source = """
        extension Container<Element> {
            struct Inner<T: ~Copyable>: ~Copyable {
                init(consuming value: consuming T) {}
            }
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on non-generic type with method-local generic consuming parameter is not flagged`() {
        let source = """
        extension Ownership.Transfer.Erased.Incoming {
            func consume<T>(_ value: consuming T) {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on non-generic type with method-local generic borrowing parameter is not flagged`() {
        let source = """
        extension Ownership.Transfer.Erased.Incoming {
            func inspect<T>(_ value: borrowing T) {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with method-local generic init consuming parameter is not flagged`() {
        let source = """
        extension Box {
            init<T>(consuming value: consuming T) {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with consuming parameter whose type is not method-local is still flagged`() {
        let source = """
        extension Pool<Resource> {
            func take<T>(_ resource: consuming Resource) {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `consuming-self method with own generic params on non-generic extended type is not flagged`() {
        let source = """
        extension Ownership.Transfer.Erased.Incoming {
            public consuming func consume<T>(_ type: T.Type) -> T { fatalError() }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `borrowing-self method with own generic params on non-generic extended type is not flagged`() {
        let source = """
        extension Ownership.Transfer.Erased.Incoming {
            public borrowing func inspect<T>(_ type: T.Type) -> Bool { false }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `consuming-self method without own generic params is still flagged`() {
        let source = """
        extension Container<Element> {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-1] (positive-Copyable). Author has
    // explicitly scoped the extension to a Copyable surface; the
    // "silent shrink to Copyable" premise is inverted by the explicit
    // conformance and the rule MUST NOT fire.

    @Test
    func `extension with positive Copyable constraint is exempt per RULE-EXEMPT-1`() {
        let source = """
        extension Container where Element: Copyable {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with composition positive Copyable constraint is exempt per RULE-EXEMPT-1`() {
        let source = """
        extension Container where Element: SomeProtocol & Copyable {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with Swift-qualified positive Copyable constraint is exempt per RULE-EXEMPT-1`() {
        let source = """
        extension Container where Element: Swift.Copyable {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: syntactic non-generic detection. The rule's
    // premise — "extension on `~Copyable`-aware GENERIC type implicitly
    // constrains to Copyable, silently shrinking the surface" — applies
    // only when the extension target IS generic. For syntactically-
    // non-generic targets (no `<...>`, no where clause), the where
    // clause is structurally inexpressible and the rule MUST NOT fire.
    // Scales automatically to new directly-`~Copyable` types without
    // per-type allowlist maintenance.

    @Test
    func `extension on bare non-generic leaf is exempt via syntactic detection`() {
        let source = """
        extension Comparison {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on qualified non-generic type is exempt via syntactic detection`() {
        let source = """
        extension Affine.Discrete.Vector {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on directly-Noncopyable type is exempt via syntactic detection`() {
        // Lint.Source.Parsed is `~Copyable, Sendable` at L1 per the
        // Tier-2 RECOMMENDATION v1.1.0 (2026-05-13). Extensions carry
        // `borrowing func` methods; the rule's `where ~Copyable` request
        // is structurally inexpressible (no generic parameter exists).
        let source = """
        extension Lint.Source.Parsed {
            borrowing func visibility(at position: Int) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Ordinal leaf is not flagged regression check`() {
        let source = """
        extension Ordinal {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on explicit-generic-form of bare leaf still fires`() {
        // Demonstrates that the syntactic detection's discriminator is
        // presence of `<...>` (not the type's leaf name). An author who
        // writes the explicit-parameter form of a generic type without
        // a where clause IS subject to the rule's premise.
        let source = """
        extension Vector<Element> {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.`extension noncopyable constraint Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

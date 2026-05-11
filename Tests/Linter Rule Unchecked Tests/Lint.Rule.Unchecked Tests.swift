// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter project authors
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
@testable import Linter_Rule_Unchecked

extension Lint.Rule {
    @Suite
    struct `unchecked call site Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`unchecked call site Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unchecked call site`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`unchecked call site Tests`.Unit {
    @Test
    func `Call site with __unchecked label is flagged`() {
        let source = "let x = Foo(__unchecked: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "unchecked_call_site")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Declaration site with __unchecked parameter is NOT flagged`() {
        let source = """
        struct Foo {
            init(__unchecked _: ()) {}
        }
        """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Other argument labels are NOT flagged`() {
        let source = "let x = Foo(name: 42, value: \"abc\")"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Multiple call sites are all flagged`() {
        let source = """
        let a = Foo(__unchecked: (), value: 1)
        let b = Bar(other: 2, __unchecked: ())
        let c = Baz(__unchecked: ())
        """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `Mixed declaration AND call sites flag only call sites`() {
        let source = """
        struct Foo {
            init(__unchecked _: ()) {}
        }

        let x = Foo(__unchecked: ())
        """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let x = Foo(__unchecked: ())"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`unchecked call site`.findings(parsed, .error)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

extension Lint.Rule.`unchecked call site Tests`.`Edge Case` {
    @Test
    func `Nested call site with __unchecked is flagged`() {
        let source = "let x = outer(inner: Foo(__unchecked: ()))"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Generic call site with __unchecked is flagged`() {
        let source = "let x = Foo<Int>(__unchecked: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Trailing closure call with __unchecked label is flagged`() {
        let source = """
        let x = Foo(__unchecked: ()) { value in
            value + 1
        }
        """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `__unchecked appearing in a string literal is NOT flagged`() {
        let source = "let x = \"Foo(__unchecked: ())\""
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `__unchecked in a comment is NOT flagged`() {
        let source = """
        // Foo(__unchecked: ()) is the canonical anti-pattern
        let x = 42
        """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `__unchecked as part of a larger label is NOT flagged`() {
        let source = "let x = Foo(__unchecked_extra: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Static method call site with __unchecked is flagged`() {
        let source = "let x = Foo.make(__unchecked: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `self.init call site with __unchecked is flagged`() {
        let source = """
        struct Foo {
            init(value: Int) {
                self.init(__unchecked: ())
            }
            init(__unchecked _: ()) {}
        }
        """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}

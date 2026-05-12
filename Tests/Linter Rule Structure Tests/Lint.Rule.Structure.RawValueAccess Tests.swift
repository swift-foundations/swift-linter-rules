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
    struct `raw value access Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct `Package Scope` {}
    }
}

extension Lint.Rule.`raw value access Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`raw value access`.findings(parsed, .warning)
    }

    /// Run the rule with a simulated owning-package brand-types set.
    /// Mirrors how the engine threads
    /// ``Lint/Source/Parsed/brandTypes`` onto the parsed source in
    /// production. See package-scoped admission notes on
    /// `Lint.Rule.\`raw value access\``.
    static func findings(
        in source: String,
        file: String = "test.swift",
        brandTypes: Set<Lint.Brand>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file, brandTypes: brandTypes)
        return Lint.Rule.`raw value access`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`raw value access Tests`.Unit {
    @Test
    func `rawValue access inside function body is flagged`() {
        let source = """
        func op(tag: MyTag) {
            let raw = tag.rawValue
            use(raw)
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "raw value access")
        }
    }

    @Test
    func `position access inside function body is flagged`() {
        let source = """
        func op(index: MyIndex) {
            let p = index.position
            use(p)
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`raw value access Tests`.`Edge Case` {
    @Test
    func `rawValue at top-level type scope is NOT flagged`() {
        let source = """
        struct Foo {
            static let max = MyTag.maxRawValue
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated member access is NOT flagged`() {
        let source = """
        func op(tag: MyTag) {
            let n = tag.name
            use(n)
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

// MARK: - Package-scoped admission (numerics rule-recognizer, 2026-05-12)
//
// The rule admits `.rawValue` access when the file's owning SwiftPM
// package declares brand-newtypes via `.swift-linter.json`. The
// three-row matrix below pins the contract:
//
//   1. Positive (admit): `brandTypes` matches the access target → no fire.
//   2. Negative (mismatch): `brandTypes` declares a different brand → fire (strict-superset).
//   3. Negative (default): no `brandTypes` → fire (back-compat).

extension Lint.Rule.`raw value access Tests`.`Package Scope` {
    @Test
    func `same-package access with matching brand-type is admitted (direct base)`() {
        // Site shape: `Cardinal.rawValue` inside a same-package
        // implementation. Brand-types set declares "Cardinal" → the
        // rule recognizes the access as legitimate-by-construction
        // and does NOT emit.
        let source = """
        extension Cardinal {
            public static func test() -> Int {
                Cardinal.rawValue
            }
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(
            in: source,
            brandTypes: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `same-package access with variable base is admitted (package-scope fallback)`() {
        // Site shape: `lhs.rawValue` inside an extension on
        // `Cardinal`. The variable base does not resolve to a
        // type-name at AST, so the package-scope fallback admits
        // when `brandTypes` is non-empty.
        let source = """
        extension Cardinal {
            public static func test(lhs: Cardinal) -> Int {
                lhs.rawValue
            }
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(
            in: source,
            brandTypes: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested-type access is admitted when its dotted name is declared`() {
        // Site shape: `Affine.Discrete.Vector.rawValue` — the
        // direct-case extractor reassembles the dotted name from
        // the `MemberAccessExprSyntax` chain.
        let source = """
        public func test() -> Int {
            Affine.Discrete.Vector.rawValue
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(
            in: source,
            brandTypes: ["Affine.Discrete.Vector"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `cross-package access fires when brand-type list mismatches (strict superset)`() {
        // Site shape: `Cardinal.rawValue` but the file's owning
        // package declares a different brand ("Foo"). Since the
        // direct extractor returns "Cardinal" and "Cardinal" is NOT
        // in the brand-types set, the rule fires.
        let source = """
        public func test() -> Int {
            Cardinal.rawValue
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(
            in: source,
            brandTypes: ["Foo"]
        )
        #expect(findings.count == 1)
    }

    @Test
    func `no brand-types declared - rule fires as today (back-compat)`() {
        // Default behaviour: a file with no `.swift-linter.json`
        // (so `brandTypes` is empty) keeps the rule's pre-recognizer
        // semantics. Critical for downstream consumers that have not
        // adopted the new config file.
        let source = """
        public func test(tag: MyTag) -> Int {
            tag.rawValue
        }
        """
        let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

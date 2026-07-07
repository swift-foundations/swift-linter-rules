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

@testable import Linter_Rule_Suppression

extension Lint.Rule {
    @Suite
    struct `malformed suppression directive Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`malformed suppression directive Tests` {
    static func findings(in source: String, file: String = "/Sources/X/File.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`malformed suppression directive`.findings(parsed, .warning)
    }
}

// MARK: - Unit: malformed forms MUST fire

extension Lint.Rule.`malformed suppression directive Tests`.Unit {
    @Test
    func `block form without next or line is flagged`() {
        let source = """
            // swift-linter:disable unchecked call site
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enable form is flagged (no enable directive exists)`() {
        let source = """
            // swift-linter:enable unchecked call site
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `empty rule id after next is flagged`() {
        let source = """
            // swift-linter:disable:next
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `whitespace-only rule id after next is flagged`() {
        // Trailing space present so the honored prefix matches, but the id is empty.
        let source =
            "// swift-linter:disable:next \nlet value = compute()"
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `wrong sub-token this is flagged (engine uses line)`() {
        let source = """
            // swift-linter:disable:this unchecked call site
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `missing space after slashes is flagged`() {
        let source = """
            //swift-linter:disable:next unchecked call site
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// MARK: - Edge Case: well-formed / out-of-scope MUST NOT fire

extension Lint.Rule.`malformed suppression directive Tests`.`Edge Case` {
    @Test
    func `well-formed disable next is permitted`() {
        let source = """
            // swift-linter:disable:next unchecked call site
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `well-formed disable line trailing comment is permitted`() {
        let source = """
            let value = compute() // swift-linter:disable:line raw value access
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `swiftlint-prefixed directive is out of scope`() {
        let source = """
            // swiftlint:disable:next force_cast
            let value = compute() as! Int
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `swiftlint block form is out of scope`() {
        // This is exactly the swift-spm-standard 285f46a^ shape — owned by
        // SwiftLint's superfluous_disable_command / blanket_disable_command.
        let source = """
            // swiftlint:disable no_foundation_import_warning typed_throws_required
            let value = compute()
            // swiftlint:enable no_foundation_import_warning typed_throws_required
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `prose mentioning the directive is not a directive`() {
        let source = """
            // see swift-linter:disable:next in the engine docs for the grammar
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `doc comment mention is not scanned`() {
        // `///` is a docLineComment, not a lineComment — the engine scanner
        // (and this rule) skip it, matching Lint.Suppression.scan.
        let source = """
            /// swift-linter:disable:next unchecked call site
            let value = compute()
            """
        let findings = Lint.Rule.`malformed suppression directive Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

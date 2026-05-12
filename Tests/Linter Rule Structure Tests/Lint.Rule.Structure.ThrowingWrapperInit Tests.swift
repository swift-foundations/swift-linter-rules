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
    struct `throwing wrapper init Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`throwing wrapper init Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`throwing wrapper init`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`throwing wrapper init Tests`.Unit {
    @Test
    func `throwing init with try-only body is flagged`() {
        let source = """
        struct NonEmpty {
            init(_ raw: [Int]) throws {
                try self.base = Base(raw)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "throwing wrapper init")
        }
    }
}

extension Lint.Rule.`throwing wrapper init Tests`.`Edge Case` {
    @Test
    func `throwing init with additional validation is NOT flagged`() {
        let source = """
        struct NonEmpty {
            init(_ raw: [Int]) throws {
                guard !raw.isEmpty else { throw Error.empty }
                try self.base = Base(raw)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing init is NOT flagged`() {
        let source = """
        struct Wrapper {
            init(_ raw: [Int]) {
                self.base = raw
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Int with throwing init from institute type is admitted`() {
        let source = """
        extension Int {
            public init<Tag: ~Copyable>(_ position: Tagged<Tag, Ordinal>) throws(Ordinal.Error) {
                self = try Int(position.underlying)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        // Int is the LAX type; the rule's "wrapper specializes stricter
        // invariant" premise is inverted when the enclosing type is the
        // lax primitive and the parameter is the stricter institute
        // type. The body's overflow check IS the validation.
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on UInt with throwing init is admitted`() {
        let source = """
        extension UInt {
            public init<Tag: ~Copyable>(_ position: Tagged<Tag, Cardinal>) throws(Cardinal.Error) {
                self = try UInt(position.underlying)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throwing init on institute wrapper struct is still flagged`() {
        let source = """
        struct Wrapper {
            init(_ raw: Int) throws {
                try self.init(base: raw)
            }
        }
        """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        // Institute wrapper struct (not on the lax allowlist) — the
        // rule's premise applies and the init should still fire.
        #expect(findings.count == 1)
    }
}

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
    struct `wrapper backing exposed Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`wrapper backing exposed Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`wrapper backing exposed`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`wrapper backing exposed Tests`.Unit {
    @Test
    func `default-internal _backing in struct is flagged`() {
        let source = """
        public struct Lane {
            let _backing: IO.Blocking.Lane
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "wrapper backing exposed")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `explicit internal _wrapped in actor is flagged`() {
        let source = """
        public actor Box {
            internal var _wrapped: Underlying
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `package _underlying in class is flagged`() {
        let source = """
        class Wrapper {
            package var _underlying: Storage
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`wrapper backing exposed Tests`.`Edge Case` {
    @Test
    func `private _backing is NOT flagged`() {
        let source = """
        struct Lane {
            private let _backing: IO.Blocking.Lane
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fileprivate _wrapped is NOT flagged`() {
        let source = """
        struct Wrapper {
            fileprivate var _wrapped: Underlying
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `usableFromInline _backing is NOT flagged`() {
        let source = """
        public struct Lane {
            @usableFromInline
            var _backing: IO.Blocking.Lane
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-tracked underscore name is NOT flagged`() {
        let source = """
        struct S {
            var _other: Int
            var _internal: String
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `_backing at file scope is NOT flagged`() {
        let source = """
        let _backing = 0
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `_backing in protocol is NOT flagged`() {
        // Protocols declare requirements; backing-property convention
        // does not apply to protocol requirements.
        let source = """
        protocol P {
            var _backing: Underlying { get }
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-tracked names like backing without underscore are NOT flagged`() {
        let source = """
        struct S {
            var backing: Underlying
            var wrapped: Other
        }
        """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

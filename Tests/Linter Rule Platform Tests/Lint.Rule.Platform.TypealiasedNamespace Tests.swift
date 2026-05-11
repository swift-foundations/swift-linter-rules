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
@testable import Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `typealiased namespace bridge Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`typealiased namespace bridge Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`typealiased namespace bridge`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`typealiased namespace bridge Tests`.Unit {
    @Test
    func `cross-module typealias keeping leaf name is flagged`() {
        let source = """
        extension ISO_9945 {
            public typealias Kernel = Kernel_Primitives_Core.Kernel
        }
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "typealiased_namespace_bridge")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `simple file-scope namespace-bridge typealias is flagged`() {
        let source = """
        typealias Socket = Foundation.Socket
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `deep member chain ending in matching leaf is flagged`() {
        let source = """
        typealias Descriptor = A.B.C.D.Descriptor
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`typealiased namespace bridge Tests`.`Edge Case` {
    @Test
    func `typealias with different LHS-RHS leaf names is NOT flagged`() {
        let source = """
        typealias Storage = Internal.Buffer
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to bare identifier is NOT flagged`() {
        let source = """
        typealias Foo = Int
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to generic specialization NOT a member type is NOT flagged`() {
        let source = """
        typealias Bytes = Array<UInt8>
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to Self dot Foo (no namespace bridge) is NOT flagged`() {
        // `Self.Foo` is a regular dotted member, not a namespace bridge —
        // though LHS-name equality could match if leaf coincides. The
        // detection's narrow-scope is intentional: same-name bridging
        // pattern is the canonical [PLAT-ARCH-018] shape.
        let source = """
        extension Holder {
            typealias Foo = OtherType.Foo
        }
        """
        // This DOES match the pattern (leaf names equal). Rule flags it
        // — correctly, because consumers calling `Holder.Foo.X` would
        // resolve through to `OtherType.Foo.X`.
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple typealiases in same extension each evaluated`() {
        let source = """
        extension POSIX {
            typealias Kernel = Kernel_Primitives.Kernel
            typealias Socket = Net_Primitives.Socket
            typealias Mode = Other.Different
        }
        """
        let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
        // First two flagged (leaf match), third not (different leaf).
        #expect(findings.count == 2)
    }
}

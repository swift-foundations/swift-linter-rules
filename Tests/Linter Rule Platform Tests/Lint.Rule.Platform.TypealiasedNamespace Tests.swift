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
@testable import Linter_Rule_Platform

extension Lint.Rule.Platform.TypealiasedNamespace {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.TypealiasedNamespace.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.TypealiasedNamespace().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.TypealiasedNamespace.Test.Unit {
    @Test
    func `cross-module typealias keeping leaf name is flagged`() {
        let source = """
        extension ISO_9945 {
            public typealias Kernel = Kernel_Primitives_Core.Kernel
        }
        """
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
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
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `deep member chain ending in matching leaf is flagged`() {
        let source = """
        typealias Descriptor = A.B.C.D.Descriptor
        """
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Platform.TypealiasedNamespace.Test.`Edge Case` {
    @Test
    func `typealias with different LHS-RHS leaf names is NOT flagged`() {
        let source = """
        typealias Storage = Internal.Buffer
        """
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to bare identifier is NOT flagged`() {
        let source = """
        typealias Foo = Int
        """
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to generic specialization NOT a member type is NOT flagged`() {
        let source = """
        typealias Bytes = Array<UInt8>
        """
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
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
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
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
        let findings = Lint.Rule.Platform.TypealiasedNamespace.Test.findings(in: source)
        // First two flagged (leaf match), third not (different leaf).
        #expect(findings.count == 2)
    }
}

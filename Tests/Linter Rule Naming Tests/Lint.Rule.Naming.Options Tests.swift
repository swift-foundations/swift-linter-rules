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
@testable import Linter_Rule_Naming

extension Lint.Rule.Naming.Options {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Naming.Options.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Lint.Finding] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Naming.Options().findings(in: parsed)
    }
}

extension Lint.Rule.Naming.Options.Test.Unit {
    @Test
    func `OptionSet struct ending in Flags is flagged`() {
        let source = """
        struct OpenFlags: OptionSet {
            let rawValue: Int
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "option_named_flags")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `OptionSet struct with Swift dot OptionSet inheritance is flagged`() {
        let source = """
        struct OpenFlags: Swift.OptionSet {
            let rawValue: Int
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple inheritance with OptionSet is flagged`() {
        let source = """
        struct OpenFlags: OptionSet, Sendable {
            let rawValue: Int
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending types are all flagged`() {
        let source = """
        struct AFlags: OptionSet { let rawValue: Int }
        struct BFlags: OptionSet { let rawValue: Int }
        struct CFlags: OptionSet { let rawValue: Int }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `nested OptionSet ending in Flags is flagged`() {
        let source = """
        enum File {
            struct OpenFlags: OptionSet {
                let rawValue: Int
            }
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Naming.Options.Test.`Edge Case` {
    @Test
    func `OptionSet struct named Options is NOT flagged`() {
        let source = """
        struct OpenOptions: OptionSet {
            let rawValue: Int
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-OptionSet struct ending in Flags is NOT flagged`() {
        let source = """
        struct DebugFlags {
            var verbose: Bool
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-OptionSet struct ending in Flags with Sendable is NOT flagged`() {
        let source = """
        struct DebugFlags: Sendable {
            var verbose: Bool
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare struct named Flags (no suffix) is NOT flagged`() {
        let source = """
        struct Flags: OptionSet {
            let rawValue: Int
        }
        """
        // Rule requires "ends in Flags" with at least one prefix character; "Flags"
        // alone doesn't have a suffix-bearing prefix.
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `class named XFlags conforming to OptionSet is NOT flagged`() {
        // OptionSet is struct-only conventionally; classes don't conform. The rule
        // visits StructDeclSyntax only.
        let source = """
        class OpenFlags {
            var rawValue: Int = 0
        }
        """
        let findings = Lint.Rule.Naming.Options.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

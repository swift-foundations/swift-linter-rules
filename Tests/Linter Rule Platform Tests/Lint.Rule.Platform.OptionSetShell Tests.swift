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

extension Lint.Rule.Platform.OptionSetShell {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.OptionSetShell.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.OptionSetShell().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.OptionSetShell.Test.Unit {
    @Test
    func `OptionSet with static let Self rawValue in body is flagged`() {
        let source = """
        struct Options: OptionSet {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
            public static let create = Self(rawValue: O_CREAT)
        }
        """
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "optionset_shell_pattern")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `multiple platform constants in body each flagged`() {
        let source = """
        struct Options: OptionSet {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
            public static let create = Self(rawValue: O_CREAT)
            public static let truncate = Self(rawValue: O_TRUNC)
            public static let exclusive = Self(rawValue: O_EXCL)
        }
        """
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `Swift dot OptionSet conformance is recognized`() {
        let source = """
        struct Options: Swift.OptionSet {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
            public static let bit = Self(rawValue: 1)
        }
        """
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Platform.OptionSetShell.Test.`Edge Case` {
    @Test
    func `clean shell with only rawValue and init is NOT flagged`() {
        let source = """
        struct Options: OptionSet, Sendable {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
        }
        """
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `static constants in extension are NOT flagged`() {
        let source = """
        struct Options: OptionSet {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
        }
        extension Options {
            public static let create = Self(rawValue: O_CREAT)
            public static let truncate = Self(rawValue: O_TRUNC)
        }
        """
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct not conforming to OptionSet is NOT flagged`() {
        let source = """
        struct Holder {
            let rawValue: Int32
            public static let foo = Self(rawValue: 0)
        }
        """
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `static decl with non-Self initializer is NOT flagged`() {
        let source = """
        struct Options: OptionSet {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
            public static let default = Options(rawValue: 0)
        }
        """
        // `Options(rawValue:)` not `Self(rawValue:)` — narrow rule scopes
        // to the canonical `Self(rawValue:)` shape used by the institute
        // convention.
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `static var (not let) with Self rawValue is flagged too`() {
        let source = """
        struct Options: OptionSet {
            let rawValue: Int32
            init(rawValue: Int32) { self.rawValue = rawValue }
            public static var custom: Self = Self(rawValue: 0)
        }
        """
        // `var` form, but same `Self(rawValue:)` shape — flagged.
        let findings = Lint.Rule.Platform.OptionSetShell.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

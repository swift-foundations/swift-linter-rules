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

extension Lint.Rule.Platform.DeadCasePerPlatform {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.DeadCasePerPlatform.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.DeadCasePerPlatform().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.DeadCasePerPlatform.Test.Unit {
    @Test
    func `posix windows enum is flagged`() {
        let source = """
        public enum RawEncoding {
            case posix
            case windows
        }
        """
        let findings = Lint.Rule.Platform.DeadCasePerPlatform.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "dead_case_per_platform_enum")
        }
    }

    @Test
    func `utf8 utf16 enum is flagged`() {
        let source = """
        public enum Encoding {
            case utf8
            case utf16
        }
        """
        let findings = Lint.Rule.Platform.DeadCasePerPlatform.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Platform.DeadCasePerPlatform.Test.`Edge Case` {
    @Test
    func `domain alternatives enum is NOT flagged`() {
        let source = """
        public enum URLScheme {
            case http
            case https
            case ftp
        }
        """
        let findings = Lint.Rule.Platform.DeadCasePerPlatform.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal enum is NOT flagged`() {
        let source = """
        internal enum RawEncoding {
            case posix
            case windows
        }
        """
        let findings = Lint.Rule.Platform.DeadCasePerPlatform.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

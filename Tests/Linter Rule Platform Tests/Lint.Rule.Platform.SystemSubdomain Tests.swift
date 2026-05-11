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

extension Lint.Rule.Platform.SystemSubdomain {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.SystemSubdomain.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.SystemSubdomain().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.SystemSubdomain.Test.Unit {
    @Test
    func `extension Darwin dot System is flagged`() {
        let source = """
        extension Darwin.System {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "platform_system_subdomain")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `extension Linux with nested enum System is flagged`() {
        let source = """
        extension Linux {
            public enum System {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enum Windows with nested enum System is flagged`() {
        let source = """
        public enum Windows {
            public enum System {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `both extension forms in one file flagged twice`() {
        let source = """
        extension Darwin.System {}
        extension Linux.System {}
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Platform.SystemSubdomain.Test.`Edge Case` {
    @Test
    func `extension System is NOT flagged`() {
        let source = """
        extension System {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension Darwin with non-System subdomain is NOT flagged`() {
        let source = """
        extension Darwin {
            public enum Kernel {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `file-scope enum System is NOT flagged`() {
        let source = """
        public enum System {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-platform parent with enum System is NOT flagged`() {
        let source = """
        public enum Foo {
            public enum System {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension Darwin dot Kernel is NOT flagged`() {
        let source = """
        extension Darwin.Kernel {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.Platform.SystemSubdomain.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

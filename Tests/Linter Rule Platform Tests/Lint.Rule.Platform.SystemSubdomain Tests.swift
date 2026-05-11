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
    struct `system subdomain Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`system subdomain Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`system subdomain`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`system subdomain Tests`.Unit {
    @Test
    func `extension Darwin dot System is flagged`() {
        let source = """
        extension Darwin.System {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
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
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enum Windows with nested enum System is flagged`() {
        let source = """
        public enum Windows {
            public enum System {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `both extension forms in one file flagged twice`() {
        let source = """
        extension Darwin.System {}
        extension Linux.System {}
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`system subdomain Tests`.`Edge Case` {
    @Test
    func `extension System is NOT flagged`() {
        let source = """
        extension System {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension Darwin with non-System subdomain is NOT flagged`() {
        let source = """
        extension Darwin {
            public enum Kernel {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `file-scope enum System is NOT flagged`() {
        let source = """
        public enum System {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-platform parent with enum System is NOT flagged`() {
        let source = """
        public enum Foo {
            public enum System {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension Darwin dot Kernel is NOT flagged`() {
        let source = """
        extension Darwin.Kernel {
            public static func op() {}
        }
        """
        let findings = Lint.Rule.`system subdomain Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

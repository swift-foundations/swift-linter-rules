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
@testable import Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `lifecycle typealias review Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`lifecycle typealias review Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`lifecycle typealias review`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`lifecycle typealias review Tests`.Unit {
    @Test
    func `typealias Error to Async dot Lifecycle dot Error is flagged`() {
        let source = """
        extension Channel {
            public typealias Error = Async.Lifecycle.Error
        }
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "lifecycle_typealias_review")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `typealias Error to Pool dot Lifecycle dot Error is flagged`() {
        let source = """
        public typealias Error = Pool.Lifecycle.Error
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `typealias Error to bare Lifecycle dot Error is flagged`() {
        let source = """
        typealias Error = Lifecycle.Error
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`lifecycle typealias review Tests`.`Edge Case` {
    @Test
    func `typealias Error to concrete enum is NOT flagged`() {
        let source = """
        typealias Error = ChannelError
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to non-Error final member is NOT flagged`() {
        let source = """
        typealias Lifecycle = Async.Lifecycle
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias E (non-Error name) to lifecycle error is NOT flagged`() {
        // [API-ERR-008] is keyed on the per-primitive convention where the
        // alias name is `Error`. Non-conforming names are out of scope.
        let source = """
        typealias E = Async.Lifecycle.Error
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias Error to non-lifecycle Error is NOT flagged`() {
        let source = """
        typealias Error = Domain.Submission.Error
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested namespace before Lifecycle is flagged`() {
        let source = """
        typealias Error = Module.Async.Lifecycle.Error
        """
        let findings = Lint.Rule.`lifecycle typealias review Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

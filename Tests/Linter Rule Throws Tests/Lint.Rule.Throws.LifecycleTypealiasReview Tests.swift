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
@testable import Linter_Rule_Throws

extension Lint.Rule.Throws.LifecycleTypealiasReview {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Throws.LifecycleTypealiasReview.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Throws.LifecycleTypealiasReview().findings(in: parsed)
    }
}

extension Lint.Rule.Throws.LifecycleTypealiasReview.Test.Unit {
    @Test
    func `typealias Error to Async dot Lifecycle dot Error is flagged`() {
        let source = """
        extension Channel {
            public typealias Error = Async.Lifecycle.Error
        }
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
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
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `typealias Error to bare Lifecycle dot Error is flagged`() {
        let source = """
        typealias Error = Lifecycle.Error
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Throws.LifecycleTypealiasReview.Test.`Edge Case` {
    @Test
    func `typealias Error to concrete enum is NOT flagged`() {
        let source = """
        typealias Error = ChannelError
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias to non-Error final member is NOT flagged`() {
        let source = """
        typealias Lifecycle = Async.Lifecycle
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias E (non-Error name) to lifecycle error is NOT flagged`() {
        // [API-ERR-008] is keyed on the per-primitive convention where the
        // alias name is `Error`. Non-conforming names are out of scope.
        let source = """
        typealias E = Async.Lifecycle.Error
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias Error to non-lifecycle Error is NOT flagged`() {
        let source = """
        typealias Error = Domain.Submission.Error
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested namespace before Lifecycle is flagged`() {
        let source = """
        typealias Error = Module.Async.Lifecycle.Error
        """
        let findings = Lint.Rule.Throws.LifecycleTypealiasReview.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

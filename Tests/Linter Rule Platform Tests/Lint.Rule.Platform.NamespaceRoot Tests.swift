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

extension Lint.Rule.Platform.NamespaceRoot {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.NamespaceRoot.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.NamespaceRoot().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.NamespaceRoot.Test.Unit {
    @Test
    func `LinuxKernel compound name is flagged`() {
        let source = """
        public enum LinuxKernel {}
        """
        let findings = Lint.Rule.Platform.NamespaceRoot.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "namespace_root_compound_platform")
        }
    }

    @Test
    func `KqueueEventNotification compound name is flagged`() {
        let source = """
        public enum KqueueEventNotification {}
        """
        let findings = Lint.Rule.Platform.NamespaceRoot.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Platform.NamespaceRoot.Test.`Edge Case` {
    @Test
    func `Kernel namespace alone is NOT flagged`() {
        let source = """
        public enum Kernel {}
        """
        let findings = Lint.Rule.Platform.NamespaceRoot.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Kernel is NOT flagged`() {
        let source = """
        extension Kernel.IO {
            public enum Uring {}
        }
        """
        let findings = Lint.Rule.Platform.NamespaceRoot.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested type inside enum is NOT flagged`() {
        let source = """
        public enum Outer {
            public enum LinuxKernel {}
        }
        """
        let findings = Lint.Rule.Platform.NamespaceRoot.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

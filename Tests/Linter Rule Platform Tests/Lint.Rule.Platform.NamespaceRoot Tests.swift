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
    struct `compound platform namespace root Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`compound platform namespace root Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`compound platform namespace root`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`compound platform namespace root Tests`.Unit {
    @Test
    func `LinuxKernel compound name is flagged`() {
        let source = """
        public enum LinuxKernel {}
        """
        let findings = Lint.Rule.`compound platform namespace root Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "compound platform namespace root")
        }
    }

    @Test
    func `KqueueEventNotification compound name is flagged`() {
        let source = """
        public enum KqueueEventNotification {}
        """
        let findings = Lint.Rule.`compound platform namespace root Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`compound platform namespace root Tests`.`Edge Case` {
    @Test
    func `Kernel namespace alone is NOT flagged`() {
        let source = """
        public enum Kernel {}
        """
        let findings = Lint.Rule.`compound platform namespace root Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Kernel is NOT flagged`() {
        let source = """
        extension Kernel.IO {
            public enum Uring {}
        }
        """
        let findings = Lint.Rule.`compound platform namespace root Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested type inside enum is NOT flagged`() {
        let source = """
        public enum Outer {
            public enum LinuxKernel {}
        }
        """
        let findings = Lint.Rule.`compound platform namespace root Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

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
@testable import Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `unsafe assignment granularity Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`unsafe assignment granularity Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unsafe assignment granularity`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`unsafe assignment granularity Tests`.Unit {
    @Test
    func `self assignment with RHS-only unsafe is flagged`() {
        let source = """
        func op() {
            self.raw = unsafe Unmanaged.passRetained(x).toOpaque()
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "unsafe_assignment_granularity")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `subscript assignment with RHS-only unsafe is flagged`() {
        let source = """
        func op() {
            buffer[i] = unsafe pointer.pointee
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending assignments each flagged`() {
        let source = """
        func op() {
            self.a = unsafe x.deref()
            self.b = unsafe y.deref()
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`unsafe assignment granularity Tests`.`Edge Case` {
    @Test
    func `unsafe wrapping entire assignment is NOT flagged`() {
        let source = """
        func op() {
            unsafe (self.raw = Unmanaged.passRetained(x).toOpaque())
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `let binding with unsafe initializer is NOT flagged`() {
        // Binding-initializer is a different shape from assignment; the
        // `let` boundary covers the destination implicitly.
        let source = """
        func op() {
            let x = unsafe pointer.pointee
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare unsafe expression is NOT flagged`() {
        let source = """
        func op() {
            unsafe pointer.pointee
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `assignment with non-unsafe RHS is NOT flagged`() {
        let source = """
        func op() {
            self.a = 0
            self.b = compute()
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `var binding with unsafe initializer is NOT flagged`() {
        let source = """
        func op() {
            var x = unsafe pointer.pointee
            x = 0
        }
        """
        let findings = Lint.Rule.`unsafe assignment granularity Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

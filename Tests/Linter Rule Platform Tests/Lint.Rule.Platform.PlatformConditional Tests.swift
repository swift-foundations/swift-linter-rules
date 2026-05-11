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
    struct `canimport conditional Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`canimport conditional Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`canimport conditional`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`canimport conditional Tests`.Unit {
    @Test
    func `canImport Darwin Kernel Standard is flagged`() {
        let source = """
        #if canImport(Darwin_Kernel_Standard)
        import Darwin_Kernel_Standard
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "platform_canimport_conditional")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `canImport bare Darwin is flagged`() {
        let source = """
        #if canImport(Darwin)
        import Darwin
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Linux underscored is flagged`() {
        let source = """
        #if canImport(Linux_Kernel)
        import Linux_Kernel
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Glibc is flagged`() {
        let source = """
        #if canImport(Glibc)
        import Glibc
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `canImport Windows in elseif is flagged`() {
        let source = """
        #if os(macOS)
        import Foundation
        #elseif canImport(Windows_Kernel)
        import Windows_Kernel
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`canimport conditional Tests`.`Edge Case` {
    @Test
    func `if os macOS is NOT flagged`() {
        let source = """
        #if os(macOS)
        let x = 1
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport SwiftUI is NOT flagged`() {
        let source = """
        #if canImport(SwiftUI)
        import SwiftUI
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `canImport Combine is NOT flagged`() {
        let source = """
        #if canImport(Combine)
        import Combine
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `os check with multiple platforms is NOT flagged`() {
        let source = """
        #if os(macOS) || os(iOS) || os(tvOS)
        import Darwin_Kernel_Standard
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-canImport function call is NOT flagged`() {
        // Plain `#if` with arbitrary expression — not relevant to rule.
        let source = """
        #if DEBUG
        let x = 1
        #endif
        """
        let findings = Lint.Rule.`canimport conditional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

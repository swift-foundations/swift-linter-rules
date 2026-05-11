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
@testable import Linter_Rule_Structure

extension Lint.Rule.Structure.WrapperBackingExposed {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.WrapperBackingExposed.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.WrapperBackingExposed().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.WrapperBackingExposed.Test.Unit {
    @Test
    func `default-internal _backing in struct is flagged`() {
        let source = """
        public struct Lane {
            let _backing: IO.Blocking.Lane
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "wrapper_backing_exposed")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `explicit internal _wrapped in actor is flagged`() {
        let source = """
        public actor Box {
            internal var _wrapped: Underlying
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `package _underlying in class is flagged`() {
        let source = """
        class Wrapper {
            package var _underlying: Storage
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Structure.WrapperBackingExposed.Test.`Edge Case` {
    @Test
    func `private _backing is NOT flagged`() {
        let source = """
        struct Lane {
            private let _backing: IO.Blocking.Lane
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fileprivate _wrapped is NOT flagged`() {
        let source = """
        struct Wrapper {
            fileprivate var _wrapped: Underlying
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `usableFromInline _backing is NOT flagged`() {
        let source = """
        public struct Lane {
            @usableFromInline
            var _backing: IO.Blocking.Lane
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-tracked underscore name is NOT flagged`() {
        let source = """
        struct S {
            var _other: Int
            var _internal: String
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `_backing at file scope is NOT flagged`() {
        let source = """
        let _backing = 0
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `_backing in protocol is NOT flagged`() {
        // Protocols declare requirements; backing-property convention
        // does not apply to protocol requirements.
        let source = """
        protocol P {
            var _backing: Underlying { get }
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-tracked names like backing without underscore are NOT flagged`() {
        let source = """
        struct S {
            var backing: Underlying
            var wrapped: Other
        }
        """
        let findings = Lint.Rule.Structure.WrapperBackingExposed.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

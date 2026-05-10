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

extension Lint.Rule.Structure.InlinableInternalAccess {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.InlinableInternalAccess.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.InlinableInternalAccess().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.InlinableInternalAccess.Test.Unit {
    @Test
    func `inlinable internal func is flagged`() {
        let source = """
        @inlinable
        func foo() {}
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `inlinable public func is permitted`() {
        let source = """
        @inlinable
        public func foo() {}
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable package func is permitted`() {
        let source = """
        @inlinable
        package func foo() {}
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable usableFromInline func is permitted`() {
        let source = """
        @inlinable @usableFromInline
        func foo() {}
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable internal var is flagged`() {
        let source = """
        @inlinable
        var x: Int { 1 }
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `inlinable public var is permitted`() {
        let source = """
        @inlinable
        public var x: Int { 1 }
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable internal init is flagged`() {
        let source = """
        struct S {
            @inlinable
            init() {}
        }
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Structure.InlinableInternalAccess.Test.`Edge Case` {
    @Test
    func `non-inlinable internal func is not flagged`() {
        let source = "func foo() {}"
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `inlinable open func is permitted`() {
        let source = """
        @inlinable
        open func foo() {}
        """
        let findings = Lint.Rule.Structure.InlinableInternalAccess.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

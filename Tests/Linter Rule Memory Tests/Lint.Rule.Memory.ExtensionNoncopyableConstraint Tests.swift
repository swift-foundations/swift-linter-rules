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
@testable import Linter_Rule_Memory

extension Lint.Rule.Memory.ExtensionNoncopyableConstraint {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.ExtensionNoncopyableConstraint().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.Unit {
    @Test
    func `extension with consuming method but no constraint is flagged`() {
        let source = """
        extension Container {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming method and noncopyable constraint is permitted`() {
        let source = """
        extension Container where Element: ~Copyable {
            consuming func transfer() {}
        }
        """
        let findings = Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with no ownership-affecting members is not flagged`() {
        let source = """
        extension Container {
            func describe() -> String { "" }
        }
        """
        let findings = Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with borrowing method but no constraint is flagged`() {
        let source = """
        extension Container {
            borrowing func peek() {}
        }
        """
        let findings = Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with consuming parameter but no constraint is flagged`() {
        let source = """
        extension Pipe {
            func push(_ token: consuming Token) {}
        }
        """
        let findings = Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension with where clause containing noncopyable on a different generic param is permitted`() {
        let source = """
        extension Pair where Left: ~Copyable {
            consuming func split() {}
        }
        """
        let findings = Lint.Rule.Memory.ExtensionNoncopyableConstraint.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

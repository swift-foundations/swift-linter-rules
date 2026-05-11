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

extension Lint.Rule.Memory.StructSendableClassMember {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Memory.StructSendableClassMember.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.StructSendableClassMember().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.StructSendableClassMember.Test.Unit {
    @Test
    func `struct unchecked Sendable with NSObject member is flagged`() {
        let source = """
        struct Wrapper: @unchecked Sendable {
            var inner: NSObject
        }
        """
        let findings = Lint.Rule.Memory.StructSendableClassMember.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "struct_sendable_class_member")
        }
    }

    @Test
    func `struct unchecked Sendable with Class-suffix member is flagged`() {
        let source = """
        struct Wrapper: @unchecked Sendable {
            var inner: PayloadClass
        }
        """
        let findings = Lint.Rule.Memory.StructSendableClassMember.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Memory.StructSendableClassMember.Test.`Edge Case` {
    @Test
    func `plain Sendable struct is NOT flagged`() {
        let source = """
        struct Wrapper: Sendable {
            var inner: NSObject
        }
        """
        let findings = Lint.Rule.Memory.StructSendableClassMember.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct without Sendable is NOT flagged`() {
        let source = """
        struct Wrapper {
            var inner: NSObject
        }
        """
        let findings = Lint.Rule.Memory.StructSendableClassMember.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with value-typed member is NOT flagged`() {
        let source = """
        struct Wrapper: @unchecked Sendable {
            var count: Int
            var name: String
        }
        """
        let findings = Lint.Rule.Memory.StructSendableClassMember.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

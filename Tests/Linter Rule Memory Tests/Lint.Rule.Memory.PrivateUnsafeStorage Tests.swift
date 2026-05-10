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

extension Lint.Rule.Memory.PrivateUnsafeStorage {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Lint.Rule.Memory.PrivateUnsafeStorage.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Memory.PrivateUnsafeStorage().findings(in: parsed)
    }
}

extension Lint.Rule.Memory.PrivateUnsafeStorage.Test.Unit {
    @Test
    func `public unsafe pointer property is flagged`() {
        let source = """
        struct Buffer {
            public let storage: UnsafeMutablePointer<UInt8>
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `private unsafe pointer property is permitted`() {
        let source = """
        struct Buffer {
            private let storage: UnsafeMutablePointer<UInt8>
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal unsafe pointer property is permitted`() {
        let source = """
        struct Buffer {
            let storage: UnsafeMutablePointer<UInt8>
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public unsafe pointer with unsafe attr is permitted`() {
        let source = """
        struct Buffer {
            @unsafe public let storage: UnsafeMutablePointer<UInt8>
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public non-pointer property is not flagged`() {
        let source = """
        struct Foo {
            public let count: Int
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `optional unsafe pointer property still flagged`() {
        let source = """
        struct Buffer {
            public let storage: UnsafeMutablePointer<UInt8>?
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple unsafe pointer types in allowlist`() {
        let source = """
        struct Buffer {
            public let raw: UnsafeRawPointer
            public let mutableRaw: UnsafeMutableRawPointer
            public let buf: UnsafeBufferPointer<UInt8>
        }
        """
        let findings = Lint.Rule.Memory.PrivateUnsafeStorage.Test.findings(in: source)
        #expect(findings.count == 3)
    }
}

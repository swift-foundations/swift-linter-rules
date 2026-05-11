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

extension Lint.Rule.Platform.CTypeInPublicAPI {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.CTypeInPublicAPI.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.CTypeInPublicAPI().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.CTypeInPublicAPI.Test.Unit {
    @Test
    func `public func with kevent parameter is flagged`() {
        let source = """
        public func register(events: [kevent]) -> Int { 0 }
        """
        let findings = Lint.Rule.Platform.CTypeInPublicAPI.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "c_type_in_public_api")
        }
    }

    @Test
    func `public func with HANDLE return type is flagged`() {
        let source = """
        public func open() -> HANDLE { fatalError() }
        """
        let findings = Lint.Rule.Platform.CTypeInPublicAPI.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public init with epoll_event parameter is flagged`() {
        let source = """
        public struct Foo {
            public init(event: epoll_event) {}
        }
        """
        let findings = Lint.Rule.Platform.CTypeInPublicAPI.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Platform.CTypeInPublicAPI.Test.`Edge Case` {
    @Test
    func `internal func with C type is NOT flagged`() {
        let source = """
        internal func raw(event: kevent) {}
        """
        let findings = Lint.Rule.Platform.CTypeInPublicAPI.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public func with ecosystem types is NOT flagged`() {
        let source = """
        public func register(events: [Kernel.Kqueue.Event]) {}
        """
        let findings = Lint.Rule.Platform.CTypeInPublicAPI.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

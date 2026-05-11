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

extension Lint.Rule.Structure.HoistedProtocolAlias {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.HoistedProtocolAlias.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.HoistedProtocolAlias().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.HoistedProtocolAlias.Test.Unit {
    @Test
    func `self-referential conformance via typealias path is flagged`() {
        let source = """
        extension Parser.Error.Located: Parser.Error.Located.Protocol {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "hoisted_protocol_self_conformance")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `nested type self-conformance is flagged`() {
        let source = """
        extension Foo.Bar: Foo.Bar.Protocol {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare type self-conformance is flagged`() {
        let source = """
        extension X: X.Protocol {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Structure.HoistedProtocolAlias.Test.`Edge Case` {
    @Test
    func `consumer module conformance via typealias is NOT flagged`() {
        let source = """
        extension MyError: Parser.Error.Located.Protocol {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `declaring module using hoisted name is NOT flagged`() {
        let source = """
        extension Parser.Error.Located: _LocatedErrorProtocol {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Sendable conformance is NOT flagged`() {
        let source = """
        extension Parser.Error.Located: Sendable {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with no inheritance is NOT flagged`() {
        let source = """
        extension Parser.Error.Located {
            func op() {}
        }
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `multiple inheritance with one self-Protocol is flagged for that one`() {
        let source = """
        extension Foo: Sendable, Foo.Protocol, Hashable {}
        """
        let findings = Lint.Rule.Structure.HoistedProtocolAlias.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

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

extension Lint.Rule.Structure.TypeTransformPlacement {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.TypeTransformPlacement.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.TypeTransformPlacement().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.TypeTransformPlacement.Test.Unit {
    @Test
    func `toFoo returning Foo is flagged`() {
        let source = """
        extension Source {
            public func toFoo() -> Foo { fatalError() }
        }
        """
        let findings = Lint.Rule.Structure.TypeTransformPlacement.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "type_transform_placement")
        }
    }

    @Test
    func `asBar returning Bar is flagged`() {
        let source = """
        extension Source {
            public func asBar() -> Bar { fatalError() }
        }
        """
        let findings = Lint.Rule.Structure.TypeTransformPlacement.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Structure.TypeTransformPlacement.Test.`Edge Case` {
    @Test
    func `static method is NOT flagged`() {
        let source = """
        extension Foo {
            public static func from(_ source: Source) -> Foo { fatalError() }
        }
        """
        let findings = Lint.Rule.Structure.TypeTransformPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `toString convention method is NOT flagged when return is different`() {
        let source = """
        extension Foo {
            public func toRepresentation() -> Bar { fatalError() }
        }
        """
        let findings = Lint.Rule.Structure.TypeTransformPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `method without to or as prefix is NOT flagged`() {
        let source = """
        extension Foo {
            public func describe() -> Bar { fatalError() }
        }
        """
        let findings = Lint.Rule.Structure.TypeTransformPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

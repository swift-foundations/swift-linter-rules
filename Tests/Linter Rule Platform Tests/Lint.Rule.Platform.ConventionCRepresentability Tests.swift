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

extension Lint.Rule.Platform.ConventionCRepresentability {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.ConventionCRepresentability.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.ConventionCRepresentability().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.ConventionCRepresentability.Test.Unit {
    @Test
    func `convention c with UnsafeMutablePointer to qualified type is flagged`() {
        let source = """
        let cb: @convention(c) (UnsafeMutablePointer<Kernel.Signal.Information>?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "convention_c_representability")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `convention c with UnsafePointer to qualified type is flagged`() {
        let source = """
        let cb: @convention(c) (UnsafePointer<Foo.Bar>?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple unsafe-pointer-to-qualified parameters each flagged`() {
        let source = """
        let cb: @convention(c) (UnsafeMutablePointer<Foo.Bar>?, UnsafeMutablePointer<Baz.Qux>?) -> Void = { _, _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Platform.ConventionCRepresentability.Test.`Edge Case` {
    @Test
    func `convention c with OpaquePointer is NOT flagged`() {
        let source = """
        let cb: @convention(c) (OpaquePointer?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutableRawPointer is NOT flagged`() {
        let source = """
        let cb: @convention(c) (UnsafeMutableRawPointer?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with UnsafeMutablePointer to primitive Int32 is NOT flagged`() {
        let source = """
        let cb: @convention(c) (UnsafeMutablePointer<Int32>?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-convention-c function type with same pointer is NOT flagged`() {
        let source = """
        let cb: (UnsafeMutablePointer<Foo.Bar>?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention swift with qualified pointer is NOT flagged`() {
        let source = """
        let cb: @convention(swift) (UnsafeMutablePointer<Foo.Bar>?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `convention c with cType variant is also matched`() {
        let source = """
        let cb: @convention(c, cType: "void (*)(int *)") (UnsafeMutablePointer<Foo.Bar>?) -> Void = { _ in }
        """
        let findings = Lint.Rule.Platform.ConventionCRepresentability.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

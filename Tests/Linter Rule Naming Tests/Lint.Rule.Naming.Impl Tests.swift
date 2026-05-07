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
@testable import Linter_Rule_Naming

extension Lint.Rule.Naming.Impl {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Naming.Impl.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Lint.Finding] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Naming.Impl().findings(in: parsed)
    }
}

extension Lint.Rule.Naming.Impl.Test.Unit {
    @Test
    func `let impl is flagged`() {
        let source = "let impl = make()"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "var_named_impl")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `var impl is flagged`() {
        let source = "var impl = make()"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let _impl is flagged`() {
        let source = "let _impl = make()"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let impl with type annotation is flagged`() {
        let source = "let impl: Actor = Actor()"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let impl inside function body is flagged`() {
        let source = """
        func setup() {
            let impl = factory()
            _ = impl
        }
        """
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple impl bindings are all flagged`() {
        let source = """
        let impl = a()
        var _impl = b()
        let impl2: Int = 0
        _ = impl2
        """
        // `impl2` is NOT flagged (substring match disallowed). 2 hits expected.
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Naming.Impl.Test.`Edge Case` {
    @Test
    func `let implementation is NOT flagged`() {
        let source = "let implementation = make()"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `let implOf is NOT flagged`() {
        let source = "let implOf = make()"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `func parameter named impl is NOT flagged`() {
        // The rule targets variable bindings, not function parameters.
        let source = "func f(impl: Int) -> Int { impl }"
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `impl in a string literal is NOT flagged`() {
        let source = "let s = \"let impl = make()\""
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.Naming.Impl.Test.findings(in: "")
        #expect(findings.isEmpty)
    }
}

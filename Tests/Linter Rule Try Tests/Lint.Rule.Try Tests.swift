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
@testable import Linter_Rule_Try

extension Lint.Rule {
    @Suite
    struct `try optional Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`try optional Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(
            file: manager.file(for: id),
            path: Lint.Source.Path(file),
            tree: tree,
            converter: converter
        )
        return Lint.Rule.`try optional`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`try optional Tests`.Unit {
    @Test
    func `try? at top level is flagged`() {
        let source = "let x = try? throwingCall()"
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "try_optional")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `try? inside function body is flagged`() {
        let source = """
        func read() {
            let result = try? parse()
            _ = result
        }
        """
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple try? sites are all flagged`() {
        let source = """
        let a = try? f()
        let b = try? g()
        let c = try? h()
        """
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `try? as a discarded expression is flagged`() {
        let source = "_ = try? cleanup()"
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested try? inside method chain is flagged`() {
        let source = "let x = (try? loader.load())?.result"
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `custom severity is honored`() {
        let source = "let x = try? f()"
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: "test.swift", tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: "test.swift", filePath: "test.swift", content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(
            file: manager.file(for: id),
            path: "test.swift",
            tree: tree,
            converter: converter
        )
        let findings = Lint.Rule.`try optional`.findings(parsed, .error)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

extension Lint.Rule.`try optional Tests`.`Edge Case` {
    @Test
    func `try without ? or ! is NOT flagged`() {
        let source = """
        do {
            let x = try f()
            _ = x
        } catch {
            _ = error
        }
        """
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try! is NOT flagged`() {
        let source = "let x = try! f()"
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try? in a string literal is NOT flagged`() {
        let source = "let s = \"let x = try? f()\""
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try? in a comment is NOT flagged`() {
        let source = """
        // let x = try? f()
        let y = 42
        """
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`try optional Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `try? in closure body is flagged`() {
        let source = """
        let action = { () -> Int? in
            return try? f()
        }
        _ = action
        """
        let findings = Lint.Rule.`try optional Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

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
@testable import Linter_Rule_Throws

extension Lint.Rule.Throws.DoCatchTyped {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Throws.DoCatchTyped.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Throws.DoCatchTyped().findings(in: parsed)
    }
}

extension Lint.Rule.Throws.DoCatchTyped.Test.Unit {
    @Test
    func `bare do try catch is flagged`() {
        let source = """
        func f() {
            do {
                try x()
            } catch {
                print(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `do throws(E) try catch is permitted`() {
        let source = """
        func f() {
            do throws(MyError) {
                try x()
            } catch {
                print(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do without try is not flagged`() {
        let source = """
        func f() {
            do {
                let x = 1
                _ = x
            } catch {}
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do without catch is not flagged`() {
        let source = """
        func f() {
            do {
                try x()
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.Throws.DoCatchTyped.Test.`Edge Case` {
    @Test
    func `nested do-catch tracked independently`() {
        // Outer do has no direct `try` (the inner do scopes its own try),
        // so the outer is not flagged. Inner is already typed.
        let source = """
        func f() {
            do {
                do throws(MyError) {
                    try x()
                } catch {
                    print(error)
                }
            } catch {
                print(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `outer do flagged when it contains a direct try plus an inner typed do`() {
        let source = """
        func f() {
            do {
                try y()
                do throws(MyError) {
                    try x()
                } catch {}
            } catch {}
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `top-level do try catch is flagged`() {
        let source = """
        do {
            try x()
        } catch {}
        """
        let findings = Lint.Rule.Throws.DoCatchTyped.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

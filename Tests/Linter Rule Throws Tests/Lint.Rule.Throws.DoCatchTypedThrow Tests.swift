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

extension Lint.Rule.Throws.DoCatchTypedThrow {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Throws.DoCatchTypedThrow.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Throws.DoCatchTypedThrow().findings(in: parsed)
    }
}

extension Lint.Rule.Throws.DoCatchTypedThrow.Test.Unit {
    @Test
    func `bare do throw catch is flagged`() {
        let source = """
        func f() {
            do {
                throw MyError.bar
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "do_throws_e_for_typed_catch_throw")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `throw nested in if is flagged`() {
        let source = """
        func f(_ cond: Bool) {
            do {
                if cond {
                    throw MyError.bar
                }
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple bare do throw blocks all flagged`() {
        let source = """
        func f() {
            do { throw A.x } catch { handle(error) }
            do { throw B.y } catch { handle(error) }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Throws.DoCatchTypedThrow.Test.`Edge Case` {
    @Test
    func `typed do throw catch is NOT flagged`() {
        let source = """
        func f() {
            do throws(MyError) {
                throw .bar
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do with try (no throw) is NOT flagged - handled by DoCatchTyped`() {
        let source = """
        func f() {
            do {
                try foo()
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do with both try and throw is NOT flagged here - DoCatchTyped covers it`() {
        let source = """
        func f() {
            do {
                try foo()
                throw MyError.x
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do throw without catch is NOT flagged`() {
        let source = """
        func f() throws {
            do {
                throw MyError.x
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throw inside nested closure is NOT flagged at outer do`() {
        let source = """
        func f() {
            do {
                let _ = { throw MyError.x }
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throw inside nested do is NOT counted toward outer do`() {
        let source = """
        func f() {
            do {
                do throws(MyError) {
                    throw .x
                } catch {
                    handle(error)
                }
            } catch {
                handle(error)
            }
        }
        """
        let findings = Lint.Rule.Throws.DoCatchTypedThrow.Test.findings(in: source)
        // Outer do has no direct throw; inner do has throw but already typed.
        // Neither should be flagged.
        #expect(findings.isEmpty)
    }
}

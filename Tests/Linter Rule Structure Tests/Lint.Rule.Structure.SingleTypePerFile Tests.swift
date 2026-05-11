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
import Linter_Rules_Test_Support
@testable import Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `single type per file Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`single type per file Tests` {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`single type per file`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`single type per file Tests`.Unit {
    @Test
    func `single struct is permitted`() {
        let source = "struct Foo {}"
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single class is permitted`() {
        let findings = Lint.Rule.`single type per file Tests`.findings(in: "class Foo {}")
        #expect(findings.isEmpty)
    }

    @Test
    func `single enum is permitted`() {
        let findings = Lint.Rule.`single type per file Tests`.findings(in: "enum Foo {}")
        #expect(findings.isEmpty)
    }

    @Test
    func `single actor is permitted`() {
        let findings = Lint.Rule.`single type per file Tests`.findings(in: "actor Foo {}")
        #expect(findings.isEmpty)
    }

    @Test
    func `single protocol is permitted`() {
        let findings = Lint.Rule.`single type per file Tests`.findings(in: "protocol Foo {}")
        #expect(findings.isEmpty)
    }

    @Test
    func `two structs are flagged - second only`() {
        let source = """
        struct Foo {}
        struct Bar {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "single type per file")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `three top-level types flag the second and third`() {
        let source = """
        struct Foo {}
        enum Bar {}
        class Baz {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `mixed type kinds at file scope - second flagged`() {
        let source = """
        protocol P {}
        actor A {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`single type per file Tests`.`Edge Case` {
    @Test
    func `extension declarations are permitted alongside one type`() {
        let source = """
        struct Foo {
            let x: Int
        }
        extension Foo {
            func y() {}
        }
        extension Foo: Sendable {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested types do NOT count as additional file-scope types`() {
        let source = """
        struct Foo {
            struct Bar {}
            enum Baz {
                case a
            }
            class Qux {}
        }
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Tests path scope-excluded - multiple types permitted`() {
        let source = """
        struct A {}
        struct B {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(
            in: source,
            file: "Tests/Foo Tests/Test Fixtures.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Experiments path scope-excluded`() {
        let source = """
        enum X {}
        enum Y {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(
            in: source,
            file: "Experiments/Foo/main.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Examples path scope-excluded`() {
        let source = """
        struct A {}
        struct B {}
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(
            in: source,
            file: "Examples/Demo/Main.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `extension with nested type does not count as file-scope type`() {
        let source = """
        struct Foo {}
        extension Foo {
            struct Bar {}
        }
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty file produces no findings`() {
        let findings = Lint.Rule.`single type per file Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    @Test
    func `only-extensions file produces no findings`() {
        let source = """
        extension String {
            var doubled: String { self + self }
        }
        extension Int {
            var twice: Int { self * 2 }
        }
        """
        let findings = Lint.Rule.`single type per file Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

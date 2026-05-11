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

extension Lint.Rule.Structure.MinimalTypeBody {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.MinimalTypeBody.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.MinimalTypeBody().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.MinimalTypeBody.Test.Unit {
    @Test
    func `method in type body is flagged`() {
        let source = """
        struct Buffer {
            var x: Int
            func append(_ value: Int) {}
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "minimal_type_body")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `computed property in type body is flagged`() {
        let source = """
        struct State {
            var raw: Int
            var isEmpty: Bool { raw == 0 }
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `static member is flagged`() {
        let source = """
        struct Foo {
            var x: Int
            static let shared = Foo(x: 0)
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested struct in type body is flagged`() {
        let source = """
        struct Outer {
            var x: Int
            struct Inner {}
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `typealias in type body is flagged`() {
        let source = """
        struct Foo {
            var x: Int
            typealias Element = Int
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending members each flagged`() {
        let source = """
        struct Foo {
            var x: Int
            func a() {}
            var computed: Int { x }
            static let shared = 0
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.Structure.MinimalTypeBody.Test.`Edge Case` {
    @Test
    func `stored properties and init only - NOT flagged`() {
        let source = """
        struct Buffer {
            @usableFromInline
            var storage: Storage

            @usableFromInline
            var count: Int

            @inlinable
            public init() {
                self.storage = Storage()
                self.count = 0
            }
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `class with deinit - NOT flagged`() {
        let source = """
        class Box {
            var x: Int
            init() { self.x = 0 }
            deinit {}
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property with willSet observer - NOT flagged`() {
        let source = """
        struct S {
            var x: Int {
                willSet { print(newValue) }
            }
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property with didSet observer - NOT flagged`() {
        let source = """
        struct S {
            var x: Int {
                didSet { print(oldValue) }
            }
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `enum case is NOT flagged`() {
        let source = """
        enum E {
            case foo
            case bar
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `protocol requirements are out of scope - NOT flagged`() {
        let source = """
        protocol P {
            func op()
            var name: String { get }
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `methods in extension are NOT flagged`() {
        let source = """
        struct Buffer {
            var x: Int
        }
        extension Buffer {
            func op() {}
            var doubled: Int { x * 2 }
        }
        """
        let findings = Lint.Rule.Structure.MinimalTypeBody.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

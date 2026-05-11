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

extension Lint.Rule.Naming.SingleTypeNamespace {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Naming.SingleTypeNamespace.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Naming.SingleTypeNamespace().findings(in: parsed)
    }
}

extension Lint.Rule.Naming.SingleTypeNamespace.Test.Unit {
    @Test
    func `caseless enum with one nested struct is flagged`() {
        let source = """
        public enum Cooperative {
            public struct Executor {}
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "single_type_namespace")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `caseless enum with one nested class is flagged`() {
        let source = """
        enum Polling {
            class Worker {}
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `caseless enum with one nested enum is flagged`() {
        let source = """
        enum Outer {
            enum Inner {
                case x, y
            }
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        // Outer has exactly one nested type (Inner) — flagged.
        // Inner has cases — not flagged.
        #expect(findings.count == 1)
    }

    @Test
    func `nested caseless namespace with one nested type is flagged too`() {
        let source = """
        enum File {
            enum Directory {
                struct Walk {}
            }
        }
        """
        // File has one nested type (Directory) → flagged.
        // Directory has one nested type (Walk) → flagged.
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Naming.SingleTypeNamespace.Test.`Edge Case` {
    @Test
    func `caseless enum with two nested types is NOT flagged`() {
        let source = """
        public enum File {
            public enum Directory {
                public struct Walk {}
                public struct Listing {}
            }
        }
        """
        // File has one nested type (Directory) → flagged.
        // Directory has two nested types → NOT flagged.
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `enum with cases is NOT flagged`() {
        let source = """
        enum State {
            case foo
            case bar
            struct Inner {}
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `caseless enum with method member is NOT flagged`() {
        let source = """
        enum Util {
            struct Inner {}
            static func op() {}
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `caseless enum with only typealias and one type is flagged`() {
        let source = """
        enum Module {
            typealias X = Int
            struct Y {}
        }
        """
        // Typealiases count as sibling labels; one type still flagged.
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `caseless empty enum is NOT flagged`() {
        let source = """
        enum Namespace {}
        """
        // Zero types — not a single-type namespace.
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct namespace with one nested type is NOT flagged`() {
        // Rule scopes to caseless enums; structs/classes are not
        // recognized institute namespaces (they have storage / instances).
        let source = """
        struct Holder {
            struct Inner {}
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `caseless enum with multiple nested types is NOT flagged`() {
        let source = """
        enum File {
            struct Path {}
            struct Walk {}
            enum Directory {}
        }
        """
        let findings = Lint.Rule.Naming.SingleTypeNamespace.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

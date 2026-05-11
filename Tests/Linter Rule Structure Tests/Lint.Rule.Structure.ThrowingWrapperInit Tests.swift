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

extension Lint.Rule.Structure.ThrowingWrapperInit {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Structure.ThrowingWrapperInit.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Structure.ThrowingWrapperInit().findings(in: parsed)
    }
}

extension Lint.Rule.Structure.ThrowingWrapperInit.Test.Unit {
    @Test
    func `throwing init with try-only body is flagged`() {
        let source = """
        struct NonEmpty {
            init(_ raw: [Int]) throws {
                try self.base = Base(raw)
            }
        }
        """
        let findings = Lint.Rule.Structure.ThrowingWrapperInit.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "throwing_wrapper_init_no_validation")
        }
    }
}

extension Lint.Rule.Structure.ThrowingWrapperInit.Test.`Edge Case` {
    @Test
    func `throwing init with additional validation is NOT flagged`() {
        let source = """
        struct NonEmpty {
            init(_ raw: [Int]) throws {
                guard !raw.isEmpty else { throw Error.empty }
                try self.base = Base(raw)
            }
        }
        """
        let findings = Lint.Rule.Structure.ThrowingWrapperInit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing init is NOT flagged`() {
        let source = """
        struct Wrapper {
            init(_ raw: [Int]) {
                self.base = raw
            }
        }
        """
        let findings = Lint.Rule.Structure.ThrowingWrapperInit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

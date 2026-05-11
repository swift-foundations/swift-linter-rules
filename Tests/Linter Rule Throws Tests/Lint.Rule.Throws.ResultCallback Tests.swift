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

extension Lint.Rule.Throws.ResultCallback {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Throws.ResultCallback.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Throws.ResultCallback().findings(in: parsed)
    }
}

extension Lint.Rule.Throws.ResultCallback.Test.Unit {
    @Test
    func `closure parameter taking Result is flagged`() {
        let source = """
        public struct API {
            public init(callback: (Result<Int, MyError>) -> Void) {}
        }
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "callback_result_over_throws_thunk")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `function parameter as closure taking Result is flagged`() {
        let source = """
        func register(_ callback: @escaping (Result<Data, IOError>) -> Bool) {}
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `stored property of closure-of-Result type is flagged`() {
        let source = """
        struct S {
            let onTick: (Result<Int, Error>) -> Void
        }
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `qualified Swift dot Result is flagged`() {
        let source = """
        func op(callback: (Swift.Result<Int, MyError>) -> Void) {}
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.Throws.ResultCallback.Test.`Edge Case` {
    @Test
    func `function returning Result is NOT flagged`() {
        let source = """
        func op() -> Result<Int, MyError> {
            .success(0)
        }
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property of Result type alone is NOT flagged`() {
        let source = """
        struct S {
            let cached: Result<Int, MyError>
        }
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level function parameter typed Result is NOT flagged`() {
        let source = """
        func process(_ outcome: Result<Int, MyError>) {}
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws thunk closure parameter is NOT flagged`() {
        let source = """
        func op(_ wait: () throws(MyError) -> Int) {}
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested closure type carrying Result is flagged`() {
        let source = """
        let f: ((Result<Int, MyError>) -> Void) -> Void = { _ in }
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        // The inner closure (Result<...>) -> Void is one flag; the outer
        // takes a closure (not Result) so no second flag.
        #expect(findings.count == 1)
    }

    @Test
    func `optional closure of Result is flagged`() {
        let source = """
        struct S {
            let onTick: ((Result<Int, Error>) -> Void)?
        }
        """
        let findings = Lint.Rule.Throws.ResultCallback.Test.findings(in: source)
        #expect(findings.count == 1)
    }
}

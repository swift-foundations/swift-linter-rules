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

extension Lint.Rule.Platform.SwiftQualification {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Platform.SwiftQualification.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Platform.SwiftQualification().findings(in: parsed)
    }
}

extension Lint.Rule.Platform.SwiftQualification.Test.Unit {
    @Test
    func `bare some Sequence parameter is flagged`() {
        let source = "func consume(_ bytes: some Sequence<UInt8>) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "swift_protocol_qualification")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `bare Error generic constraint is flagged`() {
        let source = "func parse<E: Error>() throws(E) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Error conformance is flagged`() {
        let source = "enum State: Error {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Sequence in where-clause is flagged`() {
        let source = """
        extension Foo where T: Sequence {
            func bar() {}
        }
        """
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `bare Collection conformance is flagged`() {
        let source = "struct Buffer: Collection {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `composition with bare Sequence flags Sequence only`() {
        // `some Sequence & Sendable` — Sequence flagged, Sendable is not
        // in the shadowed set.
        let source = "func consume(_ bytes: some Sequence & Sendable) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple bare references are all flagged`() {
        let source = """
        func a<T: Sequence>(_ x: T) {}
        func b<E: Error>(_ x: E) {}
        struct C: Collection {}
        """
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.Platform.SwiftQualification.Test.`Edge Case` {
    @Test
    func `qualified Swift dot Sequence is NOT flagged`() {
        let source = "func consume(_ bytes: some Swift.Sequence<UInt8>) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified Swift dot Error generic constraint is NOT flagged`() {
        let source = "func parse<E: Swift.Error>() throws(E) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `member-type MyDomain dot Error throws is NOT flagged`() {
        // `MyDomain.Error` is the project's typed-throws leaf, not the
        // stdlib `Swift.Error` protocol bare. Member-type access is OK.
        let source = "func op() throws(MyDomain.Error) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-shadowed protocol Hashable conformance is NOT flagged`() {
        let source = "struct Foo: Hashable {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Sendable in composition is NOT flagged`() {
        // Sendable is not in the shadowed set (no institute namespace
        // collision). It's exempt.
        let source = "func consume(_ bytes: some Sendable) {}"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Variable binding type Sequence is NOT flagged`() {
        // Out of mechanical scope per rule body (variable bindings).
        let source = "let x: Sequence = fatalError() as Never"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `function-return-type Sequence in non-some position is NOT flagged`() {
        // Plain return-type position (not some/any) is out of scope —
        // typically the type wouldn't even compile (Sequence is a PAT).
        // Document the boundary as edge case.
        let source = "func op() -> Sequence { fatalError() }"
        let findings = Lint.Rule.Platform.SwiftQualification.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

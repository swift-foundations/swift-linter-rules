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
@testable import Linter_Rule_Closure

extension Lint.Rule.Closure.ConfigurationPlacement {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.Closure.ConfigurationPlacement.Test {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.Closure.ConfigurationPlacement().findings(in: parsed)
    }
}

extension Lint.Rule.Closure.ConfigurationPlacement.Test.Unit {
    @Test
    func `Options between two domain parameters is flagged`() {
        let source = """
        func perform(on target: Target, options: Options, mode: Mode) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "configuration_parameter_placement")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Configuration in the middle is flagged`() {
        let source = """
        func op(a: A, configuration: Configuration, b: B) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Context in the middle with trailing closure is flagged`() {
        let source = """
        func op(a: A, context: Context, b: B, body: () -> Void) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple configuration parameters in the middle each flagged`() {
        let source = """
        func op(a: A, options: Options, b: B, context: Context, c: C) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.Closure.ConfigurationPlacement.Test.`Edge Case` {
    @Test
    func `Options at last non-closure position is NOT flagged`() {
        let source = """
        func perform(on target: Target, mode: Mode, options: Options = []) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Options last before trailing closure is NOT flagged`() {
        let source = """
        func perform(on target: Target, mode: Mode, options: Options = [], body: () -> Void) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Configuration at first position is NOT flagged`() {
        let source = """
        init(_ configuration: Configuration = .default, mode: Mode, target: Target) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single configuration parameter is NOT flagged`() {
        let source = """
        init(_ configuration: Configuration = .default) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `two parameters with config first is NOT flagged`() {
        let source = """
        init(options: Options = [], extra: Int) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `two parameters with config last is NOT flagged`() {
        let source = """
        init(extra: Int, options: Options = []) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified Foo dot Options counts as configuration type`() {
        let source = """
        func op(a: A, options: Foo.Options, b: B) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unrelated middle parameter (not config) is NOT flagged`() {
        let source = """
        func op(a: A, mode: Mode, b: B) {}
        """
        let findings = Lint.Rule.Closure.ConfigurationPlacement.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

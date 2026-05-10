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
@testable import Linter_Rule_RawValue

extension Lint.Rule.RawValue.TaggedExtensionPublicInit {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.RawValue.TaggedExtensionPublicInit.Test {
    static func findings(in source: String, file: String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(fileID: file, filePath: file, content: Array(source.utf8))
        let parsed = Lint.Source.Parsed(file: manager.file(for: id), tree: tree, converter: converter)
        return Lint.Rule.RawValue.TaggedExtensionPublicInit().findings(in: parsed)
    }
}

extension Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.Unit {
    @Test
    func `extension on bare Tagged with public init is flagged`() {
        let source = """
        extension Tagged {
            public init(rawValue: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "tagged_rawvalue_extension_public_init")
        }
    }

    @Test
    func `extension on Tagged generic specialization with public init is flagged`() {
        let source = """
        extension Tagged<UserTag, String> {
            public init(_ s: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on Tagged with internal init is permitted`() {
        let source = """
        extension Tagged {
            init(rawValue: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on non-Tagged type with public init is permitted`() {
        let source = """
        extension MyType {
            public init(rawValue: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged with multiple public inits flags each`() {
        let source = """
        extension Tagged {
            public init(_ s: String) { fatalError() }
            public init(value: Int) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `extension on Tagged with public method but no public init is permitted`() {
        let source = """
        extension Tagged {
            public func foo() {}
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.`Edge Case` {
    @Test
    func `extension on qualified Tagging Tagged is flagged`() {
        let source = """
        extension Tagging.Tagged {
            public init(_ s: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on Tagged with where clause is flagged`() {
        let source = """
        extension Tagged where RawValue == String {
            public init(_ s: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on TaggedFoo (compound name) is not flagged`() {
        let source = """
        extension TaggedFoo {
            public init(_ s: String) { fatalError() }
        }
        """
        let findings = Lint.Rule.RawValue.TaggedExtensionPublicInit.Test.findings(in: source)
        #expect(findings.isEmpty)
    }
}

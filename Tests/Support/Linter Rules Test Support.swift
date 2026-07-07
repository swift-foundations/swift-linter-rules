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

public import Byte_Primitives
public import Linter_Primitives
import SwiftParser
import SwiftSyntax

extension Lint.Source {
    /// Build a `Lint.Source.Parsed` from a Swift source string for use
    /// in rule unit tests.
    ///
    /// Each rule pack's tests currently re-implement this lifting flow
    /// (`Source.Manager` register → `Parser.parse` → `SourceLocationConverter`).
    /// This shared factory replaces those copies with one boundary.
    /// Per `feedback_extension_inits_for_test_fixtures` the factory is
    /// expressed as an extension init / static method on the type
    /// being constructed (`Lint.Source.Parsed`) rather than a free
    /// function, so call sites read `Lint.Source.Parsed.test(...)`.
    public static func parsed(
        from source: Swift.String,
        file: Swift.String = "test.swift",
        path: Lint.Source.Path? = nil,
        declaredTypeNames: Swift.Set<Swift.String> = []
    ) -> Lint.Source.Parsed {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var manager = Source.Manager()
        let id = manager.register(
            fileID: file,
            filePath: file,
            content: source.utf8.map(Byte.init)
        )
        return Self.Parsed(
            file: manager.file(for: id),
            path: path ?? Self.Path(file),
            tree: tree,
            converter: converter,
            declaredTypeNames: declaredTypeNames
        )
    }
}

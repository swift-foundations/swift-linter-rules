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

public import Linter_Primitives
internal import SwiftSyntax

/// Wave 4 (mechanization-program) — ad-hoc `_Box` (or `Box` / `_Storage`)
/// reference wrappers reach for ecosystem primitives that already exist.
///
/// Citation: `[IMPL-107]` (implementation skill, ownership.md).
///
/// When authors need value-type indirection (recursive value types,
/// shared mutable buffers, copy-on-write boxes), the institute provides
/// `Reference<T>` / `Owned<T>` in the ownership-primitives ecosystem.
/// Ad-hoc `class _Box<T>` / `class _Storage<T>` reinvent the same
/// wrapper without the ecosystem's ownership-checked guarantees.
///
/// AST shape: a `ClassDeclSyntax` whose name (after stripping a leading
/// underscore) is one of `Box`, `Storage`, `Wrap`, `Wrapper`, `Cell`
/// AND which carries no inheritance clause (free-standing wrapper, not
/// part of a protocol hierarchy). Classes inheriting from a base class
/// (`ManagedBuffer`-derived buffers, framework hierarchies) are exempt.
/// Names without the canonical `_` prefix and longer than 4 characters
/// (e.g., `StorageRing`, `WrapperDescriptor`) are not flagged — the
/// heuristic targets bare ad-hoc wrappers.
extension Lint.Rule.Naming {
    public struct BoxClass: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "ad_hoc_box_class"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Diagnostic.Record] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.Naming.BoxClass {
    @usableFromInline
    static let message: Swift.String =
        "[ad_hoc_box_class] [IMPL-107]: ad-hoc `_Box` / `_Storage` reference "
        + "wrapper duplicates ecosystem primitives. Prefer `Reference<T>` "
        + "(shared mutable indirection) or `Owned<T>` (unique-owner indirection) "
        + "from `swift-ownership-primitives` so the wrapper's ownership story "
        + "is checked by the type system, not ad-hoc."

    static let flaggedNames: Swift.Set<Swift.String> = [
        "Box", "Storage", "Wrap", "Wrapper", "Cell",
    ]

    static func isFlaggedName(_ name: Swift.String) -> Swift.Bool {
        var trimmed = name
        if trimmed.hasPrefix("_") {
            trimmed.removeFirst()
        }
        return flaggedNames.contains(trimmed)
    }

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            // Free-standing wrappers only — skip declarations with an
            // inheritance clause (frameworks, ManagedBuffer-derived types).
            if node.inheritanceClause != nil {
                return .visitChildren
            }
            let name = node.name.text
            if !Lint.Rule.Naming.BoxClass.isFlaggedName(name) {
                return .visitChildren
            }
            let location = converter.location(
                for: node.name.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Naming.BoxClass.id.underlying,
                message: Lint.Rule.Naming.BoxClass.message
            ))
            return .visitChildren
        }
    }
}

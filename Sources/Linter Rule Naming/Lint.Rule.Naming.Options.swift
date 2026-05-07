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

/// Wave-1 — `OptionSet` type with a `Flags` suffix.
///
/// Citation: `feedback_options_not_flags`.
///
/// `Flags` is C-speak for what Swift calls an `OptionSet`. The institute
/// convention is to suffix `OptionSet` types with `.Options` (e.g.,
/// `File.Open.Options`, `Walk.Options`). Naming a type `XFlags` while it
/// conforms to `OptionSet` is a C-idiom carry-over.
///
/// AST shape: a `StructDeclSyntax` whose name ends in `Flags` AND whose
/// inheritance clause names `OptionSet` (or `Swift.OptionSet`).
extension Lint.Rule.Naming {
    public struct Options: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "option_named_flags"
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

extension Lint.Rule.Naming.Options {
    @usableFromInline
    static let message: Swift.String =
        "[option_named_flags] feedback_options_not_flags: an `OptionSet` type named with "
        + "the `Flags` suffix uses C-speak. The institute convention is `.Options` "
        + "(e.g., `File.Open.Options`, `Walk.Options`). Rename `XFlags` → `XOptions` (or "
        + "nest under a parent type as `Parent.Options`)."

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

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            let name = node.name.text
            guard name.hasSuffix("Flags"), name != "Flags" else {
                return .visitChildren
            }
            guard let inheritance = node.inheritanceClause,
                  conformsToOptionSet(inheritance)
            else {
                return .visitChildren
            }
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Naming.Options.id.underlying,
                message: Lint.Rule.Naming.Options.message
            ))
            return .visitChildren
        }

        private func conformsToOptionSet(_ clause: InheritanceClauseSyntax) -> Bool {
            for entry in clause.inheritedTypes {
                if let identifier = entry.type.as(IdentifierTypeSyntax.self),
                   identifier.name.text == "OptionSet"
                {
                    return true
                }
                if let member = entry.type.as(MemberTypeSyntax.self),
                   member.name.text == "OptionSet",
                   let base = member.baseType.as(IdentifierTypeSyntax.self),
                   base.name.text == "Swift"
                {
                    return true
                }
            }
            return false
        }
    }
}

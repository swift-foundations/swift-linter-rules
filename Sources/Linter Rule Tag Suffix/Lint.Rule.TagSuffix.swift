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

/// Wave-1 — phantom-type marker types named with `Tag` suffix.
///
/// Citation: `feedback_no_tag_suffix`.
///
/// Phantom-type tags used as `Tagged<Tag, Underlying>` markers MUST use
/// the concept name directly (`enum Cardinal {}`, `enum X {}`, `struct
/// MillimeterUnit {}`), never a `Tag` suffix (`struct CardinalTag {}`,
/// `enum XTag {}`). The suffix adds noise without clarifying intent.
///
/// AST shape: a `StructDeclSyntax` or `EnumDeclSyntax` whose name ends
/// in `Tag` AND whose body has zero stored properties (struct) or zero
/// cases (enum). The empty-body heuristic isolates phantom-type markers
/// from legitimate types that happen to end in `Tag` (e.g., `XMLTag`
/// would have stored properties for name/attributes/content).
extension Lint.Rule {
    public struct TagSuffix: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "tag_suffix"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.TagSuffix {
    @usableFromInline
    static let message: Swift.String =
        "[tag_suffix] feedback_no_tag_suffix: phantom-type tags MUST use the concept name "
        + "directly (`enum Cardinal {}`, `struct Millimeter {}`), never a `Tag` suffix "
        + "(`struct CardinalTag {}`, `enum MillimeterTag {}`). The suffix adds noise "
        + "without clarifying intent."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Lint.Finding] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            let name = node.name.text
            guard name.hasSuffix("Tag"), name != "Tag" else {
                return .visitChildren
            }
            guard !hasStoredProperty(node.memberBlock) else {
                return .visitChildren
            }
            emit(at: node.name.positionAfterSkippingLeadingTrivia)
            return .visitChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            let name = node.name.text
            guard name.hasSuffix("Tag"), name != "Tag" else {
                return .visitChildren
            }
            guard !hasEnumCase(node.memberBlock) else {
                return .visitChildren
            }
            emit(at: node.name.positionAfterSkippingLeadingTrivia)
            return .visitChildren
        }

        private func hasStoredProperty(_ block: MemberBlockSyntax) -> Bool {
            for member in block.members {
                guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                    continue
                }
                for binding in variable.bindings {
                    if binding.accessorBlock == nil {
                        return true
                    }
                }
            }
            return false
        }

        private func hasEnumCase(_ block: MemberBlockSyntax) -> Bool {
            for member in block.members where member.decl.is(EnumCaseDeclSyntax.self) {
                return true
            }
            return false
        }

        private func emit(at position: AbsolutePosition) {
            let location = converter.location(for: position)
            matches.append(Lint.Finding(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.TagSuffix.id.underlying,
                message: Lint.Rule.TagSuffix.message
            ))
        }
    }
}

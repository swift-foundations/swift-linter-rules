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

/// Wave 2b finalization (2026-05-10) — extensions on `Tagged` MUST NOT
/// expose public initializers.
///
/// Citation: `[PATTERN-019]` (implementation skill, patterns.md).
///
/// `Tagged<Tag, RawValue>` carries bounded invariants in its `Tag` —
/// brand-newtypes encode "this `String` is a `User.ID`, not a free
/// string". Extending `Tagged` with a `public init` that takes a
/// `RawValue` (or anything else) bypasses the type's bounded
/// construction surface: callers who go through the extension init
/// have not crossed any validation gate the brand owner controls.
///
/// AST shape: `ExtensionDeclSyntax` whose extended type starts with
/// `Tagged` (covers `Tagged<...>`, `Tagged where ...`, etc.) AND whose
/// member block contains an `InitializerDeclSyntax` with a `public`
/// modifier. Each public init in the extension is flagged.
extension Lint.Rule.RawValue {
    public struct TaggedExtensionPublicInit: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "tagged_rawvalue_extension_public_init"
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

extension Lint.Rule.RawValue.TaggedExtensionPublicInit {
    @usableFromInline
    static let message: Swift.String =
        "[tagged_rawvalue_extension_public_init] [PATTERN-019]: extensions on `Tagged` "
        + "MUST NOT provide `public init` — bypasses the brand's bounded invariants. "
        + "Callers reaching through an extension init never cross the validation gate "
        + "the tag owner controls. Drop the init, or move construction behind a "
        + "validating factory at the brand owner's layer."

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

        private func extendsTagged(_ extendedType: TypeSyntax) -> Bool {
            // Match `Tagged`, `Tagged<...>`, `Tagged_Primitives.Tagged`, or any
            // qualified path ending in `.Tagged`. Use trimmed description as
            // the canonical form; check first identifier or last segment.
            let text = extendedType.trimmedDescription
            if text == "Tagged" || text.hasPrefix("Tagged<") || text.hasPrefix("Tagged ") {
                return true
            }
            // Qualified: `Tagging.Tagged`, `Foo.Bar.Tagged<...>`.
            if let lastSegment = text.split(separator: ".").last {
                let segment = String(lastSegment)
                if segment == "Tagged" || segment.hasPrefix("Tagged<") || segment.hasPrefix("Tagged ") {
                    return true
                }
            }
            return false
        }

        private func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
            for modifier in modifiers {
                if modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.open) {
                    return true
                }
            }
            return false
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard extendsTagged(node.extendedType) else {
                return .visitChildren
            }
            for member in node.memberBlock.members {
                guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else {
                    continue
                }
                guard hasPublicModifier(initDecl.modifiers) else {
                    continue
                }
                let location = converter.location(for: initDecl.initKeyword.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.RawValue.TaggedExtensionPublicInit.id.underlying,
                    message: Lint.Rule.RawValue.TaggedExtensionPublicInit.message
                ))
            }
            return .visitChildren
        }
    }
}

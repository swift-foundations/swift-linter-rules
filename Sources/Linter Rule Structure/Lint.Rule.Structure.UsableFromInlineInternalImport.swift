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

/// Wave 4 (mechanization-program) — file pairs `@usableFromInline` with
/// `internal import` of a module whose types the inline body references.
///
/// Citation: `[PATTERN-055]` (implementation skill, patterns.md).
///
/// `@usableFromInline` exposes a declaration to the optimizer for
/// cross-module inlining. The inline body MUST be able to reach every
/// identifier it touches across the module boundary; if the file imports
/// a referenced module as `internal`, the compiler rejects the body with
/// an "internal import used in @usableFromInline" error. Downgrade
/// visibility on the decl OR upgrade the import to `public` / `package`.
///
/// AST shape: the rule flags any file that contains AT LEAST ONE
/// `@usableFromInline` declaration AND AT LEAST ONE `internal import`
/// declaration. The flag is at the `internal import` keyword position
/// (the compiler-actionable site). The narrow heuristic over-approximates
/// — internal imports of modules NOT referenced in inline bodies are
/// false positives — but the cost of the heuristic is one keyword move
/// per match, and the compile-time failure mode it prevents is severe.
extension Lint.Rule.Structure {
    public struct UsableFromInlineInternalImport: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "usable_from_inline_internal_import"
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

extension Lint.Rule.Structure.UsableFromInlineInternalImport {
    @usableFromInline
    static let message: Swift.String =
        "[usable_from_inline_internal_import] [PATTERN-055]: file pairs "
        + "`@usableFromInline` with `internal import` of a referenced module. "
        + "Swift rejects `@usableFromInline` bodies that reach identifiers in "
        + "internally-imported modules at compile time. Either downgrade the "
        + "decl's visibility or upgrade the import to `public` / `package`."

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        var hasUsableFromInline: Swift.Bool = false
        var internalImports: [AbsolutePosition] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
            if let identifier = node.attributeName.as(IdentifierTypeSyntax.self),
               identifier.name.text == "usableFromInline" {
                hasUsableFromInline = true
            }
            return .visitChildren
        }

        override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
            // `internal import M` has access-level modifier `internal` OR
            // (in some toolchains) no modifier under InternalImportsByDefault.
            // We flag explicit `internal import` only — the implicit-internal
            // case is the file's responsibility under the upcoming-feature
            // discipline and is too noisy here.
            for modifier in node.modifiers {
                if case .keyword(.internal) = modifier.name.tokenKind {
                    internalImports.append(
                        node.importKeyword.positionAfterSkippingLeadingTrivia
                    )
                }
            }
            return .visitChildren
        }

        func finalize() {
            guard hasUsableFromInline else { return }
            for position in internalImports {
                let location = converter.location(for: position)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Structure.UsableFromInlineInternalImport.id.underlying,
                    message: Lint.Rule.Structure.UsableFromInlineInternalImport.message
                ))
            }
        }

        override func visitPost(_: SourceFileSyntax) {
            finalize()
        }
    }
}

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

/// Wave-1 — local variable bound as `impl` (or `_impl`).
///
/// Citation: `feedback_no_impl_abbreviation`.
///
/// Binding a local variable as `impl` is an abbreviation that hides the
/// type's actual identity. The institute convention is to use the
/// type's own name lowercased (e.g., `let actor = IO.Blocking.Actor(...)`)
/// so the binding is self-describing at every read site.
///
/// AST shape: `VariableDeclSyntax` with at least one binding whose
/// pattern is an `IdentifierPatternSyntax` named `impl` or `_impl`.
extension Lint.Rule.Naming {
    public struct Impl: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "var_named_impl"
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

extension Lint.Rule.Naming.Impl {
    @usableFromInline
    static let message: Swift.String =
        "[var_named_impl] feedback_no_impl_abbreviation: do not bind a local as `impl` "
        + "or `_impl` — it hides the type's identity. Use the type's own name lowercased "
        + "(e.g., `let actor = IO.Blocking.Actor(...)`, `let resolver = Manifest.Resolver(...)`) "
        + "so each read site reveals what the binding actually holds."

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

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            for binding in node.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }
                let name = pattern.identifier.text
                guard name == "impl" || name == "_impl" else {
                    continue
                }
                let location = converter.location(for: pattern.identifier.positionAfterSkippingLeadingTrivia)
                matches.append(Lint.Finding(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Naming.Impl.id.underlying,
                    message: Lint.Rule.Naming.Impl.message
                ))
            }
            return .visitChildren
        }
    }
}

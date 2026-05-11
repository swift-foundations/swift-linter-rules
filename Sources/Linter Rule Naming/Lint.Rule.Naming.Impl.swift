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
extension Lint.Rule {
    public static let `variable named impl` = Lint.Rule(
        id: "var_named_impl",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingImplVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let namingImplMessage: Swift.String =
    "[var_named_impl] feedback_no_impl_abbreviation: do not bind a local as `impl` "
    + "or `_impl` — it hides the type's identity. Use the type's own name lowercased "
    + "(e.g., `let actor = IO.Blocking.Actor(...)`, `let resolver = Manifest.Resolver(...)`) "
    + "so each read site reveals what the binding actually holds."

internal final class NamingImplVisitor: SyntaxVisitor {
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
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "var_named_impl",
                message: namingImplMessage
            ))
        }
        return .visitChildren
    }
}

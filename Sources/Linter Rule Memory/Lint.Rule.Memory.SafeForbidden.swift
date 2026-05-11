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

/// Wave 3 Thread 7 (2026-05-11) — the `@safe` attribute MUST NOT
/// appear on any declaration in `Sources/`.
///
/// Citation: `[MEM-SAFE-025b]` (memory-safety skill, safety-isolation.md).
///
/// The institute policy converged on stating encapsulation invariants
/// in adjacent `// SAFETY:` / `// WHY:` prose comments instead of via
/// the `@safe` attribute (SE-0458). Comments are richer (they name
/// the specific invariant) and skill citations are first-class.
///
/// See `swift-institute/Research/mem-safe-025-reconciliation.md` for
/// the decision rationale. This rule replaces (alongside
/// `Lint.Rule.Memory.NonisolatedUnsafeInvariant`) the original
/// `Lint.Rule.Memory.NonisolatedUnsafeSafe`.
extension Lint.Rule {
    public static let `safe attribute forbidden` = Lint.Rule(
        id: "safe attribute forbidden",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemorySafeForbiddenVisitor(
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
internal let memorySafeForbiddenMessage: Swift.String =
    "[safe attribute forbidden] [MEM-SAFE-025b]: the `@safe` attribute MUST NOT "
    + "appear in `Sources/`. Express encapsulation invariants as adjacent "
    + "`// SAFETY:` / `// WHY:` comments per [MEM-SAFE-025a] (when adjacent to "
    + "`nonisolated(unsafe)`) or as `## Safety Invariant` doc-comment sections "
    + "per [MEM-SAFE-024] (when adjacent to `@unchecked Sendable` conformances). "
    + "The comment form is richer than the attribute (it names the specific "
    + "invariant and may cite skill rules)."

internal final class MemorySafeForbiddenVisitor: SyntaxVisitor {
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

    private func recordSafeAttributes(_ attributes: AttributeListSyntax) {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "safe" {
                let location = converter.location(for: attr.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "safe attribute forbidden",
                    message: memorySafeForbiddenMessage
                ))
            }
        }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        recordSafeAttributes(node.attributes)
        return .visitChildren
    }
}

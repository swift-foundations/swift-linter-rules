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

/// Wave 2b finalization (2026-05-10) — `nonisolated(unsafe)` globals
/// MUST carry an explicit `@safe` annotation.
///
/// Citation: `[MEM-SAFE-025]` (memory-safety skill, safety-isolation.md).
///
/// `nonisolated(unsafe)` globals (or static stored properties) used as
/// sentinels / one-time-allocated constants are encapsulated-safe by
/// invariant — the institute requires the invariant be stated at the
/// declaration site with `@safe`. Without `@safe`, the cross-thread
/// safety story is implicit and easy to silently violate.
extension Lint.Rule {
    public static let `nonisolated unsafe without safe` = Lint.Rule(
        id: "nonisolated_unsafe_safe",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryNonisolatedUnsafeSafeVisitor(
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
internal let memoryNonisolatedUnsafeSafeMessage: Swift.String =
    "[nonisolated_unsafe_safe] [MEM-SAFE-025]: `nonisolated(unsafe)` globals MUST "
    + "carry `@safe` to assert the encapsulation invariant (allocated once, never "
    + "mutated post-init, only used as sentinel / constant). Without `@safe` the "
    + "safety story is implicit. Concurrently-mutated `nonisolated(unsafe)` is a "
    + "separate violation — use `Mutex` / `Atomic`, not temporal invariants."

internal final class MemoryNonisolatedUnsafeSafeVisitor: SyntaxVisitor {
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

    private func hasNonisolatedUnsafe(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.nonisolated) {
                if let detail = modifier.detail {
                    // detail is `(unsafe)` — match by trimmed text.
                    if detail.detail.text == "unsafe" {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func hasSafeAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "safe" {
                return true
            }
        }
        return false
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasNonisolatedUnsafe(node.modifiers) else {
            return .visitChildren
        }
        guard !hasSafeAttribute(node.attributes) else {
            return .visitChildren
        }
        let location = converter.location(for: node.bindingSpecifier.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "nonisolated_unsafe_safe",
            message: memoryNonisolatedUnsafeSafeMessage
        ))
        return .visitChildren
    }
}

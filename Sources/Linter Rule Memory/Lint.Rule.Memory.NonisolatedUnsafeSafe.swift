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
///
/// AST shape: `VariableDeclSyntax` whose modifiers contain
/// `nonisolated(unsafe)` AND whose attributes do NOT contain `@safe`.
/// Both `let` and `var` are in scope; `var` is *additionally*
/// suspect (mutable globals are a separate category) but the same
/// `@safe`-or-synchronized requirement applies.
extension Lint.Rule.Memory {
    public struct NonisolatedUnsafeSafe: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "nonisolated_unsafe_safe"
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

extension Lint.Rule.Memory.NonisolatedUnsafeSafe {
    @usableFromInline
    static let message: Swift.String =
        "[nonisolated_unsafe_safe] [MEM-SAFE-025]: `nonisolated(unsafe)` globals MUST "
        + "carry `@safe` to assert the encapsulation invariant (allocated once, never "
        + "mutated post-init, only used as sentinel / constant). Without `@safe` the "
        + "safety story is implicit. Concurrently-mutated `nonisolated(unsafe)` is a "
        + "separate violation — use `Mutex` / `Atomic`, not temporal invariants."

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
                identifier: Lint.Rule.Memory.NonisolatedUnsafeSafe.id.underlying,
                message: Lint.Rule.Memory.NonisolatedUnsafeSafe.message
            ))
            return .visitChildren
        }
    }
}

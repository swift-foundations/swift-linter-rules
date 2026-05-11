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

/// Wave 3 (mechanization-program) — assignment to unsafe storage MUST
/// wrap the entire assignment expression in `unsafe (…)`; placing the
/// `unsafe` keyword on the RHS alone leaves the destination
/// unacknowledged.
///
/// Citation: `[PATTERN-005b]` / `[MEM-SAFE-002]` (platform skill, memory-
/// safety skill — expression granularity of unsafe).
///
/// Swift 6's strict memory safety operates at expression granularity.
/// `self.raw = unsafe Unmanaged.passRetained(x).toOpaque()` marks only
/// the RHS expression as unsafe — the assignment to `self.raw` itself
/// is uncovered. The institute convention wraps the entire assignment:
/// `unsafe (self.raw = Unmanaged.passRetained(x).toOpaque())`. Each
/// unsafe operation requires its own `unsafe` acknowledgment.
///
/// AST shape: walk `SequenceExprSyntax`. For each occurrence of an
/// `AssignmentExprSyntax` in the element list, inspect the following
/// element (the right-hand side of `=`). If that element is a top-
/// level `UnsafeExprSyntax`, flag — the `unsafe` should wrap the
/// entire `lhs = rhs` expression, not just the RHS.
///
/// Worked examples (flagged):
///   - `self.raw = unsafe Unmanaged.passRetained(x).toOpaque()` —
///     destination uncovered.
///   - `buffer[i] = unsafe pointer.pointee` — index assignment with
///     RHS-only `unsafe`.
///
/// Worked examples (NOT flagged):
///   - `unsafe (self.raw = Unmanaged.passRetained(x).toOpaque())` —
///     entire assignment wrapped.
///   - `let x = unsafe pointer.pointee` — binding declaration; not an
///     assignment-to-unsafe-storage shape (binding initializer is
///     covered by the surrounding `let`/`var` boundary).
///   - `func op() { unsafe pointer.pointee }` — bare expression, no
///     assignment.
extension Lint.Rule.Memory {
    public struct UnsafeAssignmentGranularity: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "unsafe_assignment_granularity"
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

extension Lint.Rule.Memory.UnsafeAssignmentGranularity {
    @usableFromInline
    static let message: Swift.String =
        "[unsafe_assignment_granularity] [PATTERN-005b]/[MEM-SAFE-002]: "
        + "`<lvalue> = unsafe <expr>` marks only the RHS as unsafe — the "
        + "assignment to `<lvalue>` is uncovered. Wrap the entire "
        + "expression: `unsafe (<lvalue> = <expr>)`. Each unsafe operation "
        + "requires its own `unsafe` acknowledgment; expression granularity."

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

        override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
            let elements = Array(node.elements)
            for index in elements.indices.dropLast() {
                guard elements[index].is(AssignmentExprSyntax.self) else { continue }
                let rhs = elements[index + 1]
                guard rhs.is(UnsafeExprSyntax.self) else { continue }
                let location = converter.location(
                    for: rhs.positionAfterSkippingLeadingTrivia
                )
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Memory.UnsafeAssignmentGranularity.id.underlying,
                    message: Lint.Rule.Memory.UnsafeAssignmentGranularity.message
                ))
            }
            return .visitChildren
        }
    }
}

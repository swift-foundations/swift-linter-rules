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
extension Lint.Rule {
    public static let `unsafe assignment granularity` = Lint.Rule(
        id: "unsafe_assignment_granularity",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryUnsafeAssignmentGranularityVisitor(
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
internal let memoryUnsafeAssignmentGranularityMessage: Swift.String =
    "[unsafe_assignment_granularity] [PATTERN-005b]/[MEM-SAFE-002]: "
    + "`<lvalue> = unsafe <expr>` marks only the RHS as unsafe — the "
    + "assignment to `<lvalue>` is uncovered. Wrap the entire "
    + "expression: `unsafe (<lvalue> = <expr>)`. Each unsafe operation "
    + "requires its own `unsafe` acknowledgment; expression granularity."

internal final class MemoryUnsafeAssignmentGranularityVisitor: SyntaxVisitor {
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
                identifier: "unsafe_assignment_granularity",
                message: memoryUnsafeAssignmentGranularityMessage
            ))
        }
        return .visitChildren
    }
}

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

/// Wave 4 (mechanization-program) — raw pointer arithmetic via
/// `.advanced(by:)` is mechanism; types managing memory SHOULD expose a
/// typed `pointer(at:)` primitive that encapsulates offset computation.
///
/// Citation: `[IMPL-011]` (implementation skill, infrastructure.md).
extension Lint.Rule {
    public static let `pointer advanced by` = Lint.Rule(
        id: "pointer_advanced_by",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryPointerArithmeticVisitor(
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
internal let memoryPointerArithmeticMessage: Swift.String =
    "[pointer_advanced_by] [IMPL-011]: raw pointer arithmetic via "
    + "`.advanced(by:)` is mechanism. Types managing memory SHOULD expose "
    + "a typed `pointer(at: Index<Element>)` primitive that encapsulates "
    + "the offset computation. Either (a) add the typed primitive to the "
    + "storage type and call it, or (b) confine the `.advanced(by:)` to a "
    + "designated pointer-primitives package."

internal final class MemoryPointerArithmeticVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        guard member.declName.baseName.text == "advanced" else {
            return .visitChildren
        }
        // Single argument labeled `by:`.
        guard node.arguments.count == 1,
              let argument = node.arguments.first,
              argument.label?.text == "by"
        else {
            return .visitChildren
        }
        let location = converter.location(
            for: member.declName.baseName.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "pointer_advanced_by",
            message: memoryPointerArithmeticMessage
        ))
        return .visitChildren
    }
}

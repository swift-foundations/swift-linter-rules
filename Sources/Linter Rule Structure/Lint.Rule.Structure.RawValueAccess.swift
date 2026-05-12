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

/// Wave 4 (mechanization-program) — `.rawValue` and `.position` accesses
/// at consumer call sites bypass typed-conversion ladders.
///
/// Citation: `[PATTERN-017]` (implementation skill, patterns.md).
extension Lint.Rule {
    public static let `raw value access` = Lint.Rule(
        id: "raw value access",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureRawValueAccessVisitor(
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
internal let structureRawValueAccessMessage: Swift.String =
    "[raw value access] [PATTERN-017]: `.rawValue` / `.position` at a "
    + "consumer call site bypasses the typed-conversion ladder. These "
    + "accessors are reserved for extension initializers (the brand-newtype's "
    + "own boundary) and same-package implementations. Prefer the typed "
    + "operation; suppress with `// swift-linter:disable:next raw value access` "
    + "and a `// REASON:` continuation for legitimate same-package use."

internal let structureRawValueAccessFlaggedAccessors: Swift.Set<Swift.String> = ["rawValue", "position"]

internal final class StructureRawValueAccessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var bodyDepth: Swift.Int = 0

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: FunctionDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: InitializerDeclSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ClosureExprSyntax) {
        bodyDepth -= 1
    }
    override func visit(_: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        return .visitChildren
    }
    override func visitPost(_: AccessorDeclSyntax) {
        bodyDepth -= 1
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard bodyDepth > 0 else { return .visitChildren }
        let name = node.declName.baseName.text
        guard structureRawValueAccessFlaggedAccessors.contains(name) else {
            return .visitChildren
        }
        let location = converter.location(
            for: node.declName.baseName.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "raw value access",
            message: structureRawValueAccessMessage
        ))
        return .visitChildren
    }
}

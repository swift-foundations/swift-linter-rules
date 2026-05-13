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
internal import Cardinal_Primitives
internal import SwiftSyntax

/// Wave 2b finalization (2026-05-10) — one type declaration per file.
///
/// Citation: `[API-IMPL-005]` (code-surface skill).
extension Lint.Rule {
    public static let `single type per file` = Lint.Rule(
        id: "single type per file",
        default: .warning,
        findings: { source, severity in
            // Scope-exclusion per Decision 2: skip files whose path has a
            // segment named `Tests`, `Experiments`, or `Examples`.
            let path = source.file.filePath.underlying
            for excluded in ["Tests", "Experiments", "Examples"] {
                if path == excluded
                    || path.hasPrefix("\(excluded)/")
                    || path.contains("/\(excluded)/")
                {
                    return []
                }
            }
            let visitor = StructureSingleTypePerFileVisitor(
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
internal let structureSingleTypePerFileMessage: Swift.String =
    "[single type per file] [API-IMPL-005]: each `.swift` source file MUST contain "
    + "exactly one type declaration (`struct`, `class`, `enum`, `actor`, `protocol`). "
    + "Multiple `extension` declarations of the enclosing type are permitted. "
    + "Move additional types to their own files; the file naming convention "
    + "[API-IMPL-006] requires the file name to match the type's nested path."

internal final class StructureSingleTypePerFileVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var currentDepth: Int = 0
    var topLevelCount: Cardinal = .zero

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func handleTypeDecl(at position: AbsolutePosition) {
        guard currentDepth == 0 else { return }
        topLevelCount += .one
        guard topLevelCount > .one else { return }
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "single type per file",
            message: structureSingleTypePerFileMessage
        ))
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
        currentDepth += 1
        return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { currentDepth -= 1 }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
        currentDepth += 1
        return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { currentDepth -= 1 }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
        currentDepth += 1
        return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { currentDepth -= 1 }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
        currentDepth += 1
        return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { currentDepth -= 1 }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        handleTypeDecl(at: node.name.positionAfterSkippingLeadingTrivia)
        currentDepth += 1
        return .visitChildren
    }
    override func visitPost(_ node: ProtocolDeclSyntax) { currentDepth -= 1 }

    override func visit(_: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        currentDepth += 1
        return .visitChildren
    }
    override func visitPost(_: ExtensionDeclSyntax) { currentDepth -= 1 }
}

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

/// Phantom-type marker types named with `Tag` suffix — use concept names
/// directly. Citation: `feedback_no_tag_suffix`.
extension Lint.Rule {
    public static let `tag suffix` = Lint.Rule(
        id: "tag suffix",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingTagVisitor(
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
internal let namingTagMessage: Swift.String =
    "[tag suffix] feedback_no_tag_suffix: phantom-type tags MUST use the concept name "
    + "directly (`enum Cardinal {}`, `struct Millimeter {}`), never a `Tag` suffix."

internal final class NamingTagVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard name.hasSuffix("Tag"), name != "Tag" else { return .visitChildren }
        guard !tagHasStoredProperty(node.memberBlock) else { return .visitChildren }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard name.hasSuffix("Tag"), name != "Tag" else { return .visitChildren }
        guard !tagHasEnumCase(node.memberBlock) else { return .visitChildren }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "tag suffix",
            message: namingTagMessage
        ))
    }
}

private func tagHasStoredProperty(_ block: MemberBlockSyntax) -> Swift.Bool {
    for member in block.members {
        guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
        for binding in variable.bindings {
            if binding.accessorBlock == nil { return true }
        }
    }
    return false
}

private func tagHasEnumCase(_ block: MemberBlockSyntax) -> Swift.Bool {
    for member in block.members where member.decl.is(EnumCaseDeclSyntax.self) { return true }
    return false
}

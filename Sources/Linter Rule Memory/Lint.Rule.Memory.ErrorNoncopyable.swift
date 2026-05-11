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

/// Wave 2b finalization (2026-05-10) — `Error`-conforming types MUST
/// NOT also suppress `Copyable`.
///
/// Citation: `[MEM-COPY-002]` (memory-safety skill, ownership.md).
///
/// `Swift.Error` requires `Copyable` (the protocol's existential
/// boxing relies on the value being copyable). A type declared
/// `~Copyable` cannot conform to `Error`. The fix is to use a
/// non-throwing outcome type carrying the move-only value, or to
/// keep the error type `Copyable` and refer to the move-only value
/// through a copyable handle.
extension Lint.Rule {
    public static let `noncopyable error` = Lint.Rule(
        id: "error_noncopyable_check",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryErrorNoncopyableVisitor(
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
internal let memoryErrorNoncopyableMessage: Swift.String =
    "[error_noncopyable_check] [MEM-COPY-002]: `Error`-conforming types MUST NOT "
    + "suppress `Copyable`. `Swift.Error`'s existential boxing requires `Copyable`. "
    + "A `~Copyable` Error type fails to compile or to interoperate with the "
    + "throwing protocol surface. Use a non-throwing `Outcome` enum (`.success`/"
    + "`.failure`) carrying the move-only value, or hold the move-only state in "
    + "a copyable handle and reference it from the error."

internal final class MemoryErrorNoncopyableVisitor: SyntaxVisitor {
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

    private func conformsToError(_ inheritanceClause: InheritanceClauseSyntax) -> Bool {
        for inherited in inheritanceClause.inheritedTypes {
            var current = inherited.type
            while let attributed = current.as(AttributedTypeSyntax.self) {
                current = attributed.baseType
            }
            if let identifier = current.as(IdentifierTypeSyntax.self),
               identifier.name.text == "Error"
            {
                return true
            }
            if let member = current.as(MemberTypeSyntax.self),
               member.name.text == "Error"
            {
                return true
            }
        }
        return false
    }

    private func suppressesCopyable(_ inheritanceClause: InheritanceClauseSyntax) -> Bool {
        for inherited in inheritanceClause.inheritedTypes {
            if let suppressed = inherited.type.as(SuppressedTypeSyntax.self) {
                let typeName = suppressed.type.trimmedDescription
                if typeName == "Copyable" || typeName.hasSuffix(".Copyable") {
                    return true
                }
            }
        }
        return false
    }

    private func check(name: TokenSyntax, inheritanceClause: InheritanceClauseSyntax?) {
        guard let inheritanceClause else { return }
        guard conformsToError(inheritanceClause) else { return }
        guard suppressesCopyable(inheritanceClause) else { return }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "error_noncopyable_check",
            message: memoryErrorNoncopyableMessage
        ))
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        check(name: node.name, inheritanceClause: node.inheritanceClause)
        return .visitChildren
    }
}

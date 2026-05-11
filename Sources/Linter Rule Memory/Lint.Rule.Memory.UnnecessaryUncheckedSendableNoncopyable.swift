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

/// Wave 2b finalization (2026-05-10) — `~Copyable` types whose stored
/// surface is Sendable-by-construction MUST use plain `Sendable`, not
/// `@unchecked Sendable`.
///
/// Citation: `[MEM-SEND-004]` (memory-safety skill, concurrency.md).
extension Lint.Rule {
    public static let `unchecked sendable noncopyable` = Lint.Rule(
        id: "unchecked sendable noncopyable",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = MemoryUnnecessaryUncheckedSendableNoncopyableVisitor(
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
internal let memoryUnnecessaryUncheckedSendableNoncopyableMessage: Swift.String =
    "[unchecked sendable noncopyable] [MEM-SEND-004]: `~Copyable` "
    + "structs whose stored properties are all `Sendable` MUST use plain `Sendable`. "
    + "The compiler synthesises and checks `Sendable` for `~Copyable` structs the "
    + "same way as for `Copyable` ones — there is no inference gap. `@unchecked "
    + "Sendable` here is a misleading safety claim. Drop `@unchecked` and let the "
    + "checker verify."

internal final class MemoryUnnecessaryUncheckedSendableNoncopyableVisitor: SyntaxVisitor {
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

    private func uncheckedSendablePosition(_ inheritanceClause: InheritanceClauseSyntax) -> AbsolutePosition? {
        for inherited in inheritanceClause.inheritedTypes {
            guard let attributed = inherited.type.as(AttributedTypeSyntax.self) else { continue }
            var hasUnchecked = false
            for attribute in attributed.attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "unchecked" {
                    hasUnchecked = true
                }
            }
            guard hasUnchecked else { continue }
            let baseName: String
            if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self) {
                baseName = identifier.name.text
            } else if let member = attributed.baseType.as(MemberTypeSyntax.self) {
                baseName = member.name.text
            } else {
                continue
            }
            if baseName == "Sendable" {
                return inherited.positionAfterSkippingLeadingTrivia
            }
        }
        return nil
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let inheritanceClause = node.inheritanceClause else {
            return .visitChildren
        }
        guard suppressesCopyable(inheritanceClause) else {
            return .visitChildren
        }
        guard let position = uncheckedSendablePosition(inheritanceClause) else {
            return .visitChildren
        }
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "unchecked sendable noncopyable",
            message: memoryUnnecessaryUncheckedSendableNoncopyableMessage
        ))
        return .visitChildren
    }
}

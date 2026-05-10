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
///
/// The compiler synthesises and checks `Sendable` for `~Copyable`
/// structs the same way as for `Copyable` structs — there is no
/// inference gap that requires `@unchecked Sendable`. An author who
/// reaches for `@unchecked Sendable` on a `~Copyable` struct is
/// usually working from old habits or copying a non-noncopyable
/// pattern; the result is a misleading safety claim that opts out of
/// real checking. Drop the `@unchecked` and let the compiler verify.
///
/// AST shape (heuristic): `StructDeclSyntax` whose conformance list
/// contains both `~Copyable` AND `@unchecked Sendable`. This is a
/// strong-signal heuristic; false positives are when stored properties
/// genuinely need `@unsafe @unchecked Sendable` (Category A/B/D under
/// `[MEM-SAFE-024]`), which is rare for `~Copyable` types.
extension Lint.Rule.Memory {
    public struct UnnecessaryUncheckedSendableNoncopyable: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "unnecessary_unchecked_sendable_noncopyable"
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

extension Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable {
    @usableFromInline
    static let message: Swift.String =
        "[unnecessary_unchecked_sendable_noncopyable] [MEM-SEND-004]: `~Copyable` "
        + "structs whose stored properties are all `Sendable` MUST use plain `Sendable`. "
        + "The compiler synthesises and checks `Sendable` for `~Copyable` structs the "
        + "same way as for `Copyable` ones — there is no inference gap. `@unchecked "
        + "Sendable` here is a misleading safety claim. Drop `@unchecked` and let the "
        + "checker verify."

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
                identifier: Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.id.underlying,
                message: Lint.Rule.Memory.UnnecessaryUncheckedSendableNoncopyable.message
            ))
            return .visitChildren
        }
    }
}

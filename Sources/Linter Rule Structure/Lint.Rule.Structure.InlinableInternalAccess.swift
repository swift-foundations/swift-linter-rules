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

/// Wave 2b finalization (2026-05-10) — `@inlinable` decls require non-`internal` access.
///
/// Citation: `[PATTERN-052]` (implementation skill, patterns.md).
///
/// `@inlinable` allows cross-module inlining at the call site. The
/// inlined body must be able to reference identifiers it touches across
/// the module boundary; `internal` declarations are not visible there.
/// The institute convention pairs `@inlinable` decls with at least
/// `@usableFromInline` (treats the decl as `package`-visible to the
/// optimizer) or with explicit `public` / `package` visibility.
///
/// AST shape: `FunctionDeclSyntax` / `VariableDeclSyntax` /
/// `InitializerDeclSyntax` whose attribute list contains `@inlinable`,
/// AND whose modifier list lacks `public`, `package`, or
/// `@usableFromInline`. The bare default (no modifier → internal) is
/// the canonical violation.
extension Lint.Rule.Structure {
    public struct InlinableInternalAccess: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "inlinable_internal_access"
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

extension Lint.Rule.Structure.InlinableInternalAccess {
    @usableFromInline
    static let message: Swift.String =
        "[inlinable_internal_access] [PATTERN-052]: `@inlinable` cross-module access "
        + "requires `@usableFromInline` (or `public` / `package`), not bare `internal`. "
        + "An `@inlinable` decl whose body references an `internal` identifier fails to "
        + "compile across the module boundary; pair the attribute with `@usableFromInline "
        + "package` (preferred for impl-only surface) or upgrade to `public`."

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

        private func hasInlinableAttribute(_ attributes: AttributeListSyntax) -> Bool {
            for attribute in attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "inlinable" {
                    return true
                }
            }
            return false
        }

        private func hasNonInternalAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
            for modifier in modifiers {
                switch modifier.name.tokenKind {
                case .keyword(.public), .keyword(.package), .keyword(.open):
                    return true
                default:
                    continue
                }
            }
            return false
        }

        private func hasUsableFromInline(_ attributes: AttributeListSyntax) -> Bool {
            for attribute in attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "usableFromInline" {
                    return true
                }
            }
            return false
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
                identifier: Lint.Rule.Structure.InlinableInternalAccess.id.underlying,
                message: Lint.Rule.Structure.InlinableInternalAccess.message
            ))
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            if hasInlinableAttribute(node.attributes),
               !hasNonInternalAccess(node.modifiers),
               !hasUsableFromInline(node.attributes)
            {
                emit(at: node.name.positionAfterSkippingLeadingTrivia)
            }
            return .visitChildren
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            if hasInlinableAttribute(node.attributes),
               !hasNonInternalAccess(node.modifiers),
               !hasUsableFromInline(node.attributes)
            {
                emit(at: node.bindingSpecifier.positionAfterSkippingLeadingTrivia)
            }
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            if hasInlinableAttribute(node.attributes),
               !hasNonInternalAccess(node.modifiers),
               !hasUsableFromInline(node.attributes)
            {
                emit(at: node.initKeyword.positionAfterSkippingLeadingTrivia)
            }
            return .visitChildren
        }
    }
}

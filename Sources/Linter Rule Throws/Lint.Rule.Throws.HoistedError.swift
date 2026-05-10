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

/// Wave 1 (mechanization-program) — hoisted error types in public-API
/// throws clauses.
///
/// Citation: `[API-ERR-007]` (code-surface skill — Public API Path for
/// Error Types, Not Hoisted Internals).
///
/// `__`-prefixed hoisted types are implementation details — a SwiftPM
/// workaround for Swift's inability to declare nested generic types in
/// extensions per `[PATTERN-016]`. They MUST NOT appear in `throws(T)`
/// clauses on public-API functions or initializers; the public-API
/// path (`Module.Foo.Bar.Error`) is the canonical name and documents
/// the intended access pattern.
///
/// Detection: walk `throws(...)` clauses on public/open declarations.
/// If the throw type's leaf identifier starts with `__`, flag it.
///
/// Worked examples (flagged):
///   - `public func insert(...) throws(__DictionaryError<Key>)` — flagged.
///   - `public init() throws(__BoundedError)` — flagged.
///
/// Worked examples (NOT flagged):
///   - `public func insert(...) throws(Dictionary<Key, Value>.Error)` — public path.
///   - `func op() throws(__InternalError)` — internal function, exempt.
///   - `package func op() throws(__PackageError)` — package-scope, exempt.
///   - `public func op() throws(MyDomain.Error)` — public path, OK.
///
/// Excluded scopes:
/// - Non-public functions/initializers (`internal`, `private`,
///   `fileprivate`, `package`).
/// - `try _internalFunc()` body invocations — only the THROW TYPE in
///   the `throws(...)` clause is scoped to this rule.
extension Lint.Rule.Throws {
    public struct HoistedError: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "hoisted_error_in_public_throws"
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

extension Lint.Rule.Throws.HoistedError {
    @usableFromInline
    static let message: Swift.String =
        "[hoisted_error_in_public_throws] [API-ERR-007]: public-API "
        + "`throws(T)` clauses MUST reference the canonical public path "
        + "(e.g., `Dictionary<Key, Value>.Ordered.Bounded.Error`), never "
        + "the `__`-prefixed hoisted internal type. Hoisted types are "
        + "implementation details of the `[PATTERN-016]` workaround and "
        + "MUST NOT leak into the public surface."

    static func isPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return true
            default:
                continue
            }
        }
        return false
    }

    /// Returns the leaf type identifier of a throw-type expression.
    /// `__Foo` → "__Foo"; `A.B.__Foo<X>` → "__Foo"; nil if not resolvable.
    static func leafIdentifier(of type: TypeSyntax) -> Swift.String? {
        var current = type
        // Strip optionals and attributed wrappers — not expected on
        // throw types but defensive.
        while let optional = current.as(OptionalTypeSyntax.self) {
            current = optional.wrappedType
        }
        while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            current = iuo.wrappedType
        }
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = current.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

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

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Throws.HoistedError.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            checkThrowsClause(node.signature.effectSpecifiers?.throwsClause)
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Throws.HoistedError.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            checkThrowsClause(node.signature.effectSpecifiers?.throwsClause)
            return .visitChildren
        }

        private func checkThrowsClause(_ clause: ThrowsClauseSyntax?) {
            guard let clause, let type = clause.type else { return }
            guard let leaf = Lint.Rule.Throws.HoistedError.leafIdentifier(of: type) else {
                return
            }
            guard leaf.hasPrefix("__") else { return }
            let location = converter.location(for: type.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Throws.HoistedError.id.underlying,
                message: Lint.Rule.Throws.HoistedError.message
            ))
        }
    }
}

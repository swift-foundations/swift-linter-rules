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

/// Wave 3 (mechanization-program) — public generic APIs throwing a
/// generic-parameter-typed error should consider a non-throwing
/// specialization (`where <G>.<Member> == Never`).
///
/// Citation: `[IMPL-042]` (implementation skill — non-throwing
/// specialization for generic callback APIs).
///
/// When a public API propagates a user-supplied typed error through a
/// generic parameter (`throws(Sink.Failure)`), the compiler retains
/// error-propagation scaffolding even when the caller binds Failure
/// to `Never` — generic outer types hide the binding from codegen.
/// The institute convention pairs the generic body with a specialised
/// overload under `extension Owner where G.Member == Never` so the
/// compiler can eliminate the scaffolding on the hot path.
///
/// AST shape: a public function or initializer declared `throws(M)`
/// whose type expression is a `MemberTypeSyntax` (`M = G.Sub`) where
/// `G` is a generic parameter declared on the containing type (or on
/// the function itself). This rule does NOT verify the presence of a
/// `where G.Sub == Never` extension — that is whole-module analysis.
/// The flag is a *prompt for review*: confirm a specialised overload
/// exists, or document why the hot-path criteria do not apply (per
/// [IMPL-001]).
///
/// Worked examples (flagged):
///   - `public struct Parser<Sink: Handler> { public mutating func
///     parse() throws(Sink.Failure) { ... } }` — `Sink` is a generic
///     parameter of `Parser`, so `Sink.Failure` is generic-typed throw.
///   - `extension Parser { public func consume() throws(Sink.Failure)
///     { ... } }` — same generic context.
///
/// Worked examples (NOT flagged):
///   - `public func parse() throws(MyError) { ... }` — concrete throw
///     type; no specialization needed.
///   - `public func op() throws { ... }` — untyped throws; handled by
///     `Lint.Rule.Throws.Untyped`.
///   - `internal func parse() throws(Sink.Failure) { ... }` — non-public;
///     out of scope.
extension Lint.Rule.Throws {
    public struct GenericNeverSpecialization: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "generic_throws_missing_never_specialization"
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

extension Lint.Rule.Throws.GenericNeverSpecialization {
    @usableFromInline
    static let message: Swift.String =
        "[generic_throws_missing_never_specialization] [IMPL-042]: public "
        + "generic API throws a generic-parameter-typed error. Even when "
        + "callers bind the parameter to `Never`, the generic outer type "
        + "hides the binding from codegen — error-propagation scaffolding "
        + "stays. Consider adding `extension Owner where G.Sub == Never { "
        + "/* duplicated body */ }` so the compiler can eliminate the "
        + "scaffolding on hot paths. If the API has no hot-path consumer, "
        + "document the absence per [IMPL-001]."

    static func isPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
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

    static func collectGenericParamNames(
        _ clause: GenericParameterClauseSyntax?
    ) -> Swift.Set<Swift.String> {
        guard let clause else { return [] }
        var names: Swift.Set<Swift.String> = []
        for parameter in clause.parameters {
            names.insert(parameter.name.text)
        }
        return names
    }

    /// Returns the position of the throw type if it references a name
    /// in `availableGenerics` as its base, else nil.
    static func genericFailureTypePosition(
        in clause: ThrowsClauseSyntax?,
        availableGenerics: Swift.Set<Swift.String>
    ) -> AbsolutePosition? {
        guard let clause, let type = clause.type else { return nil }
        guard let member = type.as(MemberTypeSyntax.self) else { return nil }
        guard let base = member.baseType.as(IdentifierTypeSyntax.self) else { return nil }
        guard availableGenerics.contains(base.name.text) else { return nil }
        return member.positionAfterSkippingLeadingTrivia
    }

    /// Heuristic: pull "generic-parameter-looking" identifiers from
    /// an extension's extended-type expression. We can't see the
    /// real declaration's generic parameters from the extension
    /// alone, so we infer from generic-argument syntax if present
    /// (e.g., `extension Parser<Sink>` — Swift 5.7+ short form).
    static func collectExtendedGenericNames(_ type: TypeSyntax) -> Swift.Set<Swift.String> {
        var names: Swift.Set<Swift.String> = []
        if let identifier = type.as(IdentifierTypeSyntax.self),
           let genericArgs = identifier.genericArgumentClause
        {
            for argument in genericArgs.arguments {
                if let ident = argument.argument.as(IdentifierTypeSyntax.self) {
                    names.insert(ident.name.text)
                }
            }
        }
        return names
    }

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        /// Stack of generic-parameter-name sets per enclosing type /
        /// extension. Empty entries for unparameterized scopes.
        var genericsStack: [Swift.Set<Swift.String>] = []

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
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
                identifier: Lint.Rule.Throws.GenericNeverSpecialization.id.underlying,
                message: Lint.Rule.Throws.GenericNeverSpecialization.message
            ))
        }

        private func currentAvailable(_ funcGenerics: Swift.Set<Swift.String>) -> Swift.Set<Swift.String> {
            var result: Swift.Set<Swift.String> = funcGenerics
            for set in genericsStack {
                result.formUnion(set)
            }
            return result
        }

        // MARK: - Enclosing scopes that may declare generic params

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            genericsStack.append(Lint.Rule.Throws.GenericNeverSpecialization.collectGenericParamNames(node.genericParameterClause))
            return .visitChildren
        }
        override func visitPost(_: StructDeclSyntax) { genericsStack.removeLast() }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            genericsStack.append(Lint.Rule.Throws.GenericNeverSpecialization.collectGenericParamNames(node.genericParameterClause))
            return .visitChildren
        }
        override func visitPost(_: ClassDeclSyntax) { genericsStack.removeLast() }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            genericsStack.append(Lint.Rule.Throws.GenericNeverSpecialization.collectGenericParamNames(node.genericParameterClause))
            return .visitChildren
        }
        override func visitPost(_: EnumDeclSyntax) { genericsStack.removeLast() }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            genericsStack.append(Lint.Rule.Throws.GenericNeverSpecialization.collectGenericParamNames(node.genericParameterClause))
            return .visitChildren
        }
        override func visitPost(_: ActorDeclSyntax) { genericsStack.removeLast() }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            // For extensions, generic parameters come from the extended
            // type's declaration — not visible per-file at the syntax
            // level. Push the base identifier path so generic-param
            // references in extensions resolve when the user names them
            // identically to the original declaration site.
            let names = Lint.Rule.Throws.GenericNeverSpecialization.collectExtendedGenericNames(node.extendedType)
            genericsStack.append(names)
            return .visitChildren
        }
        override func visitPost(_: ExtensionDeclSyntax) { genericsStack.removeLast() }

        // MARK: - Function / Initializer

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Throws.GenericNeverSpecialization.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            let funcGenerics = Lint.Rule.Throws.GenericNeverSpecialization.collectGenericParamNames(node.genericParameterClause)
            let available = currentAvailable(funcGenerics)
            if let position = Lint.Rule.Throws.GenericNeverSpecialization.genericFailureTypePosition(
                in: node.signature.effectSpecifiers?.throwsClause,
                availableGenerics: available
            ) {
                emit(at: position)
            }
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Throws.GenericNeverSpecialization.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            let funcGenerics = Lint.Rule.Throws.GenericNeverSpecialization.collectGenericParamNames(node.genericParameterClause)
            let available = currentAvailable(funcGenerics)
            if let position = Lint.Rule.Throws.GenericNeverSpecialization.genericFailureTypePosition(
                in: node.signature.effectSpecifiers?.throwsClause,
                availableGenerics: available
            ) {
                emit(at: position)
            }
            return .visitChildren
        }
    }
}

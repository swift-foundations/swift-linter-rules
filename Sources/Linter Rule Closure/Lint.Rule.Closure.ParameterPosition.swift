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

/// Wave 2b finalization (2026-05-10) — closure parameters trail the
/// signature.
///
/// Citation: `[API-IMPL-012]` (code-surface skill).
///
/// All closure parameters MUST occupy the final positions of a function
/// or initializer signature. A non-closure parameter MUST NOT appear
/// after a closure parameter. Typed-throws thunks per `[IMPL-092]` —
/// `() throws(E) -> T` — count as closures for this rule.
///
/// AST shape: walk the parameter list of `FunctionDeclSyntax` and
/// `InitializerDeclSyntax`. Once a closure-typed parameter is seen,
/// every subsequent non-closure parameter is flagged at its first
/// name. Detection uses the `FunctionTypeSyntax`/`AttributedTypeSyntax`
/// shape (covers `() -> T`, `() async throws(E) -> T`, `@escaping (...)
/// -> T`, etc.).
extension Lint.Rule.Closure {
    public struct ParameterPosition: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "closure_param_position"
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

extension Lint.Rule.Closure.ParameterPosition {
    @usableFromInline
    static let message: Swift.String =
        "[closure_param_position] [API-IMPL-012]: closure parameters MUST occupy the "
        + "final positions of the signature. A non-closure parameter MUST NOT appear "
        + "after a closure parameter — moves the trailing-closure call site. Reorder "
        + "non-closure parameters before all closure parameters; typed-throws thunks "
        + "(`() throws(E) -> T`) count as closures per [IMPL-092]."

    static func isClosureType(_ type: TypeSyntax) -> Bool {
        var current = type
        // Strip optional wrapping (closures may be Optional<Closure>).
        while let optional = current.as(OptionalTypeSyntax.self) {
            current = optional.wrappedType
        }
        // Strip implicitly-unwrapped optional.
        while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            current = iuo.wrappedType
        }
        // Strip attributes (e.g., `@escaping (...) -> T`,
        // `@Sendable (...) -> T`). Sometimes the inner is the closure.
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        // Strip parens around closure types.
        while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
            current = tuple.elements.first!.type
        }
        return current.is(FunctionTypeSyntax.self)
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
                identifier: Lint.Rule.Closure.ParameterPosition.id.underlying,
                message: Lint.Rule.Closure.ParameterPosition.message
            ))
        }

        private func checkParameters(_ parameters: FunctionParameterListSyntax) {
            var sawClosure = false
            for parameter in parameters {
                let isClosure = Lint.Rule.Closure.ParameterPosition.isClosureType(parameter.type)
                if sawClosure, !isClosure {
                    emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
                }
                if isClosure {
                    sawClosure = true
                }
            }
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            checkParameters(node.signature.parameterClause.parameters)
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            checkParameters(node.signature.parameterClause.parameters)
            return .visitChildren
        }
    }
}

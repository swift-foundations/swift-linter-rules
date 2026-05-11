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

/// Wave 4 (mechanization-program) — `let x = expr; return x` exposes
/// mechanism over intent.
///
/// Citation: `[IMPL-EXPR-001]` (implementation skill, style.md — prefer
/// single expressions over intermediate bindings).
///
/// When the only use of a local binding is the immediately-following
/// `return`, the binding adds nothing — the expression on its RHS IS
/// the return value. The canonical form is `return expr`. Boundary
/// conditions ([IMPL-EXPR-001] enumerates them) — multi-use, explanatory
/// name, complexity ceiling — do not fire when the binding is referenced
/// exactly once in a `return` statement.
///
/// AST shape: a `CodeBlockItemListSyntax` containing two adjacent items:
///   1. A `VariableDeclSyntax` with a single binding `let <name> = <expr>`
///      (no type annotation; explicit annotations are explanatory and
///      exempt).
///   2. A `ReturnStmtSyntax` whose expression is exactly
///      `DeclReferenceExprSyntax` with `baseName.text == <name>`.
/// The pair is flagged at the `let` token position.
///
/// Worked examples (flagged):
///   - `let result = compute(); return result`
///
/// Worked examples (NOT flagged):
///   - `let result: Foo = compute(); return result` — explicit type
///     annotation reads as explanatory name.
///   - `let result = compute(); use(result); return result` — multi-use.
///   - `var result = compute(); result.mutate(); return result` — `var`,
///     not `let`; mutation is real use.
extension Lint.Rule.Idiom {
    public struct IntermediateBindingThenReturn: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "intermediate_binding_then_return"
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

extension Lint.Rule.Idiom.IntermediateBindingThenReturn {
    @usableFromInline
    static let message: Swift.String =
        "[intermediate_binding_then_return] [IMPL-EXPR-001]: `let <name> = "
        + "<expr>; return <name>` adds mechanism. Return the expression "
        + "directly: `return <expr>`. The binding is justified only when the "
        + "name communicates domain knowledge the expression doesn't, or when "
        + "the value is consumed more than once — neither applies here."

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

        override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind {
            let items = Array(node)
            // Need ≥ 2 items to check adjacency.
            var i = 0
            while i + 1 < items.count {
                let first = items[i]
                let second = items[i + 1]
                defer { i += 1 }
                guard let varDecl = first.item.as(VariableDeclSyntax.self) else {
                    continue
                }
                guard case .keyword(.let) = varDecl.bindingSpecifier.tokenKind else {
                    continue
                }
                // Single binding only.
                guard varDecl.bindings.count == 1,
                      let binding = varDecl.bindings.first,
                      let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      binding.typeAnnotation == nil,
                      binding.initializer != nil
                else {
                    continue
                }
                guard let returnStmt = second.item.as(ReturnStmtSyntax.self) else {
                    continue
                }
                guard let expression = returnStmt.expression else { continue }
                guard let reference = expression.as(DeclReferenceExprSyntax.self) else {
                    continue
                }
                guard reference.baseName.text == pattern.identifier.text else {
                    continue
                }
                let location = converter.location(
                    for: varDecl.bindingSpecifier.positionAfterSkippingLeadingTrivia
                )
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Idiom.IntermediateBindingThenReturn.id.underlying,
                    message: Lint.Rule.Idiom.IntermediateBindingThenReturn.message
                ))
            }
            return .visitChildren
        }
    }
}

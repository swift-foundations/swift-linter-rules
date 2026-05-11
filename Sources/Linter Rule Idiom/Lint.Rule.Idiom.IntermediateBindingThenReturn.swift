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

/// `let x = expr; return x` exposes mechanism over intent.
/// Citation: `[IMPL-EXPR-001]`.
extension Lint.Rule {
    public static let `intermediate binding then return` = Lint.Rule(
        id: "intermediate_binding_then_return",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = IdiomIntermediateBindingThenReturnVisitor(
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
internal let idiomIntermediateBindingThenReturnMessage: Swift.String =
    "[intermediate_binding_then_return] [IMPL-EXPR-001]: `let <name> = "
    + "<expr>; return <name>` adds mechanism. Return the expression "
    + "directly: `return <expr>`. The binding is justified only when the "
    + "name communicates domain knowledge the expression doesn't, or when "
    + "the value is consumed more than once — neither applies here."

internal final class IdiomIntermediateBindingThenReturnVisitor: SyntaxVisitor {
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
        var i = 0
        while i + 1 < items.count {
            let first = items[i]
            let second = items[i + 1]
            defer { i += 1 }
            guard let varDecl = first.item.as(VariableDeclSyntax.self) else { continue }
            guard case .keyword(.let) = varDecl.bindingSpecifier.tokenKind else { continue }
            guard varDecl.bindings.count == 1,
                  let binding = varDecl.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  binding.typeAnnotation == nil,
                  binding.initializer != nil
            else { continue }
            guard let returnStmt = second.item.as(ReturnStmtSyntax.self) else { continue }
            guard let expression = returnStmt.expression else { continue }
            guard let reference = expression.as(DeclReferenceExprSyntax.self) else { continue }
            guard reference.baseName.text == pattern.identifier.text else { continue }
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
                identifier: "intermediate_binding_then_return",
                message: idiomIntermediateBindingThenReturnMessage
            ))
        }
        return .visitChildren
    }
}

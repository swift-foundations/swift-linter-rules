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

/// `try` inside stdlib `rethrows` higher-order methods MUST be adapted via
/// the `Result<T, E>` shim. Citation: `[IMPL-109]`.
extension Lint.Rule {
    public static let `result wrapper for rethrows shim` = Lint.Rule(
        id: "result_wrapper_for_rethrows_shim",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = ThrowsRethrowsResultShimVisitor(
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
internal let throwsRethrowsResultShimMessage: Swift.String =
    "[result_wrapper_for_rethrows_shim] [IMPL-109]: stdlib `rethrows` higher-order "
    + "methods erase typed-throws to `any Error`. Materialise `Result<T, E>` "
    + "inside the closure, return it, and `try result.get()` outside."

@usableFromInline
internal let rethrowsMethodNames: Swift.Set<Swift.String> = [
    "map", "compactMap", "flatMap", "filter", "forEach", "reduce",
    "first", "contains", "allSatisfy", "min", "max",
    "drop", "prefix", "suffix", "split", "sorted",
]

private final class ThrowsRethrowsTryFinder: SyntaxVisitor {
    var positions: [AbsolutePosition] = []
    var closureDepth: Swift.Int = -1
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark == nil {
            positions.append(node.tryKeyword.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        closureDepth += 1
        if closureDepth > 0 { return .skipChildren }
        return .visitChildren
    }
    override func visitPost(_: ClosureExprSyntax) { closureDepth -= 1 }
    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}

internal final class ThrowsRethrowsResultShimVisitor: SyntaxVisitor {
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

    private func calledMemberName(_ called: ExprSyntax) -> Swift.String? {
        if let memberAccess = called.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName.text
        }
        return nil
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let name = calledMemberName(node.calledExpression) else { return .visitChildren }
        guard rethrowsMethodNames.contains(name) else { return .visitChildren }
        var closures: [ClosureExprSyntax] = []
        if let trailing = node.trailingClosure { closures.append(trailing) }
        for additional in node.additionalTrailingClosures { closures.append(additional.closure) }
        for argument in node.arguments {
            if let closure = argument.expression.as(ClosureExprSyntax.self) {
                closures.append(closure)
            }
        }
        for closure in closures {
            let finder = ThrowsRethrowsTryFinder(viewMode: .sourceAccurate)
            finder.walk(closure)
            for position in finder.positions {
                let location = converter.location(for: position)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "result_wrapper_for_rethrows_shim",
                    message: throwsRethrowsResultShimMessage
                ))
            }
        }
        return .visitChildren
    }
}

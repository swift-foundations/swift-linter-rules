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

/// `do { throw … } catch { … }` blocks MUST use the typed-throws
/// specifier. Citation: `[IMPL-075]`.
extension Lint.Rule {
    public static let `do throws for typed catch with throw` = Lint.Rule(
        id: "do throws for typed catch with throw",
        default: .warning,
        findings: { source, severity in
            let visitor = ThrowsDoCatchTypedThrowVisitor(
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
internal let throwsDoCatchTypedThrowMessage: Swift.String =
    "[do throws for typed catch with throw] [IMPL-075]: bare `do { throw … } "
    + "catch { … }` erases the concrete error type. Use "
    + "`do throws(E) { throw … } catch { … }`."

private final class ThrowsDoCatchThrowFinder: SyntaxVisitor {
    var found = false
    override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}

private final class ThrowsDoCatchTryFinder2: SyntaxVisitor {
    var found = false
    override func visit(_: TryExprSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}

internal final class ThrowsDoCatchTypedThrowVisitor: SyntaxVisitor {
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

    override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.throwsClause != nil { return .visitChildren }
        guard !node.catchClauses.isEmpty else { return .visitChildren }
        let throwFinder = ThrowsDoCatchThrowFinder(viewMode: .sourceAccurate)
        throwFinder.walk(node.body)
        guard throwFinder.found else { return .visitChildren }
        let tryFinder = ThrowsDoCatchTryFinder2(viewMode: .sourceAccurate)
        tryFinder.walk(node.body)
        guard !tryFinder.found else { return .visitChildren }
        let location = converter.location(for: node.doKeyword.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "do throws for typed catch with throw",
            message: throwsDoCatchTypedThrowMessage
        ))
        return .visitChildren
    }
}

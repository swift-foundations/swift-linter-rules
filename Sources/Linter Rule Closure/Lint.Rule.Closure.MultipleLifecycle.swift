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

/// Multi-closure signatures: only the primary body closure may be
/// unlabelled; subsequent closures MUST carry an external label.
/// Citation: `[API-IMPL-013]`.
extension Lint.Rule {
    public static let `unlabeled lifecycle closure` = Lint.Rule(
        id: "multi_closure_unlabeled",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = ClosureMultipleLifecycleVisitor(
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
internal let closureMultipleLifecycleMessage: Swift.String =
    "[multi_closure_unlabeled] [API-IMPL-013]: signatures with two or more closure "
    + "parameters MUST label every closure after the primary body closure. The "
    + "secondary closure label names the closure's *role* (`completion:`, "
    + "`onError:`, `progress:`) — not its type. Per [API-NAME-002], roles over "
    + "types. Lifecycle order is setup → body → completion / teardown."

internal final class ClosureMultipleLifecycleVisitor: SyntaxVisitor {
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
            identifier: "multi_closure_unlabeled",
            message: closureMultipleLifecycleMessage
        ))
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var closureCount = 0
        for parameter in parameters {
            guard isClosureType(parameter.type) else { continue }
            closureCount += 1
            if closureCount >= 2, parameter.firstName.tokenKind == .wildcard {
                emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
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

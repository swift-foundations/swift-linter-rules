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

/// Multi-closure signatures MUST order closures by lifecycle:
/// setup → body → completion / teardown. Citation: `[API-IMPL-013]`.
extension Lint.Rule {
    public static let `lifecycle order` = Lint.Rule(
        id: "lifecycle order",
        default: .warning,
        findings: { source, severity in
            let visitor = ClosureLifecycleOrderVisitor(
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
internal let closureLifecycleOrderMessage: Swift.String =
    "[lifecycle order] [API-IMPL-013]: closure parameters "
    + "MUST follow lifecycle order setup → body → completion / teardown. "
    + "A completion-tier closure (`completion:`, `onError:`, `cleanup:`, "
    + "`teardown:`, `finalize:`) appears BEFORE the primary body closure "
    + "(unlabelled `_` or body-tier label) — reorder so the body comes "
    + "first."

internal let completionTierLabels: Swift.Set<Swift.String> = [
    "completion",
    "onError",
    "onComplete",
    "onCompletion",
    "onFinish",
    "finalize",
    "finally",
    "cleanup",
    "teardown",
    "close",
    "dispose",
]

internal let bodyTierLabels: Swift.Set<Swift.String> = [
    "body",
    "perform",
    "operation",
    "work",
    "action",
    "transform",
]

internal enum LifecycleTier {
    case completion
    case body
    case other
}

internal func lifecycleTier(of parameter: FunctionParameterSyntax) -> LifecycleTier {
    if parameter.firstName.tokenKind == .wildcard {
        return .body
    }
    let labelText = parameter.firstName.text
    if completionTierLabels.contains(labelText) {
        return .completion
    }
    if bodyTierLabels.contains(labelText) {
        return .body
    }
    return .other
}

internal final class ClosureLifecycleOrderVisitor: SyntaxVisitor {
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
            identifier: "lifecycle order",
            message: closureLifecycleOrderMessage
        ))
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var pendingCompletion: [AbsolutePosition] = []
        for parameter in parameters {
            guard isClosureType(parameter.type) else { continue }
            let tier = lifecycleTier(of: parameter)
            switch tier {
            case .completion:
                pendingCompletion.append(parameter.firstName.positionAfterSkippingLeadingTrivia)
            case .body:
                if !pendingCompletion.isEmpty {
                    for position in pendingCompletion {
                        emit(at: position)
                    }
                    pendingCompletion.removeAll()
                }
            case .other:
                continue
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

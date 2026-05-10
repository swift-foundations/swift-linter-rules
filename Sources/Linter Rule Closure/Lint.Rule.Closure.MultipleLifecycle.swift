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

/// Wave 2b finalization (2026-05-10) — multi-closure signatures: only
/// the primary body closure may be unlabelled; subsequent closures
/// MUST carry an external label.
///
/// Citation: `[API-IMPL-013]` (code-surface skill).
///
/// For signatures with two or more closure parameters, closures MUST be
/// ordered by lifecycle: setup → body → completion / teardown. The
/// primary body closure MAY be unlabelled (per SE-0279); all subsequent
/// closures MUST be labelled. Labels for secondary closures appear in
/// the call-site surface (`… completion: { … }`, `… onError: { … }`)
/// and MUST name the closure's *role*, not its Swift type — per
/// `[API-NAME-002]`.
///
/// AST shape: count closure-typed parameters (per
/// `Lint.Rule.Closure.ParameterPosition.isClosureType`). If ≥ 2 and the
/// 2nd-and-onward closure parameter has `firstName.tokenKind ==
/// .wildcard` (`_`), it is unlabelled — flag.
extension Lint.Rule.Closure {
    public struct MultipleLifecycle: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "multi_closure_unlabeled"
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

extension Lint.Rule.Closure.MultipleLifecycle {
    @usableFromInline
    static let message: Swift.String =
        "[multi_closure_unlabeled] [API-IMPL-013]: signatures with two or more closure "
        + "parameters MUST label every closure after the primary body closure. The "
        + "secondary closure label names the closure's *role* (`completion:`, "
        + "`onError:`, `progress:`) — not its type. Per [API-NAME-002], roles over "
        + "types. Lifecycle order is setup → body → completion / teardown."

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
                identifier: Lint.Rule.Closure.MultipleLifecycle.id.underlying,
                message: Lint.Rule.Closure.MultipleLifecycle.message
            ))
        }

        private func checkParameters(_ parameters: FunctionParameterListSyntax) {
            var closureCount = 0
            for parameter in parameters {
                guard Lint.Rule.Closure.ParameterPosition.isClosureType(parameter.type) else {
                    continue
                }
                closureCount += 1
                // Only flag the 2nd-and-onward closure parameter when its
                // external label is wildcard `_`.
                if closureCount >= 2 {
                    if parameter.firstName.tokenKind == .wildcard {
                        emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
                    }
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

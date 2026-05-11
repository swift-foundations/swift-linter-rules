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

/// Wave 3 (mechanization-program) — multi-closure signatures MUST order
/// closures by lifecycle: setup → body → completion / teardown.
///
/// Citation: `[API-IMPL-013]` (code-surface skill — multiple closures
/// follow lifecycle order).
///
/// Companion to the Wave 2b `Lint.Rule.Closure.MultipleLifecycle`,
/// which enforces the LABEL aspect of [API-IMPL-013] (the secondary
/// closure must carry an external label). This rule enforces the
/// ORDER aspect: a closure labelled with a completion / teardown-tier
/// vocabulary (e.g., `completion`, `onError`, `cleanup`, `teardown`,
/// `finalize`) MUST NOT precede a closure that is unlabelled (`_`) or
/// labelled with a setup / body-tier vocabulary.
///
/// AST shape: walk `FunctionDeclSyntax`/`InitializerDeclSyntax`
/// parameter lists. Among closure-typed parameters, track positions
/// of "completion-tier" closures (label in the completion-tier set)
/// and "body-tier" closures (unlabelled `_` OR label in the body-tier
/// set). If a completion-tier closure index is less than ANY
/// body-tier closure index → flag the misplaced completion closure.
///
/// Worked examples (flagged):
///   - `func perform(completion: @escaping (Result) -> Void, body:
///     @escaping () -> Void)` — `completion` precedes `body`; body
///     loses its trailing-closure call-site shape.
///   - `func op(onError: () -> Void, _ body: () -> Void)` — `onError`
///     (completion-tier) precedes `_` (body-tier, unlabelled).
///
/// Worked examples (NOT flagged):
///   - `func perform(_ body: () -> Void, completion: (Result) -> Void)` —
///     correct order: body before completion.
///   - `func op(setup: () -> Void, _ body: () -> Void, completion:
///     (Result) -> Void)` — correct lifecycle order.
///   - `func op(progress: () -> Void, completion: () -> Void)` — both
///     non-body closures; rule cannot tell which is intended body
///     without an unlabelled or body-tier anchor; conservatively
///     skipped.
extension Lint.Rule.Closure {
    public struct LifecycleOrder: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "multi_closure_lifecycle_order"
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

extension Lint.Rule.Closure.LifecycleOrder {
    @usableFromInline
    static let message: Swift.String =
        "[multi_closure_lifecycle_order] [API-IMPL-013]: closure parameters "
        + "MUST follow lifecycle order setup → body → completion / teardown. "
        + "A completion-tier closure (`completion:`, `onError:`, `cleanup:`, "
        + "`teardown:`, `finalize:`) appears BEFORE the primary body closure "
        + "(unlabelled `_` or body-tier label) — reorder so the body comes "
        + "first. Companion to `Lint.Rule.Closure.MultipleLifecycle` which "
        + "enforces secondary-closure labelling."

    static let completionTierLabels: Swift.Set<Swift.String> = [
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

    static let bodyTierLabels: Swift.Set<Swift.String> = [
        "body",
        "perform",
        "operation",
        "work",
        "action",
        "transform",
    ]

    /// Returns a classification token for a closure parameter:
    ///   .completion — label is in completionTierLabels
    ///   .body       — wildcard `_` external label OR label in bodyTierLabels
    ///   .other      — labelled but not in either set (e.g., `setup:`,
    ///                 `progress:`, domain-specific)
    enum Tier {
        case completion
        case body
        case other
    }

    static func tier(of parameter: FunctionParameterSyntax) -> Tier {
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
                identifier: Lint.Rule.Closure.LifecycleOrder.id.underlying,
                message: Lint.Rule.Closure.LifecycleOrder.message
            ))
        }

        private func checkParameters(_ parameters: FunctionParameterListSyntax) {
            // Walk closure-typed parameters in order; record their tier
            // and the position to flag (firstName). When a body-tier
            // closure appears AFTER a completion-tier one, the
            // completion-tier closure was misplaced — flag it.
            var sawBodyTier = false
            // Cache completion-tier positions seen so far so we can
            // emit them once any body-tier closure appears later.
            var pendingCompletion: [AbsolutePosition] = []
            for parameter in parameters {
                guard Lint.Rule.Closure.ParameterPosition.isClosureType(parameter.type) else {
                    continue
                }
                let tier = Lint.Rule.Closure.LifecycleOrder.tier(of: parameter)
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
                    sawBodyTier = true
                case .other:
                    continue
                }
            }
            // Unconsumed pendingCompletion is FINE if no body tier ever
            // appeared — `progress:`/`completion:` pairs (both labelled)
            // can't be diagnosed without an anchor.
            _ = sawBodyTier
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

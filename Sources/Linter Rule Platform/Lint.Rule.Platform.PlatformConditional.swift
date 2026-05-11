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

/// Wave 3 (mechanization-program) — platform identity checks MUST use
/// `#if os(...)`, not `#if canImport(...)`.
///
/// Citation: `[PATTERN-004a]` (platform skill — source-level platform
/// conditionals).
///
/// `os()` evaluates against the target triple — deterministic. `canImport`
/// evaluates against module resolution — varies by build system. Using
/// `canImport(Darwin_Kernel_Standard)` for platform identity makes the
/// build's platform branch depend on whether the build system has
/// resolved that module name, which is fragile and bypasses the target-
/// triple authority. Reserve `canImport` for optional feature modules
/// (e.g., `#if canImport(SwiftUI)`).
///
/// AST shape: walk `IfConfigClauseSyntax`. For each, inspect the
/// `condition` expression. If it is a `FunctionCallExprSyntax` whose
/// callee is the identifier `canImport` and the argument identifier
/// starts with a platform-namespace prefix (`Darwin`, `Linux`, `Windows`,
/// `Glibc`, `Musl`, `Bionic`, `WinSDK`), flag the argument position.
///
/// Worked examples (flagged):
///   - `#if canImport(Darwin_Kernel_Standard)` — platform identity via
///     `canImport`; should use `#if os(macOS) || os(iOS) || …`.
///   - `#if canImport(Linux)` — same antipattern.
///
/// Worked examples (NOT flagged):
///   - `#if os(macOS)` — correct platform identity check.
///   - `#if canImport(SwiftUI)` — optional feature module, not platform
///     identity.
///   - `#if canImport(Combine)` — third-party / optional Apple module.
extension Lint.Rule.Platform {
    public struct PlatformConditional: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "platform_canimport_conditional"
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

extension Lint.Rule.Platform.PlatformConditional {
    @usableFromInline
    static let message: Swift.String =
        "[platform_canimport_conditional] [PATTERN-004a]: platform "
        + "identity check uses `#if canImport(...)` on a platform-prefixed "
        + "module — `canImport` evaluates against module resolution (varies "
        + "by build system); platform identity is what `#if os(...)` is "
        + "for (evaluates against the target triple). Reserve `canImport` "
        + "for optional feature modules (`SwiftUI`, `Combine`, etc.)."

    static let platformPrefixes: Swift.Set<Swift.String> = [
        "Darwin",
        "Linux",
        "Windows",
        "Glibc",
        "Musl",
        "Bionic",
        "WinSDK",
    ]

    static func isPlatformModuleName(_ name: Swift.String) -> Swift.Bool {
        if platformPrefixes.contains(name) { return true }
        for prefix in platformPrefixes {
            if name.hasPrefix("\(prefix)_") { return true }
        }
        return false
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

        override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
            guard let condition = node.condition else { return .visitChildren }
            checkCondition(condition)
            return .visitChildren
        }

        private func checkCondition(_ expression: ExprSyntax) {
            // canImport(<name>) — single call.
            if let call = expression.as(FunctionCallExprSyntax.self) {
                if let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
                   callee.baseName.text == "canImport"
                {
                    if let argument = call.arguments.first,
                       let identifier = argument.expression.as(DeclReferenceExprSyntax.self)
                    {
                        if Lint.Rule.Platform.PlatformConditional.isPlatformModuleName(
                            identifier.baseName.text
                        ) {
                            let position = identifier.baseName.positionAfterSkippingLeadingTrivia
                            let location = converter.location(for: position)
                            matches.append(Diagnostic.Record(
                                location: Source.Location(
                                    fileID: source.fileID,
                                    filePath: source.filePath,
                                    line: location.line,
                                    column: location.column
                                ),
                                severity: severity,
                                identifier: Lint.Rule.Platform.PlatformConditional.id.underlying,
                                message: Lint.Rule.Platform.PlatformConditional.message
                            ))
                        }
                    }
                }
            }
            // Compound expressions: `canImport(X) && os(Y)` — recurse via
            // SequenceExpr / InfixOperator. SwiftParser shapes vary;
            // descend the children defensively.
            if let sequence = expression.as(SequenceExprSyntax.self) {
                for element in sequence.elements {
                    checkCondition(element)
                }
            }
            if let infix = expression.as(InfixOperatorExprSyntax.self) {
                checkCondition(infix.leftOperand)
                checkCondition(infix.rightOperand)
            }
            if let prefix = expression.as(PrefixOperatorExprSyntax.self) {
                checkCondition(prefix.expression)
            }
        }
    }
}

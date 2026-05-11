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
extension Lint.Rule {
    public static let `canimport conditional` = Lint.Rule(
        id: "platform_canimport_conditional",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = PlatformPlatformConditionalVisitor(
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
internal let platformPlatformConditionalMessage: Swift.String =
    "[platform_canimport_conditional] [PATTERN-004a]: platform "
    + "identity check uses `#if canImport(...)` on a platform-prefixed "
    + "module — `canImport` evaluates against module resolution (varies "
    + "by build system); platform identity is what `#if os(...)` is "
    + "for (evaluates against the target triple). Reserve `canImport` "
    + "for optional feature modules (`SwiftUI`, `Combine`, etc.)."

internal let platformPlatformConditionalPlatformPrefixes: Swift.Set<Swift.String> = [
    "Darwin",
    "Linux",
    "Windows",
    "Glibc",
    "Musl",
    "Bionic",
    "WinSDK",
]

internal func platformPlatformConditionalIsPlatformModuleName(_ name: Swift.String) -> Swift.Bool {
    if platformPlatformConditionalPlatformPrefixes.contains(name) { return true }
    for prefix in platformPlatformConditionalPlatformPrefixes {
        if name.hasPrefix("\(prefix)_") { return true }
    }
    return false
}

internal final class PlatformPlatformConditionalVisitor: SyntaxVisitor {
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
        if let call = expression.as(FunctionCallExprSyntax.self) {
            if let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
               callee.baseName.text == "canImport"
            {
                if let argument = call.arguments.first,
                   let identifier = argument.expression.as(DeclReferenceExprSyntax.self)
                {
                    if platformPlatformConditionalIsPlatformModuleName(
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
                            identifier: "platform_canimport_conditional",
                            message: platformPlatformConditionalMessage
                        ))
                    }
                }
            }
        }
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

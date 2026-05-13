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

/// Mock factories on pointer-wrapping `BitwiseCopyable` types MUST
/// offset tag input by at least 1. Citation: `[TEST-028]`.
extension Lint.Rule {
    public static let `mock factory zero collision` = Lint.Rule(
        id: "mock factory zero collision",
        default: .warning,
        findings: { source, severity in
            let visitor = TestingMockFactoryZeroCollisionVisitor(
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
internal let testingMockFactoryZeroCollisionMessage: Swift.String =
    "[mock factory zero collision] [TEST-028]: `unsafeBitCast(tag, to: T.self)` "
    + "for pointer-wrapping `BitwiseCopyable` `T` collides with `Optional<T>.none` "
    + "when `tag == 0`. Offset: `unsafeBitCast(tag &+ 1, to: T.self)`."

internal final class TestingMockFactoryZeroCollisionVisitor: SyntaxVisitor {
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

    private func isUnsafeBitCast(_ expr: ExprSyntax) -> Swift.Bool {
        if let identifier = expr.as(DeclReferenceExprSyntax.self) {
            return identifier.baseName.text == "unsafeBitCast"
        }
        return false
    }

    private func firstArgumentLooksRaw(_ argument: LabeledExprSyntax) -> Swift.Bool {
        let text = argument.expression.trimmedDescription
        if text.contains("&+") || text.contains("+ 1") || text.contains(" + ") {
            return false
        }
        return true
    }

    /// The rule targets mock-factory hygiene: tag-pointer collision with
    /// `Optional<T>.none` only occurs when the bitcast source is a small
    /// integer literal / variable being cast to a pointer-wrapping
    /// `BitwiseCopyable` type. Function references being reshaped
    /// (e.g., `unsafeBitCast(Type.init(arrayLiteral:) as ..., to: ...)`)
    /// have no such collision shape.
    private func firstArgumentLooksLikeIntegerTag(_ argument: LabeledExprSyntax) -> Swift.Bool {
        // Reject function-reference forms (the swift-tagged Tagged+Literals
        // case): `Underlying.init(arrayLiteral:) as (...) -> Underlying`.
        // These are AsExprSyntax wrapping a member-access of `init`.
        if argument.expression.is(AsExprSyntax.self) {
            return false
        }
        // Reject member-access expressions (function references like
        // `Foo.method` or `Type.init`).
        if argument.expression.is(MemberAccessExprSyntax.self) {
            return false
        }
        return true
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // Scope-limit: the rule targets mock-factory hygiene in test
        // code. Source-tree paths don't host mock factories — firing
        // there is rule-scope leakage.
        if !source.filePath.contains("/Tests/") {
            return .visitChildren
        }
        guard isUnsafeBitCast(node.calledExpression) else { return .visitChildren }
        guard let firstArgument = node.arguments.first else { return .visitChildren }
        guard firstArgumentLooksRaw(firstArgument) else { return .visitChildren }
        guard firstArgumentLooksLikeIntegerTag(firstArgument) else { return .visitChildren }
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "mock factory zero collision",
            message: testingMockFactoryZeroCollisionMessage
        ))
        return .visitChildren
    }
}

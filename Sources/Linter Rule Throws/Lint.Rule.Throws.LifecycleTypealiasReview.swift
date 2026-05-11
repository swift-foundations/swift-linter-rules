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

/// Wave 3 (mechanization-program) — typealiasing per-primitive `Error`
/// to a shared `*.Lifecycle.Error` requires case-coverage review.
///
/// Citation: `[API-ERR-008]` (code-surface skill — lifecycle typealias
/// only when ALL cases apply).
///
/// When a primitive types-aliases its `Error` to a shared lifecycle
/// error type (`Async.Lifecycle.Error`, `Pool.Lifecycle.Error`), the
/// alias is appropriate ONLY when the primitive actually produces
/// every case of the lifecycle type. Otherwise consumers writing
/// exhaustive `catch` blocks see phantom-case API surface — cases the
/// primitive will never produce. The typealias is a runtime promise
/// the implementation may not keep.
///
/// AST shape: a `TypealiasDeclSyntax` whose name is `Error` (per
/// `[API-NAME-001]`/`[API-ERR-002]` per-primitive convention) and whose
/// initialized type is a `MemberTypeSyntax` chain ending in `.Error`
/// where the preceding component is named `Lifecycle`. The rule cannot
/// mechanically verify case coverage; it flags for human review.
///
/// Worked examples (flagged):
///   - `typealias Error = Async.Lifecycle.Error` — review case coverage.
///   - `typealias Error = Pool.Lifecycle.Error` — review case coverage.
///   - `extension Channel { typealias Error = Async.Lifecycle.Error }` —
///     extension form, same review.
///
/// Worked examples (NOT flagged):
///   - `typealias Error = ChannelError` — concrete per-primitive type.
///   - `typealias Error = Async.Lifecycle` — points at the namespace,
///     not the `.Error` leaf; not the lifecycle-error pattern.
///   - `typealias E = Async.Lifecycle.Error` — alias name is not
///     `Error` (per-primitive convention requires `Error`).
extension Lint.Rule.Throws {
    public struct LifecycleTypealiasReview: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "lifecycle_typealias_review"
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

extension Lint.Rule.Throws.LifecycleTypealiasReview {
    @usableFromInline
    static let message: Swift.String =
        "[lifecycle_typealias_review] [API-ERR-008]: typealias `Error = "
        + "<Domain>.Lifecycle.Error` adopts a SHARED lifecycle-error type. "
        + "Confirm the primitive actually produces EVERY case of the "
        + "lifecycle type — if some cases are unreachable for this "
        + "primitive, the typealias lies (consumers see phantom-case API). "
        + "Keep a narrower per-primitive enum instead. If all cases apply, "
        + "document the analysis at the typealias site."

    /// Returns true when the member-type chain has the shape
    /// `<…>.Lifecycle.Error` (any leading namespace).
    static func isLifecycleErrorMemberType(_ type: TypeSyntax) -> Swift.Bool {
        guard let member = type.as(MemberTypeSyntax.self) else { return false }
        guard member.name.text == "Error" else { return false }
        guard let parent = member.baseType.as(MemberTypeSyntax.self) else {
            // Could be `Lifecycle.Error` directly (no leading namespace).
            if let base = member.baseType.as(IdentifierTypeSyntax.self),
               base.name.text == "Lifecycle"
            {
                return true
            }
            return false
        }
        return parent.name.text == "Lifecycle"
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

        override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.name.text == "Error" else { return .visitChildren }
            let initialized = node.initializer.value
            guard Lint.Rule.Throws.LifecycleTypealiasReview.isLifecycleErrorMemberType(initialized) else {
                return .visitChildren
            }
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Throws.LifecycleTypealiasReview.id.underlying,
                message: Lint.Rule.Throws.LifecycleTypealiasReview.message
            ))
            return .visitChildren
        }
    }
}

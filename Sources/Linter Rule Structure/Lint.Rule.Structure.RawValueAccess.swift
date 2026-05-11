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

/// Wave 4 (mechanization-program) — `.rawValue` and `.position` accesses
/// at consumer call sites bypass typed-conversion ladders.
///
/// Citation: `[PATTERN-017]` (implementation skill, patterns.md).
///
/// `.rawValue` and `.position` are escape hatches reserved for extension
/// initializers (where the conversion is the type's own boundary) and
/// same-package implementations (where the underlying representation is
/// part of the contract). At consumer call sites outside the declaring
/// package, the access surfaces mechanism — domain identity collapses
/// to its raw representation at the moment the access fires.
///
/// AST shape: a `MemberAccessExprSyntax` whose `declName.baseName.text`
/// is `rawValue` or `position` AND which appears INSIDE a function /
/// method / initializer / closure body (i.e., is not at type-level
/// declaration scope where extensions on the brand-newtype legitimately
/// reach the underlying representation). The "inside an extension init"
/// exemption is harder to verify mechanically — file paths under
/// `Sources/<DeclaringPackage>/` are domain-specific and the validator
/// cannot tell which package owns the declaration. The flag is a review
/// prompt; suppress via `// swiftlint:disable:next` for legitimate cases.
extension Lint.Rule.Structure {
    public struct RawValueAccess: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "raw_value_access"
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

extension Lint.Rule.Structure.RawValueAccess {
    @usableFromInline
    static let message: Swift.String =
        "[raw_value_access] [PATTERN-017]: `.rawValue` / `.position` at a "
        + "consumer call site bypasses the typed-conversion ladder. These "
        + "accessors are reserved for extension initializers (the brand-newtype's "
        + "own boundary) and same-package implementations. Prefer the typed "
        + "operation; suppress with `// swiftlint:disable:next raw_value_access` "
        + "with a `// WHY:` reason for legitimate same-package use."

    static let flaggedAccessors: Swift.Set<Swift.String> = ["rawValue", "position"]

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        // Stack depth: counts enclosing function / initializer / closure
        // bodies. Non-zero ⇒ we are inside an executable code region.
        var bodyDepth: Swift.Int = 0

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            bodyDepth += 1
            return .visitChildren
        }
        override func visitPost(_: FunctionDeclSyntax) {
            bodyDepth -= 1
        }
        override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            bodyDepth += 1
            return .visitChildren
        }
        override func visitPost(_: InitializerDeclSyntax) {
            bodyDepth -= 1
        }
        override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            bodyDepth += 1
            return .visitChildren
        }
        override func visitPost(_: ClosureExprSyntax) {
            bodyDepth -= 1
        }
        override func visit(_: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
            bodyDepth += 1
            return .visitChildren
        }
        override func visitPost(_: AccessorDeclSyntax) {
            bodyDepth -= 1
        }

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            guard bodyDepth > 0 else { return .visitChildren }
            let name = node.declName.baseName.text
            guard Lint.Rule.Structure.RawValueAccess.flaggedAccessors.contains(name) else {
                return .visitChildren
            }
            let location = converter.location(
                for: node.declName.baseName.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Structure.RawValueAccess.id.underlying,
                message: Lint.Rule.Structure.RawValueAccess.message
            ))
            return .visitChildren
        }
    }
}

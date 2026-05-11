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

/// Wave 4 (mechanization-program) — raw pointer arithmetic via
/// `.advanced(by:)` is mechanism; types managing memory SHOULD expose a
/// typed `pointer(at:)` primitive that encapsulates offset computation.
///
/// Citation: `[IMPL-011]` (implementation skill, infrastructure.md).
///
/// `unsafe basePointer.advanced(by: offset)` reaches inside the typed
/// layer to perform raw offset math; the institute pattern is
/// `storage.pointer(at: slot)` where `slot` is a typed `Index<Element>`
/// and the storage type encapsulates the offset computation. Direct
/// `.advanced(by:)` calls at consumer call sites indicate either (a)
/// the storage type is missing the `pointer(at:)` primitive (which
/// SHOULD be added per the rule), or (b) the consumer is reaching past
/// the typed surface inappropriately.
///
/// AST shape: `FunctionCallExprSyntax` whose called expression is a
/// `MemberAccessExprSyntax` named `advanced`. This catches the
/// canonical `pointer.advanced(by: offset)` form. Bare pointer
/// arithmetic via `+`/`-` operators on pointer types is harder to
/// detect mechanically (operator overloads on UnsafePointer vs.
/// arithmetic on regular numerics need type information); the rule
/// covers the named-method form which is the dominant idiom.
extension Lint.Rule.Memory {
    public struct PointerArithmetic: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "pointer_advanced_by"
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

extension Lint.Rule.Memory.PointerArithmetic {
    @usableFromInline
    static let message: Swift.String =
        "[pointer_advanced_by] [IMPL-011]: raw pointer arithmetic via "
        + "`.advanced(by:)` is mechanism. Types managing memory SHOULD expose "
        + "a typed `pointer(at: Index<Element>)` primitive that encapsulates "
        + "the offset computation. Either (a) add the typed primitive to the "
        + "storage type and call it, or (b) confine the `.advanced(by:)` to a "
        + "designated pointer-primitives package."

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

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
                return .visitChildren
            }
            guard member.declName.baseName.text == "advanced" else {
                return .visitChildren
            }
            // Single argument labeled `by:`.
            guard node.arguments.count == 1,
                  let argument = node.arguments.first,
                  argument.label?.text == "by"
            else {
                return .visitChildren
            }
            let location = converter.location(
                for: member.declName.baseName.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Memory.PointerArithmetic.id.underlying,
                message: Lint.Rule.Memory.PointerArithmetic.message
            ))
            return .visitChildren
        }
    }
}

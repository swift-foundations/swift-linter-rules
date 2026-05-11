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

/// Wave 4 (mechanization-program) — `for (i, _) in <expr>.enumerated()`
/// followed by `<expr>[i]` silently breaks semantics on custom
/// Collections whose Index is not a 0-based offset.
///
/// Citation: `[PATTERN-058]` (implementation skill, patterns.md).
///
/// When a `Collection.Index` is a domain-specific Int (byte position,
/// token offset) rather than a 0-based element offset, callers using
/// `.enumerated()` + subscript-by-Int assume element offsets and get
/// wrong semantics with no compiler warning. The institute pattern
/// prefers iterator-based comparison or `zip(a, b)` over the
/// enumerated-subscript form for non-Array Collections.
///
/// AST shape: `ForStmtSyntax` whose pattern is a `TuplePatternSyntax`
/// with two elements (first an identifier, second wildcard or
/// identifier) AND whose sequence is a `FunctionCallExprSyntax` on
/// `<expr>.enumerated()` AND whose body contains at least one
/// `SubscriptCallExprSyntax` whose argument's first element references
/// the loop's index identifier. The match is narrow — covers the
/// canonical anti-pattern from `Paths.Path.Components` and analogous
/// custom collections. Array iteration via `.enumerated()` is correct
/// (Array.Index IS the 0-based offset) but the linter has no type
/// information to discriminate Array from custom collections, so the
/// rule is conservative: when the SAME identifier is used in the
/// `for (i, _) in seq.enumerated()` pattern AND `seq[i]` inside the
/// body, flag the body access as the load-bearing site to review.
extension Lint.Rule.Idiom {
    public struct EnumeratedSubscript: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "enumerated_subscript_collection"
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

extension Lint.Rule.Idiom.EnumeratedSubscript {
    @usableFromInline
    static let message: Swift.String =
        "[enumerated_subscript_collection] [PATTERN-058]: `for (i, _) in "
        + "<seq>.enumerated() { ... <seq>[i] }` works on Array but silently "
        + "breaks on custom Collections whose `Index` is not a 0-based offset "
        + "(byte position, token offset). Prefer iterator-based comparison or "
        + "`zip(a, b)`. Suppress with a `// swiftlint:disable:next` and "
        + "`// WHY:` for confirmed Array call sites."

    /// Returns the loop-index name if the pattern is `(name, _)` or
    /// `(name, anything)`, else nil.
    static func loopIndexName(_ pattern: PatternSyntax) -> Swift.String? {
        guard let tuple = pattern.as(TuplePatternSyntax.self) else { return nil }
        guard tuple.elements.count == 2 else { return nil }
        guard let first = tuple.elements.first?.pattern.as(IdentifierPatternSyntax.self) else {
            return nil
        }
        return first.identifier.text
    }

    static func trimmed(_ string: Swift.String) -> Swift.String {
        var characters = Array(string)
        while let first = characters.first, first.isWhitespace {
            characters.removeFirst()
        }
        while let last = characters.last, last.isWhitespace {
            characters.removeLast()
        }
        return Swift.String(characters)
    }

    /// Returns the base-expression text if the sequence is
    /// `<expr>.enumerated()`, else nil.
    static func enumeratedReceiverText(_ sequence: ExprSyntax) -> Swift.String? {
        guard let call = sequence.as(FunctionCallExprSyntax.self) else { return nil }
        guard let member = call.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }
        guard member.declName.baseName.text == "enumerated" else { return nil }
        guard call.arguments.isEmpty else { return nil }
        guard let base = member.base else { return nil }
        return trimmed(base.description)
    }

    final class BodySearch: SyntaxVisitor {
        let indexName: Swift.String
        let receiverText: Swift.String
        var hits: [AbsolutePosition] = []

        init(indexName: Swift.String, receiverText: Swift.String) {
            self.indexName = indexName
            self.receiverText = receiverText
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: SubscriptCallExprSyntax) -> SyntaxVisitorContinueKind {
            // Compare bare receiver text — narrow string match keeps the
            // rule conservative; refactor would use scope/semantic info.
            let receiverDescription = Lint.Rule.Idiom.EnumeratedSubscript
                .trimmed(node.calledExpression.description)
            guard receiverDescription == receiverText else {
                return .visitChildren
            }
            guard let firstArgument = node.arguments.first else {
                return .visitChildren
            }
            if let reference = firstArgument.expression.as(DeclReferenceExprSyntax.self),
               reference.baseName.text == indexName {
                hits.append(node.calledExpression.endPositionBeforeTrailingTrivia)
            }
            return .visitChildren
        }
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

        override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
            guard let indexName = Lint.Rule.Idiom.EnumeratedSubscript
                .loopIndexName(node.pattern) else {
                return .visitChildren
            }
            guard let receiverText = Lint.Rule.Idiom.EnumeratedSubscript
                .enumeratedReceiverText(node.sequence) else {
                return .visitChildren
            }
            let search = BodySearch(indexName: indexName, receiverText: receiverText)
            search.walk(node.body)
            guard !search.hits.isEmpty else { return .visitChildren }
            // Flag the loop-keyword position for clear diagnostic placement.
            let location = converter.location(
                for: node.forKeyword.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Idiom.EnumeratedSubscript.id.underlying,
                message: Lint.Rule.Idiom.EnumeratedSubscript.message
            ))
            return .visitChildren
        }
    }
}

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

/// Wave 3 (mechanization-program) — callback APIs MUST express outcomes
/// as `() throws(E) -> T` thunk parameters, not as `Result<T, E>` values.
///
/// Citation: `[IMPL-092]` (implementation skill — `throws(E)` thunk
/// parameters over `Result<T, E>` for callback outcomes).
///
/// For callback APIs that deliver one-of (value, error) to a consumer
/// closure, the outcome MUST be expressed as a `() throws(E) -> T` thunk
/// parameter — the consumer reads as intent (`try wait()`/`catch`) using
/// language primitives. Passing a `Result<T, E>` value forces the
/// consumer to `switch` on cases explicitly — mechanism, not intent.
///
/// AST shape: a `FunctionTypeSyntax` appearing as a parameter or stored
/// property whose own parameter list contains an `IdentifierTypeSyntax`
/// or `MemberTypeSyntax` named `Result` or `Swift.Result`. The closure
/// type that uses `Result` is the callback that should be a throws
/// thunk; flag the `Result` token position.
///
/// Worked examples (flagged):
///   - `func op(callback: (Result<Value, MyError>) -> Void)` — closure
///     parameter takes `Result`; convert to thunk: `op(callback: ()
///     throws(MyError) -> Value)`.
///   - `let onTick: @Sendable (Result<UnsafeBuffer<T>, Error>) -> Outcome`
///     — stored property typed as closure-of-Result.
///   - `init(_: @escaping (Swift.Result<Int, Swift.Error>) -> Void)` —
///     `Swift.Result` member-type form.
///
/// Worked examples (NOT flagged):
///   - `func op() throws(E) -> Result<T, E>` — function returns
///     `Result`; that's a STORAGE / return-shape use of `Result`, not a
///     callback parameter shape ([IMPL-092] exception #1).
///   - `let cached: Result<T, E>` — stored Result, not in a closure
///     parameter context.
///   - `func op(_ value: Result<T, E>) -> Void` — top-level Result
///     parameter on a function (not a closure parameter of another
///     function); could be a deliberate API choice for storage transit.
///     Out of mechanical scope to keep diagnostics tight.
extension Lint.Rule.Throws {
    public struct ResultCallback: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "callback_result_over_throws_thunk"
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

extension Lint.Rule.Throws.ResultCallback {
    @usableFromInline
    static let message: Swift.String =
        "[callback_result_over_throws_thunk] [IMPL-092]: callback closure "
        + "parameters MUST deliver outcomes via a `() throws(E) -> T` thunk, "
        + "not a `Result<T, E>` value — consumers read `try value(); catch` "
        + "(intent, language semantics) instead of `switch result { case "
        + ".success / .failure }` (mechanism). Internal storage of the "
        + "outcome MAY still be a `Result`, an `Optional`, or a private enum."

    /// Returns the position of the `Result` token in a type expression
    /// if it is `Result<...>` or `Swift.Result<...>`, else nil.
    static func resultTokenPosition(in type: TypeSyntax) -> AbsolutePosition? {
        // Strip optional / IUO / attributed wrappers.
        var current = type
        while let optional = current.as(OptionalTypeSyntax.self) {
            current = optional.wrappedType
        }
        while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            current = iuo.wrappedType
        }
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        if let identifier = current.as(IdentifierTypeSyntax.self),
           identifier.name.text == "Result"
        {
            return identifier.name.positionAfterSkippingLeadingTrivia
        }
        if let member = current.as(MemberTypeSyntax.self),
           member.name.text == "Result",
           let base = member.baseType.as(IdentifierTypeSyntax.self),
           base.name.text == "Swift"
        {
            return member.name.positionAfterSkippingLeadingTrivia
        }
        return nil
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

        override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
            // A closure type — check each of its parameter types for Result.
            for parameter in node.parameters {
                if let position = Lint.Rule.Throws.ResultCallback.resultTokenPosition(in: parameter.type) {
                    let location = converter.location(for: position)
                    matches.append(Diagnostic.Record(
                        location: Source.Location(
                            fileID: source.fileID,
                            filePath: source.filePath,
                            line: location.line,
                            column: location.column
                        ),
                        severity: severity,
                        identifier: Lint.Rule.Throws.ResultCallback.id.underlying,
                        message: Lint.Rule.Throws.ResultCallback.message
                    ))
                }
            }
            return .visitChildren
        }
    }
}

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

/// Wave 1 (mechanization-program) — `Int` parameter or return type in
/// public-API signatures.
///
/// Citation: `[IMPL-010]` (implementation skill — Push Int to the Edge).
///
/// `Int(bitPattern:)` conversions MUST live inside boundary overloads,
/// never at call sites. Public-API parameters and return types should
/// use the typed forms — `Index<T>`, `Ordinal`, `Cardinal`,
/// `Count<T>`, `Offset<T>` — so the stdlib boundary is invisible to
/// consumers. A bare `Int` in a public signature is the structural
/// signal that the boundary has not been pushed all the way out.
///
/// Detection: walk `public` / `open` functions and initializers. If
/// a parameter type or the return type resolves (after stripping
/// optionals + attributed wrappers) to an identifier `Int` or member-
/// type `Swift.Int`, flag it. Other typed wrappers (`Index<...>`,
/// `Ordinal`, `Cardinal`, etc.) do not match the literal `Int` token
/// and are NOT flagged.
///
/// Worked examples (flagged):
///   - `public func read(count: Int) -> Int { 0 }` — both flagged.
///   - `public init(count: Int) {}` — flagged.
///   - `public func tag() -> Int { 0 }` — return flagged.
///   - `public func read(count: Swift.Int) {}` — flagged.
///
/// Worked examples (NOT flagged):
///   - `public func read(count: Cardinal) -> Cardinal {}` — typed.
///   - `public func read(at: Index<UInt8>) -> UInt8 { 0 }` — typed.
///   - `func read(count: Int) {}` — internal visibility, exempt.
///   - `public func encode(_ b: UInt8) {}` — sized integer, exempt
///     (`UInt8` for byte / `Int32` for fd / etc. are valid domain
///     types; the rule scopes to the bare `Int` token).
///   - `public func op(_ body: (Int) -> Void) {}` — closure-typed
///     parameter; the inner Int is exempt.
///
/// Excluded scopes:
/// - Non-public functions/initializers (`internal`, `private`,
///   `fileprivate`, `package`).
/// - Closure-typed parameters (the closure may take Int internally).
/// - Tuple-typed parameters (composite shape; out of scope).
/// - Sized integers (`Int8`, `Int16`, `Int32`, `Int64`, `UInt`,
///   `UInt8`–`UInt64`) — the rule targets the bare `Int` only.
extension Lint.Rule.Naming {
    public struct IntParameter: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "int_parameter_public"
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

extension Lint.Rule.Naming.IntParameter {
    @usableFromInline
    static let messageParameter: Swift.String =
        "[int_parameter_public] [IMPL-010]: public function/initializer "
        + "signature has a bare `Int` parameter. Push the stdlib boundary "
        + "out — use a typed wrapper (`Index<T>`, `Ordinal`, `Cardinal`, "
        + "`Count<T>`, `Offset<T>`) at the public surface; convert via a "
        + "boundary overload internally. `Int(bitPattern:)` lives in one "
        + "place, once, forever (per [IMPL-010])."

    @usableFromInline
    static let messageReturn: Swift.String =
        "[int_parameter_public] [IMPL-010]: public function returns a bare "
        + "`Int`. Push the stdlib boundary out — return a typed wrapper "
        + "(`Cardinal`, `Count<T>`, `Offset<T>`) so consumers see typed "
        + "intent rather than a raw machine integer."

    static func isPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return true
            default:
                continue
            }
        }
        return false
    }

    /// Strips optionals + attributed type wrappers and asks: is the
    /// underlying type the bare `Int` or `Swift.Int`?
    static func isBareInt(_ type: TypeSyntax) -> Bool {
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
        while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
            current = tuple.elements.first!.type
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Int"
        }
        if let member = current.as(MemberTypeSyntax.self) {
            if member.name.text == "Int",
               let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
               baseIdentifier.name.text == "Swift" {
                return true
            }
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

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Naming.IntParameter.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            checkParameters(node.signature.parameterClause.parameters)
            // Return type.
            if let returnClause = node.signature.returnClause,
               Lint.Rule.Naming.IntParameter.isBareInt(returnClause.type) {
                emit(at: returnClause.type.positionAfterSkippingLeadingTrivia, message: Lint.Rule.Naming.IntParameter.messageReturn)
            }
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Naming.IntParameter.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            checkParameters(node.signature.parameterClause.parameters)
            return .visitChildren
        }

        private func checkParameters(_ parameters: FunctionParameterListSyntax) {
            for parameter in parameters {
                guard Lint.Rule.Naming.IntParameter.isBareInt(parameter.type) else {
                    continue
                }
                emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia, message: Lint.Rule.Naming.IntParameter.messageParameter)
            }
        }

        private func emit(at position: AbsolutePosition, message: Swift.String) {
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Naming.IntParameter.id.underlying,
                message: message
            ))
        }
    }
}

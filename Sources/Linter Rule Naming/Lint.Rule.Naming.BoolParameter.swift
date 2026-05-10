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

/// Wave 1 (mechanization-program) — Bool parameter in public-API signature.
///
/// Citation: `[API-IMPL-003]` (code-surface skill — Enum Over Boolean).
///
/// Use enums instead of boolean flags when state can expand. The
/// mechanical signal: a parameter of type `Bool` (or `Swift.Bool`) on
/// a `public` / `open` function or initializer is the lowest-friction
/// indication of the anti-pattern. Boolean parameters in public APIs
/// are particularly painful because they (a) read as call-site
/// noise (`open(create: true, truncate: true, …)`) and (b) cannot
/// extend to a third state without an API break.
///
/// Detection: walk `FunctionDeclSyntax` and `InitializerDeclSyntax`
/// whose modifier list contains `public` or `open`. For each
/// parameter, flag the type if it resolves (after stripping
/// optionals + attributed types) to an identifier whose name is
/// `Bool` OR a `Swift.Bool` member-type expression.
///
/// Worked examples (flagged):
///   - `public func open(create: Bool, truncate: Bool) {}` — both flagged.
///   - `public init(verbose: Bool) {}` — flagged.
///   - `public func read(strict: Bool?) {}` — flagged (Optional<Bool>).
///   - `public func tag(value: Swift.Bool) {}` — flagged.
///
/// Worked examples (NOT flagged):
///   - `func open(create: Bool) {}` — no public modifier; internal
///     signature is the implementer's choice.
///   - `package func ...(b: Bool) {}` — package-scope, exempt
///     (parallel to the `Lint.Rule.Naming.Compound` rule's
///     `feedback_compound_package_scope` precedent).
///   - `public func update(_ body: (Bool) -> Void) {}` — closure-typed
///     parameter; the Bool is inside a closure, not the signature.
///   - `public func foo(_ x: BoolContainer) {}` — type whose name is
///     not exactly `Bool` (`BoolContainer` is a CompoundType case for
///     [API-NAME-001] / [API-NAME-013]; not in scope here).
///
/// Excluded scopes:
/// - Non-public functions/initializers (`internal`, `private`,
///   `fileprivate`, `package`).
/// - Closure-typed parameters (the closure may take Bool internally).
/// - Tuple-typed parameters (composite shape; out of mechanical scope).
extension Lint.Rule.Naming {
    public struct BoolParameter: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "bool_parameter_public"
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

extension Lint.Rule.Naming.BoolParameter {
    @usableFromInline
    static let message: Swift.String =
        "[bool_parameter_public] [API-IMPL-003]: public function/initializer "
        + "signature has a `Bool` parameter. Use an enum (or named-options "
        + "struct) so additional states can be added without an API break "
        + "and so call sites read as intent (`mode: .strict`) rather than "
        + "magic flags (`strict: true`). `package`-scope and non-public "
        + "declarations are exempt; closure-typed parameters with internal "
        + "Bool arguments are exempt."

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
    /// underlying type an identifier `Bool` or `Swift.Bool`?
    static func isBoolType(_ type: TypeSyntax) -> Bool {
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
        // Also unwrap single-element parenthesised forms (`(Bool)`).
        while let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1 {
            current = tuple.elements.first!.type
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Bool"
        }
        if let member = current.as(MemberTypeSyntax.self) {
            // `Swift.Bool`: base is `Swift`, name is `Bool`.
            if member.name.text == "Bool",
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
            guard Lint.Rule.Naming.BoolParameter.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            checkParameters(node.signature.parameterClause.parameters)
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Naming.BoolParameter.isPublicOrOpen(node.modifiers) else {
                return .visitChildren
            }
            checkParameters(node.signature.parameterClause.parameters)
            return .visitChildren
        }

        private func checkParameters(_ parameters: FunctionParameterListSyntax) {
            for parameter in parameters {
                guard Lint.Rule.Naming.BoolParameter.isBoolType(parameter.type) else {
                    continue
                }
                let location = converter.location(for: parameter.firstName.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Naming.BoolParameter.id.underlying,
                    message: Lint.Rule.Naming.BoolParameter.message
                ))
            }
        }
    }
}

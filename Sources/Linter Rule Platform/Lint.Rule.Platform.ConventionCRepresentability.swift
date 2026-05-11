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

/// Wave 3 (mechanization-program) — `@convention(c)` function types
/// MUST NOT take `UnsafeMutablePointer<UserType>?` parameters where
/// `UserType` is a Swift-defined struct.
///
/// Citation: `[PLAT-ARCH-005b]` (platform skill — `@convention(c)`
/// representability pre-check).
///
/// Pure Swift structs (including `@safe` layout-compatible wrappers
/// over imported C structs) are NOT `@objc`-representable and cannot
/// appear in `@convention(c)` signatures, even when the wrapper's
/// layout is identical to the underlying C type. The institute pattern
/// uses `OpaquePointer?` / `UnsafeMutableRawPointer?` in the callback
/// signature and binds the typed wrapper at the callback's first line.
///
/// AST shape: walk `AttributedTypeSyntax` whose attribute set contains
/// `@convention(c)` (or `@convention(c, cType: "…")`). Inspect the
/// underlying `FunctionTypeSyntax`'s parameter types. Each parameter
/// is stripped of optional / IUO wrapping; if it is
/// `UnsafeMutablePointer<X>` where `X` is a `MemberTypeSyntax` (a
/// qualified type path like `Kernel.Signal.Information`), flag — the
/// member-path identifier strongly suggests a Swift-defined wrapper
/// type rather than a C-imported primitive.
///
/// Worked examples (flagged):
///   - `@convention(c) (UnsafeMutablePointer<Kernel.Signal.Information>?)
///     -> Void` — typed wrapper in C-convention signature.
///   - `let cb: @convention(c) (UnsafeMutablePointer<Foo.Bar>?) -> Void`
///     — variable declaration form, same shape.
///
/// Worked examples (NOT flagged):
///   - `@convention(c) (OpaquePointer?) -> Void` — opaque pointer.
///   - `@convention(c) (UnsafeMutablePointer<Int32>?) -> Void` —
///     primitive C-representable type, not a member-type path.
///   - `@convention(c) (UnsafeMutableRawPointer?) -> Void` — raw
///     pointer, no generic argument.
extension Lint.Rule.Platform {
    public struct ConventionCRepresentability: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "convention_c_representability"
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

extension Lint.Rule.Platform.ConventionCRepresentability {
    @usableFromInline
    static let message: Swift.String =
        "[convention_c_representability] [PLAT-ARCH-005b]: `@convention(c)` "
        + "function type takes `UnsafeMutablePointer<<UserType>>?` for a "
        + "qualified type path — pure Swift structs (including @safe "
        + "wrappers) are NOT @objc-representable and the compiler rejects "
        + "them in @convention(c) signatures. Use `OpaquePointer?` or "
        + "`UnsafeMutableRawPointer?` in the callback signature; bind the "
        + "typed wrapper at the callback's first line."

    static func hasConventionC(_ attributes: AttributeListSyntax) -> Swift.Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            guard attr.attributeName.trimmedDescription == "convention" else { continue }
            // The argument is `(c)` or `(c, cType: "...")`. Match on
            // the first argument being the identifier `c`.
            if let arguments = attr.arguments,
               case .argumentList(let labeled) = arguments
            {
                if let first = labeled.first,
                   let identifier = first.expression.as(DeclReferenceExprSyntax.self),
                   identifier.baseName.text == "c"
                {
                    return true
                }
            }
        }
        return false
    }

    /// Returns true when `type` (after stripping optional / IUO /
    /// attributed wrappers) is `UnsafeMutablePointer<X>` where `X` is
    /// a qualified member-type path (`A.B`-shape).
    static func isUnsafePointerToUserType(_ type: TypeSyntax) -> Swift.Bool {
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
        guard let identifier = current.as(IdentifierTypeSyntax.self) else {
            return false
        }
        guard identifier.name.text == "UnsafeMutablePointer"
            || identifier.name.text == "UnsafePointer"
        else { return false }
        guard let genericArgs = identifier.genericArgumentClause,
              let argument = genericArgs.arguments.first
        else { return false }
        return argument.argument.is(MemberTypeSyntax.self)
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

        override func visit(_ node: AttributedTypeSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Platform.ConventionCRepresentability.hasConventionC(node.attributes) else {
                return .visitChildren
            }
            guard let function = node.baseType.as(FunctionTypeSyntax.self) else {
                return .visitChildren
            }
            for parameter in function.parameters {
                guard Lint.Rule.Platform.ConventionCRepresentability.isUnsafePointerToUserType(
                    parameter.type
                ) else { continue }
                let location = converter.location(for: parameter.type.positionAfterSkippingLeadingTrivia)
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Platform.ConventionCRepresentability.id.underlying,
                    message: Lint.Rule.Platform.ConventionCRepresentability.message
                ))
            }
            return .visitChildren
        }
    }
}

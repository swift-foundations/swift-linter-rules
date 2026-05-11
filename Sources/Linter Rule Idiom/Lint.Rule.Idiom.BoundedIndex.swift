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

/// Wave 3 (mechanization-program) — static-capacity types
/// (`<let N: Int>` value-generic parameter) MUST use
/// `Index<Element>.Bounded<N>` for subscript index parameters, not
/// raw `Int`.
///
/// Citation: `[IMPL-050]` (implementation skill — bounded indices
/// for static-capacity types).
///
/// `Index<Element>.Bounded<N>` encodes the capacity bound at compile
/// time, so the subscript's index parameter cannot exceed N at
/// authoring time. A raw `Int` subscript on a `<let N: Int>` type
/// drops the bound from the type system, forcing runtime range
/// checking and consumer-side bookkeeping. Per [IMPL-052], unbounded
/// variants MUST NOT co-exist alongside bounded variants — bounded is
/// the sole public API.
///
/// AST shape: walk type declarations (`struct`/`class`/`enum`/`actor`)
/// whose generic-parameter clause contains a parameter with the `let`
/// specifier (value generic). Inside the type's body, flag subscript
/// declarations whose first parameter is typed `Int` (or `Swift.Int`).
/// The rule scopes to the type's OWN body — extensions in other files
/// are out of per-file scope.
///
/// Worked examples (flagged):
///   - `struct Buffer<let N: Int> { subscript(index: Int) -> Int { … } }`
///     — `Int` subscript on a value-generic type.
///   - `struct FixedArray<Element, let Count: Int> { subscript(i: Int) ->
///     Element { … } }` — same shape with element generic.
///
/// Worked examples (NOT flagged):
///   - `struct Buffer<let N: Int> { subscript(i: Index<Element>.Bounded<N>)
///     -> Element { … } }` — bounded index.
///   - `struct Buffer { subscript(i: Int) -> Element { … } }` — non-
///     value-generic type; out of scope.
///   - Subscripts in extensions across separate files — out of per-file
///     scope; a complementary whole-module rule would close this gap.
extension Lint.Rule.Idiom {
    public struct BoundedIndex: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "bounded_index_static_capacity"
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

extension Lint.Rule.Idiom.BoundedIndex {
    @usableFromInline
    static let message: Swift.String =
        "[bounded_index_static_capacity] [IMPL-050]: subscript on a "
        + "static-capacity type (`<let N: Int>`) takes a raw `Int` index — "
        + "the capacity bound is dropped from the type system. Use "
        + "`Index<Element>.Bounded<N>` so the index cannot exceed `N` at "
        + "authoring time. Per [IMPL-052], unbounded variants MUST NOT "
        + "co-exist alongside bounded ones — bounded is the sole public API."

    static func hasValueGenericParameter(_ clause: GenericParameterClauseSyntax?) -> Swift.Bool {
        guard let clause else { return false }
        for parameter in clause.parameters {
            if let specifier = parameter.specifier,
               case .keyword(.let) = specifier.tokenKind
            {
                return true
            }
        }
        return false
    }

    static func isRawIntType(_ type: TypeSyntax) -> Swift.Bool {
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
           identifier.name.text == "Int"
        {
            return true
        }
        if let member = current.as(MemberTypeSyntax.self),
           member.name.text == "Int",
           let base = member.baseType.as(IdentifierTypeSyntax.self),
           base.name.text == "Swift"
        {
            return true
        }
        return false
    }

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Diagnostic.Record] = []
        /// Stack of "depth of enclosing value-generic types". When > 0,
        /// we are inside a static-capacity type body.
        var valueGenericDepth: Swift.Int = 0

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth += 1
            }
            return .visitChildren
        }
        override func visitPost(_ node: StructDeclSyntax) {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth -= 1
            }
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth += 1
            }
            return .visitChildren
        }
        override func visitPost(_ node: ClassDeclSyntax) {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth -= 1
            }
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth += 1
            }
            return .visitChildren
        }
        override func visitPost(_ node: ActorDeclSyntax) {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth -= 1
            }
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth += 1
            }
            return .visitChildren
        }
        override func visitPost(_ node: EnumDeclSyntax) {
            if Lint.Rule.Idiom.BoundedIndex.hasValueGenericParameter(node.genericParameterClause) {
                valueGenericDepth -= 1
            }
        }

        override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
            guard valueGenericDepth > 0 else { return .visitChildren }
            for parameter in node.parameterClause.parameters {
                guard Lint.Rule.Idiom.BoundedIndex.isRawIntType(parameter.type) else {
                    continue
                }
                let location = converter.location(
                    for: parameter.firstName.positionAfterSkippingLeadingTrivia
                )
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Idiom.BoundedIndex.id.underlying,
                    message: Lint.Rule.Idiom.BoundedIndex.message
                ))
            }
            return .visitChildren
        }
    }
}

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

/// Wave 4 (mechanization-program) — type-transformation methods belong
/// in initializers or static methods on the target type, not as
/// instance methods on the source.
///
/// Citation: `[PATTERN-012]` (implementation skill, patterns.md).
///
/// When converting between domain types, the canonical home is an
/// `init` on the target (`Target.init(_ source: Source)`) or a static
/// method on the target (`Target.from(_ source: Source) -> Target`).
/// An instance method on the source named `to<Type>()` or `as<Type>()`
/// returning a domain type duplicates the canonical pattern and
/// fragments the conversion site between two types.
///
/// AST shape: an instance `FunctionDeclSyntax` (no `static` / `class`
/// modifier) whose name matches `(to|as)<Identifier>` where the
/// `<Identifier>` starts with an uppercase letter AND whose return
/// type's identifier matches the suffix. Closer match: the method's
/// suffix names the return type. This narrow shape catches the
/// canonical anti-pattern; conversion helpers that don't follow the
/// suffix-as-target convention are out of scope.
extension Lint.Rule.Structure {
    public struct TypeTransformPlacement: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "type_transform_placement"
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

extension Lint.Rule.Structure.TypeTransformPlacement {
    @usableFromInline
    static let message: Swift.String =
        "[type_transform_placement] [PATTERN-012]: instance method `to<Type>()` "
        + "/ `as<Type>()` returning the matching type is the type-transformation "
        + "anti-pattern. Move the conversion to an `init(_ source: Source)` on the "
        + "target type or a static method (`Target.from(_ source: Source)`) so the "
        + "canonical conversion site lives with the target."

    static let prefixes: [Swift.String] = ["to", "as"]

    /// Returns the type-suffix (post-prefix) of a `to<Suffix>` / `as<Suffix>`
    /// method name, or nil if the name doesn't follow the shape.
    static func transformSuffix(of name: Swift.String) -> Swift.String? {
        for prefix in prefixes {
            guard name.hasPrefix(prefix) else { continue }
            let suffix = String(name.dropFirst(prefix.count))
            guard let first = suffix.first, first.isUppercase else { continue }
            return suffix
        }
        return nil
    }

    static func returnTypeLeafName(_ type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        if let optional = type.as(OptionalTypeSyntax.self) {
            return returnTypeLeafName(optional.wrappedType)
        }
        return nil
    }

    static func hasStaticOrClassModifier(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.static), .keyword(.class):
                return true
            default:
                continue
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
            // Instance methods only — static / class methods on the source are
            // a different shape and out of scope (the rule targets instance
            // `toX()` / `asX()` conversions).
            if Lint.Rule.Structure.TypeTransformPlacement.hasStaticOrClassModifier(node.modifiers) {
                return .visitChildren
            }
            let name = node.name.text
            guard let suffix = Lint.Rule.Structure.TypeTransformPlacement.transformSuffix(of: name) else {
                return .visitChildren
            }
            guard let returnType = node.signature.returnClause?.type else {
                return .visitChildren
            }
            guard let returnLeaf = Lint.Rule.Structure.TypeTransformPlacement.returnTypeLeafName(returnType) else {
                return .visitChildren
            }
            guard returnLeaf == suffix else { return .visitChildren }
            let location = converter.location(
                for: node.funcKeyword.positionAfterSkippingLeadingTrivia
            )
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Structure.TypeTransformPlacement.id.underlying,
                message: Lint.Rule.Structure.TypeTransformPlacement.message
            ))
            return .visitChildren
        }
    }
}

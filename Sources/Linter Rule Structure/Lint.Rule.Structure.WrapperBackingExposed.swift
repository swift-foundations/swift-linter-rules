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

/// Wave 3 (mechanization-program) — wrapper types whose `_backing` /
/// `_wrapped` / `_underlying` property is non-private signal an
/// incomplete-wrapper violation.
///
/// Citation: `[API-IMPL-011]` (code-surface skill — wrapper completeness).
///
/// A wrapper type that owns construction, invariants, and error domain
/// MUST also own the primary operation. When the wrapper exposes its
/// backing storage at non-private visibility (`internal` default or
/// wider), consumers reach through to the wrapped type for the missing
/// operation — `lane._backing.run { }` — and the wrapper looks fake.
/// A complete wrapper keeps `_backing` private and exposes the primary
/// operation on the wrapper itself.
///
/// AST shape: walk `StructDeclSyntax`/`ClassDeclSyntax`/`ActorDeclSyntax`
/// member properties. For any `VariableDeclSyntax` whose binding name
/// is `_backing`, `_wrapped`, or `_underlying` AND whose access
/// modifier is NOT `private` or `fileprivate`, flag the property's
/// binding specifier (`var`/`let` keyword).
///
/// Worked examples (flagged):
///   - `public struct Lane { let _backing: IO.Blocking.Lane }` — no
///     access modifier → defaults to internal → consumers in the same
///     module reach `lane._backing.run { ... }`.
///   - `internal var _wrapped: Underlying` — explicit internal; same
///     wrapper-escape concern.
///
/// Worked examples (NOT flagged):
///   - `private var _backing: IO.Blocking.Lane` — properly hidden.
///   - `fileprivate let _wrapped: Underlying` — narrower than internal.
///   - `public var name: String` — non-underscore name; out of scope.
///   - `@usableFromInline var _backing: Underlying` — explicit
///     usableFromInline pinning; treated as private + ABI-stable. Rule
///     conservatively exempts `@usableFromInline` decls — they signal
///     the author has opted into a different visibility model.
extension Lint.Rule.Structure {
    public struct WrapperBackingExposed: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "wrapper_backing_exposed"
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

extension Lint.Rule.Structure.WrapperBackingExposed {
    @usableFromInline
    static let message: Swift.String =
        "[wrapper_backing_exposed] [API-IMPL-011]: wrapper backing property "
        + "(`_backing` / `_wrapped` / `_underlying`) is exposed at non-private "
        + "visibility — consumers will reach through (`wrapper._backing.run { … }`) "
        + "for any operation the wrapper itself doesn't surface, and the wrapper "
        + "looks fake. Make the property `private` (or `fileprivate`), and own the "
        + "primary operation on the wrapper directly. `@usableFromInline` is exempt."

    static let trackedNames: Swift.Set<Swift.String> = [
        "_backing",
        "_wrapped",
        "_underlying",
    ]

    static func hasPrivateOrFilePrivate(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.private), .keyword(.fileprivate):
                return true
            default:
                continue
            }
        }
        return false
    }

    static func hasUsableFromInline(_ attributes: AttributeListSyntax) -> Swift.Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            if attr.attributeName.trimmedDescription == "usableFromInline" {
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
        /// Depth counter — > 0 when inside a struct/class/actor body
        /// (where wrapper-backing semantics apply).
        var typeDepth: Swift.Int = 0

        init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
            self.source = source
            self.severity = severity
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        // MARK: - Track enter/exit of wrapping types

        override func visit(_: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            typeDepth += 1
            return .visitChildren
        }
        override func visitPost(_: StructDeclSyntax) { typeDepth -= 1 }

        override func visit(_: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            typeDepth += 1
            return .visitChildren
        }
        override func visitPost(_: ClassDeclSyntax) { typeDepth -= 1 }

        override func visit(_: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            typeDepth += 1
            return .visitChildren
        }
        override func visitPost(_: ActorDeclSyntax) { typeDepth -= 1 }

        // MARK: - Property check

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            guard typeDepth > 0 else { return .visitChildren }
            if Lint.Rule.Structure.WrapperBackingExposed.hasPrivateOrFilePrivate(node.modifiers) {
                return .visitChildren
            }
            if Lint.Rule.Structure.WrapperBackingExposed.hasUsableFromInline(node.attributes) {
                return .visitChildren
            }
            for binding in node.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }
                guard Lint.Rule.Structure.WrapperBackingExposed.trackedNames.contains(
                    identifier.identifier.text
                ) else { continue }
                let location = converter.location(
                    for: node.bindingSpecifier.positionAfterSkippingLeadingTrivia
                )
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Structure.WrapperBackingExposed.id.underlying,
                    message: Lint.Rule.Structure.WrapperBackingExposed.message
                ))
                break
            }
            return .visitChildren
        }
    }
}

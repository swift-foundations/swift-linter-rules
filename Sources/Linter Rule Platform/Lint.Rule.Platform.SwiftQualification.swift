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

/// Wave 1 (mechanization-program) — `Swift.<Protocol>` qualification for
/// stdlib-shadowing namespaces.
///
/// Citation: `[PLAT-ARCH-022]` (platform skill).
///
/// When stdlib protocols (`Sequence`, `Collection`, `Error`) are
/// shadowed by institute namespace types of the same name in scope,
/// references to the stdlib protocol MUST use `Swift.<Protocol>`
/// qualification. This generalizes [PLAT-ARCH-011]'s `Swift.Error`
/// everywhere convention to any stdlib protocol whose name the
/// institute also uses as a namespace.
///
/// Detection: walk type-position syntax — `InheritedTypeSyntax`
/// (conformance lists), `GenericParameterSyntax` (generic constraints),
/// `ConformanceRequirementSyntax` (where-clause conformances), and
/// `SomeOrAnyTypeSyntax` (existential and opaque-result positions). For
/// each, descend into the contained type expression and check whether
/// any leaf identifier is one of the shadowed stdlib protocol names
/// without a `Swift.` prefix.
///
/// Worked examples (flagged):
///   - `func consume(_ bytes: some Sequence<UInt8>)` — `Sequence` bare,
///     should be `Swift.Sequence` per [PLAT-ARCH-022].
///   - `func parse<E: Error>() throws(E)` — `Error` constraint bare.
///   - `enum State: Error { ... }` — `Error` conformance bare.
///   - `extension Foo where T: Sequence` — `Sequence` where-clause.
///
/// Worked examples (NOT flagged):
///   - `some Swift.Sequence<UInt8>` — qualified.
///   - `extension State: Swift.Error` — qualified.
///   - `func op() throws(MyDomain.Error)` — `Error` is a NAMESPACED
///     leaf (`MyDomain.Error`); it is the project's own typed-throws
///     leaf, not the stdlib `Swift.Error` protocol referenced bare.
///   - `let x: Sequence` (variable binding) — out of mechanical scope;
///     this rule covers conformance / constraint / opaque-result
///     positions where stdlib protocol references are most common.
///
/// Stdlib protocols covered by default: `Sequence`, `Collection`, `Error`.
/// `Error` is covered for completeness — the SwiftLint Tier 1 regex
/// already catches it but AST-level coverage subsumes the regex.
extension Lint.Rule.Platform {
    public struct SwiftQualification: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "swift_protocol_qualification"
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

extension Lint.Rule.Platform.SwiftQualification {
    @usableFromInline
    static let shadowedProtocols: Swift.Set<Swift.String> = [
        "Sequence",
        "Collection",
        "Error",
    ]

    @usableFromInline
    static let message: Swift.String =
        "[swift_protocol_qualification] [PLAT-ARCH-022]: stdlib-shadowing "
        + "protocol reference is unqualified. Use `Swift.<Protocol>` form "
        + "(e.g., `some Swift.Sequence<UInt8>` not `some Sequence<UInt8>`; "
        + "`<E: Swift.Error>` not `<E: Error>`). Shadowing namespaces "
        + "(`swift-sequence-primitives.Sequence`, per-package `Module.Error`) "
        + "make the bare name resolve to the institute namespace, not the "
        + "stdlib protocol."

    /// Walks a type expression and yields every bare-identifier leaf
    /// whose name is in the shadowed-protocol set. Composition types
    /// (`A & B`) are descended into.
    static func bareShadowedLeaves(
        in type: TypeSyntax
    ) -> [(name: Swift.String, position: AbsolutePosition)] {
        var results: [(name: Swift.String, position: AbsolutePosition)] = []
        var stack: [TypeSyntax] = [type]
        while let next = stack.popLast() {
            var current = next
            // Strip optional / IUO / attributed wrappers.
            while let optional = current.as(OptionalTypeSyntax.self) {
                current = optional.wrappedType
            }
            while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                current = iuo.wrappedType
            }
            while let attributed = current.as(AttributedTypeSyntax.self) {
                current = attributed.baseType
            }
            // Composition: descend into each element.
            if let composition = current.as(CompositionTypeSyntax.self) {
                for element in composition.elements {
                    stack.append(element.type)
                }
                continue
            }
            // some/any wrapper: descend.
            if let someAny = current.as(SomeOrAnyTypeSyntax.self) {
                stack.append(someAny.constraint)
                continue
            }
            // Identifier: this is the leaf we evaluate.
            if let identifier = current.as(IdentifierTypeSyntax.self) {
                let name = identifier.name.text
                if Lint.Rule.Platform.SwiftQualification.shadowedProtocols.contains(name) {
                    results.append((name: name, position: identifier.name.positionAfterSkippingLeadingTrivia))
                }
                continue
            }
            // MemberType (`Swift.Error`, `MyMod.Sequence`, etc.) — qualified.
            // Already-qualified references are exempt; do nothing.
        }
        return results
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

        private func emit(at position: AbsolutePosition) {
            let location = converter.location(for: position)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Platform.SwiftQualification.id.underlying,
                message: Lint.Rule.Platform.SwiftQualification.message
            ))
        }

        private func check(_ type: TypeSyntax) {
            for leaf in Lint.Rule.Platform.SwiftQualification.bareShadowedLeaves(in: type) {
                emit(at: leaf.position)
            }
        }

        // Conformance lists: `struct X: Sequence, Error`.
        override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
            check(node.type)
            return .visitChildren
        }

        // Generic parameter inheritance: `<T: Sequence>`.
        override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind {
            if let inherited = node.inheritedType {
                check(inherited)
            }
            return .visitChildren
        }

        // Where-clause conformance: `where T: Sequence`.
        override func visit(_ node: ConformanceRequirementSyntax) -> SyntaxVisitorContinueKind {
            check(node.rightType)
            return .visitChildren
        }

        // some/any positions: `some Sequence`, `any Error`.
        override func visit(_ node: SomeOrAnyTypeSyntax) -> SyntaxVisitorContinueKind {
            check(node.constraint)
            return .visitChildren
        }
    }
}

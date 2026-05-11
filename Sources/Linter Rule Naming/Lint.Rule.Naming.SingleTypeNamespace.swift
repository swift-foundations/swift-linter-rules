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

/// Wave 3 (mechanization-program) — caseless-enum namespaces containing
/// exactly one nested type are variant labels, not namespaces — they
/// MUST nest under the parent type.
///
/// Citation: `[API-NAME-001a]` (code-surface skill — Single-Type-No-
/// Namespace).
///
/// A namespace containing one type is vocabulary overhead without
/// vocabulary payoff. `Cooperative.Executor` reads as "the Executor
/// type in the Cooperative namespace" — suggesting more to Cooperative
/// than there is. The corrected shape `Executor.Cooperative` reads as
/// "the Cooperative variant of Executor." Naming follows structure;
/// structure follows what types actually exist.
///
/// AST shape (per-file detection — conservative): a `EnumDeclSyntax`
/// declared as a caseless namespace (NO `EnumCaseDeclSyntax` members)
/// whose member block contains EXACTLY ONE nested type declaration
/// (`struct`/`class`/`enum`/`actor`/`protocol`) AND no non-type / non-
/// typealias members (funcs, vars, subscripts, inits, deinits). The
/// detection is per-file: a namespace appearing single-typed here may
/// have additional nested types in extensions across other files; the
/// flag is a *prompt for review*, not an unconditional violation.
///
/// Worked examples (flagged):
///   - `public enum Cooperative { public struct Executor { } }` —
///     caseless enum with exactly one nested type; rename suggests
///     `extension Executor { public struct Cooperative { } }`.
///   - `enum Polling { struct Worker { } }` — same shape.
///
/// Worked examples (NOT flagged):
///   - `public enum File { public enum Directory { ... }; public struct
///     Path { ... } }` — multiple nested types.
///   - `public enum E { case a; case b }` — non-caseless enum, it's a
///     real enum (with cases), not a namespace.
///   - `public enum Module { public typealias X = Int; public struct Y {} }`
///     — one nested type, but a typealias is treated as a sibling label
///     (still flagged once any other type-like sibling exists; here it's
///     ambiguous, conservative skip).
extension Lint.Rule.Naming {
    public struct SingleTypeNamespace: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "single_type_namespace"
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

extension Lint.Rule.Naming.SingleTypeNamespace {
    @usableFromInline
    static let message: Swift.String =
        "[single_type_namespace] [API-NAME-001a]: caseless-enum namespace "
        + "contains exactly one nested type — that's a *variant label*, "
        + "not a namespace. Promote the inner type and nest the label "
        + "under its parent: `extension <InnerType> { public struct <Label> "
        + "{ ... } }`. Genuine namespaces have two or more sibling types. "
        + "If a second type is genuinely planned, document the absence per "
        + "[IMPL-001] or temporarily nest under the existing inner type "
        + "until the second sibling arrives."

    enum MemberCategory {
        case enumCase
        case typeDecl
        case typealiasDecl
        case other
    }

    static func categorize(_ decl: DeclSyntax) -> MemberCategory {
        if decl.is(EnumCaseDeclSyntax.self) { return .enumCase }
        if decl.is(StructDeclSyntax.self) { return .typeDecl }
        if decl.is(ClassDeclSyntax.self) { return .typeDecl }
        if decl.is(EnumDeclSyntax.self) { return .typeDecl }
        if decl.is(ActorDeclSyntax.self) { return .typeDecl }
        if decl.is(ProtocolDeclSyntax.self) { return .typeDecl }
        if decl.is(TypeAliasDeclSyntax.self) { return .typealiasDecl }
        return .other
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

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            var typeCount = 0
            var hasOther = false
            for member in node.memberBlock.members {
                let category = Lint.Rule.Naming.SingleTypeNamespace.categorize(member.decl)
                switch category {
                case .enumCase:
                    // Real enum (has cases) — not a namespace; bail.
                    return .visitChildren
                case .typeDecl:
                    typeCount += 1
                case .typealiasDecl:
                    // Typealiases are sibling labels; allow alongside.
                    continue
                case .other:
                    hasOther = true
                }
            }
            guard !hasOther else { return .visitChildren }
            guard typeCount == 1 else { return .visitChildren }
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Naming.SingleTypeNamespace.id.underlying,
                message: Lint.Rule.Naming.SingleTypeNamespace.message
            ))
            return .visitChildren
        }
    }
}

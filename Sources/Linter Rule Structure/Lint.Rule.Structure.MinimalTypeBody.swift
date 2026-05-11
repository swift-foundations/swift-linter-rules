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

/// Wave 3 (mechanization-program) — type declarations MUST contain only
/// stored properties, the canonical initializer, and (for class /
/// ~Copyable types) `deinit`. All other members MUST be in extensions.
///
/// Citation: `[API-IMPL-008]` (code-surface skill — minimal type body).
///
/// Minimal bodies make storage layout immediately visible, separate
/// stable data from evolving behavior, and simplify code review.
/// Computed properties, methods, static members, protocol conformances,
/// and nested types belong in extensions.
///
/// AST shape: walk `StructDeclSyntax`/`ClassDeclSyntax`/`EnumDeclSyntax`/
/// `ActorDeclSyntax`. For each member of `memberBlock.members`, classify:
///   - stored `var`/`let` → permitted
///   - `init` → permitted
///   - `deinit` → permitted (only meaningful on class / ~Copyable)
///   - everything else (`func`, computed `var`, `static let`, nested
///     `struct`/`class`/`enum`/`actor`/`protocol`, `typealias`, ...) →
///     flagged with the suggestion to extract into an extension.
///
/// Worked examples (flagged):
///   - `struct Buffer { var x: Int; func append(_: Int) { } }` —
///     `append` is a method in the type body; move to an extension.
///   - `struct State { var raw: Int; var isEmpty: Bool { raw == 0 } }` —
///     `isEmpty` is a computed property; move to an extension.
///
/// Worked examples (NOT flagged):
///   - `struct Buffer { @usableFromInline var storage: Storage; @inlinable
///     public init() { ... } }` — body has stored props and the
///     canonical initializer only.
///   - `class Box { var x: Int; init() { ... }; deinit { ... } }` —
///     `deinit` is permitted on classes.
///   - `protocol P { func op() }` — protocol requirements are not in
///     scope; protocols declare requirements, not implementations.
///
/// Exemption ([MEM-COPY-006]): types declared with `~Copyable` generic
/// parameters MAY include nested storage types inside the body to avoid
/// constraint poisoning. Mechanical detection of "needs constraint
/// poisoning workaround" is out of scope; rule applies uniformly and
/// authors document exceptions per [PATTERN-016].
extension Lint.Rule.Structure {
    public struct MinimalTypeBody: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "minimal_type_body"
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

extension Lint.Rule.Structure.MinimalTypeBody {
    @usableFromInline
    static let message: Swift.String =
        "[minimal_type_body] [API-IMPL-008]: type bodies MUST contain "
        + "ONLY stored properties, the canonical initializer(s), and "
        + "(for classes / ~Copyable types) `deinit`. Methods, computed "
        + "properties, static members, nested types, and protocol "
        + "conformances belong in extensions. Minimal bodies make storage "
        + "layout immediately visible and separate stable data from "
        + "evolving behavior."

    /// Returns true when a `var` / `let` declaration has at least one
    /// binding with an explicit accessor block — i.e., it is a COMPUTED
    /// property, not stored.
    static func isComputedProperty(_ node: VariableDeclSyntax) -> Swift.Bool {
        for binding in node.bindings {
            if let accessors = binding.accessorBlock {
                // Stored properties with willSet/didSet observers are
                // still stored, not computed. Computed properties have
                // `get`/`set`/`_read`/`_modify` accessors. Detect by
                // looking for a `get` accessor or a single block (no
                // explicit accessors means computed `get` shorthand).
                switch accessors.accessors {
                case .accessors(let accessorList):
                    for accessor in accessorList {
                        switch accessor.accessorSpecifier.tokenKind {
                        case .keyword(.get), .keyword(.set),
                             .keyword(._read), .keyword(._modify):
                            return true
                        default:
                            continue
                        }
                    }
                case .getter:
                    // Shorthand `var x: T { expression }` → computed.
                    return true
                }
            }
        }
        return false
    }

    /// Returns true when a `var` / `let` declaration has the `static` or
    /// `class` modifier. Static members are NOT in the canonical body
    /// per [API-IMPL-008] (they belong in extensions).
    static func isStaticOrClassMember(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
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
                identifier: Lint.Rule.Structure.MinimalTypeBody.id.underlying,
                message: Lint.Rule.Structure.MinimalTypeBody.message
            ))
        }

        private func checkMembers(_ members: MemberBlockItemListSyntax) {
            for member in members {
                let decl = member.decl
                if let variable = decl.as(VariableDeclSyntax.self) {
                    if Lint.Rule.Structure.MinimalTypeBody.isStaticOrClassMember(variable.modifiers) {
                        emit(at: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia)
                    } else if Lint.Rule.Structure.MinimalTypeBody.isComputedProperty(variable) {
                        emit(at: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia)
                    }
                    continue
                }
                if let function = decl.as(FunctionDeclSyntax.self) {
                    emit(at: function.funcKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                if let subscriptDecl = decl.as(SubscriptDeclSyntax.self) {
                    emit(at: subscriptDecl.subscriptKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                if let typealiasDecl = decl.as(TypeAliasDeclSyntax.self) {
                    emit(at: typealiasDecl.typealiasKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                // Nested type declarations (struct/class/enum/actor/protocol).
                if let nested = decl.as(StructDeclSyntax.self) {
                    emit(at: nested.structKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                if let nested = decl.as(ClassDeclSyntax.self) {
                    emit(at: nested.classKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                if let nested = decl.as(EnumDeclSyntax.self) {
                    emit(at: nested.enumKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                if let nested = decl.as(ActorDeclSyntax.self) {
                    emit(at: nested.actorKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                if let nested = decl.as(ProtocolDeclSyntax.self) {
                    emit(at: nested.protocolKeyword.positionAfterSkippingLeadingTrivia)
                    continue
                }
                // Permitted: InitializerDeclSyntax, DeinitializerDeclSyntax,
                // EnumCaseDeclSyntax (enum cases are required in the body).
            }
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            checkMembers(node.memberBlock.members)
            return .visitChildren
        }

        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            checkMembers(node.memberBlock.members)
            return .visitChildren
        }

        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            checkMembers(node.memberBlock.members)
            return .visitChildren
        }

        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            checkMembers(node.memberBlock.members)
            return .visitChildren
        }

        // Protocols are out of scope — they declare requirements, not
        // implementations.
        override func visit(_: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            return .visitChildren
        }
    }
}

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

/// Wave 4 (mechanization-program) — `struct: @unchecked Sendable`
/// wrapping a class stored property is the anti-pattern.
///
/// Citation: `[IMPL-076]` (implementation skill, concurrency.md — no
/// @unchecked Sendable on struct-wrapping-class).
///
/// When a struct's only stored property is a `Sendable` class, the
/// struct MUST use plain `Sendable` — the `@unchecked` is redundant
/// and misleading because the class's own `Sendable` conformance
/// already discharges the sharability check. The institute pattern:
/// drop `@unchecked` and conform to plain `Sendable`.
///
/// AST shape: `StructDeclSyntax` whose inheritance clause names
/// `Sendable` (or `Swift.Sendable`) WITH the `@unchecked` attribute,
/// AND whose member block contains a stored `VariableDeclSyntax`
/// whose type annotation is a class-typed identifier (heuristic:
/// `IdentifierTypeSyntax` whose name starts with an uppercase letter
/// and is in a short list of known stdlib class names OR whose name
/// ends with `Class` / `Reference`). Mechanical classification of
/// arbitrary types as class vs struct is not possible without symbol
/// resolution; the heuristic is narrow.
extension Lint.Rule.Memory {
    public struct StructSendableClassMember: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "struct_sendable_class_member"
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

extension Lint.Rule.Memory.StructSendableClassMember {
    @usableFromInline
    static let message: Swift.String =
        "[struct_sendable_class_member] [IMPL-076]: `struct: @unchecked Sendable` "
        + "wrapping a class-typed stored property is redundant — if the class is "
        + "itself `Sendable`, plain `Sendable` on the struct suffices. The "
        + "`@unchecked` annotation asserts safety the type system can already "
        + "discharge; drop it and conform to plain `Sendable`."

    /// Heuristic class-name detection.
    static let knownClassNames: Swift.Set<Swift.String> = [
        "NSObject", "Thread", "DispatchQueue", "AnyObject",
    ]

    static func looksLikeClassType(_ name: Swift.String) -> Swift.Bool {
        if knownClassNames.contains(name) { return true }
        return name.hasSuffix("Class") || name.hasSuffix("Reference")
    }

    /// Returns true iff the inheritance clause names `Sendable` (or
    /// `Swift.Sendable`) AND carries an `@unchecked` attribute on the
    /// Sendable position. SwiftSyntax represents this as an
    /// `AttributedTypeSyntax` wrapping `Sendable` with `@unchecked` in
    /// the attributes list.
    static func uncheckedSendable(_ clause: InheritanceClauseSyntax?) -> Swift.Bool {
        guard let clause else { return false }
        for inherited in clause.inheritedTypes {
            guard let attributed = inherited.type.as(AttributedTypeSyntax.self)
            else { continue }
            var hasUnchecked = false
            for attribute in attributed.attributes {
                if case .attribute(let attr) = attribute,
                   let name = attr.attributeName.as(IdentifierTypeSyntax.self),
                   name.name.text == "unchecked" {
                    hasUnchecked = true
                }
            }
            guard hasUnchecked else { continue }
            if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
               identifier.name.text == "Sendable" {
                return true
            }
            if let member = attributed.baseType.as(MemberTypeSyntax.self),
               member.name.text == "Sendable",
               let base = member.baseType.as(IdentifierTypeSyntax.self),
               base.name.text == "Swift" {
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

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Lint.Rule.Memory.StructSendableClassMember
                .uncheckedSendable(node.inheritanceClause) else {
                return .visitChildren
            }
            for member in node.memberBlock.members {
                guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                    continue
                }
                // Stored properties only.
                if Lint.Rule.Memory.StructSendableClassMember.isComputed(variable) {
                    continue
                }
                for binding in variable.bindings {
                    guard let annotation = binding.typeAnnotation else { continue }
                    if let identifier = annotation.type.as(IdentifierTypeSyntax.self),
                       Lint.Rule.Memory.StructSendableClassMember.looksLikeClassType(
                           identifier.name.text
                       ) {
                        let location = converter.location(
                            for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia
                        )
                        matches.append(Diagnostic.Record(
                            location: Source.Location(
                                fileID: source.fileID,
                                filePath: source.filePath,
                                line: location.line,
                                column: location.column
                            ),
                            severity: severity,
                            identifier: Lint.Rule.Memory.StructSendableClassMember.id.underlying,
                            message: Lint.Rule.Memory.StructSendableClassMember.message
                        ))
                    }
                }
            }
            return .visitChildren
        }

        static func isComputed(_ node: VariableDeclSyntax) -> Swift.Bool { false }
    }

    static func isComputed(_ node: VariableDeclSyntax) -> Swift.Bool {
        for binding in node.bindings {
            if let accessors = binding.accessorBlock {
                switch accessors.accessors {
                case .accessors(let list):
                    for accessor in list {
                        switch accessor.accessorSpecifier.tokenKind {
                        case .keyword(.get), .keyword(.set):
                            return true
                        default: break
                        }
                    }
                case .getter:
                    return true
                }
            }
        }
        return false
    }
}

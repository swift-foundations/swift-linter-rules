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

/// Wave 2b finalization (2026-05-10) — public stored properties of
/// unsafe pointer types MUST be `private` / `internal`, or annotated
/// `@unsafe` to mark them as deliberate escape hatches.
///
/// Citation: `[MEM-SAFE-023]` (memory-safety skill, safety-isolation.md).
///
/// Public unsafe-pointer storage on an Escapable type leaks unsafety:
/// the pointer can dangle past the wrapper's lifetime. The institute
/// pattern keeps the pointer private and exposes a `Span` / view, with
/// any pointer-returning method explicitly `@unsafe`. `~Escapable` types
/// get a relaxed treatment (the type system enforces lifetime), so
/// `@unsafe` is recommended rather than required on those — but this
/// rule errs on the side of flagging; suppress with disable-comment if
/// the containing type is `~Escapable`.
///
/// AST shape: `VariableDeclSyntax` whose access modifier is `public` /
/// `open`, whose type matches the unsafe-pointer allowlist (`UnsafePointer`,
/// `UnsafeMutablePointer`, `UnsafeRawPointer`, `UnsafeMutableRawPointer`,
/// `UnsafeBufferPointer`, `UnsafeMutableBufferPointer`,
/// `UnsafeRawBufferPointer`, `UnsafeMutableRawBufferPointer`), AND
/// whose attribute list does NOT contain `@unsafe`.
extension Lint.Rule.Memory {
    public struct PrivateUnsafeStorage: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "private_unsafe_storage"
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

extension Lint.Rule.Memory.PrivateUnsafeStorage {
    @usableFromInline
    static let message: Swift.String =
        "[private_unsafe_storage] [MEM-SAFE-023]: public stored properties of unsafe "
        + "pointer types MUST be `private` / `internal`, or annotated `@unsafe` to "
        + "signal a deliberate escape hatch. Public pointer storage on an Escapable "
        + "wrapper leaks dangling-pointer risk past the wrapper's lifetime. Prefer "
        + "exposing a `Span` view; reserve `@unsafe` for explicit escape hatches."

    @usableFromInline
    static let unsafePointerTypeNames: Swift.Set<Swift.String> = [
        "UnsafePointer",
        "UnsafeMutablePointer",
        "UnsafeRawPointer",
        "UnsafeMutableRawPointer",
        "UnsafeBufferPointer",
        "UnsafeMutableBufferPointer",
        "UnsafeRawBufferPointer",
        "UnsafeMutableRawBufferPointer",
    ]

    static func isUnsafePointerType(_ type: TypeSyntax) -> Bool {
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
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            return unsafePointerTypeNames.contains(identifier.name.text)
        }
        if let member = current.as(MemberTypeSyntax.self) {
            return unsafePointerTypeNames.contains(member.name.text)
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

        private func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
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

        private func hasUnsafeAttribute(_ attributes: AttributeListSyntax) -> Bool {
            for attribute in attributes {
                guard let attr = attribute.as(AttributeSyntax.self) else { continue }
                if attr.attributeName.trimmedDescription == "unsafe" {
                    return true
                }
            }
            return false
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            guard hasPublicModifier(node.modifiers) else {
                return .visitChildren
            }
            guard !hasUnsafeAttribute(node.attributes) else {
                return .visitChildren
            }
            for binding in node.bindings {
                guard let typeAnnotation = binding.typeAnnotation else { continue }
                if Lint.Rule.Memory.PrivateUnsafeStorage.isUnsafePointerType(typeAnnotation.type) {
                    let location = converter.location(for: binding.pattern.positionAfterSkippingLeadingTrivia)
                    matches.append(Diagnostic.Record(
                        location: Source.Location(
                            fileID: source.fileID,
                            filePath: source.filePath,
                            line: location.line,
                            column: location.column
                        ),
                        severity: severity,
                        identifier: Lint.Rule.Memory.PrivateUnsafeStorage.id.underlying,
                        message: Lint.Rule.Memory.PrivateUnsafeStorage.message
                    ))
                }
            }
            return .visitChildren
        }
    }
}

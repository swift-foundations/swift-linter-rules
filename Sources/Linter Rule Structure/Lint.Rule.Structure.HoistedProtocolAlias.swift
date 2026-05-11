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

/// Wave 3 (mechanization-program) — declaring-module conformance for a
/// hoisted-protocol typealias pattern MUST use the hoisted name, not
/// the typealias path (self-referential conformance cycle).
///
/// Citation: `[API-IMPL-009]` (code-surface skill — hoisted protocol
/// with nested typealias).
///
/// The hoisted-protocol pattern is:
///   1. Hoist the protocol to module scope (`_FooProtocol`).
///   2. Nest `typealias Protocol = _FooProtocol` inside the generic
///      owner type's namespace.
///   3. Declaring-module conformance MUST use `_FooProtocol` directly.
///   4. Consumer modules MAY use the typealias path (`Owner.Inner.Protocol`).
///
/// AST shape: walk `ExtensionDeclSyntax` whose extended type ends in
/// `.Protocol` (the typealias path) AND whose `inheritedTypes` clause
/// references `.Protocol` — that's a self-referential cycle. The
/// declaring-module conformance must reference the hoisted name (e.g.,
/// `_FooProtocol`) directly. Detection trigger: any conformance whose
/// `inheritedType` is a `MemberTypeSyntax` ending in `.Protocol`, where
/// the same type is being extended.
///
/// Worked examples (flagged):
///   - `extension Parser.Error.Located: Parser.Error.Located.Protocol`
///     — declaring-module conformance via typealias path, cycle.
///
/// Worked examples (NOT flagged):
///   - `extension Parser.Error.Located: _LocatedErrorProtocol` —
///     declaring-module uses hoisted name directly.
///   - `extension MyError: Parser.Error.Located.Protocol` —
///     CONSUMER module (different type being extended) uses the
///     typealias path; that's the intended path.
///   - `extension Foo: Sendable` — non-Protocol conformance, ignored.
extension Lint.Rule.Structure {
    public struct HoistedProtocolAlias: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "hoisted_protocol_self_conformance"
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

extension Lint.Rule.Structure.HoistedProtocolAlias {
    @usableFromInline
    static let message: Swift.String =
        "[hoisted_protocol_self_conformance] [API-IMPL-009]: declaring-"
        + "module conformance via the `.Protocol` typealias path is a "
        + "self-referential cycle. Use the hoisted protocol name "
        + "(`_FooProtocol`) directly in the declaring module. The "
        + "typealias path (`Owner.Inner.Protocol`) is for CONSUMER "
        + "modules — different type, no cycle."

    /// Returns the dotted name of a type expression as a string for
    /// equality comparison. `Foo.Bar.Baz` → `"Foo.Bar.Baz"`. Handles
    /// `MemberTypeSyntax` chains and the metatype shorthand `T.Protocol`
    /// which SwiftSyntax parses as `MetatypeTypeSyntax`.
    static func dottedName(of type: TypeSyntax) -> Swift.String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            guard let baseName = dottedName(of: member.baseType) else {
                return nil
            }
            return "\(baseName).\(member.name.text)"
        }
        if let metatype = type.as(MetatypeTypeSyntax.self) {
            // `Foo.Protocol` and `Foo.Type` — keyword-suffix metatype.
            guard let baseName = dottedName(of: metatype.baseType) else {
                return nil
            }
            return "\(baseName).\(metatype.metatypeSpecifier.text)"
        }
        return nil
    }

    /// Returns true when `inheritedName == extendedName + ".Protocol"`.
    static func isSelfProtocolConformance(
        extendedName: Swift.String,
        inheritedName: Swift.String
    ) -> Swift.Bool {
        return inheritedName == "\(extendedName).Protocol"
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

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard let extendedName = Lint.Rule.Structure.HoistedProtocolAlias.dottedName(
                of: node.extendedType
            ) else {
                return .visitChildren
            }
            guard let inheritance = node.inheritanceClause else {
                return .visitChildren
            }
            for inherited in inheritance.inheritedTypes {
                guard let inheritedName = Lint.Rule.Structure.HoistedProtocolAlias.dottedName(
                    of: inherited.type
                ) else { continue }
                guard Lint.Rule.Structure.HoistedProtocolAlias.isSelfProtocolConformance(
                    extendedName: extendedName,
                    inheritedName: inheritedName
                ) else { continue }
                let location = converter.location(
                    for: inherited.type.positionAfterSkippingLeadingTrivia
                )
                matches.append(Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: Lint.Rule.Structure.HoistedProtocolAlias.id.underlying,
                    message: Lint.Rule.Structure.HoistedProtocolAlias.message
                ))
            }
            return .visitChildren
        }
    }
}

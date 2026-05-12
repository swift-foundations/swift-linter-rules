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
extension Lint.Rule {
    public static let `swift protocol qualification` = Lint.Rule(
        id: "swift protocol qualification",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = PlatformSwiftQualificationVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let platformSwiftQualificationShadowedProtocols: Swift.Set<Swift.String> = [
    "Sequence",
    "Collection",
    "Error",
]

/// Stdlib types whose declaration lives in the `Swift` module. Inside
/// `extension <X> { ... }` for `X` in this set, Swift's name resolution
/// shadows the `Swift` module name with the type's nested scope —
/// writing `Swift.Sequence` in a generic constraint yields a compile
/// error like `'Sequence' is not a member type of struct 'Swift.X.Swift'`.
/// The qualified form the rule prescribes is structurally inexpressible
/// in this context; the rule exempts.
///
/// Citation: [RULE-EXEMPT-6] (stdlib-shadow) in
/// `swift-institute/Skills/rule-exemptions/SKILL.md`.
@usableFromInline
internal let platformSwiftQualificationStdlibShadowingTypes: Swift.Set<Swift.String> = [
    "Set",
    "Array",
    "ArraySlice",
    "ContiguousArray",
    "Dictionary",
    "String",
    "Substring",
    "Optional",
    "Result",
    "Range",
    "ClosedRange",
    "CollectionOfOne",
    "EmptyCollection",
    "KeyValuePairs",
    "ReversedCollection",
    "UnsafePointer",
    "UnsafeMutablePointer",
    "UnsafeRawPointer",
    "UnsafeMutableRawPointer",
    "UnsafeBufferPointer",
    "UnsafeMutableBufferPointer",
]

internal func platformSwiftQualificationIsInsideStdlibExtension(_ node: Syntax) -> Swift.Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            if let identifier = ext.extendedType.as(IdentifierTypeSyntax.self),
               platformSwiftQualificationStdlibShadowingTypes.contains(identifier.name.text) {
                return true
            }
            if let member = ext.extendedType.as(MemberTypeSyntax.self),
               platformSwiftQualificationStdlibShadowingTypes.contains(member.name.text) {
                return true
            }
            return false
        }
        current = candidate.parent
    }
    return false
}

@usableFromInline
internal let platformSwiftQualificationMessage: Swift.String =
    "[swift protocol qualification] [PLAT-ARCH-022]: stdlib-shadowing "
    + "protocol reference is unqualified. Use `Swift.<Protocol>` form "
    + "(e.g., `some Swift.Sequence<UInt8>` not `some Sequence<UInt8>`; "
    + "`<E: Swift.Error>` not `<E: Error>`). Shadowing namespaces "
    + "(`swift-sequence-primitives.Sequence`, per-package `Module.Error`) "
    + "make the bare name resolve to the institute namespace, not the "
    + "stdlib protocol."

/// Walks a type expression and yields every bare-identifier leaf
/// whose name is in the shadowed-protocol set. Composition types
/// (`A & B`) are descended into.
internal func platformSwiftQualificationBareShadowedLeaves(
    in type: TypeSyntax
) -> [(name: Swift.String, position: AbsolutePosition)] {
    var results: [(name: Swift.String, position: AbsolutePosition)] = []
    var stack: [TypeSyntax] = [type]
    while let next = stack.popLast() {
        var current = next
        while let optional = current.as(OptionalTypeSyntax.self) {
            current = optional.wrappedType
        }
        while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            current = iuo.wrappedType
        }
        while let attributed = current.as(AttributedTypeSyntax.self) {
            current = attributed.baseType
        }
        if let composition = current.as(CompositionTypeSyntax.self) {
            for element in composition.elements {
                stack.append(element.type)
            }
            continue
        }
        if let someAny = current.as(SomeOrAnyTypeSyntax.self) {
            stack.append(someAny.constraint)
            continue
        }
        if let identifier = current.as(IdentifierTypeSyntax.self) {
            let name = identifier.name.text
            if platformSwiftQualificationShadowedProtocols.contains(name) {
                results.append((name: name, position: identifier.name.positionAfterSkippingLeadingTrivia))
            }
            continue
        }
    }
    return results
}

internal final class PlatformSwiftQualificationVisitor: SyntaxVisitor {
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
            identifier: "swift protocol qualification",
            message: platformSwiftQualificationMessage
        ))
    }

    private func check(_ type: TypeSyntax) {
        for leaf in platformSwiftQualificationBareShadowedLeaves(in: type) {
            emit(at: leaf.position)
        }
    }

    override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
        // Exempt per [RULE-EXEMPT-6] (stdlib-shadow): inside an extension
        // on a stdlib type, the `Swift.<Protocol>` form the rule prescribes
        // is structurally inexpressible due to Swift name resolution.
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        check(node.type)
        return .visitChildren
    }

    override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind {
        // Exempt per [RULE-EXEMPT-6] (stdlib-shadow).
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        if let inherited = node.inheritedType {
            check(inherited)
        }
        return .visitChildren
    }

    override func visit(_ node: ConformanceRequirementSyntax) -> SyntaxVisitorContinueKind {
        // Exempt per [RULE-EXEMPT-6] (stdlib-shadow).
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        check(node.rightType)
        return .visitChildren
    }

    override func visit(_ node: SomeOrAnyTypeSyntax) -> SyntaxVisitorContinueKind {
        // Exempt per [RULE-EXEMPT-6] (stdlib-shadow).
        if platformSwiftQualificationIsInsideStdlibExtension(Syntax(node)) {
            return .visitChildren
        }
        check(node.constraint)
        return .visitChildren
    }
}

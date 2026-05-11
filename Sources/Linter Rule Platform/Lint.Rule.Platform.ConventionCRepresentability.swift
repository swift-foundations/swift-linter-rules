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

/// Wave 3 (mechanization-program) — `@convention(c)` function types
/// MUST NOT take `UnsafeMutablePointer<UserType>?` parameters where
/// `UserType` is a Swift-defined struct.
///
/// Citation: `[PLAT-ARCH-005b]` (platform skill — `@convention(c)`
/// representability pre-check).
extension Lint.Rule {
    public static let `convention c representability` = Lint.Rule(
        id: "convention c representability",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = PlatformConventionCRepresentabilityVisitor(
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
internal let platformConventionCRepresentabilityMessage: Swift.String =
    "[convention c representability] [PLAT-ARCH-005b]: `@convention(c)` "
    + "function type takes `UnsafeMutablePointer<<UserType>>?` for a "
    + "qualified type path — pure Swift structs (including @safe "
    + "wrappers) are NOT @objc-representable and the compiler rejects "
    + "them in @convention(c) signatures. Use `OpaquePointer?` or "
    + "`UnsafeMutableRawPointer?` in the callback signature; bind the "
    + "typed wrapper at the callback's first line."

internal func platformConventionCRepresentabilityHasConventionC(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        guard attr.attributeName.trimmedDescription == "convention" else { continue }
        if let arguments = attr.arguments,
           case .argumentList(let labeled) = arguments
        {
            if let first = labeled.first,
               let identifier = first.expression.as(DeclReferenceExprSyntax.self),
               identifier.baseName.text == "c"
            {
                return true
            }
        }
    }
    return false
}

/// Returns true when `type` (after stripping optional / IUO /
/// attributed wrappers) is `UnsafeMutablePointer<X>` where `X` is
/// a qualified member-type path (`A.B`-shape).
internal func platformConventionCRepresentabilityIsUnsafePointerToUserType(_ type: TypeSyntax) -> Swift.Bool {
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
    guard let identifier = current.as(IdentifierTypeSyntax.self) else {
        return false
    }
    guard identifier.name.text == "UnsafeMutablePointer"
        || identifier.name.text == "UnsafePointer"
    else { return false }
    guard let genericArgs = identifier.genericArgumentClause,
          let argument = genericArgs.arguments.first
    else { return false }
    return argument.argument.is(MemberTypeSyntax.self)
}

internal final class PlatformConventionCRepresentabilityVisitor: SyntaxVisitor {
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

    override func visit(_ node: AttributedTypeSyntax) -> SyntaxVisitorContinueKind {
        guard platformConventionCRepresentabilityHasConventionC(node.attributes) else {
            return .visitChildren
        }
        guard let function = node.baseType.as(FunctionTypeSyntax.self) else {
            return .visitChildren
        }
        for parameter in function.parameters {
            guard platformConventionCRepresentabilityIsUnsafePointerToUserType(
                parameter.type
            ) else { continue }
            let location = converter.location(for: parameter.type.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "convention c representability",
                message: platformConventionCRepresentabilityMessage
            ))
        }
        return .visitChildren
    }
}

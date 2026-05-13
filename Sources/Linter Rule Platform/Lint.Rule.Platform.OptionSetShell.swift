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

/// Wave 3 (mechanization-program) — `OptionSet` types MUST follow the
/// shell + values pattern: type body declares only `rawValue` and the
/// canonical `init(rawValue:)`. Platform-specific static constants go
/// in extensions.
///
/// Citation: `[PLAT-ARCH-013]` (platform skill — shell + values
/// OptionSet pattern).
extension Lint.Rule {
    public static let `optionset shell pattern` = Lint.Rule(
        id: "optionset shell pattern",
        default: .warning,
        findings: { source, severity in
            let visitor = PlatformOptionSetShellVisitor(
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
internal let platformOptionSetShellMessage: Swift.String =
    "[optionset shell pattern] [PLAT-ARCH-013]: OptionSet type body "
    + "contains a `static let X = Self(rawValue: …)` platform-constant "
    + "declaration. Move platform constants to an extension to preserve "
    + "the shell + values shape: L1 (or shared) declares the empty "
    + "shell, L2 / per-platform packages add constants via extension. "
    + "Authors get cross-platform layering for free; consumers see the "
    + "shell once, the platform vocabulary at each layer."

internal func platformOptionSetShellConformsToOptionSet(_ inheritanceClause: InheritanceClauseSyntax?) -> Swift.Bool {
    guard let inheritanceClause else { return false }
    for inherited in inheritanceClause.inheritedTypes {
        if let identifier = inherited.type.as(IdentifierTypeSyntax.self),
           identifier.name.text == "OptionSet"
        {
            return true
        }
        if let member = inherited.type.as(MemberTypeSyntax.self),
           member.name.text == "OptionSet",
           let base = member.baseType.as(IdentifierTypeSyntax.self),
           base.name.text == "Swift"
        {
            return true
        }
    }
    return false
}

internal func platformOptionSetShellIsStaticDecl(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
    for modifier in modifiers {
        if case .keyword(.static) = modifier.name.tokenKind {
            return true
        }
    }
    return false
}

/// Returns true when a binding's initializer expression is a call
/// to `Self(rawValue: …)` — the canonical platform-constant shape.
internal func platformOptionSetShellIsSelfRawValueInit(_ initializer: InitializerClauseSyntax?) -> Swift.Bool {
    guard let initializer else { return false }
    guard let call = initializer.value.as(FunctionCallExprSyntax.self) else {
        return false
    }
    guard let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
          callee.baseName.text == "Self"
    else { return false }
    for argument in call.arguments {
        if argument.label?.text == "rawValue" {
            return true
        }
    }
    return false
}

internal final class PlatformOptionSetShellVisitor: SyntaxVisitor {
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
        guard platformOptionSetShellConformsToOptionSet(node.inheritanceClause) else {
            return .visitChildren
        }
        for member in node.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            guard platformOptionSetShellIsStaticDecl(variable.modifiers) else {
                continue
            }
            for binding in variable.bindings {
                if platformOptionSetShellIsSelfRawValueInit(binding.initializer) {
                    let location = converter.location(for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia)
                    matches.append(Diagnostic.Record(
                        location: Source.Location(
                            fileID: source.fileID,
                            filePath: source.filePath,
                            line: location.line,
                            column: location.column
                        ),
                        severity: severity,
                        identifier: "optionset shell pattern",
                        message: platformOptionSetShellMessage
                    ))
                    break
                }
            }
        }
        return .visitChildren
    }
}

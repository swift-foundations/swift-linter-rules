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
///
/// When a concept is universal across platforms but the constants are
/// platform-specific, the institute pattern is:
///   1. L1 defines the empty OptionSet shell — `rawValue` storage and
///      `init(rawValue:)` only.
///   2. L2 (or each platform package) adds platform-specific static
///      constants via extension.
///
/// Placing platform constants directly in the L1 shell body couples
/// the L1 declaration to a specific platform's vocabulary and makes
/// cross-platform layering impossible.
///
/// AST shape: walk `StructDeclSyntax` whose inheritance clause includes
/// `OptionSet` (or `Swift.OptionSet`). Check member block for
/// `VariableDeclSyntax` with `static let` and an `Self(rawValue: ...)`
/// initializer expression. Each such declaration is the "platform
/// constant in shell body" violation; flag the `static` keyword.
///
/// Worked examples (flagged):
///   - `struct Options: OptionSet { let rawValue: Int32; public static
///     let create = Self(rawValue: O_CREAT) }` — `create` is a
///     platform constant in the shell body; move to an extension.
///
/// Worked examples (NOT flagged):
///   - `struct Options: OptionSet { let rawValue: Int32; init(rawValue:
///     Int32) { self.rawValue = rawValue } }` — clean shell.
///   - `extension Options { static let create = Self(rawValue: O_CREAT) }`
///     — platform constants in extension, correct shape.
///   - Type doesn't conform to OptionSet — out of scope.
extension Lint.Rule.Platform {
    public struct OptionSetShell: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "optionset_shell_pattern"
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

extension Lint.Rule.Platform.OptionSetShell {
    @usableFromInline
    static let message: Swift.String =
        "[optionset_shell_pattern] [PLAT-ARCH-013]: OptionSet type body "
        + "contains a `static let X = Self(rawValue: …)` platform-constant "
        + "declaration. Move platform constants to an extension to preserve "
        + "the shell + values shape: L1 (or shared) declares the empty "
        + "shell, L2 / per-platform packages add constants via extension. "
        + "Authors get cross-platform layering for free; consumers see the "
        + "shell once, the platform vocabulary at each layer."

    static func conformsToOptionSet(_ inheritanceClause: InheritanceClauseSyntax?) -> Swift.Bool {
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

    static func isStaticDecl(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
        for modifier in modifiers {
            if case .keyword(.static) = modifier.name.tokenKind {
                return true
            }
        }
        return false
    }

    /// Returns true when a binding's initializer expression is a call
    /// to `Self(rawValue: …)` — the canonical platform-constant shape.
    static func isSelfRawValueInit(_ initializer: InitializerClauseSyntax?) -> Swift.Bool {
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
            guard Lint.Rule.Platform.OptionSetShell.conformsToOptionSet(node.inheritanceClause) else {
                return .visitChildren
            }
            for member in node.memberBlock.members {
                guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
                guard Lint.Rule.Platform.OptionSetShell.isStaticDecl(variable.modifiers) else {
                    continue
                }
                for binding in variable.bindings {
                    if Lint.Rule.Platform.OptionSetShell.isSelfRawValueInit(binding.initializer) {
                        let location = converter.location(for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia)
                        matches.append(Diagnostic.Record(
                            location: Source.Location(
                                fileID: source.fileID,
                                filePath: source.filePath,
                                line: location.line,
                                column: location.column
                            ),
                            severity: severity,
                            identifier: Lint.Rule.Platform.OptionSetShell.id.underlying,
                            message: Lint.Rule.Platform.OptionSetShell.message
                        ))
                        break
                    }
                }
            }
            return .visitChildren
        }
    }
}

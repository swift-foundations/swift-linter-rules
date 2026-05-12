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

/// Wave 4 (mechanization-program) — throwing wrapper `init` whose body
/// is `try base.init(...)` and nothing else MUST also validate the
/// wrapper's stricter invariant.
///
/// Citation: `[PATTERN-020]` (implementation skill, patterns.md —
/// throwing init on wrapper MUST NOT validate only base invariant).
extension Lint.Rule {
    public static let `throwing wrapper init` = Lint.Rule(
        id: "throwing wrapper init",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = StructureThrowingWrapperInitVisitor(
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
internal let structureThrowingWrapperInitMessage: Swift.String =
    "[throwing wrapper init] [PATTERN-020]: throwing init body "
    + "is a single `try base.init(...)` forward with no additional validation. "
    + "If the wrapper specializes to a stricter invariant than its base, the "
    + "wrapper's invariant is silently violable. Add the wrapper's validation "
    + "after the base-init call, or rewrite the init to validate the wrapper "
    + "invariant directly."

/// Stdlib primitive types whose extensions are NOT institute wrappers
/// adding stricter invariants — the rule's "wrapper specializes
/// stricter invariant than its base" premise is structurally inverted
/// when the init's enclosing type is one of these.
///
/// An `extension Int` init that accepts an institute Tagged type as a
/// parameter and forwards via `try Int(stripped)` is the LAX type
/// being constructed from a STRICTER source — the body's validation
/// (overflow / range check) is exactly what's needed; there is no
/// "wrapper invariant" to additionally enforce. Firing the rule here
/// inverts the premise.
///
/// Curated allowlist; adding entries requires verifying the type has
/// no additional invariants beyond the body of the throwing init.
@usableFromInline
internal let structureThrowingWrapperInitLaxTypeAllowlist: Swift.Set<Swift.String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Float", "Float16", "Float32", "Float64", "Float80", "Double",
    "Bool",
    "String", "Substring", "Character",
]

internal final class StructureThrowingWrapperInitVisitor: SyntaxVisitor {
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

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.signature.effectSpecifiers?.throwsClause != nil else {
            return .visitChildren
        }
        guard let body = node.body else { return .visitChildren }
        let statements = body.statements
        guard statements.count == 1 else { return .visitChildren }
        guard let only = statements.first?.item else { return .visitChildren }
        guard isTryExpression(Syntax(only)) else { return .visitChildren }
        // Skip when the init's enclosing type is a stdlib lax primitive
        // (Int, UInt, Float, etc.). The rule's "wrapper specializes
        // stricter invariant than its base" premise inverts when the
        // enclosing type IS the lax type and the parameter is the
        // stricter institute type — the body's validation (overflow /
        // range check from `try Int(stripped)`) is exactly what's
        // needed; there is no wrapper invariant to additionally enforce.
        if isInsideExtensionOnLaxType(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.initKeyword.positionAfterSkippingLeadingTrivia
        )
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "throwing wrapper init",
            message: structureThrowingWrapperInitMessage
        ))
        return .visitChildren
    }

    private func isInsideExtensionOnLaxType(_ node: Syntax) -> Swift.Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                if let identifier = ext.extendedType.as(IdentifierTypeSyntax.self) {
                    return structureThrowingWrapperInitLaxTypeAllowlist.contains(identifier.name.text)
                }
                if let member = ext.extendedType.as(MemberTypeSyntax.self) {
                    return structureThrowingWrapperInitLaxTypeAllowlist.contains(member.name.text)
                }
                return false
            }
            // Once we cross a type-decl boundary that ISN'T an extension
            // (struct / class / enum / actor / protocol), the rule's
            // wrapper premise applies and the allowlist doesn't cover.
            if candidate.is(StructDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self)
                || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ActorDeclSyntax.self)
                || candidate.is(ProtocolDeclSyntax.self) {
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private func isTryExpression(_ syntax: Syntax) -> Swift.Bool {
        if syntax.is(TryExprSyntax.self) {
            return true
        }
        if let expression = syntax.as(ExprSyntax.self),
           expression.is(TryExprSyntax.self) {
            return true
        }
        if let sequence = syntax.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                if element.is(TryExprSyntax.self) {
                    return true
                }
            }
        }
        return false
    }
}

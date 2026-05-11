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

/// Wave-1 — compound identifiers (verb-noun camelCase methods/properties).
///
/// Citation: [API-NAME-002].
///
/// Methods and properties MUST NOT use compound names — use nested
/// accessors instead (`instance.open.write { }` not `instance.openWrite { }`).
/// Compound type names are governed by [API-NAME-001] and require
/// type-info to disambiguate spec-mirroring exceptions; this rule
/// targets only the lower-risk method / property compound case.
extension Lint.Rule {
    public static let `compound identifier` = Lint.Rule(
        id: "compound_identifier",
        defaultSeverity: .warning,
        findings: { source, severity in
            let visitor = NamingCompoundVisitor(
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
internal let namingCompoundMessage: Swift.String =
    "[compound_identifier] [API-NAME-002]: methods and properties MUST NOT use "
    + "compound names. Use nested accessors instead (e.g., `instance.open.write { }` "
    + "not `instance.openWrite { }`; `dir.walk.files()` not `dir.walkFiles()`). "
    + "Boolean prefixes (`is`, `has`, `should`, `will`, `did`, `can`, `must`) are "
    + "exempt; spec-mirroring identifiers are exempt; `package`-scope declarations "
    + "are exempt per `feedback_compound_package_scope`."

@usableFromInline
internal let namingCompoundBooleanPrefixes: [Swift.String] = ["is", "has", "should", "will", "did", "can", "must"]

@usableFromInline
internal let namingCompoundStdlibIdiomNames: Swift.Set<Swift.String> = [
    "rawValue",
    "customMirror",
    "description",
    "debugDescription",
    "hashValue",
    "bitPattern",
    "startIndex",
    "endIndex",
]

internal final class NamingCompoundVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !hasPackageModifier(node.modifiers) else {
            return .visitChildren
        }
        let name = node.name.text
        guard isCompoundIdentifier(name) else {
            return .visitChildren
        }
        // Exempt result-builder protocol methods inside an `@resultBuilder`
        // type — `buildExpression`, `buildPartialBlock`, etc. read as
        // compound only because the protocol mandates camelCase names.
        if namingResultBuilderProtocolMethods.contains(name),
           namingIsInsideResultBuilderType(Syntax(node)) {
            return .visitChildren
        }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !hasPackageModifier(node.modifiers) else {
            return .visitChildren
        }
        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            let name = pattern.identifier.text
            guard isCompoundIdentifier(name) else {
                continue
            }
            emit(at: pattern.identifier.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    private func hasPackageModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.package) {
                return true
            }
        }
        return false
    }

    private func isCompoundIdentifier(_ name: Swift.String) -> Bool {
        guard !namingCompoundStdlibIdiomNames.contains(name) else {
            return false
        }
        for prefix in namingCompoundBooleanPrefixes {
            if name.hasPrefix(prefix), name.count > prefix.count {
                let nextIndex = name.index(name.startIndex, offsetBy: prefix.count)
                if name[nextIndex].isUppercase {
                    return false
                }
            }
        }
        var sawLowercase = false
        var sawUppercaseAfterLowercase = false
        for (offset, character) in name.enumerated() {
            if offset == 0 {
                guard character.isLowercase else {
                    return false
                }
                sawLowercase = true
                continue
            }
            if character.isUppercase, sawLowercase {
                sawUppercaseAfterLowercase = true
                break
            }
            if character.isLowercase || character.isNumber || character == "_" {
                continue
            }
            return false
        }
        return sawUppercaseAfterLowercase
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
            identifier: "compound_identifier",
            message: namingCompoundMessage
        ))
    }
}

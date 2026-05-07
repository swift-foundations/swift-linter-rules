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
///
/// Detection: identifier text matches `^[a-z][a-z0-9]*[A-Z][a-zA-Z0-9]*$`
/// — lowercase-first followed by an internal capital — at function
/// declaration sites and variable binding sites. Exempted:
/// - Boolean conventions: `is...`, `has...`, `should...`, `will...`,
///   `did...`, `can...`, `must...` per the [API-NAME-002] boolean
///   exception.
/// - Identifiers that are common stdlib / convention idioms: `rawValue`,
///   `customMirror`, `description`, `debugDescription`, `hashValue`,
///   `bitPattern`, `endIndex`, `startIndex`.
///
/// Excluded scopes:
/// - `package`-scoped declarations per `feedback_compound_package_scope`
///   (compound permitted at package scope for internal impl).
/// - Function parameter labels (signature ergonomics often require
///   compound `at`/`with` style; rule visits decl names only).
extension Lint.Rule {
    public struct CompoundIdentifier: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "compound_identifier"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}

extension Lint.Rule.CompoundIdentifier {
    @usableFromInline
    static let message: Swift.String =
        "[compound_identifier] [API-NAME-002]: methods and properties MUST NOT use "
        + "compound names. Use nested accessors instead (e.g., `instance.open.write { }` "
        + "not `instance.openWrite { }`; `dir.walk.files()` not `dir.walkFiles()`). "
        + "Boolean prefixes (`is`, `has`, `should`, `will`, `did`, `can`, `must`) are "
        + "exempt; spec-mirroring identifiers are exempt; `package`-scope declarations "
        + "are exempt per `feedback_compound_package_scope`."

    @usableFromInline
    static let booleanPrefixes: [Swift.String] = ["is", "has", "should", "will", "did", "can", "must"]

    @usableFromInline
    static let stdlibIdiomNames: Swift.Set<Swift.String> = [
        "rawValue",
        "customMirror",
        "description",
        "debugDescription",
        "hashValue",
        "bitPattern",
        "startIndex",
        "endIndex",
    ]

    final class Visitor: SyntaxVisitor {
        let source: Source.File
        let severity: Diagnostic.Severity
        let converter: SourceLocationConverter
        var matches: [Lint.Finding] = []

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
            guard !Lint.Rule.CompoundIdentifier.stdlibIdiomNames.contains(name) else {
                return false
            }
            for prefix in Lint.Rule.CompoundIdentifier.booleanPrefixes {
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
            matches.append(Lint.Finding(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.CompoundIdentifier.id.underlying,
                message: Lint.Rule.CompoundIdentifier.message
            ))
        }
    }
}

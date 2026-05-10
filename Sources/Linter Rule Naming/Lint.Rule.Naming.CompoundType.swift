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

/// Wave 1 (mechanization-program) — compound type names at declaration site.
///
/// Citation: `[API-NAME-001]` (code-surface skill — Nest.Name pattern).
///
/// All types MUST use `Nest.Name`; compound type names like
/// `FileDirectoryWalk`, `DirectoryWalk`, or `NonBlockingSelector` are
/// forbidden — the correct shape is the nested form
/// (`File.Directory.Walk`, `IO.NonBlocking.Selector`).
///
/// The companion rule `Lint.Rule.Naming.Compound` flags compound
/// METHOD / PROPERTY identifiers (lowercase-first); this rule flags
/// compound TYPE identifiers (uppercase-first) at declaration sites:
/// `struct`, `class`, `enum`, `actor`, `protocol`.
///
/// Detection: a "word" begins at index 0 OR at any uppercase letter
/// preceded by a lowercase letter, OR at any uppercase letter preceded
/// by uppercase but followed by lowercase (acronym → CamelCase boundary).
/// Two or more words = compound = flagged.
///
/// Worked examples (flagged):
///   - `FileDirectoryWalk`  → words: File / Directory / Walk
///   - `DirectoryWalk`      → words: Directory / Walk
///   - `NonBlockingSelector` → words: Non / Blocking / Selector
///   - `IOError`            → words: IO / Error (acronym → word boundary)
///   - `URLPath`            → words: URL / Path
///
/// Worked examples (NOT flagged):
///   - `Foo`, `Walk`, `Selector` → single word
///   - `URL`, `UUID`, `IO`, `JSON` → acronym only, single word
///   - `RFC_4122`, `ISO_9945`     → spec-namespace form (underscore present
///     → not evaluated under this rule; spec-mirroring per `[API-NAME-003]`)
///   - `_BoxStorage` (leading underscore) → SPI/internal helper, exempt
///
/// Excluded scopes:
/// - `package`-scoped declarations (compound permitted at package scope
///   per the existing `Lint.Rule.Naming.Compound` precedent).
/// - Macro declarations (`MacroDeclSyntax`) — `[API-NAME-001]` exempts
///   macros, which MUST use compound names at file scope (`@CoW`,
///   `@Defunctionalize`).
/// - Identifiers containing an underscore (treated as spec-namespace
///   form per `[API-NAME-003]`).
extension Lint.Rule.Naming {
    public struct CompoundType: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "compound_type_name"
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

extension Lint.Rule.Naming.CompoundType {
    @usableFromInline
    static let message: Swift.String =
        "[compound_type_name] [API-NAME-001]: types MUST use the `Nest.Name` "
        + "pattern. Compound type names like `FileDirectoryWalk` or "
        + "`DirectoryWalk` are forbidden — use the nested form "
        + "(`File.Directory.Walk`). Acronyms (`URL`, `UUID`, `IO`) are "
        + "permitted as single-word names; spec-namespace forms with "
        + "underscores (`RFC_4122`, `ISO_9945`) are exempt per "
        + "`[API-NAME-003]`. `package`-scope declarations and macro decls "
        + "are exempt."

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
            check(name: node.name, modifiers: node.modifiers)
            return .visitChildren
        }
        override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            check(name: node.name, modifiers: node.modifiers)
            return .visitChildren
        }
        override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            check(name: node.name, modifiers: node.modifiers)
            return .visitChildren
        }
        override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            check(name: node.name, modifiers: node.modifiers)
            return .visitChildren
        }
        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            check(name: node.name, modifiers: node.modifiers)
            return .visitChildren
        }

        // Macros are exempt per [API-NAME-001] — descend without checking.
        override func visit(_: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
            .visitChildren
        }

        private func check(name token: TokenSyntax, modifiers: DeclModifierListSyntax) {
            guard !hasPackageModifier(modifiers) else { return }
            let text = token.text
            guard isCompoundTypeIdentifier(text) else { return }
            let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: Lint.Rule.Naming.CompoundType.id.underlying,
                message: Lint.Rule.Naming.CompoundType.message
            ))
        }

        private func hasPackageModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
            for modifier in modifiers {
                if modifier.name.tokenKind == .keyword(.package) {
                    return true
                }
            }
            return false
        }

        private func isCompoundTypeIdentifier(_ name: Swift.String) -> Bool {
            // Spec-namespace forms (`RFC_4122`, `ISO_9945`) — exempt.
            if name.contains("_") { return false }
            // Empty / single-char names — degenerate, not compound.
            guard name.count >= 2 else { return false }
            // Must start with uppercase to be a type identifier (sanity).
            let chars = Array(name)
            guard chars[0].isUppercase else { return false }
            // Word-boundary count.
            var words = 1
            var i = 1
            while i < chars.count {
                let prev = chars[i - 1]
                let curr = chars[i]
                let next: Swift.Character? = i + 1 < chars.count ? chars[i + 1] : nil
                if curr.isUppercase {
                    // lowercase → uppercase: word boundary (FooBar)
                    if prev.isLowercase {
                        words += 1
                    } else if prev.isUppercase, let next, next.isLowercase {
                        // uppercase → uppercase → lowercase: acronym → word
                        // boundary (IOError ⇒ IO + Error at the E).
                        words += 1
                    }
                }
                if words >= 2 { return true }
                i += 1
            }
            return false
        }
    }
}
